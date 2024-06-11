// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.22;

import "forge-std/Script.sol";
import { DeploySetting } from "./libraries/DeploySetting.sol";
import { LibDeploy, Create2Deployer } from "./libraries/LibDeploy.sol";
import { CyberTokenAdapter } from "../src/CyberTokenAdapter.sol";
import { CyberTokenController } from "../src/CyberTokenController.sol";
import { CyberStakingPool } from "../src/CyberStakingPool.sol";
import { CyberVault } from "../src/CyberVault.sol";
import { LaunchTokenWithdrawer } from "../src/LaunchTokenWithdrawer.sol";
import { RewardTokenWithdrawer } from "../src/RewardTokenWithdrawer.sol";

import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TempScript is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();
        vm.stopBroadcast();
    }
}

contract GetOappConfog is Script, DeploySetting {
    // the formal properties are documented in the setter functions
    struct UlnConfig {
        uint64 confirmations;
        // we store the length of required DVNs and optional DVNs instead of using DVN.length directly to save gas
        uint8 requiredDVNCount; // 0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
        uint8 optionalDVNCount; // 0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
        uint8 optionalDVNThreshold; // (0, optionalDVNCount]
        address[] requiredDVNs; // no duplicates. sorted an an ascending order. allowed overlap with optionalDVNs
        address[] optionalDVNs; // no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
    }

    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        bytes memory config = ILayerZeroEndpointV2(
            deployParams[block.chainid].lzEndpoint
        ).getConfig(
                deployParams[block.chainid].lzController,
                deployParams[block.chainid].lzReceiveLib,
                // deployParams[block.chainid].lzSendLib,
                deployParams[DeploySetting.BNB].eid,
                2 // CONFIG_TYPE_ULN
            );
        console.logBytes(config);

        UlnConfig memory ulnConfig = abi.decode(config, (UlnConfig));
        console.log(ulnConfig.confirmations);
        console.log(ulnConfig.requiredDVNCount);
        console.log(ulnConfig.optionalDVNCount);
        console.log(ulnConfig.optionalDVNThreshold);
        for (uint256 i = 0; i < ulnConfig.requiredDVNs.length; i++) {
            console.logAddress(ulnConfig.requiredDVNs[i]);
        }
        for (uint256 i = 0; i < ulnConfig.optionalDVNs.length; i++) {
            console.logAddress(ulnConfig.optionalDVNs[i]);
        }

        vm.stopBroadcast();
    }
}

contract ResetOappConfig is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.BNB ||
            block.chainid == DeploySetting.ETH ||
            block.chainid == DeploySetting.OPTIMISM ||
            block.chainid == DeploySetting.CYBER
        ) {
            uint256 srcChainId = block.chainid;
            uint256[4] memory dstChainIds = [
                DeploySetting.ETH,
                DeploySetting.BNB,
                DeploySetting.OPTIMISM,
                DeploySetting.CYBER
            ];

            for (uint256 i = 0; i < dstChainIds.length; i++) {
                uint256 dstChainId = dstChainIds[i];
                if (srcChainId == dstChainId) {
                    continue;
                }
                DeployParameters memory srcChainParams = deployParams[
                    srcChainId
                ];
                DeployParameters memory dstChainParams = deployParams[
                    dstChainId
                ];

                // set peer
                IOAppCore(srcChainParams.lzController).setPeer(
                    dstChainParams.eid,
                    bytes32(0)
                );
            }
        } else {
            revert("CHAIN_ID_NOT_SUPPORTED");
        }

        vm.stopBroadcast();
    }
}

