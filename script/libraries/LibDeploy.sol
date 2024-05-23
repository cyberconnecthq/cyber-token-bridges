// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.22;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import { LibString } from "../../src/libraries/LibString.sol";

library LibDeploy {
    // create2 deploy all contract with this protocol salt
    bytes32 constant SALT = keccak256(bytes("Cyber"));

    string internal constant OUTPUT_FILE = "docs/deploy/";

    function _fileName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        string memory chainName;
        if (chainId == 1) chainName = "eth";
        else if (chainId == 80001) chainName = "mumbai";
        else if (chainId == 137) chainName = "polygon";
        else if (chainId == 420) chainName = "op_goerli";
        else if (chainId == 84531) chainName = "base_goerli";
        else if (chainId == 59140) chainName = "linea_goerli";
        else if (chainId == 534351) chainName = "scroll_sepolia";
        else if (chainId == 59144) chainName = "linea";
        else if (chainId == 56) chainName = "bnb";
        else if (chainId == 10) chainName = "op";
        else if (chainId == 42161) chainName = "arbitrum";
        else if (chainId == 421613) chainName = "arbitrum_goerli";
        else if (chainId == 97) chainName = "bnbt";
        else if (chainId == 8453) chainName = "base";
        else if (chainId == 5611) chainName = "opbnbt";
        else if (chainId == 204) chainName = "opbnb";
        else if (chainId == 534352) chainName = "scroll";
        else if (chainId == 11155111) chainName = "sepolia";
        else if (chainId == 5000) chainName = "mantle";
        else if (chainId == 5001) chainName = "mantle_testnet";
        else if (chainId == 168587773) chainName = "blast_sepolia";
        else if (chainId == 11155420) chainName = "op_sepolia";
        else if (chainId == 84532) chainName = "base_sepolia";
        else if (chainId == 81457) chainName = "blast";
        else if (chainId == 111557560) chainName = "cyber_testnet";
        else if (chainId == 80002) chainName = "amoy";
        else if (chainId == 13473) chainName = "imx_testnet";
        else if (chainId == 7560) chainName = "cyber";
        else chainName = "unknown";
        return
            string(
                abi.encodePacked(
                    OUTPUT_FILE,
                    string(
                        abi.encodePacked(
                            chainName,
                            "-",
                            LibString.toString(chainId)
                        )
                    ),
                    "/contract"
                )
            );
    }

    function _fileNameMd() internal view returns (string memory) {
        return string(abi.encodePacked(_fileName(), ".md"));
    }

    function _writeText(
        Vm vm,
        string memory fileName,
        string memory text
    ) internal {
        vm.writeLine(fileName, text);
    }

    function _writeHelper(Vm vm, string memory name, address addr) internal {
        _writeText(
            vm,
            _fileNameMd(),
            string(
                abi.encodePacked(
                    "|",
                    name,
                    "|",
                    LibString.toHexString(addr),
                    "|"
                )
            )
        );
    }

    function _write(Vm vm, string memory name, address addr) internal {
        _writeHelper(vm, name, addr);
    }
}

interface Create2Deployer {
    event Deployed(address addr, bytes32 salt);
    function deploy(bytes memory code, bytes32 salt) external returns (address);
}
