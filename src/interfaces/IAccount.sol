// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IAccount {
    /**
     * @dev Executes `call` on address `to`, with value `value` and calldata `data`.
     *
     * MUST revert and bubble up errors if call fails.
     *
     * By default, token bound accounts MUST allow the owner of the ERC-3525 token
     * which owns the account to execute arbitrary calls using `exec`.
     *
     * Token bound accounts MAY implement additional authorization mechanisms
     * which limit the ability of the ERC-3525 token holder to execute calls.
     *
     * Token bound accounts MAY implement additional execution functions which
     * grant execution permissions to other non-owner accounts.
     *
     * @param to Account to operate on
     * @param value Value to send with operation
     * @param data Encoded calldata of operation
     * @param operation Operation type (0=CALL, 1=DELEGATECALL, 2=CREATE, 3=CREATE2)
     *
     * @return The result of the call
     */
    function exec(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        payable
        returns (bytes memory);

    /**
     * @dev Token bound accounts MUST implement a `receive` function.
     *
     * Token bound accounts MAY perform arbitrary logic to restrict conditions
     * under which Ether can be received.
     */
    receive() external payable;

    /**
     * @dev Returns identifier of the ERC-3525 token which owns the account
     *
     * The return value of this function MUST be constant - it MUST NOT change
     * over time.
     *
     * @return chainId The EIP-155 ID of the chain the ERC-3525 token exists on
     * @return tokenContract The contract address of the ERC-3525 token
     * @return slotId The slot ID of the ERC-3525 token
     */
    function token() external view returns (uint256 chainId, address tokenContract, uint256 slotId);

    /**
     * @dev Returns a list of owners of the ERC-3525 slot which controls the account
     * if the slot exists.
     *
     * This value is obtained by calling `ownersOfSlot` on the IDSFT contract.
     *
     * @return Address of the owners of the ERC-3525 token which belongs to a slot
     */
    function owners() external view returns (address[] memory);
}
