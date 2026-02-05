// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SBTERC721 is ERC721, Ownable {
    uint256 private _nextTokenId;
    mapping(address => bool) public minters;

    constructor() ERC721("PCE Contributor NFT", "PCE_CONTRIBUTOR") Ownable(msg.sender) {
        minters[msg.sender] = true;
    }

    function mint(address to) external {
        require(minters[msg.sender], "SBT: not a minter");
        _safeMint(to, _nextTokenId++);
    }

    function setMinter(address minter) external onlyOwner {
        minters[minter] = true;
    }

    function transferFrom(address, address, uint256) public pure override {
        revert("SBT: non-transferable");
    }
}
