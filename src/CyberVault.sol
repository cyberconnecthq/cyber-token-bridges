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
    address public lzEndpoint;
    uint256 public lockDuration;
    address public oApp;
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
        address _lzEndpoint,
        IERC20 _cyber,
        address _stakingPool,
        address _protocolFeeTreasury
    ) external initializer {
        __ERC4626_init(_cyber);
        __ERC20_init("Compound CYBER", "cCYBER");
        __EIP712_init("Compound CYBER", "1");
        __Ownable_init(_owner);
        __Pausable_init();

        lzEndpoint = _lzEndpoint;
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
            cyberStakingPool.totalLockedAmount(address(this)) +
            IERC20(asset()).balanceOf(address(this));
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

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        super._deposit(caller, receiver, assets, shares);
        stake();
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

    function initiateRedeem(uint256 shares) external {
        claim();
        uint256 maxShares = maxRedeem(msg.sender);
        require(shares <= maxShares, "EXCEED_MAX_REDEEM");
        _initiateWithdraw(shares);
    }

    function initiateWithdraw(uint256 assets) external {
        claim();
        uint256 maxAssets = maxWithdraw(msg.sender);
        require(assets <= maxAssets, "EXCEED_MAX_WITHDRAW");
        uint256 shares = previewWithdraw(assets);
        _initiateWithdraw(shares);
    }

    function getLockAmount(
        address account
    ) external view returns (LockAmount memory) {
        return _lockAmounts[account];
    }

    function stake() public {
        uint256 amount = IERC20(asset()).balanceOf(address(this));
        if (
            amount + cyberStakingPool.balanceOf(address(this)) >=
            cyberStakingPool.minimalStakeAmount()
        ) {
            IERC20(asset()).approve(address(cyberStakingPool), amount);
            cyberStakingPool.stake(amount);
        }
    }

    function claim() public {
        uint256 rewards = cyberStakingPool.claimAllRewards();
        uint256 protocolFeeAmount = (rewards * protocolFeeBps) / MAX_BPS;
        if (protocolFeeAmount == 0) {
            return;
        }
        uint256 shares = previewDeposit(protocolFeeAmount);
        _mint(protocolFeeTreasury, shares);
        emit Deposit(
            address(this),
            protocolFeeTreasury,
            protocolFeeAmount,
            shares
        );
        emit CollectFee(protocolFeeAmount, protocolFeeTreasury);
    }

    function claimAndStake() external {
        claim();
        stake();
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER
    //////////////////////////////////////////////////////////////*/
    function setLockDuration(uint256 _lockDuration) external onlyOwner {
        lockDuration = _lockDuration;
    }

    function setOApp(address _oApp) external onlyOwner {
        oApp = _oApp;
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
    function _initiateWithdraw(uint256 shares) private {
        require(shares != 0, "ZERO_AMOUNT");

        _transfer(msg.sender, address(this), shares);

        uint256 assets = previewRedeem(shares);
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
}
