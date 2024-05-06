// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.22;

contract DeploySetting {
    struct DeployParameters {
        address deployerContract;
        address protocolOwner;
    }

    DeployParameters internal deployParams;

    uint256 internal constant ETH = 1;
    uint256 internal constant POLYGON = 137;
    uint256 internal constant OPTIMISM = 10;
    uint256 internal constant ARBITRUM = 42161;
    uint256 internal constant BNB = 56;
    uint256 internal constant BASE = 8453;
    uint256 internal constant LINEA = 59144;
    uint256 internal constant NOVA = 42170;
    uint256 internal constant OPBNB = 204;
    uint256 internal constant SCROLL = 534352;
    uint256 internal constant MANTLE = 5000;
    uint256 internal constant BLAST = 81457;
    uint256 internal constant CYBER = 7560;

    uint256 internal constant SEPOLIA = 11155111;
    uint256 internal constant GOERLI = 5;
    uint256 internal constant MUMBAI = 80001;
    uint256 internal constant OP_GOERLI = 420;
    uint256 internal constant OP_SEPOLIA = 11155420;
    uint256 internal constant BASE_GOERLI = 84531;
    uint256 internal constant BASE_SEPOLIA = 84532;
    uint256 internal constant LINEA_GOERLI = 59140;
    uint256 internal constant SCROLL_SEPOLIA = 534351;
    uint256 internal constant ARBITRUM_GOERLI = 421613;
    uint256 internal constant BNBT = 97;
    uint256 internal constant OPBNB_TESTNET = 5611;
    uint256 internal constant MANTLE_TESTENT = 5001;
    uint256 internal constant BLAST_SEPOLIA = 168587773;
    uint256 internal constant CYBER_TESTNET = 111557560;
    uint256 internal constant AMOY = 80002;
    uint256 internal constant IMX_TESTNET = 13473;

    function _setDeployParams() internal {
        deployParams
            .deployerContract = 0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f;
        deployParams.protocolOwner = 0x7884f7F04F994da14302a16Cf15E597e31eebECf;
    }
}
