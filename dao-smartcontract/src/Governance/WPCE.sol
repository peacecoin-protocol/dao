// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract WPCE is OwnableUpgradeable, ERC20VotesUpgradeable {
    mapping(address => bool) public isMinter;

    modifier onlyMinter() {
        require(isMinter[msg.sender], "Not a minter");
        _;
    }

    function initialize() external initializer {
        __ERC20_init("WPCE", "WPCE");
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
