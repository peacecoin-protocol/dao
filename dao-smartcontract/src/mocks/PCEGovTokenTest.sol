// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

contract PCEGovTokenTest is ERC20VotesUpgradeable, OwnableUpgradeable {
    function initialize() public initializer {
        __ERC20_init("PEACE COIN Governance", "PCEGOV");
        __ERC20Votes_init();
        __Ownable_init_unchained(msg.sender);
        _mint(msg.sender, 100000 ether);
    }
}
