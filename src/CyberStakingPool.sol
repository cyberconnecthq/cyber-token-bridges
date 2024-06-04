// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import { ERC20VotesUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { RewardDistribution } from "./base/RewardDistribution.sol";

import { ICyberStakingPool, LockAmount } from "./interfaces/ICyberStakingPool.sol";

/**
 * @title CyberStakingPool
 * @author Cyber
 */
contract CyberStakingPool is
    ERC20BurnableUpgradeable,
    ERC20VotesUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
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
        uint256 lockEnd,
        bytes32 key
    );
    event Withdraw(uint256 logId, address user, uint256 amount, bytes32 key);
    event ClaimReward(
        uint256 logId,
        uint16 distributionId,
        address user,
        uint256 amount
    );
    event RewardsAccrued(
        uint256 logId,
        uint16 distributionId,
        address user,
        uint256 amount
    );
    event CollectFee(
        uint256 logId,
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

    IERC20 public cyber;
    // Duration of lock for staked CYBER
    uint256 public lockDuration;
    uint256 public protocolFeeBps;
    uint256 public protocolAccruedFee;
    uint256 public protocolClaimableFee;

    uint256 internal _minimalStakeAmount;

    // User address => key => lock amount for withdrawal
    mapping(address => mapping(bytes32 => LockAmount))
        internal _lockedAmountByKey;
    /// hash(distribution id, user) => rewardsBalance
    mapping(bytes32 => uint256) private _rewardsBalances;
    mapping(address => uint256) private _lockedAmountByUser;
    uint256 public protocolLockedAmount;

    // Log ID for each event
    uint256 private _logId;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR & INITIALIZER
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _cyber) external initializer {
        cyber = IERC20(_cyber);
        lockDuration = 7 days;
        _minimalStakeAmount = 1000 ether;

        __UUPSUpgradeable_init();
        __Pausable_init();
        __ERC20_init("Staked CYBER", "stCYBER");
        __EIP712_init("Staked CYBER", "1");
        __Ownable_init(_owner);
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
    ) internal virtual override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        if (from != address(0) && to != address(0) && to != address(this)) {
            require(!paused(), "TRANSFER_PAUSED");
            // Sender
            _updateCurrentUnclaimedRewards(from, balanceOf(from));

            // Recipient
            if (from != to) {
                _updateCurrentUnclaimedRewards(to, balanceOf(to));
            }
        }
        ERC20VotesUpgradeable._update(from, to, value);
    }

    function _collectFee(
        uint16 distributionId,
        uint256 rewards
    ) internal override returns (uint256) {
        // Calculate the protocol fee as a percentage of the rewards.
        uint256 protocolFeeAmount = (rewards * protocolFeeBps) / MAX_BPS;

        if (protocolFeeAmount == 0) {
            return rewards;
        }

        uint256 userRewards = rewards - protocolFeeAmount;

        // Emit an event for the fee collection, providing transparency and traceability.
        emit CollectFee(
            _logId++,
            distributionId,
            protocolFeeAmount,
            userRewards
        );
        protocolClaimableFee += protocolFeeAmount;
        protocolAccruedFee += protocolFeeAmount;

        // Return the remaining rewards after deducting the protocol fees.
        return userRewards;
    }

    function minimalStakeAmount() external view override returns (uint256) {
        return _minimalStakeAmount;
    }

    function _authorizeUpgrade(address) internal view override {
        require(msg.sender == owner(), "ONLY_OWNER");
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL
    //////////////////////////////////////////////////////////////*/

    function stake(uint256 _amount) external override updateReward(msg.sender) {
        require(_amount > 0, "ZERO_AMOUNT");
        require(
            _amount + balanceOf(msg.sender) >= _minimalStakeAmount,
            "MINIMAL_STAKE_AMOUNT_NOT_REACHED"
        );

        cyber.safeTransferFrom(msg.sender, address(this), _amount);

        _mint(msg.sender, _amount);
        emit Stake(_logId++, msg.sender, _amount);
    }

    function unstake(
        uint256 _amount,
        bytes32 _key
    ) external override updateReward(msg.sender) {
        require(_amount > 0, "ZERO_AMOUNT");
        require(balanceOf(msg.sender) >= _amount, "INSUFFICIENT_BALANCE");

        _transfer(msg.sender, address(this), _amount);

        _lockedAmountByUser[msg.sender] += _amount;
        protocolLockedAmount += _amount;
        LockAmount memory lockAmount = _lockedAmountByKey[msg.sender][_key];
        lockAmount.amount += _amount;
        lockAmount.lockEnd = block.timestamp + lockDuration;
        _lockedAmountByKey[msg.sender][_key] = lockAmount;

        emit Unstake(
            _logId++,
            msg.sender,
            _amount,
            lockAmount.amount,
            lockAmount.lockEnd,
            _key
        );
    }

    function withdraw(bytes32 _key) external override updateReward(msg.sender) {
        LockAmount memory lockAmount = _lockedAmountByKey[msg.sender][_key];
        require(lockAmount.lockEnd != 0, "NOT_AVAILABLE_TO_WITHDRAW");
        require(
            lockAmount.lockEnd <= block.timestamp,
            "LOCKED_PERIOD_NOT_ENDED"
        );
        delete _lockedAmountByKey[msg.sender][_key];
        _burn(address(this), lockAmount.amount);
        _lockedAmountByUser[msg.sender] -= lockAmount.amount;
        protocolLockedAmount -= lockAmount.amount;

        cyber.safeTransfer(msg.sender, lockAmount.amount);
        emit Withdraw(_logId++, msg.sender, lockAmount.amount, _key);
    }

    function claimAllRewards()
        external
        override
        updateReward(msg.sender)
        returns (uint256 totalRewards)
    {
        for (
            uint16 distributionId = 1;
            distributionId <= totalDistributions;
            ++distributionId
        ) {
            totalRewards = totalRewards + _claimReward(distributionId);
        }
        return totalRewards;
    }

    function rewardBalance(
        uint16 distributionId,
        address user
    ) external view override returns (uint256) {
        return _rewardsBalances[rewardBalanceKey(distributionId, user)];
    }

    function claimableRewards(
        uint16 distributionId,
        address user
    ) public view override returns (uint256) {
        uint256 accruedRewards = _previewUpdateUser(
            distributionId,
            user,
            balanceOf(user),
            circulatingSupply()
        );
        return
            _rewardsBalances[rewardBalanceKey(distributionId, user)] +
            accruedRewards;
    }

    function claimableAllRewards(
        address user
    ) external view override returns (uint256 totalRewards) {
        for (
            uint16 distributionId = 1;
            distributionId <= totalDistributions;
            ++distributionId
        ) {
            totalRewards =
                totalRewards +
                claimableRewards(distributionId, user);
        }
        return totalRewards;
    }

    function getLockedAmountByKey(
        address user,
        bytes32 key
    ) external view returns (LockAmount memory) {
        return _lockedAmountByKey[user][key];
    }

    function lockedAmountByUser(
        address user
    ) external view override returns (uint256) {
        return _lockedAmountByUser[user];
    }

    function circulatingSupply() public view returns (uint256) {
        return totalSupply() - protocolLockedAmount;
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

    function setMinimalStakeAmount(
        uint256 minimalStakeAmount_
    ) external onlyOwner {
        _minimalStakeAmount = minimalStakeAmount_;
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

    function _claimReward(uint16 distributionId) private returns (uint256) {
        bytes32 key = rewardBalanceKey(distributionId, msg.sender);
        uint256 unclaimedRewards = _rewardsBalances[key];
        if (unclaimedRewards > 0) {
            delete _rewardsBalances[key];
            cyber.safeTransfer(msg.sender, unclaimedRewards);
            emit ClaimReward(
                _logId++,
                distributionId,
                msg.sender,
                unclaimedRewards
            );
        }
        return unclaimedRewards;
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
                circulatingSupply()
            );
            if (accruedRewards != 0) {
                bytes32 key = rewardBalanceKey(distributionId, user);
                _rewardsBalances[key] += accruedRewards;
                emit RewardsAccrued(
                    _logId++,
                    distributionId,
                    user,
                    accruedRewards
                );
            }
        }
    }
}
