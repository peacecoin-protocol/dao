// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "./interfaces/IPCEToken.sol";

contract PCEGovTokenTest is ERC20VotesUpgradeable, OwnableUpgradeable {
    function initialize() public initializer {
        __ERC20_init("PEACE COIN Governance", "PCEGOV");
        __Ownable_init_unchained(msg.sender);
        _mint(msg.sender, 1000000000000000000000000);
    }
}
