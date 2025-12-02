// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DummyERC721 is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    constructor(string memory name, string memory symbol) 
      ERC721(name, symbol) 
      Ownable(msg.sender)
    {
        _transferOwnership(msg.sender);
        _tokenIdCounter = 1; // Start token IDs from 1
    }

    function mint(address to) public {
        _safeMint(to, _tokenIdCounter);
        _tokenIdCounter++;
    }
}
