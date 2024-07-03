// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/**
 * @title CyberTokenDistributor
 * @author Cyber
 */
contract CyberTokenDistributor is
    UUPSUpgradeable,
    OwnableUpgradeable,
    EIP712Upgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event Claimed(address user, bytes32 claimId);

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20 public cyber;
    bytes32 public constant CLAIM_TYPEHASH =
        keccak256(
            "claim(address user,bytes32 claimId,uint256 amount,uint256 deadline)"
        );
    mapping(bytes32 => bool) public cliamIdUsed;
    address public signer;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR & INITIALIZER
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _signer,
        address _cyber
    ) external initializer {
        require(_owner != address(0), "INVALID_OWNER");
        require(_signer != address(0), "INVALID_SIGNER");
        require(_cyber != address(0), "INVALID_CYBER");

        cyber = IERC20(_cyber);
        signer = _signer;

        __UUPSUpgradeable_init();
        __Pausable_init();
        __Ownable_init(_owner);
        __EIP712_init("CyberTokenDistributor", "1");
    }

    /*//////////////////////////////////////////////////////////////
                        OVERRIDES
    //////////////////////////////////////////////////////////////*/
    function _authorizeUpgrade(address) internal view override {
        require(msg.sender == owner(), "ONLY_OWNER");
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL
    //////////////////////////////////////////////////////////////*/

    function claim(
        bytes32 claimId,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external whenNotPaused {
        require(deadline >= block.timestamp, "DEADLINE_EXPIRED");
        require(!cliamIdUsed[claimId], "CLAIM_ID_USED");
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    CLAIM_TYPEHASH,
                    msg.sender,
                    claimId,
                    amount,
                    deadline
                )
            )
        );
        require(
            SignatureChecker.isValidSignatureNow(signer, digest, signature),
            "INVALID_SIGNATURE"
        );
        cliamIdUsed[claimId] = true;

        cyber.safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, claimId);
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER 
    //////////////////////////////////////////////////////////////*/

    function withdrawAll(address token) external onlyOwner {
        if (token == address(0)) {
            (bool success, ) = owner().call{ value: address(this).balance }("");
            require(success, "WITHDRAW_FAILED");
        } else {
            IERC20(token).safeTransfer(
                owner(),
                IERC20(token).balanceOf(address(this))
            );
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
