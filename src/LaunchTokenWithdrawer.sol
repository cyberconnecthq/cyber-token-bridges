// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { IOFT, SendParam, OFTReceipt, MessagingReceipt, MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

/**
 * @title LaunchTokenWithdrawer
 * @author Cyber
 */
contract LaunchTokenWithdrawer is Ownable {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    struct LockAmount {
        uint256 lockEnd;
        uint256 amount;
    }

    /*//////////////////////////////////////////////////////////////
                            EVENT
    //////////////////////////////////////////////////////////////*/

    event InitiateWithdraw(uint256 index, address account, uint256 amount);
    event Withdraw(address account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable cyber;
    bytes32 public immutable merkleRoot;
    uint32 public immutable dstEid;
    uint256 public lockDuration;
    address public oft;
    address public cyberStakingPool;
    // This is a packed array of booleans.
    mapping(uint256 => uint256) private _claimedBitMap;
    mapping(address => LockAmount) public lockAmounts;

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _owner,
        address _cyber,
        bytes32 _merkleRoot,
        uint32 _dstEid
    ) Ownable(_owner) {
        cyber = _cyber;
        merkleRoot = _merkleRoot;
        dstEid = _dstEid;
        lockDuration = 7 days;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL
    //////////////////////////////////////////////////////////////*/
    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = _claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function initiateWithdraw(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        _consumeProof(index, account, amount, merkleProof);
        lockAmounts[account].lockEnd = block.timestamp + lockDuration;
        lockAmounts[account].amount = amount;
        emit InitiateWithdraw(index, account, amount);
    }

    function withdraw(address account) external {
        uint256 amount = lockAmounts[account].amount;
        require(lockAmounts[account].lockEnd <= block.timestamp, "LOCKED");
        delete lockAmounts[account];
        IERC20(cyber).safeTransfer(account, amount);
        emit Withdraw(account, amount);
    }

    function quoteBridge(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint128 gasLimit
    ) external view returns (MessagingFee memory msgFee) {
        _verifyProof(index, account, amount, merkleProof);
        bytes memory extraOption = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(0, gasLimit, 0);
        SendParam memory sendParam = SendParam(
            dstEid,
            bytes32(uint256(uint160(cyberStakingPool))),
            amount,
            amount,
            extraOption,
            abi.encode(account, amount),
            new bytes(0)
        );
        return IOFT(oft).quoteSend(sendParam, false);
    }

    function bridge(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        MessagingFee calldata fee,
        uint128 gasLimit
    )
        external
        payable
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        )
    {
        _consumeProof(index, account, amount, merkleProof);
        bytes memory extraOption = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(0, gasLimit, 0);
        SendParam memory sendParam = SendParam(
            dstEid,
            bytes32(uint256(uint160(cyberStakingPool))),
            amount,
            amount,
            extraOption,
            abi.encode(account, amount),
            new bytes(0)
        );
        IERC20(cyber).approve(oft, amount);
        return IOFT(oft).send{ value: msg.value }(sendParam, fee, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER
    //////////////////////////////////////////////////////////////*/

    function setCyberStakingPool(address _cyberStakingPool) external onlyOwner {
        require(_cyberStakingPool != address(0), "ZERO_ADDRESS");
        cyberStakingPool = _cyberStakingPool;
    }

    function setOFT(address _oft) external onlyOwner {
        require(_oft != address(0), "ZERO_ADDRESS");
        oft = _oft;
    }

    function setLockDuration(uint256 _lockDuration) external onlyOwner {
        lockDuration = _lockDuration;
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE
    //////////////////////////////////////////////////////////////*/

    function _consumeProof(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) private {
        _verifyProof(index, account, amount, merkleProof);
        _setClaimed(index);
    }

    function _verifyProof(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) private view {
        require(!isClaimed(index), "ALREADY_CLAIMED");
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "INVALID_PROOF"
        );
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        _claimedBitMap[claimedWordIndex] =
            _claimedBitMap[claimedWordIndex] |
            (1 << claimedBitIndex);
    }
}
