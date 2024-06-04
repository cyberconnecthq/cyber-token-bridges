// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct LockAmount {
    uint256 lockEnd;
    uint256 amount;
}

interface ICyberStakingPool is IERC20 {
    function minimalStakeAmount() external view returns (uint256);
    function stake(uint256 _amount) external;
    function unstake(uint256 _amount, bytes32 _key) external;
    function withdraw(bytes32 _key) external;
    function claimAllRewards() external returns (uint256);
    function rewardBalance(
        uint16 _distributionId,
        address _user
    ) external view returns (uint256);
    function claimableRewards(
        uint16 _distributionId,
        address _user
    ) external view returns (uint256);
    function claimableAllRewards(address _user) external view returns (uint256);
    function lockedAmountByUser(address user) external view returns (uint256);
}
