// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { Test, console } from "forge-std/Test.sol";
import { MockCyberToken } from "./utils/MockCyberToken.sol";
import { CyberVault } from "../src/CyberVault.sol";
import { CyberStakingPool } from "../src/CyberStakingPool.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CyberVaultTest is Test {
    CyberVault cyberVault;
    MockCyberToken cyberToken;
    CyberStakingPool cyberStakingPool;

    address owner = address(1);
    address lzEndpoint = address(2);
    address alice = address(3);
    address bob = address(4);
    address treasury = address(5);
    address charlie = address(6);

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

        address cyberVaultImpl = address(new CyberVault());
        address cyberVaultProxy = address(
            new ERC1967Proxy(
                cyberVaultImpl,
                abi.encodeWithSelector(
                    CyberVault.initialize.selector,
                    owner,
                    address(cyberToken),
                    address(cyberStakingPool),
                    treasury
                )
            )
        );
        cyberVault = CyberVault(cyberVaultProxy);
    }

    function testDeposit() public {
        uint256 amount = cyberStakingPool.minimalStakeAmount();
        vm.startPrank(alice);
        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberVault), amount);

        cyberVault.deposit(amount / 2, alice);
        assertEq(cyberToken.balanceOf(address(cyberVault)), amount / 2, "ERR1");
        assertEq(cyberToken.balanceOf(address(alice)), amount / 2, "ERR2");
        assertEq(cyberVault.balanceOf(alice), amount / 2, "ERR3");

        cyberVault.deposit(amount / 2, alice);

        assertEq(
            cyberToken.balanceOf(address(cyberStakingPool)),
            amount,
            "ERR1"
        );
        assertEq(cyberVault.balanceOf(alice), amount, "ERR2");

        vm.expectRevert();
        cyberVault.deposit(type(uint256).max + 1, alice);
    }

    function testOverlapRedeem() public {
        uint256 amount = cyberStakingPool.minimalStakeAmount();
        vm.startPrank(alice);
        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, alice);

        uint256 shares = cyberVault.balanceOf(alice);
        cyberVault.initiateRedeem(shares);

        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberVault.redeem(shares, alice, alice);

        vm.warp(block.timestamp + cyberStakingPool.lockDuration() / 2);

        vm.startPrank(bob);
        cyberToken.mint(bob, amount);
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, bob);

        cyberVault.initiateRedeem(shares);

        vm.warp(block.timestamp + cyberStakingPool.lockDuration() / 2);

        vm.startPrank(alice);
        cyberVault.redeem(shares, alice, alice);
        assertEq(cyberToken.balanceOf(alice), amount);

        vm.startPrank(bob);
        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberVault.redeem(shares, bob, bob);

        vm.warp(block.timestamp + cyberStakingPool.lockDuration() / 2);

        cyberVault.redeem(shares, bob, bob);
        assertEq(cyberToken.balanceOf(bob), amount);
    }

    function testTransfer() public {
        uint256 amount = 1 ether;
        vm.startPrank(alice);
        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, alice);

        cyberVault.transfer(bob, amount / 2);
        assertEq(cyberVault.balanceOf(alice), amount / 2);
        assertEq(cyberVault.balanceOf(bob), amount / 2);
    }

    function testPreview() public {
        uint256 amount = cyberStakingPool.minimalStakeAmount();

        vm.startPrank(owner);
        uint256 rewards = 500000 ether;
        cyberToken.mint(address(cyberStakingPool), rewards);
        uint256 start = block.timestamp + 1 days;
        uint256 end = start + 90 days;
        uint128 emissionPerSecond = uint128(rewards / (end - start));
        cyberStakingPool.createDistribution(
            emissionPerSecond,
            uint40(start),
            uint40(end)
        );

        vm.startPrank(alice);
        cyberToken.mint(alice, 100 * amount);
        cyberToken.approve(address(cyberVault), type(uint256).max);

        uint256 expectedShares = cyberVault.previewDeposit(amount);
        uint256 actualShares = cyberVault.deposit(amount, alice);
        assertEq(expectedShares, actualShares, "ERR1");

        uint256 expectedAssets = cyberVault.previewMint(amount);
        uint256 actualAssets = cyberVault.mint(amount, alice);
        assertEq(expectedAssets, actualAssets, "ERR2");

        uint256 expectedWithdraw = cyberVault.previewWithdraw(amount / 2);
        uint256 actualWithdraw = cyberVault.initiateWithdraw(amount / 2);
        assertEq(expectedWithdraw, actualWithdraw, "ERR3");

        uint256 expectedRedeem = cyberVault.previewRedeem(amount / 2);
        uint256 actualRedeem = cyberVault.initiateRedeem(amount / 2);
        assertEq(expectedRedeem, actualRedeem, "ERR4");

        vm.warp(start + 1 days);
        expectedShares = cyberVault.previewDeposit(amount);
        assertNotEq(expectedShares, actualShares, "ERR5");
        actualShares = cyberVault.deposit(amount, alice);
        assertEq(expectedShares, actualShares, "ERR6");
        console.log("actualShares", actualShares);

        expectedAssets = cyberVault.previewMint(amount);
        assertNotEq(expectedAssets, actualAssets, "ERR7");
        actualAssets = cyberVault.mint(amount, alice);
        assertEq(expectedAssets, actualAssets, "ERR8");
        console.log("actualAssets", actualAssets);

        expectedWithdraw = cyberVault.previewWithdraw(amount);
        assertNotEq(expectedWithdraw, actualWithdraw, "ERR9");
        actualWithdraw = cyberVault.initiateWithdraw(amount);
        assertEq(expectedWithdraw, actualWithdraw, "ERR10");
        console.log("actualWithdraw", actualWithdraw);

        expectedRedeem = cyberVault.previewRedeem(amount);
        assertNotEq(expectedRedeem, actualRedeem, "ERR11");
        actualRedeem = cyberVault.initiateRedeem(amount);
        assertEq(expectedRedeem, actualRedeem, "ERR12");
        console.log("actualRedeem", actualRedeem);

        uint256[] memory assets = new uint256[](2);
        assets[0] = amount;
        assets[1] = amount;
        address[] memory receivers = new address[](2);
        receivers[0] = bob;
        receivers[1] = charlie;

        cyberVault.batchDeposit(assets, receivers);
        assertEq(
            cyberVault.balanceOf(bob),
            cyberVault.balanceOf(charlie),
            "ERR13"
        );
    }

    function testInitiateRedeem() public {
        uint256 amount = cyberStakingPool.minimalStakeAmount();

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
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, owner);
        assertEq(
            cyberStakingPool.balanceOf(address(cyberVault)),
            amount,
            "ERR1"
        );

        vm.warp(start + 1 days);
        uint256 shares = cyberVault.balanceOf(owner);
        cyberVault.initiateRedeem(shares / 2);
        assertEq(cyberVault.balanceOf(address(cyberVault)), shares / 2, "ERR2");
        assertEq(cyberVault.balanceOf(owner), shares / 2, "ERR3");
        assertNotEq(cyberToken.balanceOf(treasury), 0, "ERR4");
        assertGt(
            cyberStakingPool.balanceOf(address(cyberVault)),
            amount / 2,
            "ERR5"
        );
        assertGt(
            cyberStakingPool.balanceOf(address(cyberStakingPool)),
            amount / 2,
            "ERR6"
        );
        assertGt(
            cyberStakingPool.lockedAmountByUser(address(cyberVault)),
            amount / 2,
            "ERR7"
        );
    }

    function testInitiateWithdraw() public {
        uint256 amount = cyberStakingPool.minimalStakeAmount();

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
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, owner);
        assertEq(
            cyberStakingPool.balanceOf(address(cyberVault)),
            amount,
            "ERR1"
        );

        vm.warp(start + 1 days);
        uint256 shares = cyberVault.balanceOf(owner);
        cyberVault.initiateWithdraw(amount / 2);
        assertLt(cyberVault.balanceOf(address(cyberVault)), shares / 2, "ERR2");
        assertGt(cyberVault.balanceOf(owner), shares / 2, "ERR3");
        assertNotEq(cyberToken.balanceOf(treasury), 0, "ERR4");
        assertGt(
            cyberStakingPool.balanceOf(address(cyberVault)),
            amount / 2,
            "ERR5"
        );
        assertEq(
            cyberStakingPool.balanceOf(address(cyberStakingPool)),
            amount / 2,
            "ERR6"
        );
        assertEq(
            cyberStakingPool.lockedAmountByUser(address(cyberVault)),
            amount / 2,
            "ERR7"
        );
    }

    function testRedeem() public {
        uint256 amount = cyberStakingPool.minimalStakeAmount();
        vm.startPrank(alice);
        vm.warp(block.timestamp);

        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, alice);

        uint256 shares = cyberVault.balanceOf(alice);
        cyberVault.initiateRedeem(shares / 2);

        vm.expectRevert("INVALID_SHARES");
        cyberVault.redeem(shares, alice, alice);

        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberVault.redeem(shares / 2, alice, alice);

        vm.warp(block.timestamp + 8 days);
        cyberVault.redeem(shares / 2, alice, alice);
        assertLt(cyberVault.balanceOf(address(cyberVault)), shares);
        assertGt(cyberToken.balanceOf(alice), 0);
    }

    function testWithdraw() public {
        uint256 amount = cyberStakingPool.minimalStakeAmount();
        vm.startPrank(alice);
        vm.warp(block.timestamp);

        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, alice);

        uint256 shares = cyberVault.balanceOf(alice);
        uint256 assets = cyberVault.previewWithdraw(shares);
        cyberVault.initiateWithdraw(assets / 2);

        vm.expectRevert("INVALID_ASSETS");
        cyberVault.withdraw(assets, alice, alice);

        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberVault.withdraw(assets / 2, alice, alice);

        vm.warp(block.timestamp + 8 days);
        cyberVault.withdraw(assets / 2, alice, alice);
        assertLt(cyberVault.balanceOf(address(cyberVault)), shares);
        assertGt(cyberToken.balanceOf(alice), 0);
    }

    function testClaimAndStake() public {
        uint256 amount = cyberStakingPool.minimalStakeAmount();
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
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, owner);

        vm.warp(block.timestamp + 8 days);
        uint256 oldBlance = cyberStakingPool.balanceOf(address(cyberVault));
        cyberToken.mint(owner, amount);
        cyberVault.claimAndStake();
        assertGt(cyberStakingPool.balanceOf(address(cyberVault)), oldBlance);
    }
}
