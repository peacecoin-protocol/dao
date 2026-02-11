// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract WPCE is OwnableUpgradeable, ERC20VotesUpgradeable {
    mapping(address => bool) public isMinter;

    modifier onlyMinter() {
        _onlyMinter();
        _;
    }

    function _onlyMinter() internal view {
        require(isMinter[msg.sender], "Not a minter");
    }

    function initialize() external initializer {
        __ERC20_init("WPCE", "WPCE");
        __ERC20Votes_init();
        __Ownable_init(msg.sender);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }

    function addMinter(address minter) external onlyOwner {
        isMinter[minter] = true;
    }

    function removeMinter(address minter) external onlyOwner {
        isMinter[minter] = false;
    }
}
