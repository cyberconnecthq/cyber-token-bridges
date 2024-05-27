// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { Test, console } from "forge-std/Test.sol";

import { MockCyberToken } from "./utils/MockCyberToken.sol";

import { CyberVault } from "../src/CyberVault.sol";

import { CyberStakingPool } from "../src/CyberStakingPool.sol";

import { DataTypes } from "../src/libraries/DataTypes.sol";

contract CyberVaultTest is Test {
    CyberVault cyberVault;
    MockCyberToken cyberToken;

    address owner = address(1);
    address lzEndpoint = address(2);
    address alice = address(3);
    address bob = address(4);

    function setUp() public {
        cyberToken = new MockCyberToken();

        CyberStakingPool cyberStakingPool = new CyberStakingPool(
            owner,
            address(cyberToken)
        );
        cyberVault = new CyberVault(
            owner,
            lzEndpoint,
            cyberToken,
            address(cyberStakingPool)
        );
    }

    function testDeposit() public {
        vm.startPrank(alice);
        uint256 initialAmount = 100 ether;
        cyberToken.mint(alice, initialAmount);

        uint256 amount = 1 ether;
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, alice);
        assertEq(cyberVault.balanceOf(alice), amount);
        assertEq(cyberToken.balanceOf(alice), initialAmount - amount);

        cyberToken.approve(address(cyberVault), amount);
        cyberVault.mint(amount, alice);
        assertEq(cyberVault.balanceOf(alice), amount * 2);
        assertEq(cyberToken.balanceOf(alice), initialAmount - amount * 2);
    }

    function testWithdraw() public {
        vm.startPrank(alice);
        uint256 initialAmount = 100 ether;
        cyberToken.mint(alice, initialAmount);

        uint256 amount = 1 ether;
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, alice);

        vm.expectRevert("NOT_AVAILABLE_TO_WITHDRAW");
        cyberVault.withdraw(amount, alice, alice);

        vm.expectRevert("NOT_AVAILABLE_TO_WITHDRAW");
        cyberVault.redeem(amount, alice, alice);

        cyberVault.initiateWithdraw(amount);
        assertEq(cyberVault.balanceOf(alice), 0);
        assertEq(cyberToken.balanceOf(alice), initialAmount - amount);
        DataTypes.LockAmount memory lockAmount = cyberVault.getLockAmount(
            alice
        );
        assertEq(lockAmount.amount, amount);
        assertEq(cyberVault.balanceOf(address(cyberVault)), amount);

        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberVault.withdraw(amount, alice, alice);

        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberVault.redeem(amount, alice, alice);

        vm.warp(block.timestamp + cyberVault.lockDuration());

        vm.expectRevert("INSUFFICIENT_BALANCE");
        cyberVault.withdraw(amount + 1, alice, alice);

        cyberVault.withdraw(amount / 2, alice, alice);
        assertEq(cyberVault.balanceOf(address(cyberVault)), amount / 2);
        assertEq(cyberToken.balanceOf(alice), initialAmount - amount / 2);
        assertEq(cyberVault.balanceOf(alice), 0);
        lockAmount = cyberVault.getLockAmount(alice);
        assertEq(lockAmount.amount, amount / 2);

        cyberVault.redeem(amount / 2, alice, alice);
        assertEq(cyberVault.balanceOf(address(cyberVault)), 0);
        assertEq(cyberToken.balanceOf(alice), initialAmount);
        assertEq(cyberVault.balanceOf(alice), 0);
        lockAmount = cyberVault.getLockAmount(alice);
        assertEq(lockAmount.amount, 0);
    }

    function testTransfer() public {
        vm.startPrank(alice);
        uint256 initialAmount = 100 ether;
        cyberToken.mint(alice, initialAmount);

        uint256 amount = 1 ether;
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, alice);

        cyberVault.transfer(bob, amount / 2);
    }
}
