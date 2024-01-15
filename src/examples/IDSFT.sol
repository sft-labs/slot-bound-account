// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC3525SlotEnumerable} from "@solvprotocol/erc-3525/ERC3525SlotEnumerable.sol";

import {IAccountRegistry} from "../interfaces/IAccountRegistry.sol";

contract IDSFT is ERC3525SlotEnumerable, Ownable {
    error SlotDoesNotExist();
    error SlotAlreadyExists();
    error TokenDoesNotExist();
    error NotTokenOwner();

    struct Profile {
        string name;
        address account;
    }

    IAccountRegistry public registry;
    address public accountImpl;

    mapping(address => uint256) private _userSlot;
    mapping(uint256 => Profile) private _slotProfile;

    /**
     * @dev MUST emit if a token is issued.
     *
     * @param to The recipient of the token
     * @param slotId The slot id of the token
     * @param tokenId The new token id was issued
     * @param accountAddress The address of the created smart contract account
     */
    event Issued(address indexed to, uint256 indexed slotId, uint256 indexed tokenId, address accountAddress);

    /**
     * @dev MUST emit if a token is destroyed.
     *
     * @param from The address of the owner
     * @param tokenId The token id
     */
    event Destroyed(address indexed from, uint256 indexed tokenId);

    constructor(address sbaRegistry_, address sbaImpl_) ERC3525SlotEnumerable("Slot Bound Account SFT", "SFT", 18) {
        registry = IAccountRegistry(sbaRegistry_);
        accountImpl = sbaImpl_;
    }

    function create(string memory name_) external returns (address newAcctAddress) {
        address _to = _msgSender();
        uint256 slot = uint256(keccak256(abi.encodePacked(_to, name_)));

        Profile memory _profile = _slotProfile[slot];
        if (bytes(_profile.name).length != 0 && _profile.account != address(0)) {
            revert SlotAlreadyExists();
        }

        // Mint a new token with the MAX uint256 value.
        uint256 tokenId = _mint(_to, slot, type(uint256).max);

        newAcctAddress = registry.createAccount(accountImpl, block.chainid, address(this), slot, 0, "");

        _slotProfile[slot] = Profile({name: name_, account: newAcctAddress});
        _userSlot[_to] = slot;

        emit Issued(_to, slot, tokenId, newAcctAddress);
    }

    function destroy(uint256 tokenId_) external {
        if (!_exists(tokenId_)) revert TokenDoesNotExist();
        if (ownerOf(tokenId_) != _msgSender()) revert NotTokenOwner();

        _burn(tokenId_);

        emit Destroyed(_msgSender(), tokenId_);
    }
}
