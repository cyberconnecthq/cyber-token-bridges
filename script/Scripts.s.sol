// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.22;

import "forge-std/Script.sol";
import { DeploySetting } from "./libraries/DeploySetting.sol";
import { LibDeploy, Create2Deployer } from "./libraries/LibDeploy.sol";
import { CyberTokenAdapter } from "../src/CyberTokenAdapter.sol";
import { CyberTokenController } from "../src/CyberTokenController.sol";
import { StakedCyberToken } from "../src/StakedCyberToken.sol";
import { CyberStakingPool } from "../src/CyberStakingPool.sol";
import { LaunchTokenWithdrawer } from "../src/LaunchTokenWithdrawer.sol";

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
                DeploySetting.BNBT
            ];
            OFTCore(fromChainParams.lzController).setPeer(
                toChainParams.eid,
                bytes32(uint256(uint160(toChainParams.lzController)))
            );
            bytes memory receiveOption = OptionsBuilder
                .newOptions()
                .addExecutorLzReceiveOption(150000, 0);
            EnforcedOptionParam[]
                memory enforcedOptions = new EnforcedOptionParam[](2);
            enforcedOptions[0] = EnforcedOptionParam(
                toChainParams.eid,
                1, // SEND
                receiveOption
            );
            enforcedOptions[1] = EnforcedOptionParam(
                toChainParams.eid,
                2, // SEND_AND_CALL
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

        if (
            block.chainid == DeploySetting.SEPOLIA ||
            block.chainid == DeploySetting.CYBER_TESTNET
        ) {
            DeployParameters memory fromChainParams = deployParams[
                block.chainid
            ];
            DeployParameters memory toChainParams = deployParams[
                DeploySetting.SEPOLIA
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

contract DeployStakedCyber is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.CYBER_TESTNET) {
            address token = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(
                        type(StakedCyberToken).creationCode,
                        abi.encode(
                            deployParams[block.chainid].lzEndpoint, // layerzero endpoint
                            deployParams[block.chainid].protocolOwner // owner
                        )
                    ),
                    LibDeploy.SALT
                );
            LibDeploy._write(vm, "StakedCyberToken", token);
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

        if (block.chainid == DeploySetting.BNBT) {
            address withdrawer = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(
                        type(LaunchTokenWithdrawer).creationCode,
                        abi.encode(
                            deployParams[block.chainid].protocolOwner, // owner
                            deployParams[block.chainid].cyberToken, // cyber token
                            bytes32(
                                0xc384fa53f80665caf7bace52728ff6ec249baccd23763cbe58cd43b086ac6925
                            ), // merkle root
                            deployParams[DeploySetting.CYBER_TESTNET].eid // layerzero id
                        )
                    ),
                    LibDeploy.SALT
                );
            LibDeploy._write(vm, "LaunchTokenWithdrawer", withdrawer);
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

        if (block.chainid == DeploySetting.BNBT) {
            LaunchTokenWithdrawer(deployParams[block.chainid].withdrawer)
                .setCyberStakingPool(
                    deployParams[CYBER_TESTNET].cyberStakingPool
                );
            LaunchTokenWithdrawer(deployParams[block.chainid].withdrawer)
                .setOFT(deployParams[block.chainid].lzController);
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
            MessagingFee memory msgFee = LaunchTokenWithdrawer(
                deployParams[block.chainid].withdrawer
            ).quoteBridge(
                    0,
                    0x0e0bE581B17684f849AF6964D731FCe0F7d366BD,
                    1,
                    merkleProof,
                    200000
                );

            LaunchTokenWithdrawer(deployParams[block.chainid].withdrawer)
                .bridge{ value: msgFee.nativeFee }(
                0,
                0x0e0bE581B17684f849AF6964D731FCe0F7d366BD,
                1,
                merkleProof,
                msgFee,
                200000
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
            address pool = Create2Deployer(
                deployParams[block.chainid].deployerContract
            ).deploy(
                    abi.encodePacked(
                        type(CyberStakingPool).creationCode,
                        abi.encode(
                            deployParams[block.chainid].protocolOwner, // owner
                            deployParams[block.chainid].lzEndpoint, // layerzero endpoint
                            deployParams[block.chainid].cyberToken, // cyber token
                            deployParams[block.chainid].stakedCyberToken // staked cyber token
                        )
                    ),
                    LibDeploy.SALT
                );
            LibDeploy._write(vm, "CyberStakingPool", pool);
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
                .setOApp(deployParams[block.chainid].lzController, true);
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}

contract ConfigStakedCyber is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.CYBER_TESTNET) {
            StakedCyberToken(deployParams[block.chainid].stakedCyberToken)
                .setMinter(deployParams[block.chainid].cyberStakingPool, true);
        } else {
            revert("NOT_SUPPORTED_CHAIN_ID");
        }

        vm.stopBroadcast();
    }
}
