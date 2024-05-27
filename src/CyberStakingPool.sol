// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { RewardDistribution } from "./RewardDistribution.sol";
import { DataTypes } from "./libraries/DataTypes.sol";

import { ICyberStakingPool } from "./interfaces/ICyberStakingPool.sol";

/**
 * @title CyberStakingPool
 * @author Cyber
 */
contract CyberStakingPool is
    ERC20Burnable,
    ERC20Votes,
    Pausable,
    RewardDistribution,
    ICyberStakingPool
{
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                            EVENT
    //////////////////////////////////////////////////////////////*/

    event Stake(uint256 logId, address user, uint256 amount);
    event Unstake(
        uint256 logId,
        address user,
        uint256 amount,
        uint256 totalLocked,
        uint256 lockEnd
    );
    event Withdraw(uint256 logId, address user, uint256 amount);
    event ClaimReward(uint256 logId, address user, uint256 amount);
    event RewardsAccrued(address user, uint256 amount);
    event CollectFee(
        uint16 distributionId,
        uint256 protocolFee,
        uint256 userRewards
    );

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev MAX_BPS the maximum number of basis points.
    /// 10000 basis points are equivalent to 100%.
    uint256 public constant MAX_BPS = 1e4;

    IERC20 public immutable cyber;
    uint256 public totalStaked;
    // Duration of lock for staked CYBER
    uint256 public lockDuration;
    uint256 public protocolFeeBps;
    uint256 public protocolAccruedFee;
    uint256 public protocolClaimableFee;

    // User address => lock amount for withdrawal
    mapping(address => DataTypes.LockAmount) internal _lockAmounts;
    /// hash(distribution id, user) => rewardsBalance
    mapping(bytes32 => uint256) private _rewardsBalances;

    // Log ID for each event
    uint256 private _logId;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR & INITIALIZER
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _owner,
        address _cyber
    )
        ERC20("Staked CYBER", "stCYBER")
        EIP712("Staked CYBER", "1")
        Ownable(_owner)
    {
        cyber = IERC20(_cyber);
        lockDuration = 7 days;
        _pause();
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier updateReward(address _user) {
        _updateCurrentUnclaimedRewards(_user, balanceOf(_user));
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20, ERC20Votes) {
        if (from != address(0) && to != address(0)) {
            require(!paused(), "TRANSFER_PAUSED");
            // Sender
            _updateCurrentUnclaimedRewards(from, balanceOf(from));

            // Recipient
            if (from != to) {
                _updateCurrentUnclaimedRewards(to, balanceOf(to));
            }
        }
        ERC20Votes._update(from, to, value);
    }

    function _collectFee(
        uint16 distributionId,
        uint256 rewards
    ) internal override returns (uint256) {
        // Calculate the protocol fee as a percentage of the rewards.
        uint256 protocolFeeAmount = (rewards * protocolFeeBps) / MAX_BPS;

        uint256 userRewards = rewards - protocolFeeAmount;

        // Emit an event for the fee collection, providing transparency and traceability.
        emit CollectFee(distributionId, protocolFeeAmount, userRewards);

        protocolClaimableFee += protocolFeeAmount;
        protocolAccruedFee += protocolFeeAmount;

        // Return the remaining rewards after deducting the protocol fees.
        return userRewards;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL
    //////////////////////////////////////////////////////////////*/

    function stake(uint256 _amount) external override updateReward(msg.sender) {
        require(_amount > 0, "ZERO_AMOUNT");

        cyber.safeTransferFrom(msg.sender, address(this), _amount);

        totalStaked += _amount;
        _mint(msg.sender, _amount);
        emit Stake(_logId++, msg.sender, _amount);
    }

    function unstake(
        uint256 _amount
    ) external override updateReward(msg.sender) {
        require(_amount > 0, "ZERO_AMOUNT");
        require(balanceOf(msg.sender) >= _amount, "INSUFFICIENT_BALANCE");

        totalStaked -= _amount;
        _burn(msg.sender, _amount);

        DataTypes.LockAmount memory lockAmount = _lockAmounts[msg.sender];
        lockAmount.amount += _amount;
        lockAmount.lockEnd = block.timestamp + lockDuration;
        _lockAmounts[msg.sender] = lockAmount;

        emit Unstake(
            _logId++,
            msg.sender,
            _amount,
            lockAmount.amount,
            lockAmount.lockEnd
        );
    }

    function withdraw(
        uint256 _amount
    ) external override updateReward(msg.sender) {
        require(
            _lockAmounts[msg.sender].lockEnd != 0,
            "NOT_AVAILABLE_TO_WITHDRAW"
        );
        require(
            _lockAmounts[msg.sender].lockEnd <= block.timestamp,
            "LOCKED_PERIOD_NOT_ENDED"
        );
        require(
            _lockAmounts[msg.sender].amount >= _amount,
            "INSUFFICIENT_BALANCE"
        );
        _lockAmounts[msg.sender].amount -= _amount;

        cyber.safeTransfer(msg.sender, _amount);
        emit Withdraw(_logId++, msg.sender, _amount);
    }

    function claimReward(
        uint16 distributionId
    ) external override updateReward(msg.sender) {
        bytes32 key = rewardBalanceKey(distributionId, msg.sender);
        uint256 unclaimedRewards = _rewardsBalances[key];
        require(unclaimedRewards > 0, "NO_REWARD_TO_CLAIM");
        _rewardsBalances[key] = 0;
        cyber.safeTransfer(msg.sender, unclaimedRewards);
        emit ClaimReward(_logId++, msg.sender, unclaimedRewards);
    }

    function rewardBalance(
        uint16 distributionId,
        address user
    ) external view override returns (uint256) {
        return _rewardsBalances[rewardBalanceKey(distributionId, user)];
    }

    function getLockAmount(
        address user
    ) external view returns (DataTypes.LockAmount memory) {
        return _lockAmounts[user];
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC
    //////////////////////////////////////////////////////////////*/

    function rewardBalanceKey(
        uint16 distributionId,
        address user
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(distributionId, user));
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setLockDuration(uint256 _lockDuration) external onlyOwner {
        lockDuration = _lockDuration;
    }

    function setProtocolFeeBps(uint256 _protocolFeeBps) external onlyOwner {
        require(_protocolFeeBps <= MAX_BPS, "INVALID_PROTOCOL_FEE_BPS");
        protocolFeeBps = _protocolFeeBps;
    }

    function claimProtocolFee() external onlyOwner {
        require(protocolClaimableFee > 0, "NO_CLAIMABLE_FEE");
        cyber.safeTransfer(owner(), protocolClaimableFee);
        protocolClaimableFee = 0;
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE
    //////////////////////////////////////////////////////////////*/

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }

    function _updateCurrentUnclaimedRewards(
        address user,
        uint256 stakedByUser
    ) private {
        for (
            uint16 distributionId = 1;
            distributionId <= totalDistributions;
            ++distributionId
        ) {
            uint256 accruedRewards = _updateUser(
                distributionId,
                user,
                stakedByUser,
                totalStaked
            );
            if (accruedRewards != 0) {
                bytes32 key = rewardBalanceKey(distributionId, user);
                _rewardsBalances[key] += accruedRewards;
                emit RewardsAccrued(user, accruedRewards);
            }
        }
    }
}
