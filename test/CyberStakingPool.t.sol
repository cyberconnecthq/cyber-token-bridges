// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { Test, console } from "forge-std/Test.sol";
import { MockCyberToken } from "./utils/MockCyberToken.sol";
import { CyberStakingPool, LockAmount } from "../src/CyberStakingPool.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CyberStakingPoolTest is Test {
    error EnforcedPause();

    CyberStakingPool cyberStakingPool;
    MockCyberToken cyberToken;

    address owner = address(1);
    address lzEndpoint = address(2);
    address alice = address(4);
    address bob = address(5);
    uint16 distributionId = 1;

    function setUp() public {
        cyberToken = new MockCyberToken();

        address cyberStakingPoolImpl = address(new CyberStakingPool());

        address cyberStakingPoolProxy = address(
            new ERC1967Proxy(
                cyberStakingPoolImpl,
                abi.encodeWithSelector(
                    CyberStakingPool.initialize.selector,
                    owner,
                    address(cyberToken)
                )
            )
        );
        cyberStakingPool = CyberStakingPool(cyberStakingPoolProxy);
    }

    function testDeposit() public {
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberStakingPool), amount);

        vm.expectRevert("ZERO_AMOUNT");
        cyberStakingPool.stake(0);

        vm.expectRevert("MINIMAL_STAKE_AMOUNT_NOT_REACHED");
        cyberStakingPool.stake(1);

        cyberStakingPool.stake(amount);
        assertEq(
            cyberToken.balanceOf(address(cyberStakingPool)),
            amount,
            "ERR1"
        );
        assertEq(cyberStakingPool.balanceOf(alice), amount, "ERR2");
        assertEq(cyberToken.balanceOf(alice), 0);
    }

    function testUnstake() public {
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        bytes32 key = bytes32(uint256(uint160(alice)));
        vm.expectRevert("ZERO_AMOUNT");
        cyberStakingPool.unstake(0, key);

        vm.expectRevert("INSUFFICIENT_BALANCE");
        cyberStakingPool.unstake(1, key);

        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberStakingPool), amount);
        cyberStakingPool.stake(amount);
        vm.expectRevert("INSUFFICIENT_BALANCE");
        cyberStakingPool.unstake(amount + 1, key);

        cyberStakingPool.unstake(amount, key);
        assertEq(cyberStakingPool.balanceOf(alice), 0);
        assertEq(cyberStakingPool.balanceOf(address(cyberStakingPool)), amount);
        assertEq(cyberStakingPool.lockedAmountByUser(alice), amount);
    }

    function testWithdraw() public {
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        bytes32 key = bytes32(uint256(uint160(alice)));

        vm.expectRevert("NOT_AVAILABLE_TO_WITHDRAW");
        cyberStakingPool.withdraw(key);

        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberStakingPool), amount);
        cyberStakingPool.stake(amount);

        vm.expectRevert("NOT_AVAILABLE_TO_WITHDRAW");
        cyberStakingPool.withdraw(key);

        cyberStakingPool.unstake(amount, key);

        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberStakingPool.withdraw(key);

        vm.warp(block.timestamp + cyberStakingPool.lockDuration());

        cyberStakingPool.withdraw(key);
        assertEq(cyberStakingPool.lockedAmountByUser(alice), 0, "ERR2");
        assertEq(cyberToken.balanceOf(alice), amount, "ERR3");
        assertEq(cyberStakingPool.balanceOf(alice), 0, "ERR4");
        assertEq(
            cyberStakingPool.balanceOf(address(cyberStakingPool)),
            0,
            "ERR5"
        );
    }

    function testTransfer() public {
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberStakingPool), amount);

        cyberStakingPool.stake(amount);

        vm.expectRevert("TRANSFER_NOT_ALLOWED");
        cyberStakingPool.transfer(bob, amount);

        vm.startPrank(owner);
        cyberStakingPool.setAllowTransfer(true);

        vm.startPrank(alice);
        cyberStakingPool.transfer(bob, amount);
    }

    function testPause() public {
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberStakingPool), amount);

        vm.startPrank(owner);
        cyberStakingPool.pause();

        vm.startPrank(alice);
        vm.expectRevert(EnforcedPause.selector);
        cyberStakingPool.stake(amount);

        vm.startPrank(owner);
        cyberStakingPool.unpause();

        vm.startPrank(alice);
        cyberStakingPool.stake(amount);
    }

    function testRewardBalance() public {
        uint256 amount = 2000 ether;
        vm.startPrank(owner);

        vm.warp(block.timestamp);
        uint256 rewards = 10000 ether;
        uint256 start = block.timestamp + 1 days;
        uint256 end = start + 1e22 seconds;
        uint128 emissionPerSecond = uint128(rewards / (end - start));
        cyberStakingPool.createDistribution(
            emissionPerSecond,
            uint40(start),
            uint40(end)
        );

        cyberToken.mint(owner, amount);
        cyberToken.approve(address(cyberStakingPool), amount);
        cyberStakingPool.stake(amount / 2);

        assertEq(
            cyberStakingPool.rewardBalance(distributionId, owner),
            0,
            "ERR1"
        );

        vm.warp(start + 1000 seconds);
        uint256 accruedRewards = 1000;
        bytes32 key = bytes32(uint256(uint160(owner)));
        cyberStakingPool.unstake(amount / 2, key);
        assertEq(
            cyberStakingPool.rewardBalance(distributionId, owner),
            accruedRewards,
            "ERR2"
        );

        vm.warp(start + 2000 seconds);
        cyberStakingPool.stake(amount / 2);
        console.log(cyberStakingPool.rewardBalance(distributionId, owner));
        assertEq(
            cyberStakingPool.rewardBalance(distributionId, owner),
            accruedRewards,
            "ERR2"
        );
    }

    function testGetLockedAmountByKey() public {
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        bytes32 key = bytes32(uint256(uint160(alice)));

        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberStakingPool), amount);
        cyberStakingPool.stake(amount);
        cyberStakingPool.unstake(amount, key);

        LockAmount memory lockAmount = cyberStakingPool.getLockedAmountByKey(
            alice,
            key
        );
        assertEq(lockAmount.lockEnd, block.timestamp + 7 days);
        assertEq(lockAmount.amount, amount);
    }

    function testLockedAmountByUser() public {
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        bytes32 key = bytes32(uint256(uint160(alice)));

        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberStakingPool), amount);
        cyberStakingPool.stake(amount);
        cyberStakingPool.unstake(amount, key);

        assertEq(cyberStakingPool.lockedAmountByUser(alice), amount);
    }

    function testClaimAllRewards() public {
        uint256 rewards = 500000 ether;
        uint40 startTs = 1718323200;
        uint40 endTs = 1725753600;

        uint128 emissionPerSecond = uint128(rewards / (endTs - startTs));
        vm.warp(uint256(startTs - 1));
        vm.startPrank(owner);
        cyberStakingPool.createDistribution(emissionPerSecond, startTs, endTs);
        cyberToken.mint(address(cyberStakingPool), rewards);

        uint256 expectedOneDayRewards = emissionPerSecond * 1 days;
        vm.startPrank(alice);
        uint256 stakeAmount = cyberStakingPool.minimalStakeAmount();
        cyberToken.mint(alice, stakeAmount);
        cyberToken.approve(address(cyberStakingPool), stakeAmount);

        cyberStakingPool.stake(stakeAmount);
        console.log("rewards");
        console.log(cyberStakingPool.claimAllRewards());

        vm.warp(block.timestamp + 1 days);
        // stCYBER still exists, totalSupply is not influenced
        cyberStakingPool.unstake(stakeAmount, bytes32(uint256(uint160(alice))));
        uint256 totalRewards = cyberStakingPool.claimAllRewards();
        assertTrue(expectedOneDayRewards - totalRewards < 1e17, "ERR1");
    }
}
