// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { Test, console } from "forge-std/Test.sol";

import { MockCyberToken } from "./utils/MockCyberToken.sol";

import { CyberStakingPool, LockAmount } from "../src/CyberStakingPool.sol";

contract CyberStakingPoolTest is Test {
    CyberStakingPool cyberStakingPool;
    MockCyberToken cyberToken;

    address owner = address(1);
    address lzEndpoint = address(2);
    address alice = address(3);
    address bob = address(4);

    function setUp() public {
        cyberToken = new MockCyberToken();

        cyberStakingPool = new CyberStakingPool(owner, lzEndpoint, cyberToken);
    }

    function testDeposit() public {
        vm.startPrank(alice);
        uint256 initialAmount = 100 ether;
        cyberToken.mint(alice, initialAmount);

        uint256 amount = 1 ether;
        cyberToken.approve(address(cyberStakingPool), amount);
        cyberStakingPool.deposit(amount, alice);
        assertEq(cyberStakingPool.balanceOf(alice), amount);
        assertEq(cyberToken.balanceOf(alice), initialAmount - amount);

        cyberToken.approve(address(cyberStakingPool), amount);
        cyberStakingPool.mint(amount, alice);
        assertEq(cyberStakingPool.balanceOf(alice), amount * 2);
        assertEq(cyberToken.balanceOf(alice), initialAmount - amount * 2);
    }

    function testWithdraw() public {
        vm.startPrank(alice);
        uint256 initialAmount = 100 ether;
        cyberToken.mint(alice, initialAmount);

        uint256 amount = 1 ether;
        cyberToken.approve(address(cyberStakingPool), amount);
        cyberStakingPool.deposit(amount, alice);

        vm.expectRevert("NOT_AVAILABLE_TO_WITHDRAW");
        cyberStakingPool.withdraw(amount, alice, alice);

        vm.expectRevert("NOT_AVAILABLE_TO_WITHDRAW");
        cyberStakingPool.redeem(amount, alice, alice);

        cyberStakingPool.initiateWithdraw(amount);
        assertEq(cyberStakingPool.balanceOf(alice), 0);
        assertEq(cyberToken.balanceOf(alice), initialAmount - amount);
        LockAmount memory lockAmount = cyberStakingPool.getLockAmount(alice);
        assertEq(lockAmount.amount, amount);
        assertEq(cyberStakingPool.balanceOf(address(cyberStakingPool)), 0);

        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberStakingPool.withdraw(amount, alice, alice);

        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberStakingPool.redeem(amount, alice, alice);

        vm.warp(block.timestamp + cyberStakingPool.lockDuration());

        vm.expectRevert("INSUFFICIENT_BALANCE");
        cyberStakingPool.withdraw(amount + 1, alice, alice);

        cyberStakingPool.withdraw(amount / 2, alice, alice);
        assertEq(cyberStakingPool.balanceOf(address(cyberStakingPool)), 0);
        assertEq(cyberToken.balanceOf(alice), initialAmount - amount / 2);
        assertEq(cyberStakingPool.balanceOf(alice), 0);
        lockAmount = cyberStakingPool.getLockAmount(alice);
        assertEq(lockAmount.amount, amount / 2);

        cyberStakingPool.redeem(amount / 2, alice, alice);
        assertEq(cyberStakingPool.balanceOf(address(cyberStakingPool)), 0);
        assertEq(cyberToken.balanceOf(alice), initialAmount);
        assertEq(cyberStakingPool.balanceOf(alice), 0);
        lockAmount = cyberStakingPool.getLockAmount(alice);
        assertEq(lockAmount.amount, 0);
    }

    function testTransfer() public {
        vm.startPrank(alice);
        uint256 initialAmount = 100 ether;
        cyberToken.mint(alice, initialAmount);

        uint256 amount = 1 ether;
        cyberToken.approve(address(cyberStakingPool), amount);
        cyberStakingPool.deposit(amount, alice);

        vm.expectRevert("TRANSFER_PAUSED");
        cyberStakingPool.transfer(bob, amount / 2);
    }
}