contract SetOappConfig is Script, DeploySetting {
    using OptionsBuilder for bytes;
    // the formal properties are documented in the setter functions
    struct UlnConfig {
        uint64 confirmations;
        // we store the length of required DVNs and optional DVNs instead of using DVN.length directly to save gas
        uint8 requiredDVNCount; // 0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
        uint8 optionalDVNCount; // 0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
        uint8 optionalDVNThreshold; // (0, optionalDVNCount]
        address[] requiredDVNs; // no duplicates. sorted an an ascending order. allowed overlap with optionalDVNs
        address[] optionalDVNs; // no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
    }

    function setupMsgLibOneOutOfOneParam(
        uint256 srcChainId,
        uint256 dstChainId,
        uint64 confirmations
    ) private view returns (SetConfigParam[] memory) {
        SetConfigParam[] memory params = new SetConfigParam[](1);
        address[] memory requiredDVNs = new address[](1);
        // sort DVNs in ascending order
        address lzLabsDVN = deployParams[srcChainId].lzLabsDVN;
        requiredDVNs[0] = lzLabsDVN;

        params[0] = SetConfigParam(
            deployParams[dstChainId].eid,
            2, // CONFIG_TYPE_ULN
            abi.encode(
                UlnConfig(
                    confirmations, // confirmations
                    1, // requiredDVNCount
                    0, // optionalDVNCount
                    0, // optionalDVNThreshold
                    requiredDVNs,
                    new address[](0)
                )
            )
        );
        return params;
    }

    function setupMsgLibParam(
        uint256 srcChainId,
        uint256 dstChainId,
        uint64 confirmations
    ) private view returns (SetConfigParam[] memory) {
        SetConfigParam[] memory params = new SetConfigParam[](1);
        address[] memory requiredDVNs = new address[](2);
        // sort DVNs in ascending order
        address lzLabsDVN = deployParams[srcChainId].lzLabsDVN;
        address lzPolyhedraDVN = deployParams[srcChainId].lzPolyhedraDVN;
        if (lzLabsDVN < lzPolyhedraDVN) {
            requiredDVNs[0] = lzLabsDVN;
            requiredDVNs[1] = lzPolyhedraDVN;
        } else {
            requiredDVNs[0] = lzPolyhedraDVN;
            requiredDVNs[1] = lzLabsDVN;
        }
        params[0] = SetConfigParam(
            deployParams[dstChainId].eid,
            2, // CONFIG_TYPE_ULN
            abi.encode(
                UlnConfig(
                    confirmations, // confirmations
                    2, // requiredDVNCount
                    0, // optionalDVNCount
                    0, // optionalDVNThreshold
                    requiredDVNs,
                    new address[](0)
                )
            )
        );
        return params;
    }

    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.BNB ||
            block.chainid == DeploySetting.ETH ||
            block.chainid == DeploySetting.OPTIMISM ||
            block.chainid == DeploySetting.CYBER
        ) {
            uint256 srcChainId = block.chainid;
            uint256[1] memory dstChainIds = [
                // DeploySetting.ETH,
                // DeploySetting.BNB,
                DeploySetting.OPTIMISM
                // DeploySetting.CYBER
            ];

            for (uint256 i = 0; i < dstChainIds.length; i++) {
                uint256 dstChainId = dstChainIds[i];
                if (srcChainId == dstChainId) {
                    continue;
                }
                DeployParameters memory srcChainParams = deployParams[
                    srcChainId
                ];
                DeployParameters memory dstChainParams = deployParams[
                    dstChainId
                ];

                // set send dvn
                // SetConfigParam[]
                //     memory sendParams = setupMsgLibOneOutOfOneParam(
                //         srcChainId,
                //         dstChainId,
                //         srcChainParams.confirmations
                //     );
                // ILayerZeroEndpointV2(srcChainParams.lzEndpoint).setConfig(
                //     srcChainParams.lzController,
                //     srcChainParams.lzSendLib,
                //     sendParams
                // );

                // set receive dvn
                SetConfigParam[]
                    memory receiveParams = setupMsgLibOneOutOfOneParam(
                        srcChainId,
                        dstChainId,
                        dstChainParams.confirmations
                    );

                ILayerZeroEndpointV2(srcChainParams.lzEndpoint).setConfig(
                    srcChainParams.lzController,
                    srcChainParams.lzReceiveLib,
                    receiveParams
                );

                // set peer
                // IOAppCore(srcChainParams.lzController).setPeer(
                //     dstChainParams.eid,
                //     bytes32(uint256(uint160(dstChainParams.lzController)))
                // );

                // enforced options
                // bytes memory receiveOption = OptionsBuilder
                //     .newOptions()
                //     .addExecutorLzReceiveOption(dstChainParams.enforcedGas, 0);
                // EnforcedOptionParam[]
                //     memory enforcedOptions = new EnforcedOptionParam[](1);
                // enforcedOptions[0] = EnforcedOptionParam(
                //     dstChainParams.eid,
                //     1, // SEND
                //     receiveOption
                // );
                // OFTCore(srcChainParams.lzController).setEnforcedOptions(
                //     enforcedOptions
                // );
            }
        } else {
            revert("CHAIN_ID_NOT_SUPPORTED");
        }

        vm.stopBroadcast();
    }
}

