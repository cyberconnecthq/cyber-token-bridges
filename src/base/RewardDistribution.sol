// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { IRewardDistribution, DistributionData } from "../interfaces/IRewardDistribution.sol";

/// @dev Accounting contract to manage staking distributions
/// This is adapted from https://etherscan.io/address/0xedbaee53b410d2c59f1b73144e8d500e94b496a0#code
// solhint-disable not-rely-on-time
abstract contract RewardDistribution is
    OwnableUpgradeable,
    IRewardDistribution
{
    using SafeERC20 for IERC20;

    uint16 public totalDistributions;
    uint256 public constant PRECISION_FACTOR = 1e18;

    // Distribution ID => Distribution Data
    mapping(uint16 => DistributionData) public distributions;

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    // slither-disable-next-line unused-state
    uint256[48] private __gap;

    modifier onlyValidDistributionEndTime(uint40 endTime) {
        require(endTime >= block.timestamp, "INVALID_DISTRIBUTION_END_TIME");
        _;
    }

    ///////////////////////
    // External Functions
    ///////////////////////

    /// @inheritdoc IRewardDistribution
    function createDistribution(
        uint128 emissionPerSecond_,
        uint40 startTime_,
        uint40 endTime_
    ) external onlyOwner onlyValidDistributionEndTime(endTime_) {
        require(
            startTime_ > block.timestamp,
            "INVALID_DISTRIBUTION_START_TIME"
        );

        require(startTime_ < endTime_, "INVALID_DISTRIBUTION_END_TIME");

        totalDistributions++;
        uint16 distributionId = totalDistributions;

        DistributionData storage distribution = distributions[distributionId];

        distribution.emissionPerSecond = emissionPerSecond_;
        distribution.startTime = startTime_;
        distribution.endTime = endTime_;
    }

    /// @inheritdoc IRewardDistribution
    function setDistributionEnd(
        uint16 distributionId,
        uint40 endTime
    ) external onlyOwner onlyValidDistributionEndTime(endTime) {
        DistributionData storage distribution = distributions[distributionId];

        require(
            endTime > distribution.endTime,
            "INVALID_DISTRIBUTION_END_TIME"
        );

        distribution.endTime = endTime;
    }

    /// @inheritdoc IRewardDistribution
    function distributionIndex(
        uint16 distributionId
    ) external view returns (uint256) {
        return distributions[distributionId].index;
    }

    /// @inheritdoc IRewardDistribution
    function distributionUserIndex(
        uint16 distributionId,
        address staker
    ) external view returns (uint256) {
        return distributions[distributionId].userIndices[staker];
    }

    ///////////////////////
    // Internal Functions
    ///////////////////////

    /// @dev Updates the distribution index based on time elapsed and emission rate, respecting the distribution period and supply constraints.
    /// @param distributionId Identifier for the specific distribution.
    /// @param currentIndex The current index reflecting the accumulated distribution up to the last update.
    /// @param lastUpdateTimestamp_ Timestamp of the last update, used to calculate time elapsed.
    /// @param totalSupply The total token supply.
    /// @return The updated index, or the current index if conditions prevent recalculation (e.g., no time elapsed, emission rate or total supply is zero, outside distribution period).
    function _getDistributionIndex(
        uint16 distributionId,
        uint256 currentIndex,
        uint40 lastUpdateTimestamp_,
        uint256 totalSupply
    ) internal view returns (uint256) {
        DistributionData storage distribution = distributions[distributionId];
        if (
            // slither-disable-next-line incorrect-equality
            lastUpdateTimestamp_ == block.timestamp ||
            distribution.emissionPerSecond == 0 ||
            totalSupply == 0 ||
            block.timestamp < distribution.startTime ||
            lastUpdateTimestamp_ >= distribution.endTime
        ) {
            return currentIndex;
        }

        uint256 currentTimestamp = block.timestamp > distribution.endTime
            ? distribution.endTime
            : block.timestamp;

        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp_;

        uint256 newIndex = (distribution.emissionPerSecond *
            timeDelta *
            PRECISION_FACTOR) / totalSupply;

        return newIndex + currentIndex;
    }

    /// @dev Iterates and updates each distribution's state.
    /// @param totalStaked Total amount staked, affecting distribution indices.
    function _updateAllDistribution(uint256 totalStaked) internal {
        for (
            uint16 distributionId = 1;
            distributionId <= totalDistributions;
            ++distributionId
        ) {
            _updateDistribution(distributionId, totalStaked);
        }
    }

    /// @dev Updates the state of one distribution, mainly rewards index and timestamp
    /// @param totalStaked Current total of staked assets for this distribution
    /// @return The new distribution index
    function _updateDistribution(
        uint16 distributionId,
        uint256 totalStaked
    ) internal returns (uint256) {
        DistributionData storage distribution = distributions[distributionId];

        uint256 oldIndex = distribution.index;
        uint40 lastUpdateTimestamp = _lastUpdateTimestamp(distribution);

        // Note that it's inclusive
        if (
            distribution.endTime <= lastUpdateTimestamp ||
            block.timestamp <= lastUpdateTimestamp
        ) {
            return oldIndex;
        }

        uint256 newIndex = _getDistributionIndex(
            distributionId,
            oldIndex,
            lastUpdateTimestamp,
            totalStaked
        );

        if (newIndex != oldIndex) {
            distribution.index = newIndex;
            emit DistributionIndexUpdated(distributionId, newIndex);
        }

        distribution.updateTimestamp = uint40(block.timestamp);

        return newIndex;
    }

    /// @dev Updates the state of an user in a distribution
    /// @param user The user's address
    /// @param stakedByUser Amount of tokens staked by the user in the distribution at the moment
    /// @param totalStaked Total tokens staked in the distribution
    /// @return The accrued rewards for the user until the moment
    function _updateUser(
        uint16 distributionId,
        address user,
        uint256 stakedByUser,
        uint256 totalStaked
    ) internal returns (uint256) {
        DistributionData storage distribution = distributions[distributionId];

        uint256 newIndex = _updateDistribution(distributionId, totalStaked);
        uint256 userIndex = distribution.userIndices[user];

        uint256 accruedRewards = 0;

        if (userIndex != newIndex) {
            if (stakedByUser != 0) {
                accruedRewards = _getAccruedRewards(
                    stakedByUser,
                    newIndex,
                    userIndex
                );
            }

            distribution.userIndices[user] = newIndex;
            emit UserIndexUpdated(distributionId, user, newIndex);
        }

        if (accruedRewards > 0) {
            accruedRewards = _collectFee(distributionId, accruedRewards);
        }

        return accruedRewards;
    }

    function _lastUpdateTimestamp(
        DistributionData storage distribution
    ) internal view returns (uint40) {
        return
            distribution.updateTimestamp < distribution.startTime
                ? distribution.startTime
                : distribution.updateTimestamp;
    }

    /// @dev Internal function for the calculation of user's rewards on a distribution
    /// @param stakedByUser Amount staked by the user on a distribution
    /// @param distributionIndex_ Current index of the distribution
    /// @param userIndex Index stored for the user, representation his staking moment
    /// @return The rewards
    function _getAccruedRewards(
        uint256 stakedByUser,
        uint256 distributionIndex_,
        uint256 userIndex
    ) internal pure returns (uint256) {
        uint256 indexDelta = (distributionIndex_ - userIndex);
        return (stakedByUser * indexDelta) / PRECISION_FACTOR;
    }

    /// @dev Collects fees from the rewards and distributes them to the protocol.
    /// The fees are determined based on the `FEE_BPS` constant.
    /// @param distributionId Distribution ID
    /// @param rewards The total amount of rewards from which fees will be deducted.
    /// @return The remaining rewards after deducting the protocol fees.
    function _collectFee(
        uint16 distributionId,
        uint256 rewards
    ) internal virtual returns (uint256);
}
