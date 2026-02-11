// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PCE is OwnableUpgradeable, ERC20Upgradeable {
    function initialize() external initializer {
        __ERC20_init("PEACECOIN", "PCE");
        __Ownable_init(msg.sender);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
