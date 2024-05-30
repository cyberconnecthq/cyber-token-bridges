// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { MerkleDistribution } from "./base/MerkleDistribution.sol";

/**
 * @title RewardTokenWithdrawer
 * @author Cyber
 */
contract RewardTokenWithdrawer is MerkleDistribution, Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            EVENT
    //////////////////////////////////////////////////////////////*/

    event Withdraw(uint256 logId, address account, uint256 amount);
    event Stake(uint256 logId, address account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable cyber;
    address public immutable cyberVault;
    uint256 private _logId;

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _owner,
        address _cyber,
        address _cyberVault,
        bytes32 _merkleRoot
    ) MerkleDistribution(_merkleRoot) Ownable(_owner) {
        cyber = _cyber;
        cyberVault = _cyberVault;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL
    //////////////////////////////////////////////////////////////*/

    function withdraw(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        _consumeProof(index, account, amount, merkleProof);
        IERC20(cyber).safeTransfer(account, amount);
        emit Withdraw(_logId++, account, amount);
    }

    function stake(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        _consumeProof(index, account, amount, merkleProof);
        IERC20(cyber).approve(cyberVault, amount);
        IERC4626(cyberVault).deposit(amount, account);
        emit Stake(_logId++, account, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER
    //////////////////////////////////////////////////////////////*/

    function rescueToken(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool success, ) = owner().call{ value: amount }("");
            require(success, "WITHDRAW_FAILED");
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }
}
