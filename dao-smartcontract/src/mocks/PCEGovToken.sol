// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {IPCEToken} from "../interfaces/IPCEToken.sol";

contract PCEGovToken is ERC20VotesUpgradeable, OwnableUpgradeable {
    address public pceToken;
    mapping(address => bool) public isCommunityTokenClaimed;

    function initialize(address owner, address pceTokenAddress) public initializer {
        pceToken = pceTokenAddress;
        __ERC20_init("PEACE COIN Governance", "PCEGOV");
        __ERC20Votes_init();
        __Ownable_init_unchained(owner);
    }

    function claimGovernanceTokens(address communityToken) external {
        require(!isCommunityTokenClaimed[communityToken], "Community token already claimed");
        require(
            IPCEToken(communityToken).owner() == msg.sender,
            "Community token not owned by sender"
        );

        IPCEToken.LocalToken memory localToken = IPCEToken(pceToken).getLocalToken(
            communityToken
        );

        isCommunityTokenClaimed[communityToken] = true;

        _mint(msg.sender, localToken.depositedPceToken);
    }
}
