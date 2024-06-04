// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20VotesUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC4626Upgradeable, Math } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { ICyberStakingPool } from "./interfaces/ICyberStakingPool.sol";

struct LockAmount {
    uint256 lockEnd;
    uint256 lockedShares;
    uint256 lockedAssets;
}

/**
 * @title CyberVault
 * @author Cyber
 */
contract CyberVault is
    ERC4626Upgradeable,
    ERC20VotesUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                            EVENT
    //////////////////////////////////////////////////////////////*/

    event InitiateWithdraw(
        address account,
        uint256 shares,
        uint256 totalLockedShares,
        uint256 assets,
        uint256 totalLockedAssets,
        uint256 lockEnd
    );
    event CollectFee(uint256 protocolFee, address protocolFeeTreasury);

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev MAX_BPS the maximum number of basis points.
    /// 10000 basis points are equivalent to 100%.
    uint256 public constant MAX_BPS = 1e4;

    ICyberStakingPool public cyberStakingPool;
    uint256 public lockDuration;
    uint256 public protocolFeeBps;
    address public protocolFeeTreasury;
    mapping(address => LockAmount) internal _lockAmounts;

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR & INITIALIZER
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        IERC20 _cyber,
        address _stakingPool,
        address _protocolFeeTreasury
    ) external initializer {
        __ERC4626_init(_cyber);
        __ERC20_init("Compound CYBER", "cCYBER");
        __EIP712_init("Compound CYBER", "1");
        __Ownable_init(_owner);
        __Pausable_init();

        protocolFeeTreasury = _protocolFeeTreasury;
        cyberStakingPool = ICyberStakingPool(_stakingPool);
        lockDuration = 7 days;
        protocolFeeBps = 1000;
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDE 
    //////////////////////////////////////////////////////////////*/

    /** @dev See {IERC4626-totalAssets}. */
    function totalAssets() public view override returns (uint256) {
        return
            cyberStakingPool.balanceOf(address(this)) +
            cyberStakingPool.lockedAmountByUser(address(this)) +
            cyberStakingPool.claimableAllRewards(address(this)) +
            IERC20(asset()).balanceOf(address(this));
    }

    /** @dev See {IERC4626-previewDeposit}. */
    function previewDeposit(
        uint256 assets
    ) public view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor, true);
    }

    /** @dev See {IERC4626-previewMint}. */
    function previewMint(
        uint256 shares
    ) public view override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil, true);
    }

    /** @dev See {IERC4626-previewWithdraw}. */
    function previewWithdraw(
        uint256 assets
    ) public view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil, true);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(
        uint256 shares
    ) public view override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor, true);
    }

    /** @dev See {IERC4626-deposit}. */
    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256) {
        claim();
        uint256 maxAssets = maxDeposit(receiver);
        require(assets <= maxAssets, "EXCEED_MAX_DEPOSIT");
        uint256 shares = _previewDepositInternal(assets);
        _deposit(msg.sender, receiver, assets, shares);
        stake();
        return shares;
    }

    /** @dev See {IERC4626-mint}. */
    function mint(
        uint256 shares,
        address receiver
    ) public override returns (uint256) {
        claim();
        uint256 maxShares = maxMint(receiver);
        require(shares <= maxShares, "EXCEED_MAX_MINT");
        uint256 assets = _previewMintInternal(shares);
        _deposit(msg.sender, receiver, assets, shares);
        stake();
        return assets;
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address _owner
    ) public override returns (uint256) {
        LockAmount memory lockAmount = _lockAmounts[_owner];
        require(assets == lockAmount.lockedAssets, "INVALID_ASSETS");
        _withdraw(
            msg.sender,
            receiver,
            _owner,
            assets,
            lockAmount.lockedShares
        );
        return lockAmount.lockedShares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(
        uint256 shares,
        address receiver,
        address _owner
    ) public override returns (uint256) {
        LockAmount memory lockAmount = _lockAmounts[_owner];
        require(shares == lockAmount.lockedShares, "INVALID_SHARES");
        _withdraw(
            msg.sender,
            receiver,
            _owner,
            lockAmount.lockedAssets,
            shares
        );
        return lockAmount.lockedAssets;
    }

    function _withdraw(
        address caller,
        address receiver,
        address _owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        LockAmount memory lockAmount = _lockAmounts[_owner];
        require(lockAmount.lockEnd != 0, "NOT_AVAILABLE_TO_WITHDRAW");
        require(
            lockAmount.lockEnd <= block.timestamp,
            "LOCKED_PERIOD_NOT_ENDED"
        );
        require(lockAmount.lockedShares >= shares, "INSUFFICIENT_BALANCE");
        delete _lockAmounts[_owner];

        if (caller != _owner) {
            _spendAllowance(_owner, caller, shares);
        }
        _burn(address(this), shares);
        bytes32 key = bytes32(uint256(uint160(_owner)));
        cyberStakingPool.withdraw(key);
        IERC20(asset()).safeTransfer(receiver, assets);
        emit Withdraw(caller, receiver, _owner, assets, shares);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        ERC20VotesUpgradeable._update(from, to, value);
    }

    function decimals()
        public
        view
        override(ERC4626Upgradeable, ERC20Upgradeable)
        returns (uint8)
    {
        return IERC20Metadata(asset()).decimals();
    }

    function _authorizeUpgrade(address) internal view override {
        require(msg.sender == owner(), "ONLY_OWNER");
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL 
    //////////////////////////////////////////////////////////////*/

    function initiateRedeem(uint256 shares) external returns (uint256) {
        claimAndStake();
        uint256 maxShares = maxRedeem(msg.sender);
        require(shares <= maxShares, "EXCEED_MAX_REDEEM");
        uint256 assets = _previewRedeemInternal(shares);
        _initiateWithdraw(shares, assets);
        return assets;
    }

    function initiateWithdraw(uint256 assets) external returns (uint256) {
        claimAndStake();
        uint256 maxAssets = maxWithdraw(msg.sender);
        require(assets <= maxAssets, "EXCEED_MAX_WITHDRAW");
        uint256 shares = _previewWithdrawInternal(assets);
        _initiateWithdraw(shares, assets);
        return shares;
    }

    function getLockAmount(
        address account
    ) external view returns (LockAmount memory) {
        return _lockAmounts[account];
    }

    function stake() public {
        uint256 amount = IERC20(asset()).balanceOf(address(this));
        if (
            amount != 0 &&
            amount + cyberStakingPool.balanceOf(address(this)) >=
            cyberStakingPool.minimalStakeAmount()
        ) {
            IERC20(asset()).approve(address(cyberStakingPool), amount);
            cyberStakingPool.stake(amount);
        }
    }

    function claim() public returns (uint256 protocolFeeAssets) {
        uint256 rewards = cyberStakingPool.claimAllRewards();
        protocolFeeAssets = (rewards * protocolFeeBps) / MAX_BPS;
        if (protocolFeeAssets == 0) {
            return protocolFeeAssets;
        }
        IERC20(asset()).safeTransfer(protocolFeeTreasury, protocolFeeAssets);
        emit CollectFee(protocolFeeAssets, protocolFeeTreasury);
    }

    function claimAndStake() public {
        claim();
        stake();
    }

    function batchDeposit(
        uint256[] calldata assets,
        address[] calldata receivers
    ) external {
        require(assets.length == receivers.length, "INVALID_LENGTH");
        claim();
        uint256 totalDeposit = 0;
        uint256[] memory shares = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            require(assets[i] != 0, "ZERO_AMOUNT");
            totalDeposit += assets[i];
            shares[i] = _previewDepositInternal(assets[i]);
        }

        for (uint256 i = 0; i < shares.length; i++) {
            _mint(receivers[i], shares[i]);
            emit Deposit(msg.sender, receivers[i], assets[i], shares[i]);
        }

        IERC20(asset()).safeTransferFrom(
            msg.sender,
            address(this),
            totalDeposit
        );
        stake();
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER
    //////////////////////////////////////////////////////////////*/
    function setLockDuration(uint256 _lockDuration) external onlyOwner {
        lockDuration = _lockDuration;
    }

    function setProtocolFeeBps(uint256 _protocolFeeBps) external onlyOwner {
        require(_protocolFeeBps <= MAX_BPS, "INVALID_PROTOCOL_FEE_BPS");
        protocolFeeBps = _protocolFeeBps;
    }

    function setProtocolFeeTreasury(
        address _protocolFeeTreasury
    ) external onlyOwner {
        protocolFeeTreasury = _protocolFeeTreasury;
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE
    //////////////////////////////////////////////////////////////*/
    function _initiateWithdraw(uint256 shares, uint256 assets) private {
        require(shares != 0, "ZERO_AMOUNT");

        _transfer(msg.sender, address(this), shares);

        bytes32 key = bytes32(uint256(uint160(msg.sender)));
        cyberStakingPool.unstake(assets, key);

        LockAmount memory lockAmount = _lockAmounts[msg.sender];
        lockAmount.lockedShares += shares;
        lockAmount.lockedAssets += assets;
        lockAmount.lockEnd = block.timestamp + lockDuration;

        _lockAmounts[msg.sender] = lockAmount;

        emit InitiateWithdraw(
            msg.sender,
            shares,
            lockAmount.lockedShares,
            assets,
            lockAmount.lockedAssets,
            lockAmount.lockEnd
        );
    }

    function _convertToShares(
        uint256 assets,
        Math.Rounding rounding,
        bool countFee
    ) private view returns (uint256) {
        uint256 totalAssets_;
        if (countFee) {
            totalAssets_ = _totalAssetsWithoutFee();
        } else {
            totalAssets_ = totalAssets();
        }
        return
            assets.mulDiv(
                totalSupply() + 10 ** _decimalsOffset(),
                totalAssets_ + 1,
                rounding
            );
    }

    function _convertToAssets(
        uint256 shares,
        Math.Rounding rounding,
        bool countFee
    ) private view returns (uint256) {
        uint256 totalAssets_;
        if (countFee) {
            totalAssets_ = _totalAssetsWithoutFee();
        } else {
            totalAssets_ = totalAssets();
        }
        return
            shares.mulDiv(
                totalAssets_ + 1,
                totalSupply() + 10 ** _decimalsOffset(),
                rounding
            );
    }

    function _totalAssetsWithoutFee() private view returns (uint256) {
        uint256 claimable = cyberStakingPool.claimableAllRewards(address(this));
        uint256 protocolFee = (claimable * protocolFeeBps) / MAX_BPS;

        return
            claimable -
            protocolFee +
            cyberStakingPool.balanceOf(address(this)) +
            cyberStakingPool.lockedAmountByUser(address(this)) +
            IERC20(asset()).balanceOf(address(this));
    }

    function _previewDepositInternal(
        uint256 assets
    ) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor, false);
    }

    function _previewMintInternal(
        uint256 shares
    ) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil, false);
    }

    function _previewWithdrawInternal(
        uint256 assets
    ) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil, false);
    }

    function _previewRedeemInternal(
        uint256 shares
    ) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor, false);
    }
}
