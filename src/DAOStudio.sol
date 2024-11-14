// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./Governance/GovernorAlpha.sol";
import "./Governance/Timelock.sol";
import "./PCECommunityGovToken.sol";

import "./interfaces/IPCEToken.sol";

contract DAOStudio is OwnableUpgradeable {
    struct DAOParam {
        bool isCreated;
        address governor;
        address timelock;
    }

    address public pceToken;
    uint256 public timelockDelay;
    mapping(address => DAOParam) public daos;

    function initialize(address _owner, address _pceToken) public initializer {
        pceToken = _pceToken;
        __Ownable_init_unchained(_owner);
    }

    function setTimelockDelay(uint256 _delay) external onlyOwner {
        timelockDelay = _delay;
    }

    function create(address _communityToken) external {
        require(
            IPCEToken(pceToken).owner() == msg.sender,
            "Community token not owned by sender"
        );

        require(!daos[_communityToken].isCreated, "DAO already created");

        Timelock timelock = new Timelock(msg.sender, timelockDelay);
        GovernorAlpha governor = new GovernorAlpha(
            address(timelock),
            pceToken,
            msg.sender
        );
        timelock.setPendingAdmin(address(governor));

        DAOParam memory param = DAOParam({
            isCreated: true,
            governor: address(governor),
            timelock: address(timelock)
        });
        daos[_communityToken] = param;
    }

    function deleteDAO(address _communityToken) external onlyOwner {
        require(daos[_communityToken].isCreated, "DAO not created");
        delete daos[_communityToken];
    }
}
