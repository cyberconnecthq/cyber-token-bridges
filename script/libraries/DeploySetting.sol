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

    uint256 internal constant SEPOLIA = 11155111;
    uint256 internal constant OP_SEPOLIA = 11155420;
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
                .lzController = 0x12E4147A0C8d8d00eb3Eeb30Df3a089aB0420000;
            deployParams[SEPOLIA].eid = 40161;
            deployParams[SEPOLIA]
                .withdrawer = 0x4A973F53A72Fd16bc37d23F77b105baFC4c4B873;
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
        }

        {
            deployParams[BNBT]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[BNBT]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[BNBT]
                .cyberToken = 0xdb359A83ff0B91551161f12e9C5454CC04FA2fCc;
            deployParams[BNBT]
                .lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
            deployParams[BNBT]
                .lzController = 0xD610b93C19e87b7C3039bc8DA906a233aD85386b;
            deployParams[BNBT].eid = 40102;
            deployParams[BNBT]
                .withdrawer = 0x7E28D6e5108c702A9424a5AdAF03bBA57dFf7C61;
        }

        {
            deployParams[CYBER_TESTNET]
                .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
            deployParams[CYBER_TESTNET]
                .protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[CYBER_TESTNET]
                .cyberToken = 0x3F0Cabe797a717A2ca97072942D66065BCF56dDC;
            deployParams[CYBER_TESTNET]
                .lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
            deployParams[CYBER_TESTNET]
                .lzController = 0xfd522AE1Cec35a85237D1CddbfFeBe65E49eFb98;
            deployParams[CYBER_TESTNET].eid = 40280;
            deployParams[CYBER_TESTNET]
                .cyberStakingPool = 0x8577aD3Da02e34315C76dFcD66EA70dFFE75e742;
            deployParams[CYBER_TESTNET]
                .cyberVault = 0x580278859B01BFdc303ca80B36bE364b438105D6;
            deployParams[CYBER_TESTNET]
                .treasury = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[CYBER_TESTNET]
                .withdrawer = 0x06A7794454934437E0C66788863afb379487C681;
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
                .lzController = 0x0644076B2100ad7200e63141101870FC948DcA7f;
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
                .lzController = 0x3d2fe83ea885C2E43A422C82C738847669708210;
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
                .lzController = 0x0644076B2100ad7200e63141101870FC948DcA7f;
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
                .lzController = 0x0644076B2100ad7200e63141101870FC948DcA7f;
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
