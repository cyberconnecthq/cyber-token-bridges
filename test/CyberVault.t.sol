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
                    lzEndpoint,
                    address(cyberToken),
                    address(cyberStakingPool),
                    treasury
                )
            )
        );
        cyberVault = CyberVault(cyberVaultProxy);
    }

    function testDeposit() public {}

    function testWithdraw() public {}

    function testTransfer() public {}
}
