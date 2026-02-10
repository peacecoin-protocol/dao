// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract PCECommunityGovToken is
    OwnableUpgradeable,
    ERC20VotesUpgradeable,
    ReentrancyGuardUpgradeable
{
    ERC20Upgradeable public communityToken;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function initialize(address communityTokenAddress) external initializer {
        communityToken = ERC20Upgradeable(communityTokenAddress);

        __ERC20_init("Community Governance Token", "COM_GOV");
        __ERC20Votes_init();
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Stake: can't stake 0");

        _mint(msg.sender, amount);
        emit Deposited(msg.sender, amount);

        bool success = communityToken.transferFrom(msg.sender, address(this), amount);
        require(success, "ERC20: transferFrom failed");
    }

    function withdraw(uint256 amount) public nonReentrant {
        require(amount > 0, "Amount should be greater then 0");

        _burn(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);

        bool success = communityToken.transfer(msg.sender, amount);
        require(success, "ERC20: transfer failed");
    }
}
