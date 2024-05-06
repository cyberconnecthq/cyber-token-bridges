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

contract DeployAdapter is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.SEPOLIA) {
            address adapter = Create2Deployer(deployParams.deployerContract)
                .deploy(
                    abi.encodePacked(
                        type(CyberTokenAdapter).creationCode,
                        abi.encode(
                            0xF616904ac19f5bE8206A923E92bFf8953a16c7Fc, // cyber token
                            0x6EDCE65403992e310A62460808c4b910D972f10f, // layerzero endpoint
                            deployParams.protocolOwner // owner
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

        if (block.chainid == DeploySetting.BNBT) {
            address adapter = Create2Deployer(deployParams.deployerContract)
                .deploy(
                    abi.encodePacked(
                        type(CyberTokenController).creationCode,
                        abi.encode(
                            0xdb359A83ff0B91551161f12e9C5454CC04FA2fCc, // cyber token
                            0x6EDCE65403992e310A62460808c4b910D972f10f, // layerzero endpoint
                            deployParams.protocolOwner // owner
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
        vm.startBroadcast();

        if (block.chainid == DeploySetting.SEPOLIA) {
            // CyberTokenAdapter(0x12E4147A0C8d8d00eb3Eeb30Df3a089aB0420000)
            //     .setPeer(
            //         40102,
            //         bytes32(
            //             uint256(
            //                 uint160(0xD610b93C19e87b7C3039bc8DA906a233aD85386b)
            //             )
            //         )
            //     );
            // bytes memory receiveOption = OptionsBuilder
            //     .newOptions()
            //     .addExecutorLzReceiveOption(60000, 0);
            // EnforcedOptionParam[]
            //     memory enforcedOptions = new EnforcedOptionParam[](1);
            // enforcedOptions[0] = EnforcedOptionParam(40102, 1, receiveOption);
            // CyberTokenAdapter(0x12E4147A0C8d8d00eb3Eeb30Df3a089aB0420000)
            //     .setEnforcedOptions(enforcedOptions);
        } else if (block.chainid == DeploySetting.BNBT) {
            CyberTokenController(0xD610b93C19e87b7C3039bc8DA906a233aD85386b)
                .setPeer(
                    40161,
                    bytes32(
                        uint256(
                            uint160(0x12E4147A0C8d8d00eb3Eeb30Df3a089aB0420000)
                        )
                    )
                );
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract TestBridge is Script, DeploySetting {
    function run() external {
        vm.startBroadcast();

        if (block.chainid == DeploySetting.SEPOLIA) {
            uint256 amountToBridge = 1 ether + 1 wei;
            SendParam memory sendParam = SendParam(
                40102,
                bytes32(uint256(uint160(msg.sender))),
                amountToBridge,
                amountToBridge,
                new bytes(0),
                new bytes(0),
                new bytes(0)
            );

            MessagingFee memory msgFee = CyberTokenAdapter(
                0x12E4147A0C8d8d00eb3Eeb30Df3a089aB0420000
            ).quoteSend(sendParam, false);

            IERC20(0xF616904ac19f5bE8206A923E92bFf8953a16c7Fc).approve(
                0x12E4147A0C8d8d00eb3Eeb30Df3a089aB0420000,
                amountToBridge
            );
            CyberTokenAdapter(0x12E4147A0C8d8d00eb3Eeb30Df3a089aB0420000).send{
                value: msgFee.nativeFee
            }(sendParam, msgFee, msg.sender);
        } else if (block.chainid == DeploySetting.BNBT) {
            // CyberTokenController(0xD610b93C19e87b7C3039bc8DA906a233aD85386b);
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}
