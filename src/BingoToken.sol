// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract BingoToken is ERC20, Ownable {
    constructor(uint256 amount) ERC20("BingoToken", "BT") Ownable(msg.sender) {
        _mint(msg.sender, amount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
