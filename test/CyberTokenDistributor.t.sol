// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { Test, console } from "forge-std/Test.sol";
import { MockCyberToken } from "./utils/MockCyberToken.sol";
import { CyberTokenDistributor } from "../src/CyberTokenDistributor.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TestLib712 } from "./utils/TestLib712.sol";

contract CyberStakingPoolTest is Test {
    CyberTokenDistributor cyberTokenDistributor;
    MockCyberToken cyberToken;

    address owner = address(1);
    address alice = address(2);
    address bob = address(3);
    uint256 signerSk = 11111;
    address signer = vm.addr(signerSk);

    event Claimed(address user, bytes32 claimId);

    function setUp() public {
        cyberToken = new MockCyberToken();

        address cyberTokenDistributorImpl = address(
            new CyberTokenDistributor()
        );

        address cyberTokenDistributorProxy = address(
            new ERC1967Proxy(
                cyberTokenDistributorImpl,
                abi.encodeWithSelector(
                    CyberTokenDistributor.initialize.selector,
                    owner,
                    signer,
                    address(cyberToken)
                )
            )
        );
        cyberTokenDistributor = CyberTokenDistributor(
            cyberTokenDistributorProxy
        );
    }

    function testClaim() public {
        uint256 amount = 10000 ether;
        cyberToken.mint(address(cyberTokenDistributor), amount);

        bytes32 claimId = keccak256(abi.encodePacked(alice, amount));
        uint256 deadline = block.timestamp + 1000;

        bytes memory signature = _generateSig(
            signerSk,
            deadline,
            alice,
            claimId,
            amount
        );

        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Claimed(alice, claimId);
        cyberTokenDistributor.claim(claimId, amount, deadline, signature);
        assertEq(cyberToken.balanceOf(alice), amount);
        assertEq(cyberToken.balanceOf(address(cyberTokenDistributor)), 0);

        vm.expectRevert("CLAIM_ID_USED");
        cyberTokenDistributor.claim(claimId, amount, deadline, signature);

        vm.warp(deadline + 1);
        vm.expectRevert("DEADLINE_EXPIRED");
        cyberTokenDistributor.claim(claimId, amount, deadline, signature);
    }

    function _generateSig(
        uint256 signerPk,
        uint256 deadline,
        address user,
        bytes32 claimId,
        uint256 amount
    ) internal view returns (bytes memory) {
        bytes32 digest = TestLib712.hashTypedDataV4(
            address(cyberTokenDistributor),
            keccak256(
                abi.encode(
                    cyberTokenDistributor.CLAIM_TYPEHASH(),
                    user,
                    claimId,
                    amount,
                    deadline
                )
            ),
            "CyberTokenDistributor",
            "1"
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return abi.encodePacked(r, s, v);
    }
}
