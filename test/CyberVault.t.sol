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

    function testWithdraw() public {
        uint256 amount = cyberStakingPool.minimalStakeAmount();
        vm.startPrank(alice);
        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, alice);
        console.log("stage1");
        console.log(cyberVault.totalAssets());
        console.log(cyberVault.totalSupply());

        uint256 shares = cyberVault.balanceOf(alice);
        cyberVault.initiateRedeem(shares);
        console.log("stage2");
        console.log(cyberVault.totalAssets());
        console.log(cyberVault.totalSupply());

        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberVault.redeem(shares, alice, alice);

        vm.warp(block.timestamp + cyberStakingPool.lockDuration() / 2);

        vm.startPrank(bob);
        cyberToken.mint(bob, amount);
        cyberToken.approve(address(cyberVault), amount);
        cyberVault.deposit(amount, bob);
        console.log("stage3");
        console.log(cyberVault.totalAssets());
        console.log(cyberVault.totalSupply());

        cyberVault.initiateRedeem(shares);

        vm.warp(block.timestamp + cyberStakingPool.lockDuration() / 2);

        vm.startPrank(alice);
        cyberVault.redeem(shares, alice, alice);
        assertEq(cyberToken.balanceOf(alice), amount);
        console.log("stage4");
        console.log(cyberVault.totalAssets());
        console.log(cyberVault.totalSupply());

        vm.startPrank(bob);
        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberVault.redeem(shares, bob, bob);

        vm.warp(block.timestamp + cyberStakingPool.lockDuration() / 2);

        cyberVault.redeem(shares, bob, bob);
        assertEq(cyberToken.balanceOf(bob), amount);
        console.log("stage5");
        console.log(cyberVault.totalAssets());
        console.log(cyberVault.totalSupply());
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
        assertNotEq(cyberVault.balanceOf(treasury), 0, "ERR4");
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
        assertNotEq(cyberVault.balanceOf(treasury), 0, "ERR4");
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
