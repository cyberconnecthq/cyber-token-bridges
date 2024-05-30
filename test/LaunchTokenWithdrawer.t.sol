// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { Test, console } from "forge-std/Test.sol";

import { MockCyberToken } from "./utils/MockCyberToken.sol";

import { LaunchTokenWithdrawer } from "../src/LaunchTokenWithdrawer.sol";

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";

contract LaunchTokenWithdrawerTest is Test {
    LaunchTokenWithdrawer launchTokenWithdrawer;
    MockCyberToken cyberToken;

    address owner = address(1);
    address alice = address(2);
    address bob = address(3);
    address bridgeRecipient = address(4);
    bytes32 merkleRoot = 0x6d5dc6fe135c77c34c3a902394c654348fa1c1cf887a6d9c2092aab9784e00d1;

    function setUp() public {
        cyberToken = new MockCyberToken();
        launchTokenWithdrawer = new LaunchTokenWithdrawer(owner, address(cyberToken), merkleRoot, bridgeRecipient);
    }

    function testInitiateWithdraw() public {
        vm.startPrank(alice);
        uint256 index = 0;
        bytes32[] memory merkleProof = new bytes32[](0);

        uint256 amount = 100;
        launchTokenWithdrawer.initiateWithdraw(index, alice, amount, merkleProof);

        vm.expectRevert("ALREADY_CLAIMED");
        launchTokenWithdrawer.initiateWithdraw(index, alice, amount, merkleProof);

        vm.expectRevert("INVALID_PROOF");
        launchTokenWithdrawer.initiateWithdraw(index+1, bob, amount, merkleProof);
    }

    function testWithdraw() public {
        vm.startPrank(alice);
        uint256 index = 0;
        bytes32[] memory merkleProof = new bytes32[](0);

        uint256 amount = 100;
        cyberToken.mint(address(launchTokenWithdrawer), amount);
        assertEq(cyberToken.balanceOf(address(launchTokenWithdrawer)), amount);

        launchTokenWithdrawer.initiateWithdraw(index, alice, amount, merkleProof);

        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("LOCKED");
        launchTokenWithdrawer.withdraw(alice);

        vm.warp(block.timestamp + 8 days);
        launchTokenWithdrawer.withdraw(alice);
        assertEq(cyberToken.balanceOf(alice), amount);
        assertEq(cyberToken.balanceOf(address(launchTokenWithdrawer)), 0);
    }

    function testBridge() public {
        vm.startPrank(owner);

        uint256 amount = 100;
        cyberToken.mint(address(launchTokenWithdrawer), amount);
        assertEq(cyberToken.balanceOf(address(launchTokenWithdrawer)), amount);

        bytes32[] memory merkleProof = new bytes32[](0);
        uint256 index = 0;

        // MessagingFee memory fee = launchTokenWithdrawer.quoteBridge(index, alice, amount, merkleProof, 210000);

        // vm.expectRevert("INVALID_PROOF");
        // launchTokenWithdrawer.bridge(index, bob, amount, merkleProof, fee, 210000);

        // launchTokenWithdrawer.bridge(index, alice, amount, merkleProof, fee, 210000);
        // assertEq(cyberToken.balanceOf(alice), 0);

        // launchTokenWithdrawer.initiateWithdraw(index, alice, amount, merkleProof);
        // vm.expectRevert("ALREADY_CLAIMED");
        // launchTokenWithdrawer.bridge(index, alice, amount, merkleProof, fee, 210000);
    }
}
