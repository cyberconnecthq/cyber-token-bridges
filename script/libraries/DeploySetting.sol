// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.22;

contract DeploySetting {
    struct DeployParameters {
        address deployerContract;
        address protocolOwner;
        address cyberToken;
        address lzEndpoint;
        uint32 eid;
        address lzController;
        address cyberVault;
        address withdrawer;
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
                .withdrawer = 0xefb3F5f64Bd860a1bFde7897918d8e668dCab7B1;
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
                .cyberVault = 0xFE789B66AD470dd8DD961a6fB3F8aD941B2c79c1;
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
            // deployParams[CYBER]
            //     .lzController = 0xfd522AE1Cec35a85237D1CddbfFeBe65E49eFb98;
            deployParams[CYBER].eid = 30283;
            // deployParams[CYBER]
            //     .cyberVault = 0xFE789B66AD470dd8DD961a6fB3F8aD941B2c79c1;
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
            // deployParams[OPTIMISM]
            //     .lzController = 0xfd522AE1Cec35a85237D1CddbfFeBe65E49eFb98;
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
            // deployParams[BNB]
            //     .lzController = 0xfd522AE1Cec35a85237D1CddbfFeBe65E49eFb98;
        }
    }
}
