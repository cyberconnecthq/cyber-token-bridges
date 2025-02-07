import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { OAppEnforcedOption, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import { generateConnectionsConfig } from '@layerzerolabs/metadata-tools'

export const ethContract: OmniPointHardhat = {
    eid: EndpointId.ETHEREUM_V2_MAINNET,
    contractName: 'CyberTokenAdapter',
}

export const baseContract: OmniPointHardhat = {
    eid: EndpointId.BASE_V2_MAINNET,
    contractName: 'CyberTokenController',
}

export const cyberContract: OmniPointHardhat = {
    eid: EndpointId.CYBER_V2_MAINNET,
    contractName: 'CyberTokenController',
}

export const solanaContract: OmniPointHardhat = {
    eid: EndpointId.SOLANA_V2_MAINNET,
    address: 'Fsy4yRuTRY4daNrF9fPYTGwc7MniBgjavUAhC8S9gAK8', // your OFT Store address
}

const EVM_ENFORCED_OPTIONS: OAppEnforcedOption[] = [
    {
        msgType: 1,
        optionType: ExecutorOptionType.LZ_RECEIVE,
        gas: 150000,
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
            ethContract,
            solanaContract,
            [['LayerZero Labs', 'Nethermind'], []],
            [15, 32],
            [SOLANA_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
        ],
        [
            cyberContract,
            solanaContract,
            [['LayerZero Labs', 'Nethermind'], []],
            [20, 32],
            [SOLANA_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
        ],
        [
            baseContract,
            ethContract,
            [['LayerZero Labs', 'Nethermind'], []],
            [20, 15],
            [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
        ],
        [
            baseContract,
            cyberContract,
            [['LayerZero Labs', 'Nethermind'], []],
            [20, 20],
            [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
        ],
    ])

    return {
        contracts: [
            { contract: ethContract },
            { contract: baseContract },
            { contract: cyberContract },
            { contract: solanaContract },
        ],
        connections,
    }
}
