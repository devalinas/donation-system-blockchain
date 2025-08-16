// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Toncoin is ERC20 {
    string internal constant NAME = "Toncoin";
    string internal constant SYMBOL = "TON";

    constructor() ERC20(NAME, SYMBOL) {
        _mint(_msgSender(), 1_000_000 ether);
    }

    function mintFor(address user, uint256 amount) external {
        _mint(user, amount);
    }

    function mint(uint256 amount) external {
        _mint(_msgSender(), amount);
    }
}