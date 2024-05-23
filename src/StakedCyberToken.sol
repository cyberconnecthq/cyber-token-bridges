// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { OFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

/**
 * @title StakedCyberToken
 * @author Cyber
 */
contract StakedCyberToken is ERC20Burnable, ERC20Votes, Pausable, OFT {
    /*//////////////////////////////////////////////////////////////
                            EVENT
    //////////////////////////////////////////////////////////////*/

    event SetMinter(address indexed minter, bool status);

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => bool) public minters;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _lzEndpoint,
        address _owner
    )
        OFT("Staked CYBER", "stCYBER", _lzEndpoint, _owner)
        EIP712("Staked CYBER", "1")
        Ownable(_owner)
    {}

    /*//////////////////////////////////////////////////////////////
                            ERC20 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20, ERC20Votes) {
        if (from != address(0) && to != address(0)) {
            require(!paused(), "TRANSFER_PAUSED");
        }
        ERC20Votes._update(from, to, value);
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY MINTER
    //////////////////////////////////////////////////////////////*/

    function mint(address _account, uint256 _amount) external {
        require(minters[msg.sender], "NOT_MINTER");
        _mint(_account, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            ONLY OWNER
    //////////////////////////////////////////////////////////////*/

    function setMinter(address _minter, bool _status) external onlyOwner {
        require(_minter != address(0), "ZERO_ADDRESS");
        require(minters[_minter] != _status, "SAME_STATUS");
        minters[_minter] = _status;
        emit SetMinter(_minter, _status);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
