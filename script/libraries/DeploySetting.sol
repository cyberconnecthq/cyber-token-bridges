// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.22;

contract DeploySetting {
    struct DeployParameters {
        address deployerContract;
        address protocolOwner;
        address cyberToken;
        uint32 eid;
        address lzController;
        address cyberStakingPool;
        address cyberVault;
        address withdrawer;
        address treasury;
        address backendSigner;
        // lz related
        address lzPolyhedraDVN;
        address lzLabsDVN;
        address lzEndpoint;
        address lzSendLib;
        address lzReceiveLib;
        uint64 confirmations;
        uint128 enforcedGas;
    }

    mapping(uint256 => DeployParameters) internal deployParams;

    uint256 internal constant ETH = 1;
    uint256 internal constant OPTIMISM = 10;
    uint256 internal constant BNB = 56;
    uint256 internal constant CYBER = 7560;
    uint256 internal constant BASE = 8453;

    uint256 internal constant SEPOLIA = 11155111;
    uint256 internal constant OP_SEPOLIA = 11155420;
    uint256 internal constant BASE_SEPOLIA = 84532;
    uint256 internal constant BNBT = 97;
    uint256 internal constant CYBER_TESTNET = 111557560;

    function _setDeployParams() internal {
        {
            deployParams[SEPOLIA]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[SEPOLIA]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[SEPOLIA]
                .cyberToken = 0xF616904ac19f5bE8206A923E92bFf8953a16c7Fc;
            deployParams[SEPOLIA]
                .lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
            deployParams[SEPOLIA]
                .lzController = 0x2C251296AFb9385CFf7AbC8Bcd5C6F54b38b9B51;
            deployParams[SEPOLIA].eid = 40161;
            deployParams[SEPOLIA]
                .withdrawer = 0x4A973F53A72Fd16bc37d23F77b105baFC4c4B873;
            deployParams[SEPOLIA].enforcedGas = 65000;
        }

        {
            deployParams[OP_SEPOLIA]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[OP_SEPOLIA]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[OP_SEPOLIA]
                .cyberToken = 0x1F765DC8b75D46786171A7967b99f1184D91b67B;
            deployParams[OP_SEPOLIA]
                .lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
            deployParams[OP_SEPOLIA].eid = 40232;
            deployParams[OP_SEPOLIA]
                .withdrawer = 0x3562C0b0eD286Cca224440b00a9631Dac7749422;
            deployParams[OP_SEPOLIA]
                .lzController = 0x195eB2439CEDd006adc760A14CbA1663Ff353d24;
            deployParams[OP_SEPOLIA]
                .lzSendLib = 0xB31D2cb502E25B30C651842C7C3293c51Fe6d16f;
            deployParams[OP_SEPOLIA]
                .lzReceiveLib = 0x9284fd59B95b9143AF0b9795CAC16eb3C723C9Ca;
            deployParams[OP_SEPOLIA]
                .lzLabsDVN = 0xd680ec569f269aa7015F7979b4f1239b5aa4582C;
            deployParams[OP_SEPOLIA].enforcedGas = 100000;
            deployParams[OP_SEPOLIA].confirmations = 20;
        }

        {
            deployParams[BASE_SEPOLIA]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[BASE_SEPOLIA]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[BASE_SEPOLIA]
                .cyberToken = 0x67a38c9f526966dBc9F3a2f06a67FF258A79A3A6;
            deployParams[BASE_SEPOLIA]
                .lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
            deployParams[BASE_SEPOLIA].eid = 40245;
            deployParams[BASE_SEPOLIA]
                .lzController = 0xffC20A4176680a2b8d9fd2F9efb5e620f96F4bE2;
            deployParams[BASE_SEPOLIA]
                .lzSendLib = 0xC1868e054425D378095A003EcbA3823a5D0135C9;
            deployParams[BASE_SEPOLIA]
                .lzReceiveLib = 0x12523de19dc41c91F7d2093E0CFbB76b17012C8d;
            deployParams[BASE_SEPOLIA]
                .lzLabsDVN = 0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6;
            deployParams[BASE_SEPOLIA].enforcedGas = 100000;
            deployParams[BASE_SEPOLIA].confirmations = 20;
        }

        {
            deployParams[BNBT]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[BNBT]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[BNBT]
                .cyberToken = 0xf3b3eeBb542808487A464C38a1462Bf93c1bF1a8;
            deployParams[BNBT]
                .lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
            deployParams[BNBT]
                .lzController = 0x0DD60dA738ed56682d816D8d6925FaBBF8e6D44B;
            deployParams[BNBT].eid = 40102;
            deployParams[BNBT]
                .withdrawer = 0x7E28D6e5108c702A9424a5AdAF03bBA57dFf7C61;
            deployParams[BNBT].enforcedGas = 100000;
        }

        {
            deployParams[CYBER_TESTNET]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[CYBER_TESTNET]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[CYBER_TESTNET]
                .cyberToken = 0x817C122fb22560A9Ecfd0e20E0c7FC99eBd9da0D;
            deployParams[CYBER_TESTNET]
                .lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
            deployParams[CYBER_TESTNET]
                .lzController = 0xeADe18d33dc4Ab38BABEf85a10aDf3bac38D9833;
            deployParams[CYBER_TESTNET]
                .lzSendLib = 0x45841dd1ca50265Da7614fC43A361e526c0e6160;
            deployParams[CYBER_TESTNET]
                .lzReceiveLib = 0xd682ECF100f6F4284138AA925348633B0611Ae21;
            deployParams[CYBER_TESTNET].eid = 40280;
            deployParams[CYBER_TESTNET]
                .cyberStakingPool = 0x8577aD3Da02e34315C76dFcD66EA70dFFE75e742;
            deployParams[CYBER_TESTNET]
                .cyberVault = 0x580278859B01BFdc303ca80B36bE364b438105D6;
            deployParams[CYBER_TESTNET]
                .treasury = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[CYBER_TESTNET]
                .withdrawer = 0x06A7794454934437E0C66788863afb379487C681;
            deployParams[CYBER_TESTNET]
                .lzLabsDVN = 0x88B27057A9e00c5F05DDa29241027afF63f9e6e0;
            deployParams[CYBER_TESTNET].enforcedGas = 100000;
            deployParams[CYBER_TESTNET].confirmations = 20;
            deployParams[CYBER_TESTNET]
                .backendSigner = 0xaB24749c622AF8FC567CA2b4d3EC53019F83dB8F;
        }

        {
            deployParams[BASE]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[BASE]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[BASE]
                .cyberToken = 0x14778860E937f509e651192a90589dE711Fb88a9;
            deployParams[BASE]
                .lzEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;
            // deployParams[BASE]
            // .lzController = 0x9A9D5a29206Dde4F70825032dF32333De5f63921;
            deployParams[BASE].eid = 30184;
            deployParams[BASE]
                .lzSendLib = 0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2;
            deployParams[BASE]
                .lzReceiveLib = 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf;
            // deployParams[BASE]
            //     .lzLabsDVN = 0x6788f52439ACA6BFF597d3eeC2DC9a44B8FEE842;
            // deployParams[BASE]
            //     .lzPolyhedraDVN = 0x8ddF05F9A5c488b4973897E278B58895bF87Cb24;
            deployParams[BASE].confirmations = 20;
            deployParams[BASE].enforcedGas = 100000;
            // deployParams[BASE]
            //     .treasury = 0x0793811Ee06942bAcAb7BD28669D810dE62487B6;
            // deployParams[BASE]
            //     .cyberStakingPool = 0x3EfE22FA52F6789DDfc263Cec5BCf435b14b77e2;
            // deployParams[BASE]
            //     .cyberVault = 0x522D3A9C2Bc14cE1C4D210ED41ab239FdED02F2b;
            // deployParams[BASE]
            //     .backendSigner = 0xB6f53FCF8a8F9e2b9D7C5fCf1D6D052496e8A098;
        }

        {
            deployParams[CYBER]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[CYBER]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[CYBER]
                .cyberToken = 0x14778860E937f509e651192a90589dE711Fb88a9;
            deployParams[CYBER]
                .lzEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;
            deployParams[CYBER]
                .lzController = 0x9A9D5a29206Dde4F70825032dF32333De5f63921;
            deployParams[CYBER].eid = 30283;
            deployParams[CYBER]
                .lzSendLib = 0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7;
            deployParams[CYBER]
                .lzReceiveLib = 0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043;
            deployParams[CYBER]
                .lzLabsDVN = 0x6788f52439ACA6BFF597d3eeC2DC9a44B8FEE842;
            deployParams[CYBER]
                .lzPolyhedraDVN = 0x8ddF05F9A5c488b4973897E278B58895bF87Cb24;
            deployParams[CYBER].confirmations = 20;
            deployParams[CYBER].enforcedGas = 100000;
            deployParams[CYBER]
                .treasury = 0x0793811Ee06942bAcAb7BD28669D810dE62487B6;
            deployParams[CYBER]
                .cyberStakingPool = 0x3EfE22FA52F6789DDfc263Cec5BCf435b14b77e2;
            deployParams[CYBER]
                .cyberVault = 0x522D3A9C2Bc14cE1C4D210ED41ab239FdED02F2b;
            deployParams[CYBER]
                .backendSigner = 0xB6f53FCF8a8F9e2b9D7C5fCf1D6D052496e8A098;
        }

        {
            deployParams[ETH]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[ETH]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[ETH]
                .cyberToken = 0x14778860E937f509e651192a90589dE711Fb88a9;
            deployParams[ETH]
                .lzEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;
            deployParams[ETH].eid = 30101;
            deployParams[ETH]
                .lzController = 0xCB07992DE144bDeE56fDb66Fff2454B43243b052;
            deployParams[ETH]
                .lzSendLib = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1;
            deployParams[ETH]
                .lzReceiveLib = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;
            deployParams[ETH]
                .lzLabsDVN = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
            deployParams[ETH]
                .lzPolyhedraDVN = 0x8ddF05F9A5c488b4973897E278B58895bF87Cb24;
            deployParams[ETH].confirmations = 15;
            deployParams[ETH].enforcedGas = 65000;
            deployParams[ETH]
                .treasury = 0x455DB34c99A866489F3ac63fa2F068c726BC286b;
            deployParams[ETH]
                .backendSigner = 0xB6f53FCF8a8F9e2b9D7C5fCf1D6D052496e8A098;
        }

        {
            deployParams[OPTIMISM]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[OPTIMISM]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[OPTIMISM]
                .cyberToken = 0x14778860E937f509e651192a90589dE711Fb88a9;
            deployParams[OPTIMISM]
                .lzEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;
            deployParams[OPTIMISM].eid = 30111;
            deployParams[OPTIMISM]
                .lzController = 0x9A9D5a29206Dde4F70825032dF32333De5f63921;
            deployParams[OPTIMISM]
                .lzSendLib = 0x1322871e4ab09Bc7f5717189434f97bBD9546e95;
            deployParams[OPTIMISM]
                .lzReceiveLib = 0x3c4962Ff6258dcfCafD23a814237B7d6Eb712063;
            deployParams[OPTIMISM]
                .lzLabsDVN = 0x6A02D83e8d433304bba74EF1c427913958187142;
            deployParams[OPTIMISM]
                .lzPolyhedraDVN = 0x8ddF05F9A5c488b4973897E278B58895bF87Cb24;
            deployParams[OPTIMISM].confirmations = 20;
            deployParams[OPTIMISM].enforcedGas = 100000;
            deployParams[OPTIMISM]
                .treasury = 0x2f199646760aE75d423F4E98bb5249207ED1DC15;
        }

        {
            deployParams[BNB]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[BNB]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[BNB]
                .cyberToken = 0x14778860E937f509e651192a90589dE711Fb88a9;
            deployParams[BNB]
                .lzEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;
            deployParams[BNB].eid = 30102;
            deployParams[BNB]
                .lzController = 0x9A9D5a29206Dde4F70825032dF32333De5f63921;
            deployParams[BNB]
                .lzSendLib = 0x9F8C645f2D0b2159767Bd6E0839DE4BE49e823DE;
            deployParams[BNB]
                .lzReceiveLib = 0xB217266c3A98C8B2709Ee26836C98cf12f6cCEC1;
            deployParams[BNB]
                .lzLabsDVN = 0xfD6865c841c2d64565562fCc7e05e619A30615f0;
            deployParams[BNB]
                .lzPolyhedraDVN = 0x8ddF05F9A5c488b4973897E278B58895bF87Cb24;
            deployParams[BNB].confirmations = 20;
            deployParams[BNB].enforcedGas = 100000;
            deployParams[BNB]
                .treasury = 0x4729A8F1FEc3b1353a751ce0143Fb16d119f706a;
        }
    }
}
