// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IAccountRegistry} from "./interfaces/IAccountRegistry.sol";
import {ERC6551BytecodeLib} from "./lib/ERC6551BytecodeLib.sol";

/// reference: ERC6551 Account Registry
contract AccountRegistry is IAccountRegistry {
    error InitializationFailed();

    function createAccount(
        address implementation_,
        uint256 chainId_,
        address tokenContract_,
        uint256 slotId_,
        uint256 salt_,
        bytes calldata initData
    ) external returns (address) {
        bytes memory code =
            ERC6551BytecodeLib.getCreationCode(implementation_, chainId_, tokenContract_, slotId_, salt_);

        address _account = Create2.computeAddress(bytes32(salt_), keccak256(code));

        if (_account.code.length != 0) return _account;

        emit AccountCreated(_account, implementation_, chainId_, tokenContract_, slotId_, salt_);

        _account = Create2.deploy(0, bytes32(salt_), code);

        if (initData.length != 0) {
            (bool success,) = _account.call(initData);
            if (!success) revert InitializationFailed();
        }

        return _account;
    }

    function account(address implementation_, uint256 chainId_, address tokenContract_, uint256 slotId_, uint256 salt_)
        external
        view
        returns (address)
    {
        bytes32 bytecodeHash =
            keccak256(ERC6551BytecodeLib.getCreationCode(implementation_, chainId_, tokenContract_, slotId_, salt_));

        return Create2.computeAddress(bytes32(salt_), bytecodeHash);
    }
}
