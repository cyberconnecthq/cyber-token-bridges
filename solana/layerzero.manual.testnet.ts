import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'

import type {
    OAppOmniGraphHardhat,
    OmniPointHardhat,
    OmniEdgeHardhat,
    OAppEdgeConfig,
} from '@layerzerolabs/toolbox-hardhat'

// Note:  Do not use address for EVM OmniPointHardhat contracts.  Contracts are loaded using hardhat-deploy.
// If you do use an address, ensure artifacts exists.
const sepoliaContract: OmniPointHardhat = {
    eid: EndpointId.SEPOLIA_V2_TESTNET,
    contractName: 'CyberTokenAdapter',
}

export const baseSepoliaContract: OmniPointHardhat = {
    eid: EndpointId.BASESEP_V2_TESTNET,
    contractName: 'CyberTokenController',
}

export const cyberSepoliaContract: OmniPointHardhat = {
    eid: EndpointId.CYBER_V2_TESTNET,
    contractName: 'CyberTokenController',
}

export const solanaDevnetContract: OmniPointHardhat = {
    eid: EndpointId.SOLANA_V2_TESTNET,
    address: 'Fsy4yRuTRY4daNrF9fPYTGwc7MniBgjavUAhC8S9gAK8',
}

const cyberSepoliaToSolanaConnection: OmniEdgeHardhat<OAppEdgeConfig> = {
    from: cyberSepoliaContract,
    to: solanaDevnetContract,
    config: {
        sendLibrary: '0x45841dd1ca50265Da7614fC43A361e526c0e6160',
        receiveLibraryConfig: {
            receiveLibrary: '0xd682ECF100f6F4284138AA925348633B0611Ae21',
            gracePeriod: BigInt(0),
        },
        // Optional Send Configuration
        // @dev Controls how the `from` chain sends messages to the `to` chain.
        sendConfig: {
            ulnConfig: {
                // // The number of block confirmations to wait before emitting the message from the source chain.
                confirmations: BigInt(1),
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until ALL `requiredDVNs` verify the message.
                requiredDVNs: [
                    '0x88b27057a9e00c5f05dda29241027aff63f9e6e0', // LayerZero
                ],
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until the configured threshold of `optionalDVNs` verify a message.
                optionalDVNs: [],
                // The number of `optionalDVNs` that need to successfully verify the message for it to be considered Verified.
                optionalDVNThreshold: 0,
            },
        },
        // Optional Receive Configuration
        // @dev Controls how the `from` chain receives messages from the `to` chain.
        receiveConfig: {
            ulnConfig: {
                // The number of block confirmations to expect from the `to` chain.
                confirmations: BigInt(1),
                // The address of the DVNs your `receiveConfig` expects to receive verifications from on the `from` chain ).
                // The `from` chain's OApp will wait until the configured threshold of `requiredDVNs` verify the message.
                requiredDVNs: [
                    '0x88b27057a9e00c5f05dda29241027aff63f9e6e0', // LayerZero
                ],
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until the configured threshold of `optionalDVNs` verify a message.
                optionalDVNs: [],
                // The number of `optionalDVNs` that need to successfully verify the message for it to be considered Verified.
                optionalDVNThreshold: 0,
            },
        },
        enforcedOptions: [
            {
                msgType: 1,
                optionType: ExecutorOptionType.LZ_RECEIVE,
                gas: 200000,
                value: 2500000,
            },
        ],
    },
}

