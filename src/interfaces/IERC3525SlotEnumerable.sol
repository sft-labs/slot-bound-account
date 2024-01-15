// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC3525} from "@solvprotocol/erc-3525/IERC3525.sol";

interface IERC3525SlotEnumerable is IERC3525 {
    function tokenSupplyInSlot(uint256 slot) external view returns (uint256);
    function tokenInSlotByIndex(uint256 slot, uint256 index) external view returns (uint256);
}
