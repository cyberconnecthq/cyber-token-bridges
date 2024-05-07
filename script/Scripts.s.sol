// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.22;

import "forge-std/Script.sol";
import { DeploySetting } from "./libraries/DeploySetting.sol";
import { LibDeploy, Create2Deployer } from "./libraries/LibDeploy.sol";
import { CyberTokenAdapter } from "../src/CyberTokenAdapter.sol";
import { CyberTokenController } from "../src/CyberTokenController.sol";

import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract DeployAdapter is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.SEPOLIA) {
            address adapter = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(
                        type(CyberTokenAdapter).creationCode,
                        abi.encode(
                            deployParams[block.chainid].cyberToken, // cyber token
                            deployParams[block.chainid].lzEndpoint, // layerzero endpoint
                            deployParams[block.chainid].protocolOwner // owner
                        )
                    ),
                    LibDeploy.SALT
                );
            LibDeploy._write(vm, "CyberTokenAdapter", adapter);
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract DeployController is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.BNBT ||
            block.chainid == DeploySetting.CYBER_TESTNET
        ) {
            address adapter = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(
                        type(CyberTokenController).creationCode,
                        abi.encode(
                            deployParams[block.chainid].cyberToken, // cyber token
                            deployParams[block.chainid].lzEndpoint, // layerzero endpoint
                            deployParams[block.chainid].protocolOwner // owner
                        )
                    ),
                    LibDeploy.SALT
                );
            LibDeploy._write(vm, "CyberTokenController", adapter);
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract ConfigOApp is Script, DeploySetting {
    using OptionsBuilder for bytes;
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.SEPOLIA ||
            block.chainid == DeploySetting.BNBT ||
            block.chainid == DeploySetting.CYBER_TESTNET
        ) {
            DeployParameters memory fromChainParams = deployParams[
                block.chainid
            ];
            DeployParameters memory toChainParams = deployParams[
                DeploySetting.CYBER_TESTNET
            ];
            OFTCore(fromChainParams.lzController).setPeer(
                toChainParams.eid,
                bytes32(uint256(uint160(toChainParams.lzController)))
            );
            bytes memory receiveOption = OptionsBuilder
                .newOptions()
                .addExecutorLzReceiveOption(60000, 0);
            EnforcedOptionParam[]
                memory enforcedOptions = new EnforcedOptionParam[](1);
            enforcedOptions[0] = EnforcedOptionParam(
                toChainParams.eid,
                1,
                receiveOption
            );
            OFTCore(fromChainParams.lzController).setEnforcedOptions(
                enforcedOptions
            );
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract TestBridge is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.SEPOLIA) {
            DeployParameters memory fromChainParams = deployParams[
                block.chainid
            ];
            DeployParameters memory toChainParams = deployParams[
                DeploySetting.CYBER_TESTNET
            ];

            uint256 amountToBridge = 1 ether + 1 wei;
            SendParam memory sendParam = SendParam(
                toChainParams.eid,
                bytes32(uint256(uint160(msg.sender))),
                amountToBridge,
                amountToBridge,
                new bytes(0),
                new bytes(0),
                new bytes(0)
            );

            MessagingFee memory msgFee = OFTCore(fromChainParams.lzController)
                .quoteSend(sendParam, false);

            IERC20(fromChainParams.cyberToken).approve(
                fromChainParams.lzController,
                amountToBridge
            );
            OFTCore(fromChainParams.lzController).send{
                value: msgFee.nativeFee
            }(sendParam, msgFee, msg.sender);
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract TransferTokenOwner is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.BNBT ||
            block.chainid == DeploySetting.CYBER_TESTNET
        ) {
            Ownable(deployParams[block.chainid].cyberToken).transferOwnership(
                deployParams[block.chainid].lzController
            );
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}
