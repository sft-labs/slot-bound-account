// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC3525Receiver} from "@solvprotocol/erc-3525/IERC3525Receiver.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {SignatureChecker, ECDSA} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {LibExecutor} from "@tokenbound/contracts/lib/LibExecutor.sol";

import {IAccount} from "./interfaces/IAccount.sol";
import {ERC6551AccountLib} from "./lib/ERC6551AccountLib.sol";
import {IERC3525SlotEnumerable} from "./interfaces/IERC3525SlotEnumerable.sol";

contract SlotBoundAccount is IAccount, IERC1271, IERC3525Receiver, Context, ERC721Holder, ERC1155Holder {
    error NotAuthorized();

    event TransactionExecuted(address indexed msgSender, address indexed target, uint256 value, bytes data);

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @inheritdoc IAccount
    function exec(address target_, uint256 value_, bytes calldata data_, uint8 operation_)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        if (!_isValidExecutor(_msgSender())) revert NotAuthorized();

        result = LibExecutor._execute(target_, value_, data_, operation_);

        emit TransactionExecuted(_msgSender(), target_, value_, data_);
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    receive() external payable {}

    /// @inheritdoc IERC1271
    function isValidSignature(bytes32 hash_, bytes calldata signature_)
        external
        view
        virtual
        override
        returns (bytes4 magicValue)
    {
        if (_isValidSignature(hash_, signature_)) {
            return IERC1271.isValidSignature.selector;
        }

        return bytes4(0);
    }

    /// @inheritdoc IAccount
    function owners() external view virtual override returns (address[] memory) {
        return _owners();
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /// @inheritdoc IAccount
    function token() public view returns (uint256 chainId, address tokenContract, uint256 slotId) {
        return ERC6551AccountLib.token();
    }

    function supportsInterface(bytes4 interfaceId_) public view override returns (bool) {
        return interfaceId_ == type(IAccount).interfaceId || interfaceId_ == type(IERC721Receiver).interfaceId
            || interfaceId_ == type(IERC1155Receiver).interfaceId || interfaceId_ == type(IERC3525Receiver).interfaceId
            || super.supportsInterface(interfaceId_);
    }

    /// @inheritdoc IERC3525Receiver
    function onERC3525Received(address, uint256, uint256, uint256, bytes calldata)
        public
        pure
        virtual
        returns (bytes4)
    {
        return this.onERC3525Received.selector;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
     * @notice Returns whether a given account is authorized to sign on behalf of this account
     *
     * @param signer_ The address to query authorization for
     * @return True if the signer is valid, false otherwise
     */
    function _isValidSigner(address signer_, bytes memory) internal view virtual returns (bool) {
        return _isOwnerOfSlot(signer_);
    }

    /**
     * @dev Determines if a given hash and signature are valid for this account
     *
     * @param hash_ Hash of signed data
     * @param signature_ ECDSA signature or encoded contract signature (v=0)
     */
    function _isValidSignature(bytes32 hash_, bytes calldata signature_) internal view virtual returns (bool) {
        uint8 v = uint8(signature_[64]);
        address signer;

        // Smart contract signature
        if (v == 0) {
            // Signer address encoded in r
            signer = address(uint160(uint256(bytes32(signature_[:32]))));

            // Allow recursive signature verification
            if (!_isValidSigner(signer, "") && signer != address(this)) {
                return false;
            }

            // Signature offset encoded in s
            bytes calldata _signature = signature_[uint256(bytes32(signature_[32:64])):];

            return SignatureChecker.isValidERC1271SignatureNow(signer, hash_, _signature);
        }

        ECDSA.RecoverError _error;
        (signer, _error) = ECDSA.tryRecover(hash_, signature_);

        if (_error != ECDSA.RecoverError.NoError) return false;

        return _isValidSigner(signer, "");
    }

    /**
     * @notice Returns whether a given account is authorized to execute transactions on behalf of
     * this account
     *
     * @param executor_ The address to query authorization for
     * @return True if the executor is authorized, false otherwise
     */
    function _isValidExecutor(address executor_) internal view virtual returns (bool) {
        return _isOwnerOfSlot(executor_);
    }

    /**
     * @notice Returns whether a given account is one of owners of the slot
     *
     * @param owner_ The address to query authorization for
     * @return True if the `owner_` is one of owners, false otherwise
     */
    function _isOwnerOfSlot(address owner_) internal view virtual returns (bool) {
        (uint256 chainId_, address tokenContract_, uint256 slot_) = this.token();
        if (chainId_ != block.chainid) return false;

        IERC3525SlotEnumerable erc3525 = IERC3525SlotEnumerable(tokenContract_);
        uint256 totalSupply = erc3525.tokenSupplyInSlot(slot_);
        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 _tokenId = erc3525.tokenInSlotByIndex(slot_, i);
            address _tknOwner = erc3525.ownerOf(_tokenId);
            if (_tknOwner == owner_ && erc3525.balanceOf(_tokenId) > 0) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Returns owners of the slot
     *
     * @return owners_ a list of owners address
     */
    function _owners() internal view virtual returns (address[] memory owners_) {
        (uint256 chainId_, address tokenContract_, uint256 slot_) = this.token();
        if (chainId_ != block.chainid) return new address[](0);

        IERC3525SlotEnumerable erc3525 = IERC3525SlotEnumerable(tokenContract_);
        uint256 totalSupply = erc3525.tokenSupplyInSlot(slot_);
        owners_ = new address[](totalSupply);

        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 _tokenId = erc3525.tokenInSlotByIndex(slot_, i);
            address _tknOwner = erc3525.ownerOf(_tokenId);
            if (erc3525.balanceOf(_tokenId) > 0) {
                owners_[i] = _tknOwner;
            }
        }

        return owners_;
    }
}
