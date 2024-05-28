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
        // cyberToken = new MockCyberToken();
        // CyberStakingPool cyberStakingPool = new CyberStakingPool(
        //     owner,
        //     address(cyberToken)
        // );
        // cyberVault = new CyberVault(
        //     owner,
        //     lzEndpoint,
        //     cyberToken,
        //     address(cyberStakingPool)
        // );
    }

    function testDeposit() public {}

    function testWithdraw() public {}

    function testTransfer() public {}
}
