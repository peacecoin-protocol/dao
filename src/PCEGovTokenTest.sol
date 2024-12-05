// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "./interfaces/IPCEToken.sol";

contract PCEGovTokenTest is ERC20VotesUpgradeable, OwnableUpgradeable {
    function initialize(address _owner) public initializer {
        __ERC20_init("PEACE COIN Governance", "PCEGOV");
        __Ownable_init_unchained(_owner);
        _mint(_owner, 1000000000000000000000000);
    }
}
