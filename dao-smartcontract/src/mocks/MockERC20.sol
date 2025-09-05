// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockERC20 is OwnableUpgradeable, ERC20Upgradeable {
    function initialize() external initializer {
        __ERC20_init("MockERC20", "MOCK");
        __Ownable_init(msg.sender);
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
