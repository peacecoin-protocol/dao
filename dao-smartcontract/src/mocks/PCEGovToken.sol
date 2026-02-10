// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {IPCEToken} from "../interfaces/IPCEToken.sol";

contract PCEGovToken is ERC20VotesUpgradeable, OwnableUpgradeable {
    address public pceToken;
    mapping(address => bool) public isCommunityTokenClaimed;

    function initialize(address _owner, address _pceToken) public initializer {
        pceToken = _pceToken;
        __ERC20_init("PEACE COIN Governance", "PCEGOV");
        __ERC20Votes_init();
        __Ownable_init_unchained(_owner);
    }

    function claimGovernanceTokens(address _communityToken) external {
        require(!isCommunityTokenClaimed[_communityToken], "Community token already claimed");
        require(
            IPCEToken(_communityToken).owner() == msg.sender,
            "Community token not owned by sender"
        );

        IPCEToken.LocalToken memory localToken = IPCEToken(pceToken).getLocalToken(_communityToken);

        isCommunityTokenClaimed[_communityToken] = true;

        _mint(msg.sender, localToken.depositedPceToken);
    }
}
