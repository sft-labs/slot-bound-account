// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IAccountRegistry {
    /**
     * @dev Registry instances emit the AccountCreated event upon successful account creation
     */
    event AccountCreated(
        address account, address implementation, uint256 chainId, address tokenContract, uint256 slotId, uint256 salt
    );

    /**
     * @dev Creates a smart contract account.
     *
     * If account has already been created, returns the account address without calling create2.
     *
     * @param salt - The identifying salt for which the user wishes to deploy an Account Instance
     *
     * Emits AccountCreated event
     * @return the address for which the Account Instance was created
     */
    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 slotId,
        uint256 salt,
        bytes calldata initData
    ) external returns (address);

    /**
     * @dev Returns the computed address of a smart contract account for a given identifying salt
     *
     * @return the computed address of the account
     */
    function account(address implementation, uint256 chainId, address tokenContract, uint256 slotId, uint256 salt)
        external
        view
        returns (address);
}
