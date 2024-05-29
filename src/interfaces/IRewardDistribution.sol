// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct DistributionData {
    uint40 startTime;
    uint40 endTime;
    uint40 updateTimestamp;
    uint128 emissionPerSecond;
    IERC20 rewardToken;
    uint256 index;
    mapping(address => uint256) userIndices;
}

/// @title Interface for RewardDistribution
/// @notice This interface outlines the public and external functions for managing distribution of rewards in a staking contract.
interface IRewardDistribution {
    ////////////////
    // Events
    ////////////////

    /// @notice Indicates a distribution index was updated
    /// @dev This event should be emitted when a distribution's index is updated
    /// @param distributionID The ID of the distribution being updated
    /// @param index The new index after the update
    event DistributionIndexUpdated(
        uint256 indexed distributionID,
        uint256 index
    );

    /// @notice Indicates a user's index in a distribution was updated
    /// @dev This event should be emitted when a user's index within a distribution is updated
    /// @param distributionID The ID of the distribution being referenced
    /// @param user The address of the user for whom the index was updated
    /// @param index The new user-specific index after the update
    event UserIndexUpdated(
        uint256 indexed distributionID,
        address indexed user,
        uint256 index
    );

    ////////////////
    // Functions
    ////////////////

    /// @notice Creates a new distribution
    /// @param emissionPerSecond The amount of reward token emitted per second
    /// @param startTime The start time of the distribution in UNIX timestamp
    /// @param endTime The end time of the distribution in UNIX timestamp
    /// @param rewardToken The ERC20 token to be used as the reward. The rewardToken must be strictly ERC-20 compliant.
    /// @dev Emits a DistributionIndexUpdated event on success
    function createDistribution(
        uint128 emissionPerSecond,
        uint40 startTime,
        uint40 endTime,
        IERC20 rewardToken
    ) external;

    /// @notice Sets the end time for an existing distribution
    /// @param distributionId The ID of the distribution to be modified
    /// @param endTime The new end time for the distribution
    /// @dev This action can only be performed by the owner of the contract
    function setDistributionEnd(uint16 distributionId, uint40 endTime) external;

    /// @notice Gets the current index of a distribution
    /// @param distributionId The ID of the distribution
    /// @return The current index of the distribution
    function distributionIndex(
        uint16 distributionId
    ) external view returns (uint256);

    /// @notice Gets the user-specific index within a distribution for a staker
    /// @param distributionId The ID of the distribution
    /// @param staker The address of the staker
    /// @return The current user-specific index within the distribution
    function distributionUserIndex(
        uint16 distributionId,
        address staker
    ) external view returns (uint256);
}
