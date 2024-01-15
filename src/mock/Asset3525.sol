// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@solvprotocol/erc-3525/ERC3525.sol";

contract Asset3525 is ERC3525, Ownable {
    using Strings for uint256;

    constructor() ERC3525("Asset3525", "AT3525", 18) {}

    function mint(address to_, uint256 slot_, uint256 amount_) external onlyOwner {
        _mint(to_, slot_, amount_);
    }
}
