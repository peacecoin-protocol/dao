// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
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
        address communityToken;
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

    bytes public governanceTokenBytecode;

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

    function setBytecodeForGovernorToken(bytes calldata _bytecode) external onlyOwner {
        governanceTokenBytecode = _bytecode;
    }

    function createDAO(
        string memory daoName,
        SocialConfig memory socialConfig,
        address communityToken,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumPercentage,
        uint256 timelockDelay
    ) external returns (bytes32) {
        require(communityToken != address(0), "Invalid governance token");
        require(IGovernanceToken(communityToken).owner() == msg.sender, "Invalid community token owner");
        require(bytes(daoName).length > 0, "Empty name not allowed");
        require(!daoNames[daoName], "DAO name already exists");

        bytes32 daoId = keccak256(abi.encodePacked(daoName));
        require(!daos[daoId].exists, "DAO already exists");
        // Deploy Timelock

        bytes memory timelockBytecode = type(Timelock).creationCode;
        bytes memory timelockConstructorArgs = abi.encode(address(this), timelockDelay);
        bytes memory timelockBytecodeWithConstructorArgs = abi.encodePacked(timelockBytecode, timelockConstructorArgs);
        address timelockAddress = deploy(timelockBytecodeWithConstructorArgs);

        // Deploy Governance Token
        address governanceTokenAddress = deploy(governanceTokenBytecode);
        IGovernanceToken(governanceTokenAddress).initialize(communityToken);

        // Deploy Governor

        bytes memory governorBytecode = type(GovernorAlpha).creationCode;
        bytes memory governorConstructorArgs = abi.encode(
            daoName,
            address(governanceTokenAddress),
            address(timelockAddress),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumPercentage
        );
        bytes memory governorBytecodeWithConstructorArgs = abi.encodePacked(governorBytecode, governorConstructorArgs);
        address governorAddress = deploy(governorBytecodeWithConstructorArgs);

        Timelock(timelockAddress).setPendingAdmin(governorAddress);
        GovernorAlpha(governorAddress).__acceptAdmin();

        // Store DAO configuration
        daos[daoId] = DAOConfig({
            governor: governorAddress,
            timelock: timelockAddress,
            communityToken: communityToken,
            governanceToken: governanceTokenAddress,
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
            // Create a new contract using the `create` opcode
            deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        // Check if deployment was successful
        require(deployedAddress != address(0), "Contract deployment failed");

        // Emit an event with the address of the new contract
        emit ContractDeployed(deployedAddress);
    }
}

interface IGovernanceToken {
    function owner() external view returns (address);
    function initialize(address _communityToken) external;
}
