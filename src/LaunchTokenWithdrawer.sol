// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { MerkleDistribution } from "./base/MerkleDistribution.sol";

/**
 * @title LaunchTokenWithdrawer
 * @author Cyber
 */
contract LaunchTokenWithdrawer is MerkleDistribution, Ownable {
    using SafeERC20 for IERC20;

    struct LockAmount {
        uint256 lockEnd;
        uint256 amount;
    }

    /*//////////////////////////////////////////////////////////////
                            EVENT
    //////////////////////////////////////////////////////////////*/

    event InitiateWithdraw(
        uint256 logId,
        uint256 index,
        address account,
        uint256 amount
    );
    event Withdraw(uint256 logId, address account, uint256 amount);
    event BridgeAndStake(uint256 logId, address account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable cyber;
    address public bridgeRecipient;
    uint256 public lockDuration;
    mapping(address => LockAmount) public lockAmounts;
    uint256 private _logId;

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _owner,
        address _cyber,
        bytes32 _merkleRoot,
        address _bridgeRecipient
    ) Ownable(_owner) MerkleDistribution(_merkleRoot) {
        cyber = _cyber;
        lockDuration = 7 days;
        bridgeRecipient = _bridgeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL
    //////////////////////////////////////////////////////////////*/

    function initiateWithdraw(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        _consumeProof(index, account, amount, merkleProof);
        lockAmounts[account].lockEnd = block.timestamp + lockDuration;
        lockAmounts[account].amount = amount;
        emit InitiateWithdraw(_logId++, index, account, amount);
    }

    function withdraw(address account) external {
        uint256 amount = lockAmounts[account].amount;
        require(amount > 0, "NO_LOCKED_AMOUNT");
        require(lockAmounts[account].lockEnd <= block.timestamp, "LOCKED");
        delete lockAmounts[account];
        IERC20(cyber).safeTransfer(account, amount);
        emit Withdraw(_logId++, account, amount);
    }

    function bridgeAndStake(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        _consumeProof(index, account, amount, merkleProof);
        IERC20(cyber).safeTransfer(bridgeRecipient, amount);
        emit BridgeAndStake(_logId++, account, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER
    //////////////////////////////////////////////////////////////*/

    function setBridgeRecipient(address _bridgeRecipient) external onlyOwner {
        bridgeRecipient = _bridgeRecipient;
    }

    function setLockDuration(uint256 _lockDuration) external onlyOwner {
        lockDuration = _lockDuration;
    }

    function rescueToken(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool success, ) = owner().call{ value: amount }("");
            require(success, "WITHDRAW_FAILED");
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }
}
