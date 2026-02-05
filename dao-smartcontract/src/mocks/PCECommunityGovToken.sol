// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

contract PCECommunityGovToken is OwnableUpgradeable, ERC20VotesUpgradeable {
    ERC20Upgradeable public communityToken;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function initialize(address _communityToken) external initializer {
        communityToken = ERC20Upgradeable(_communityToken);

        __ERC20_init("Community Governance Token", "COM_GOV");
        __ERC20Votes_init();
        __Ownable_init(msg.sender);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Stake: can't stake 0");

        bool success = communityToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "ERC20: transferFrom failed");
        _mint(msg.sender, _amount);
        emit Deposited(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public {
        require(_amount > 0, "Amount should be greater then 0");

        _burn(msg.sender, _amount);
        bool success = communityToken.transfer(msg.sender, _amount);
        require(success, "ERC20: transfer failed");
        emit Withdrawn(msg.sender, _amount);
    }
}
