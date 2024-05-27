// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ICyberStakingPool is IERC20 {
    function stake(uint256 _amount) external;
    function unstake(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function claimReward(uint16 _distributionId) external;
    function rewardBalance(
        uint16 _distributionId,
        address _user
    ) external view returns (uint256);
}
