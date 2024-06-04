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
        address cyberStakingPool;
        address cyberVault;
        address withdrawer;
        address lzSendLib;
        address lzReceiveLib;
        address treasury;
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
                .withdrawer = 0x91768AfD9B8adB5110E93AF7Aea374e7E75d2d8F;
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
                .cyberStakingPool = 0xB382b8642Be4A6e7109916430527f29ed8241b01;
            deployParams[CYBER_TESTNET]
                .cyberVault = 0x85C0Edb7cB24Ce00c4B33fD82Fa18eFc21e7d6Bb;
            deployParams[CYBER_TESTNET]
                .treasury = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
            deployParams[CYBER_TESTNET]
                .withdrawer = 0xAf1a221Db8eCa631c16Bf07ae5ADF355ef368398;
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
            deployParams[ETH]
                .lzSendLib = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1;
            deployParams[ETH]
                .lzReceiveLib = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;
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
        }
    }
}
