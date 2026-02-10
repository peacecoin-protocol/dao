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

    function mint(address _to, uint256 _amount) external onlyMinter {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyMinter {
        _burn(_from, _amount);
    }

    function addMinter(address _minter) external onlyOwner {
        isMinter[_minter] = true;
    }

    function removeMinter(address _minter) external onlyOwner {
        isMinter[_minter] = false;
    }
}
