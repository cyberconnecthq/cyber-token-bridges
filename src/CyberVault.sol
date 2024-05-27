// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC4626, Math } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { IOAppComposer } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppComposer.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

import { DataTypes } from "./libraries/DataTypes.sol";

import { ICyberStakingPool } from "./interfaces/ICyberStakingPool.sol";

/**
 * @title CyberVault
 * @author Cyber
 */
contract CyberVault is ERC4626, ERC20Votes, Pausable, Ownable, IOAppComposer {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            EVENT
    //////////////////////////////////////////////////////////////*/

    event LzCompose(address oApp, address account, uint256 amount);
    event InitiateWithdraw(
        address account,
        uint256 amount,
        uint256 totalLocked,
        uint256 lockEnd
    );

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    ICyberStakingPool public immutable cyberStakingPool;
    address public immutable lzEndpoint;
    uint256 public lockDuration;
    address public oApp;
    mapping(address => DataTypes.LockAmount) internal _lockAmounts;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _owner,
        address _lzEndpoint,
        IERC20 _cyber,
        address _stakingPool
    )
        ERC4626(_cyber)
        ERC20("Compound CYBER", "cCYBER")
        EIP712("Compound CYBER", "1")
        Ownable(_owner)
    {
        lzEndpoint = _lzEndpoint;
        cyberStakingPool = ICyberStakingPool(_stakingPool);
        lockDuration = 7 days;
        _pause();
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDE 
    //////////////////////////////////////////////////////////////*/

    /** @dev See {IERC4626-totalAssets}. */
    function totalAssets() public view override returns (uint256) {
        return cyberStakingPool.balanceOf(address(this));
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address _owner
    ) public override returns (uint256) {
        uint256 shares = previewWithdraw(assets);
        _withdraw(msg.sender, receiver, _owner, assets, shares);
        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(
        uint256 shares,
        address receiver,
        address _owner
    ) public override returns (uint256) {
        uint256 assets = previewRedeem(shares);
        _withdraw(msg.sender, receiver, _owner, assets, shares);
        return assets;
    }

    function _withdraw(
        address caller,
        address receiver,
        address _owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        require(_lockAmounts[_owner].lockEnd != 0, "NOT_AVAILABLE_TO_WITHDRAW");
        require(
            _lockAmounts[_owner].lockEnd <= block.timestamp,
            "LOCKED_PERIOD_NOT_ENDED"
        );
        require(_lockAmounts[_owner].amount >= shares, "INSUFFICIENT_BALANCE");
        _lockAmounts[_owner].amount -= shares;

        if (caller != _owner) {
            _spendAllowance(_owner, caller, shares);
        }
        _burn(address(this), shares);
        IERC20(asset()).safeTransfer(receiver, assets);
        emit Withdraw(caller, receiver, _owner, assets, shares);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20, ERC20Votes) {
        ERC20Votes._update(from, to, value);
    }

    function decimals() public view override(ERC4626, ERC20) returns (uint8) {
        return IERC20Metadata(asset()).decimals();
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL 
    //////////////////////////////////////////////////////////////*/

    function initiateRedeem(uint256 shares) external {
        uint256 maxShares = maxRedeem(msg.sender);
        require(shares <= maxShares, "EXCEED_MAX_REDEEM");
        _initiateWithdraw(shares);
    }

    function initiateWithdraw(uint256 assets) external {
        uint256 maxAssets = maxWithdraw(msg.sender);
        require(assets <= maxAssets, "EXCEED_MAX_WITHDRAW");
        uint256 shares = previewWithdraw(assets);
        _initiateWithdraw(shares);
    }

    function getLockAmount(
        address account
    ) external view returns (DataTypes.LockAmount memory) {
        return _lockAmounts[account];
    }

    function stake() external {
        uint256 amount = IERC20(asset()).balanceOf(address(this));
        require(amount != 0, "ZERO_AMOUNT");
        IERC20(asset()).approve(address(cyberStakingPool), amount);
        cyberStakingPool.stake(amount);
    }

    function claim(uint16 distributionId) external {
        cyberStakingPool.claimReward(distributionId);
    }

    function lzCompose(
        address _oApp,
        bytes32 /*_guid*/,
        bytes calldata message,
        address /*Executor*/,
        bytes calldata /*Executor Data*/
    ) external payable override {
        require(_oApp == oApp, "OAPP_NOT_ALLOWED");
        require(msg.sender == lzEndpoint, "SENDER_NOT_ALLOWED");

        // Extract the composed message from the delivered message using the MsgCodec
        bytes memory composeMsgContent = OFTComposeMsgCodec.composeMsg(message);
        (address account, uint256 assets) = abi.decode(
            composeMsgContent,
            (address, uint256)
        );

        uint256 shares = previewDeposit(assets);
        _mint(account, shares);
        emit Deposit(address(this), account, assets, shares);
        emit LzCompose(oApp, account, assets);
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

    /*//////////////////////////////////////////////////////////////
                            PRIVATE
    //////////////////////////////////////////////////////////////*/
    function _initiateWithdraw(uint256 shares) private {
        require(shares != 0, "ZERO_AMOUNT");

        _transfer(msg.sender, address(this), shares);

        DataTypes.LockAmount memory lockAmount = _lockAmounts[msg.sender];
        lockAmount.amount += shares;
        lockAmount.lockEnd = block.timestamp + lockDuration;
        _lockAmounts[msg.sender] = lockAmount;

        emit InitiateWithdraw(
            msg.sender,
            shares,
            lockAmount.amount,
            lockAmount.lockEnd
        );
    }
}