contract DeployAdapter is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.SEPOLIA ||
            block.chainid == DeploySetting.ETH
        ) {
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
            block.chainid == DeploySetting.CYBER_TESTNET ||
            block.chainid == DeploySetting.BNB ||
            block.chainid == DeploySetting.OPTIMISM ||
            block.chainid == DeploySetting.CYBER
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

contract TestBridge is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.SEPOLIA ||
            block.chainid == DeploySetting.CYBER_TESTNET ||
            block.chainid == DeploySetting.BNBT
        ) {
            DeployParameters memory fromChainParams = deployParams[
                block.chainid
            ];
            DeployParameters memory toChainParams = deployParams[
                DeploySetting.BNBT
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
        } else if (
            block.chainid == DeploySetting.BNB ||
            block.chainid == DeploySetting.ETH ||
            block.chainid == DeploySetting.OPTIMISM ||
            block.chainid == DeploySetting.CYBER
        ) {
            uint256 srcChainId = block.chainid;
            uint256[1] memory dstChainIds = [
                // DeploySetting.ETH,
                // DeploySetting.BNB,
                // DeploySetting.OPTIMISM
                DeploySetting.CYBER
            ];

            for (uint256 i = 0; i < dstChainIds.length; i++) {
                uint256 dstChainId = dstChainIds[i];
                if (srcChainId == dstChainId) {
                    continue;
                }
                DeployParameters memory srcChainParams = deployParams[
                    srcChainId
                ];
                DeployParameters memory dstChainParams = deployParams[
                    dstChainId
                ];

                uint256 amountToBridge = 1 ether + 1 wei;
                SendParam memory sendParam = SendParam(
                    dstChainParams.eid,
                    bytes32(uint256(uint160(msg.sender))),
                    amountToBridge,
                    amountToBridge,
                    new bytes(0),
                    new bytes(0),
                    new bytes(0)
                );

                MessagingFee memory msgFee = OFTCore(
                    srcChainParams.lzController
                ).quoteSend(sendParam, false);

                // eth
                require(msgFee.nativeFee <= 0.003 ether, "TOO_HIGH_FEE");
                // bsc
                // require(msgFee.nativeFee <= 0.02 ether, "TOO_HIGH_FEE");

                uint256 currentAllowed = IERC20(srcChainParams.cyberToken)
                    .allowance(msg.sender, srcChainParams.lzController);
                if (currentAllowed < amountToBridge) {
                    IERC20(srcChainParams.cyberToken).approve(
                        srcChainParams.lzController,
                        type(uint256).max
                    );
                }
                OFTCore(srcChainParams.lzController).send{
                    value: msgFee.nativeFee
                }(sendParam, msgFee, msg.sender);
            }
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

contract DeployWithdrawer is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.BNBT ||
            block.chainid == DeploySetting.OP_SEPOLIA ||
            block.chainid == DeploySetting.SEPOLIA
        ) {
            address withdrawer = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(
                        type(LaunchTokenWithdrawer).creationCode,
                        abi.encode(
                            deployParams[block.chainid].protocolOwner, // owner
                            deployParams[block.chainid].cyberToken, // cyber token
                            bytes32(
                                0x5b982cbc0aaa3c4a565587cbe7fdf90ec7fdcf1a7dd1c99f8c4b80246a1f3826
                            ), // merkle root
                            deployParams[block.chainid].protocolOwner // bridge recipient
                        )
                    ),
                    LibDeploy.SALT
                );
            LibDeploy._write(vm, "LaunchTokenWithdrawer", withdrawer);
        } else if (block.chainid == DeploySetting.CYBER_TESTNET) {
            address withdrawer = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(
                        type(RewardTokenWithdrawer).creationCode,
                        abi.encode(
                            deployParams[block.chainid].protocolOwner, // owner
                            deployParams[block.chainid].cyberToken, // cyber token
                            deployParams[block.chainid].cyberVault, // cyber vault
                            bytes32(
                                0x787701ccbc9901e0784d311f884298f249e9ee386c5f5097d5866d7f0c446318
                            ) // merkle root
                        )
                    ),
                    LibDeploy.SALT
                );
            LibDeploy._write(vm, "RewardTokenWithdrawer", withdrawer);
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract ConfigWithdrawer is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.BNBT ||
            block.chainid == DeploySetting.OP_SEPOLIA ||
            block.chainid == DeploySetting.SEPOLIA
        ) {
            LaunchTokenWithdrawer(deployParams[block.chainid].withdrawer)
                .setLockDuration(5 minutes);
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract TestBridgeAndStake is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.BNBT) {
            bytes32[] memory merkleProof = new bytes32[](2);
            merkleProof[0] = bytes32(
                0x656c2b18f876f81b6f8f77f9d6dddc13e3bc3bce90786ddf6fd8e386e3faa1dc
            );
            merkleProof[1] = bytes32(
                0xe7b5a97720b58f02fc30a748f545603cb455138f10c7c5470e492b9c88f5c25c
            );

            LaunchTokenWithdrawer(deployParams[block.chainid].withdrawer)
                .bridgeAndStake(
                    0,
                    0x0e0bE581B17684f849AF6964D731FCe0F7d366BD,
                    1,
                    merkleProof
                );
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract DeployCyberVault is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.CYBER_TESTNET) {
            address cyberVaultImpl = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(type(CyberVault).creationCode),
                    LibDeploy.SALT
                );

            LibDeploy._write(vm, "CyberVault(Impl)", cyberVaultImpl);

            address cyberVaultProxy = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            cyberVaultImpl,
                            abi.encodeWithSelector(
                                CyberVault.initialize.selector,
                                deployParams[block.chainid].protocolOwner,
                                deployParams[block.chainid].cyberToken,
                                deployParams[block.chainid].cyberStakingPool,
                                deployParams[block.chainid].treasury
                            )
                        )
                    ),
                    LibDeploy.SALT
                );
            LibDeploy._write(vm, "CyberVault(Proxy)", cyberVaultProxy);
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract ConfigCyberVault is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.CYBER_TESTNET) {
            CyberVault(deployParams[block.chainid].cyberVault).setLockDuration(
                5 minutes
            );
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract DeployCyberStakingPool is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.CYBER_TESTNET) {
            address stakingPoolImpl = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(type(CyberStakingPool).creationCode),
                    LibDeploy.SALT
                );

            LibDeploy._write(vm, "CyberStakingPool(Impl)", stakingPoolImpl);

            address stakingPoolProxy = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            stakingPoolImpl,
                            abi.encodeWithSelector(
                                CyberStakingPool.initialize.selector,
                                deployParams[block.chainid].protocolOwner,
                                deployParams[block.chainid].cyberToken
                            )
                        )
                    ),
                    LibDeploy.SALT
                );
            LibDeploy._write(vm, "CyberStakingPool(Proxy)", stakingPoolProxy);
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract ConfigCyberStakingPool is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.CYBER_TESTNET) {
            CyberStakingPool(deployParams[block.chainid].cyberStakingPool)
                .setLockDuration(5 minutes);
            // CyberStakingPool(deployParams[block.chainid].cyberStakingPool)
            //     .setMinimalStakeAmount(1 ether);
            // uint256 totalRewards = 500000 ether;
            // uint256 startTime = 1717516800;
            // uint256 endTime = startTime + 90 days;
            // CyberStakingPool(deployParams[block.chainid].cyberStakingPool)
            //     .createDistribution(
            //         uint128(totalRewards / 90 days),
            //         uint40(startTime),
            //         uint40(endTime)
            //     );
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}