const sepoliaToSolanaConnection: OmniEdgeHardhat<OAppEdgeConfig> = {
    from: sepoliaContract,
    to: solanaDevnetContract,
    config: {
        sendLibrary: '0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE',
        receiveLibraryConfig: {
            receiveLibrary: '0xdAf00F5eE2158dD58E0d3857851c432E34A3A851',
            gracePeriod: BigInt(0),
        },
        // Optional Send Configuration
        // @dev Controls how the `from` chain sends messages to the `to` chain.
        sendConfig: {
            ulnConfig: {
                // // The number of block confirmations to wait before emitting the message from the source chain.
                confirmations: BigInt(1),
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until ALL `requiredDVNs` verify the message.
                requiredDVNs: [
                    '0x8eebf8b423b73bfca51a1db4b7354aa0bfca9193', // LayerZero
                ],
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until the configured threshold of `optionalDVNs` verify a message.
                optionalDVNs: [],
                // The number of `optionalDVNs` that need to successfully verify the message for it to be considered Verified.
                optionalDVNThreshold: 0,
            },
        },
        // Optional Receive Configuration
        // @dev Controls how the `from` chain receives messages from the `to` chain.
        receiveConfig: {
            ulnConfig: {
                // The number of block confirmations to expect from the `to` chain.
                confirmations: BigInt(1),
                // The address of the DVNs your `receiveConfig` expects to receive verifications from on the `from` chain ).
                // The `from` chain's OApp will wait until the configured threshold of `requiredDVNs` verify the message.
                requiredDVNs: [
                    '0x8eebf8b423b73bfca51a1db4b7354aa0bfca9193', // LayerZero
                ],
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until the configured threshold of `optionalDVNs` verify a message.
                optionalDVNs: [],
                // The number of `optionalDVNs` that need to successfully verify the message for it to be considered Verified.
                optionalDVNThreshold: 0,
            },
        },
        enforcedOptions: [
            {
                msgType: 1,
                optionType: ExecutorOptionType.LZ_RECEIVE,
                gas: 200000,
                value: 2500000,
            },
        ],
    },
}

const solanaToSepoliaConnection: OmniEdgeHardhat<OAppEdgeConfig> = {
    from: solanaDevnetContract,
    to: sepoliaContract,
    // TODO Here are some default settings that have been found to work well sending to Sepolia.
    // You need to either enable these enforcedOptions or pass in extraOptions when calling send().
    // Having neither will cause a revert when calling send().
    // We suggest performing additional profiling to ensure they are correct for your use case.
    config: {
        sendLibrary: '7a4WjyR8VZ7yZz5XJAKm39BUGn5iT9CKcv2pmG9tdXVH',
        receiveLibraryConfig: {
            receiveLibrary: '7a4WjyR8VZ7yZz5XJAKm39BUGn5iT9CKcv2pmG9tdXVH',
            gracePeriod: BigInt(0),
        },
        // Optional Send Configuration
        // @dev Controls how the `from` chain sends messages to the `to` chain.
        sendConfig: {
            executorConfig: {
                maxMessageSize: 10000,
                // The configured Executor address.  Note, this is the executor PDA not the program ID.
                executor: 'AwrbHeCyniXaQhiJZkLhgWdUCteeWSGaSN1sTfLiY7xK',
            },
            ulnConfig: {
                // // The number of block confirmations to wait before emitting the message from the source chain.
                confirmations: BigInt(10),
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until ALL `requiredDVNs` verify the message.
                requiredDVNs: [
                    '4VDjp6XQaxoZf5RGwiPU9NR1EXSZn2TP4ATMmiSzLfhb', // LayerZero
                ],
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until the configured threshold of `optionalDVNs` verify a message.
                optionalDVNs: [],
                // The number of `optionalDVNs` that need to successfully verify the message for it to be considered Verified.
                optionalDVNThreshold: 0,
            },
        },
        // Optional Receive Configuration
        // @dev Controls how the `from` chain receives messages from the `to` chain.
        receiveConfig: {
            ulnConfig: {
                // The number of block confirmations to expect from the `to` chain.
                confirmations: BigInt(2),
                // The address of the DVNs your `receiveConfig` expects to receive verifications from on the `from` chain ).
                // The `from` chain's OApp will wait until the configured threshold of `requiredDVNs` verify the message.
                requiredDVNs: [
                    '4VDjp6XQaxoZf5RGwiPU9NR1EXSZn2TP4ATMmiSzLfhb', // LayerZero
                ],
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until the configured threshold of `optionalDVNs` verify a message.
                optionalDVNs: [],
                // The number of `optionalDVNs` that need to successfully verify the message for it to be considered Verified.
                optionalDVNThreshold: 0,
            },
        },
        enforcedOptions: [
            {
                msgType: 1,
                optionType: ExecutorOptionType.LZ_RECEIVE,
                gas: 65000,
            },
        ],
    },
}

