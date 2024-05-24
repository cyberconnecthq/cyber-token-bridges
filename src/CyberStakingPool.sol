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

struct LockAmount {
    uint256 lockEnd;
    uint256 amount;
}

/**
 * @title CyberStakingPool
 * @author Cyber
 */
contract CyberStakingPool is
    ERC4626,
    ERC20Votes,
    Pausable,
    Ownable,
    IOAppComposer
{
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

    address public immutable lzEndpoint;
    uint256 public lockDuration;
    address public oApp;
    mapping(address => LockAmount) internal _lockAmounts;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _owner,
        address _lzEndpoint,
        IERC20 _cyber
    )
        ERC4626(_cyber)
        ERC20("Staked CYBER", "stCYBER")
        EIP712("Staked CYBER", "1")
        Ownable(_owner)
    {
        lzEndpoint = _lzEndpoint;
        lockDuration = 7 days;
        _pause();
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDE 
    //////////////////////////////////////////////////////////////*/

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address _owner
    ) public override returns (uint256) {
        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, _owner, assets, shares);
        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(
        uint256 shares,
        address receiver,
        address _owner
    ) public override returns (uint256) {
        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, _owner, assets, shares);
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
        require(_lockAmounts[_owner].amount >= assets, "INSUFFICIENT_BALANCE");
        _lockAmounts[_owner].amount -= assets;

        if (caller != _owner) {
            _spendAllowance(_owner, caller, shares);
        }

        IERC20(asset()).safeTransfer(receiver, assets);
        emit Withdraw(caller, receiver, _owner, assets, shares);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20, ERC20Votes) {
        if (from != address(0) && to != address(0)) {
            require(!paused(), "TRANSFER_PAUSED");
        }
        ERC20Votes._update(from, to, value);
    }

    function decimals() public view override(ERC4626, ERC20) returns (uint8) {
        return IERC20Metadata(asset()).decimals();
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL 
    //////////////////////////////////////////////////////////////*/

    function initiateWithdraw(uint256 assets) external {
        require(assets != 0, "ZERO_AMOUNT");

        _burn(msg.sender, assets);

        LockAmount memory lockAmount = _lockAmounts[msg.sender];
        lockAmount.amount += assets;
        lockAmount.lockEnd = block.timestamp + lockDuration;
        _lockAmounts[msg.sender] = lockAmount;

        emit InitiateWithdraw(
            msg.sender,
            assets,
            lockAmount.amount,
            lockAmount.lockEnd
        );
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

    function getLockAmount(
        address account
    ) external view returns (LockAmount memory) {
        return _lockAmounts[account];
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
}
