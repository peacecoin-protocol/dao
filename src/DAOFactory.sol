// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Governance/GovernorAlpha.sol";
import "./Governance/Timelock.sol";

contract DAOFactory is Ownable {
    struct SocialConfig {
        string description;
        string website;
        string linkedin;
        string twitter;
        string telegram;
    }

    struct DAOConfig {
        address governor;
        address timelock;
        address governanceToken;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumPercentage;
        SocialConfig socialConfig;
        bool exists;
    }

    // Mapping from DAO ID to its configuration
    mapping(bytes32 => DAOConfig) public daos;
    // Mapping to track DAO names to prevent duplicates
    mapping(string => bool) public daoNames;
    // Counter for total DAOs
    uint256 public totalDAOs;

    event DAOCreated(
        bytes32 indexed daoId,
        string description,
        string website,
        string linkedin,
        string twitter,
        string telegram,
        string name,
        address indexed governor,
        address indexed timelock,
        address governanceToken
    );

    constructor() Ownable(msg.sender) {}

    function createDAO(
        string memory daoName,
        SocialConfig memory socialConfig,
        address governanceToken,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumPercentage,
        uint256 timelockDelay
    ) external returns (bytes32) {
        require(governanceToken != address(0), "Invalid governance token");
        require(IGovernanceToken(governanceToken).owner() == msg.sender, "Invalid governance token owner");
        require(bytes(daoName).length > 0, "Empty name not allowed");
        require(!daoNames[daoName], "DAO name already exists");

        bytes32 daoId = keccak256(abi.encodePacked(daoName));
        require(!daos[daoId].exists, "DAO already exists");

        // Deploy Timelock
        Timelock timelock = new Timelock(address(this), timelockDelay);

        // Deploy Governor
        GovernorAlpha governor = new GovernorAlpha(
            daoName,
            IERC20(governanceToken),
            address(timelock),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumPercentage
        );

        timelock.setPendingAdmin(address(governor));
        governor.__acceptAdmin();

        // Store DAO configuration
        daos[daoId] = DAOConfig({
            governor: address(governor),
            timelock: address(timelock),
            governanceToken: governanceToken,
            votingDelay: votingDelay,
            votingPeriod: votingPeriod,
            proposalThreshold: proposalThreshold,
            quorumPercentage: quorumPercentage,
            socialConfig: socialConfig,
            exists: true
        });

        daoNames[daoName] = true;
        totalDAOs++;

        emit DAOCreated(
            daoId,
            socialConfig.description,
            socialConfig.website,
            socialConfig.linkedin,
            socialConfig.twitter,
            socialConfig.telegram,
            daoName,
            address(governor),
            address(timelock),
            governanceToken
        );

        return daoId;
    }

    function getDAO(bytes32 daoId) external view returns (DAOConfig memory) {
        require(daos[daoId].exists, "DAO does not exist");
        return daos[daoId];
    }

    function isDaoExists(bytes32 daoId) external view returns (bool) {
        return daos[daoId].exists;
    }
}

interface IGovernanceToken {
    function owner() external view returns (address);
}