const solanaToCyberSepoliaConnection: OmniEdgeHardhat<OAppEdgeConfig> = {
    from: solanaDevnetContract,
    to: cyberSepoliaContract,
    // TODO Here are some default settings that have been found to work well sending to Sepolia.
    // You need to either enable these enforcedOptions or pass in extraOptions when calling send().
    // Having neither will cause a revert when calling send().
    // We suggest performing additional profiling to ensure they are correct for your use case.
    config: {
        sendLibrary: '7a4WjyR8VZ7yZz5XJAKm39BUGn5iT9CKcv2pmG9tdXVH',
        receiveLibraryConfig: {
            receiveLibrary: '7a4WjyR8VZ7yZz5XJAKm39BUGn5iT9CKcv2pmG9tdXVH',
            gracePeriod: BigInt(0),
        },
        // Optional Send Configuration
        // @dev Controls how the `from` chain sends messages to the `to` chain.
        sendConfig: {
            executorConfig: {
                maxMessageSize: 10000,
                // The configured Executor address.  Note, this is the executor PDA not the program ID.
                executor: 'AwrbHeCyniXaQhiJZkLhgWdUCteeWSGaSN1sTfLiY7xK',
            },
            ulnConfig: {
                // // The number of block confirmations to wait before emitting the message from the source chain.
                confirmations: BigInt(10),
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until ALL `requiredDVNs` verify the message.
                requiredDVNs: [
                    '4VDjp6XQaxoZf5RGwiPU9NR1EXSZn2TP4ATMmiSzLfhb', // LayerZero
                ],
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until the configured threshold of `optionalDVNs` verify a message.
                optionalDVNs: [],
                // The number of `optionalDVNs` that need to successfully verify the message for it to be considered Verified.
                optionalDVNThreshold: 0,
            },
        },
        // Optional Receive Configuration
        // @dev Controls how the `from` chain receives messages from the `to` chain.
        receiveConfig: {
            ulnConfig: {
                // The number of block confirmations to expect from the `to` chain.
                confirmations: BigInt(2),
                // The address of the DVNs your `receiveConfig` expects to receive verifications from on the `from` chain ).
                // The `from` chain's OApp will wait until the configured threshold of `requiredDVNs` verify the message.
                requiredDVNs: [
                    '4VDjp6XQaxoZf5RGwiPU9NR1EXSZn2TP4ATMmiSzLfhb', // LayerZero
                ],
                // The address of the DVNs you will pay to verify a sent message on the source chain ).
                // The destination tx will wait until the configured threshold of `optionalDVNs` verify a message.
                optionalDVNs: [],
                // The number of `optionalDVNs` that need to successfully verify the message for it to be considered Verified.
                optionalDVNThreshold: 0,
            },
        },
        enforcedOptions: [
            {
                msgType: 1,
                optionType: ExecutorOptionType.LZ_RECEIVE,
                gas: 100000,
            },
        ],
    },
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: sepoliaContract,
        },
        {
            contract: solanaDevnetContract,
        },
        {
            contract: baseSepoliaContract,
        },
        {
            contract: cyberSepoliaContract,
        },
    ],
    connections: [
        // sepoliaToSolanaConnection,
        // solanaToSepoliaConnection,
        // cyberSepoliaToSolanaConnection,
        // solanaToCyberSepoliaConnection,
    ],
}

export default config
