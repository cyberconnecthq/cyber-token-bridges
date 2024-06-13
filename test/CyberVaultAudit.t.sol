pragma solidity ^0.8.22;

import { Test, console } from "forge-std/Test.sol";
import { MockCyberToken } from "./utils/MockCyberToken.sol";
import { CyberVault, LockAmount } from "../src/CyberVault.sol";
import { CyberStakingPool } from "../src/CyberStakingPool.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract CyberVaultTest is Test {
    using Math for uint256;
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

    function testCalcShares() public {
        uint256 minAmount = cyberStakingPool.minimalStakeAmount();

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

        cyberToken.mint(alice, minAmount);
        cyberToken.mint(bob, minAmount);
        cyberToken.mint(charlie, minAmount);

        // alice deposit
        vm.startPrank(alice);
        cyberToken.approve(address(cyberVault), type(uint256).max);
        cyberVault.deposit(minAmount, alice);
        uint256 sharesAlice = cyberVault.balanceOf(alice);
        console.log("sharesAlice", sharesAlice);

        // bob deposit
        vm.startPrank(bob);
        cyberToken.approve(address(cyberVault), type(uint256).max);
        cyberVault.deposit(minAmount, bob);
        uint256 sharesBob = cyberVault.balanceOf(bob);
        console.log("sharesBob", sharesBob);

        // increase rewards
        vm.warp(block.timestamp + 2 days);
        uint256 totalRewards = cyberStakingPool.claimableAllRewards(
            address(cyberVault)
        );
        console.log("totalRewards", totalRewards);

        // alice unstake
        vm.startPrank(alice);
        cyberVault.initiateRedeem(sharesAlice);
        LockAmount memory aliceLockAmount = cyberVault.getLockAmount(alice);
        console.log("aliceLockAmount", aliceLockAmount.lockedAssets);
        console.log("aliceLockedShares", aliceLockAmount.lockedShares);

        // increase rewards
        vm.warp(block.timestamp + 10 days);
        uint256 newTotalRewards = cyberStakingPool.claimableAllRewards(
            address(cyberVault)
        );
        console.log("newTotalRewards", newTotalRewards);

        uint256 vaultTotalSupply = cyberVault.totalSupply() +
            aliceLockAmount.lockedShares;
        uint256 vaultTotalAssets = cyberVault.totalAssets() +
            aliceLockAmount.lockedAssets;

        // charlie deposit
        vm.startPrank(charlie);
        {
            // Calculation: If Alice's share of withdrawals and funds are burned before Charlie's deposit, how much share should Charlie receive?
            uint256 charlieShares = minAmount.mulDiv(
                vaultTotalSupply + 1,
                vaultTotalAssets + 1,
                Math.Rounding.Floor
            );
            console.log("sharesCharlie1", charlieShares);
        }

        cyberToken.approve(address(cyberVault), type(uint256).max);
        cyberVault.deposit(minAmount, charlie);
        // Calculation: According to the current design, how much share should Charlie receive?
        uint256 sharesCharlie = cyberVault.balanceOf(charlie);
        console.log("sharesCharlie2", sharesCharlie);

        // alice redeem
        vm.startPrank(alice);
        cyberVault.redeem(aliceLockAmount.lockedShares, alice, alice);

        // charlie unstake
        vm.startPrank(charlie);
        cyberVault.initiateRedeem(sharesCharlie);
        LockAmount memory charlieLockAmount = cyberVault.getLockAmount(charlie);
        console.log("charlieLockAmount", charlieLockAmount.lockedAssets);
        console.log("charlieLockedShares", charlieLockAmount.lockedShares);
    }
}
