// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract DAOFactory is Ownable {
    using Clones for address;

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
        address communityToken;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorum;
        SocialConfig socialConfig;
        bool exists;
    }

    // Mapping from DAO ID to its configuration
    mapping(bytes32 => DAOConfig) public daos;
    // Mapping to track DAO names to prevent duplicates
    mapping(string => bool) public daoNames;
    // Counter for total DAOs
    uint256 public totalDAOs;

    address public timelockImplementation;
    address public governorImplementation;
    address public governanceTokenImplementation;

    event ContractDeployed(address contractAddress);

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
        address governanceToken,
        address communityToken
    );

    constructor() Ownable(msg.sender) {}

    function setImplementation(
        address _timelockImplementation,
        address _governorImplementation,
        address _governanceTokenImplementation
    ) external onlyOwner {
        timelockImplementation = _timelockImplementation;
        governorImplementation = _governorImplementation;
        governanceTokenImplementation = _governanceTokenImplementation;
    }

    function createDAO(
        string memory daoName,
        SocialConfig memory socialConfig,
        address communityToken,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorum,
        uint256 timelockDelay
    ) external returns (bytes32) {
        require(communityToken != address(0), "Invalid governance token");
        require(IGovernanceToken(communityToken).owner() == msg.sender, "Invalid community token owner");
        require(bytes(daoName).length > 0, "Empty name not allowed");
        require(!daoNames[daoName], "DAO name already exists");

        bytes32 daoId = keccak256(abi.encodePacked(daoName));
        require(!daos[daoId].exists, "DAO already exists");

        // Deploy Timelock
        require(timelockImplementation != address(0), "Timelock implementation not set");
        address timelockAddress = timelockImplementation.clone();
        ITimelock(timelockAddress).initialize(address(this), timelockDelay);

        // Deploy Governance Token
        require(governanceTokenImplementation != address(0), "Governor token address not set");
        address governanceTokenAddress = governanceTokenImplementation.clone();
        IGovernanceToken(governanceTokenAddress).initialize(communityToken);

        // Deploy Governor
        require(quorum > 0, "Quorum cannot be zero");

        require(governorImplementation != address(0), "Governor implementation not set");
        address governorAddress = governorImplementation.clone();
        IGovernorAlpha(governorAddress).initialize(
            daoName,
            governanceTokenAddress,
            address(timelockAddress),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorum
        );

        ITimelock(timelockAddress).setPendingAdmin(governorAddress);
        IGovernorAlpha(governorAddress).__acceptAdmin();

        // Store DAO configuration
        daos[daoId] = DAOConfig({
            governor: governorAddress,
            timelock: timelockAddress,
            communityToken: communityToken,
            governanceToken: governanceTokenAddress,
            votingDelay: votingDelay,
            votingPeriod: votingPeriod,
            proposalThreshold: proposalThreshold,
            quorum: quorum,
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
            governorAddress,
            timelockAddress,
            governanceTokenAddress,
            communityToken
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

    function deploy(bytes memory bytecode) internal returns (address deployedAddress) {
        // Create a new contract using assembly
        // solhint-disable-next-line no-inline-assembly
        assembly {
            deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(deployedAddress != address(0), "Contract deployment failed");
        emit ContractDeployed(deployedAddress);
    }

    function updateDAOSocialConfig(bytes32 daoId, SocialConfig memory newConfig) external {
        require(daos[daoId].exists, "DAO does not exist");

        daos[daoId].socialConfig = newConfig;

        emit DAOSocialConfigUpdated(
            daoId, newConfig.description, newConfig.website, newConfig.linkedin, newConfig.twitter, newConfig.telegram
        );
    }

    event DAOSocialConfigUpdated(
        bytes32 indexed daoId, string description, string website, string linkedin, string twitter, string telegram
    );
}

interface IGovernanceToken {
    function owner() external view returns (address);
    function initialize(address _communityToken) external;
}

interface ITimelock {
    function setPendingAdmin(address newAdmin) external;
    function initialize(address _owner, uint256 _delay) external;
}

interface IGovernorAlpha {
    function __acceptAdmin() external;
    function initialize(
        string memory daoName,
        address _token,
        address _timelock,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumVotes
    ) external;
}
