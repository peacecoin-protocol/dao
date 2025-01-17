// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

contract PCECommunityGovToken is OwnableUpgradeable, ERC20VotesUpgradeable {
    ERC20Upgradeable public communityToken;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function initialize(address _communityToken) external initializer {
        communityToken = ERC20Upgradeable(_communityToken);

        __Ownable_init(msg.sender);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Stake: can't stake 0");

        communityToken.transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
        emit Deposited(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public {
        require(_amount > 0, "Amount should be greater then 0");

        _burn(msg.sender, _amount);
        communityToken.transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }
}
