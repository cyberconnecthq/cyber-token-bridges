// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { DataTypes } from "./libraries/DataTypes.sol";

/**
 * @title CyberStakingPool
 * @author Cyber
 */
contract CyberStakingPool is ERC20Burnable, ERC20Votes, Ownable, Pausable {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                            EVENT
    //////////////////////////////////////////////////////////////*/

    event Stake(address account, uint256 amount);
    event Unstake(
        address account,
        uint256 amount,
        uint256 totalLocked,
        uint256 lockEnd
    );
    event Withdraw(address account, uint256 amount);
    event ClaimReward(address account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable cyber;
    // Duration of rewards to be paid out (in seconds)
    uint256 public duration;
    // Timestamp of when the rewards finish
    uint256 public finishAt;
    // Minimum of last updated time and reward finish time
    uint256 public updatedAt;
    // Reward to be paid out per second
    uint256 public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint256 public rewardPerTokenStored;
    // Duration of lock for staked CYBER
    uint256 public lockDuration;
    // User address => rewardPerTokenStored
    mapping(address => uint256) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint256) public rewards;
    // User address => lock amount for withdrawal
    mapping(address => DataTypes.LockAmount) internal _lockAmounts;

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

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OVERRIDES
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL
    //////////////////////////////////////////////////////////////*/

    function stake(uint256 _amount) external updateReward(msg.sender) {
        require(_amount > 0, "ZERO_AMOUNT");
        cyber.safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
        emit Stake(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external updateReward(msg.sender) {
        require(_amount > 0, "ZERO_AMOUNT");
        require(balanceOf(msg.sender) >= _amount, "INSUFFICIENT_BALANCE");

        _burn(msg.sender, _amount);

        DataTypes.LockAmount memory lockAmount = _lockAmounts[msg.sender];
        lockAmount.amount += _amount;
        lockAmount.lockEnd = block.timestamp + lockDuration;
        _lockAmounts[msg.sender] = lockAmount;

        emit Unstake(
            msg.sender,
            _amount,
            lockAmount.amount,
            lockAmount.lockEnd
        );
    }

    function withdraw(uint256 _amount) external updateReward(msg.sender) {
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
        emit Withdraw(msg.sender, _amount);
    }

    function claimReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "NO_REWARD_TO_CLAIM");
        rewards[msg.sender] = 0;
        cyber.safeTransfer(msg.sender, reward);
        emit ClaimReward(msg.sender, reward);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC
    //////////////////////////////////////////////////////////////*/

    function earned(address _account) public view returns (uint256) {
        return
            ((balanceOf(_account) *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
            rewards[_account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalSupply();
    }

    function getLockAmount(
        address account
    ) external view returns (DataTypes.LockAmount memory) {
        return _lockAmounts[account];
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

    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(finishAt < block.timestamp, "REWARDS_DURATION_NOT_FINISHED");
        duration = _duration;
    }

    function notifyRewardAmount(
        uint256 _amount
    ) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint256 remainingRewards = (finishAt - block.timestamp) *
                rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "REWARD_RATE_ZERO");
        require(
            rewardRate * duration <= cyber.balanceOf(address(this)),
            "INSUFFICIENT_REWARD_BALANCE"
        );

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE
    //////////////////////////////////////////////////////////////*/

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }
}
