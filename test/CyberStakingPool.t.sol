// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { Test, console } from "forge-std/Test.sol";
import { MockCyberToken } from "./utils/MockCyberToken.sol";
import { CyberStakingPool } from "../src/CyberStakingPool.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CyberStakingPoolTest is Test {
    CyberStakingPool cyberStakingPool;
    MockCyberToken cyberToken;

    address owner = address(1);
    address lzEndpoint = address(2);
    address alice = address(4);
    address bob = address(5);

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

        cyberStakingPool.stake(amount);

        assertEq(
            cyberToken.balanceOf(address(cyberStakingPool)),
            amount,
            "ERR1"
        );
        assertEq(cyberStakingPool.balanceOf(alice), amount, "ERR2");
    }

    function testWithdraw() public {
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberStakingPool), amount);

        cyberStakingPool.stake(amount);

        bytes32 key = bytes32(uint256(uint160(alice)));
        cyberStakingPool.unstake(amount, key);

        vm.expectRevert("LOCKED_PERIOD_NOT_ENDED");
        cyberStakingPool.withdraw(key);

        vm.warp(block.timestamp + cyberStakingPool.lockDuration());

        cyberStakingPool.withdraw(key);
        assertEq(cyberToken.balanceOf(alice), amount, "ERR3");
        assertEq(cyberStakingPool.balanceOf(alice), 0, "ERR4");
    }

    function testTransfer() public {
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        cyberToken.mint(alice, amount);
        cyberToken.approve(address(cyberStakingPool), amount);

        cyberStakingPool.stake(amount);

        vm.expectRevert("TRANSFER_PAUSED");
        cyberStakingPool.transfer(bob, amount);
    }
}
