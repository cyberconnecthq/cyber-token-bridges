// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IOAppCore } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";
import { IOAppComposer } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppComposer.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

import { IMintableBurnable } from "./interfaces/IMintableBurnable.sol";
/**
 * @title CyberStakingPool
 * @author Cyber
 */
contract CyberStakingPool is Ownable, IOAppComposer {
    using SafeERC20 for IERC20;

    struct LockAmount {
        uint256 lockEnd;
        uint256 amount;
    }

    /*//////////////////////////////////////////////////////////////
                            EVENT
    //////////////////////////////////////////////////////////////*/

    event LzCompose(address oApp, address account, uint256 amount);
    event Unstake(address account, uint256 amount, uint256 lockEnd);
    event Withdraw(address account, uint256 amount);
    event Stake(address account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable cyber;
    address public immutable stakedCyber;
    address public immutable lzEndpoint;
    uint256 public lockDuration;
    mapping(address => bool) public oApps;
    mapping(address => LockAmount) public lockAmounts;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _owner,
        address _lzEndpoint,
        address _cyber,
        address _stakedCyber
    ) Ownable(_owner) {
        lzEndpoint = _lzEndpoint;
        cyber = _cyber;
        stakedCyber = _stakedCyber;
        lockDuration = 7 days;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL 
    //////////////////////////////////////////////////////////////*/

    function stake(address to, uint256 amount) external {
        IERC20(cyber).safeTransferFrom(msg.sender, address(this), amount);
        _stake(to, amount);
    }

    function unstake(uint256 amount) external {
        require(amount != 0, "ZERO_AMOUNT");
        IERC20(stakedCyber).safeTransferFrom(msg.sender, address(this), amount);

        LockAmount memory lockAmount = lockAmounts[msg.sender];
        lockAmount.amount += amount;
        lockAmount.lockEnd = block.timestamp + lockDuration;
        lockAmounts[msg.sender] = lockAmount;

        emit Unstake(msg.sender, lockAmount.amount, lockAmount.lockEnd);
    }

    function withdraw() external {
        LockAmount memory lockAmount = lockAmounts[msg.sender];
        require(lockAmount.lockEnd != 0, "NOT_AVAILABLE_TO_WITHDRAW");
        require(
            lockAmount.lockEnd <= block.timestamp,
            "LOCKED_PERIOD_NOT_ENDED"
        );

        uint256 withdrawable = lockAmount.amount;

        delete lockAmounts[msg.sender];

        IERC20(cyber).safeTransfer(msg.sender, withdrawable);
        IMintableBurnable(stakedCyber).burn(withdrawable);

        emit Withdraw(msg.sender, withdrawable);
    }

    function lzCompose(
        address oApp,
        bytes32 /*_guid*/,
        bytes calldata message,
        address /*Executor*/,
        bytes calldata /*Executor Data*/
    ) external payable override {
        require(oApps[oApp], "OAPP_NOT_ALLOWED");
        require(msg.sender == lzEndpoint, "SENDER_NOT_ALLOWED");

        // Extract the composed message from the delivered message using the MsgCodec
        bytes memory composeMsgContent = OFTComposeMsgCodec.composeMsg(message);
        (address account, uint256 amount) = abi.decode(
            composeMsgContent,
            (address, uint256)
        );

        _stake(account, amount);
        emit LzCompose(oApp, account, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER
    //////////////////////////////////////////////////////////////*/
    function setLockDuration(uint256 _lockDuration) external onlyOwner {
        lockDuration = _lockDuration;
    }

    function setOApp(address oApp, bool allowed) external onlyOwner {
        oApps[oApp] = allowed;
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE 
    //////////////////////////////////////////////////////////////*/

    function _stake(address account, uint256 amount) private {
        IMintableBurnable(stakedCyber).mint(account, amount);
        emit Stake(account, amount);
    }
}
