// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockGovToken is OwnableUpgradeable, ERC20VotesUpgradeable {
    function initialize() external initializer {
        __ERC20_init("PCEGovTest", "PCEGOVTEST");
        __Ownable_init(msg.sender);
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
