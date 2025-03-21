import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { OAppEnforcedOption, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import { generateConnectionsConfig } from '@layerzerolabs/metadata-tools'

export const sepoliaContract: OmniPointHardhat = {
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

const EVM_BURN_MINT_ENFORCED_OPTIONS: OAppEnforcedOption[] = [
    {
        msgType: 1,
        optionType: ExecutorOptionType.LZ_RECEIVE,
        gas: 100000,
        value: 0,
    },
]

const EVM_LOCK_UNLOCK_ENFORCED_OPTIONS: OAppEnforcedOption[] = [
    {
        msgType: 1,
        optionType: ExecutorOptionType.LZ_RECEIVE,
        gas: 65000,
        value: 0,
    },
]

const SOLANA_ENFORCED_OPTIONS: OAppEnforcedOption[] = [
    {
        msgType: 1,
        optionType: ExecutorOptionType.LZ_RECEIVE,
        gas: 200000,
        value: 2500000,
    },
]

export default async function () {
    const connections = await generateConnectionsConfig([
        [
            sepoliaContract, // srcContract
            solanaDevnetContract, // dstContract
            [['LayerZero Labs'], []], // [ requiredDVN[], [ optionalDVN[], threshold ] ]
            [1, 1], // [srcToDstConfirmations, dstToSrcConfirmations]
            [SOLANA_ENFORCED_OPTIONS, EVM_LOCK_UNLOCK_ENFORCED_OPTIONS], // [enforcedOptionsSrcToDst, enforcedOptionsDstToSrc]
        ],
        [
            sepoliaContract, // srcContract
            baseSepoliaContract, // dstContract
            [['LayerZero Labs'], []], // [ requiredDVN[], [ optionalDVN[], threshold ] ]
            [1, 1], // [srcToDstConfirmations, dstToSrcConfirmations]
            [EVM_BURN_MINT_ENFORCED_OPTIONS, EVM_LOCK_UNLOCK_ENFORCED_OPTIONS], // [enforcedOptionsSrcToDst, enforcedOptionsDstToSrc]
        ],
        [
            cyberSepoliaContract, // srcContract
            solanaDevnetContract, // dstContract
            [['LayerZero Labs'], []], // [ requiredDVN[], [ optionalDVN[], threshold ] ]
            [1, 1], // [srcToDstConfirmations, dstToSrcConfirmations]
            [SOLANA_ENFORCED_OPTIONS, EVM_BURN_MINT_ENFORCED_OPTIONS], // [enforcedOptionsSrcToDst, enforcedOptionsDstToSrc]
        ],
        [
            cyberSepoliaContract, // srcContract
            baseSepoliaContract, // dstContract
            [['LayerZero Labs'], []], // [ requiredDVN[], [ optionalDVN[], threshold ] ]
            [1, 1], // [srcToDstConfirmations, dstToSrcConfirmations]
            [EVM_BURN_MINT_ENFORCED_OPTIONS, EVM_BURN_MINT_ENFORCED_OPTIONS], // [enforcedOptionsSrcToDst, enforcedOptionsDstToSrc]
        ],
    ])

    return {
        contracts: [
            { contract: sepoliaContract },
            { contract: solanaDevnetContract },
            { contract: baseSepoliaContract },
            { contract: cyberSepoliaContract },
        ],
        connections,
    }
}
