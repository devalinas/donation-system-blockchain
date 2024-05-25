// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BinanceCoin is ERC20 {
    string internal constant NAME = "Binance Coin";
    string internal constant SYMBOL = "BNB";


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