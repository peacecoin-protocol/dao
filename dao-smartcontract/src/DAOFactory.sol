// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {INFTInterface} from "./interfaces/INFTInterface.sol";
import {IDAOFactory} from "./interfaces/IDAOFactory.sol";
import {IErrors} from "./interfaces/IErrors.sol";

/**
 * @title DAOFactory
 * @dev Factory contract for creating and managing DAOs
 * @notice This contract allows authorized users to create new DAOs with governance tokens and timelock controllers
 * @author Daniel Lee
 */
contract DAOFactory is
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IDAOFactory,
    IErrors
{
    using Clones for address;

    // ============ Constants ============
    bytes32 public constant daoManagerRole = keccak256("DAO_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Maximum values for safety
    uint256 public constant MIN_TIMELOCK_DELAY = 1 minutes;
    uint256 public constant MAX_TIMELOCK_DELAY = 30 hours;
    uint256 public constant MIN_VOTING_PERIOD = 7200;
    uint256 public constant MIN_VOTING_DELAY = 1;

    // ============ State Variables ============

    /// @notice Mapping from DAO ID to its creator
    mapping(bytes32 => DaoConfig) public daoConfigs;

    string public uri_;

    /// @notice Implementation addresses for cloning
    address public timelockImplementation;
    address public governorImplementation;
    address public governanceTokenImplementation;
    address public sbtImplementation;
    address public nftImplementation;

    address public campaignFactory;
    address public multipleVotingImplementation;

    // ============ Events ============
    event ContractDeployed(address indexed contractAddress);
    event DAOCreated(bytes32 indexed daoId, string daoName, address creator);

    event ImplementationUpdated(
        address indexed timelockImplementation,
        address indexed governorImplementation,
        address indexed governanceTokenImplementation,
        address multipleVotingImplementation,
        address sbtImplementation,
        address nftImplementation
    );

    // ============ Modifiers ============

    modifier validImplementation() {
        _validateImplementation();
        _;
    }

    function _validateImplementation() internal view {
        if (timelockImplementation == address(0)) revert IErrors.TimelockImplementationNotSet();
        if (governorImplementation == address(0)) revert IErrors.GovernorImplementationNotSet();
        if (governanceTokenImplementation == address(0)) {
            revert IErrors.GovernanceTokenImplementationNotSet();
        }
        if (sbtImplementation == address(0)) revert IErrors.InvalidAddress();
        if (nftImplementation == address(0)) revert IErrors.InvalidAddress();
    }

    // ============ Initializer ============
    function initialize() public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    // ============ External Functions ============

    /**
     * @notice Set implementation addresses for DAO components
     * @dev Only callable by the contract owner
     * @param newTimelockImplementation Address of the timelock implementation
     * @param newGovernorImplementation Address of the governor implementation
     * @param newGovernanceTokenImplementation Address of the governance token implementation
     * @param newMultipleVotingImplementation Address of the multiple voting implementation
     * @param newSbtImplementation Address of the SBT implementation
     * @param newNftImplementation Address of the NFT implementation
     */
    function setImplementation(
        address newTimelockImplementation,
        address newGovernorImplementation,
        address newGovernanceTokenImplementation,
        address newMultipleVotingImplementation,
        address newSbtImplementation,
        address newNftImplementation
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTimelockImplementation == address(0)) {
            revert IErrors.TimelockImplementationNotSet();
        }
        if (newGovernorImplementation == address(0)) revert IErrors.GovernorImplementationNotSet();
        if (newGovernanceTokenImplementation == address(0)) {
            revert IErrors.GovernanceTokenImplementationNotSet();
        }
        if (newMultipleVotingImplementation == address(0)) {
            revert IErrors.MultipleVotingImplementationNotSet();
        }
        if (newSbtImplementation == address(0)) revert IErrors.InvalidAddress();
        if (newNftImplementation == address(0)) revert IErrors.InvalidAddress();

        timelockImplementation = newTimelockImplementation;
        governorImplementation = newGovernorImplementation;
        governanceTokenImplementation = newGovernanceTokenImplementation;
        multipleVotingImplementation = newMultipleVotingImplementation;
        sbtImplementation = newSbtImplementation;
        nftImplementation = newNftImplementation;

        emit ImplementationUpdated(
            newTimelockImplementation,
            newGovernorImplementation,
            newGovernanceTokenImplementation,
            newMultipleVotingImplementation,
            newSbtImplementation,
            newNftImplementation
        );
    }

    function setURI(string memory uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uri_ = uri;
    }

    function setCampaignFactory(address newCampaignFactory) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(DEFAULT_ADMIN_ROLE, campaignFactory);

        campaignFactory = newCampaignFactory;
        _grantRole(DEFAULT_ADMIN_ROLE, campaignFactory);
    }

    function removeCampaignFactory() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(DEFAULT_ADMIN_ROLE, campaignFactory);
        campaignFactory = address(0);
    }

    /**
     * @notice Create a new DAO with governance infrastructure
     * @dev Creates timelock, governance token, and governor contracts
     * @param daoName Name of the DAO (must be unique)
     * @param socialConfig Social media and description configuration
     * @param communityToken Address of the community token
     * @param votingDelay Delay before voting starts on a proposal
     * @param votingPeriod Duration of voting on a proposal
     * @param proposalThreshold Minimum tokens required to create a proposal
     * @param timelockDelay Delay for timelock execution
     * @return daoId Unique identifier for the created DAO
     */
    function createDao(
        string memory daoName,
        SocialConfig memory socialConfig,
        address communityToken,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 timelockDelay,
        uint256 quorumVotes
    ) external override nonReentrant whenNotPaused validImplementation returns (bytes32) {
        // Input validation
        _validateCreateDaoInputs(
            daoName,
            communityToken,
            votingDelay,
            votingPeriod,
            timelockDelay,
            quorumVotes,
            msg.sender
        );
        // Local variables for gas optimization
        string memory _daoName = daoName;
        uint256 _proposalThreshold = proposalThreshold;
        uint256 _quorumVotes = quorumVotes;
        address _communityToken = communityToken;
        SocialConfig memory _socialConfig = socialConfig;

        // Check if DAO already exists
        bytes32 daoId = keccak256(abi.encodePacked(_daoName));
        if (daoConfigs[daoId].timelock != address(0)) revert IErrors.DAOAlreadyExists();

        // Deploy contracts
        address timelockAddress = _deployTimelock(timelockDelay);
        address governanceTokenAddress = _deployGovernanceToken(_communityToken);

        address sbtAddress = _deploySbt(msg.sender);
        address nftAddress = _deployNft(msg.sender);
        address governorAddress = _deployGovernor(
            _daoName,
            governanceTokenAddress,
            sbtAddress,
            nftAddress,
            timelockAddress,
            votingDelay,
            votingPeriod,
            _proposalThreshold,
            _quorumVotes,
            address(this),
            _socialConfig
        );
        address multipleVotingAddress = _deployMultipleVoting(governorAddress, msg.sender);

        daoConfigs[daoId] = IDAOFactory.DaoConfig({
            timelock: timelockAddress,
            multipleVoting: multipleVotingAddress,
            sbt: sbtAddress,
            nft: nftAddress,
            governor: governorAddress,
            governanceToken: governanceTokenAddress,
            communityToken: _communityToken,
            creator: msg.sender
        });

        // Set up governance hierarchy
        ITimelock(timelockAddress).setPendingAdmin(governorAddress);
        ICommunityGovernance(governorAddress).acceptAdmin();

        // Grant DAO manager role
        _grantRole(daoManagerRole, msg.sender);
        // Emit events
        emit DAOCreated(daoId, _daoName, msg.sender);

        return daoId;
    }

    /**
     * @notice Pause the contract
     * @dev Only callable by pausers
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract
     * @dev Only callable by pausers
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ============ Internal Functions ============

    function _validateCreateDaoInputs(
        string memory daoName,
        address communityToken,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 timelockDelay,
        uint256 quorumVotes,
        address creator
    ) internal view {
        _validateName(daoName);
        _validateAddresses(communityToken, creator);
        _validateParameters(votingDelay, votingPeriod, timelockDelay, quorumVotes);
    }

    function _validateName(string memory daoName) internal pure {
        if (bytes(daoName).length == 0) revert IErrors.InvalidName();
    }

    /**
     * @notice Validate address inputs
     */
    function _validateAddresses(address communityToken, address creator) internal view {
        if (communityToken == address(0)) revert IErrors.InvalidAddress();
        if (creator != IToken(communityToken).owner()) revert IErrors.InvalidCommunityTokenOwner();
    }

    /**
     * @notice Validate governance parameters
     */
    function _validateParameters(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 timelockDelay,
        uint256 quorumVotes
    ) internal pure {
        if (votingDelay < MIN_VOTING_DELAY) revert IErrors.InvalidVotingDelay();
        if (votingPeriod < MIN_VOTING_PERIOD) revert IErrors.InvalidVotingPeriod();
        if (timelockDelay < MIN_TIMELOCK_DELAY) revert IErrors.InvalidTimelockDelay();
        if (timelockDelay > MAX_TIMELOCK_DELAY) revert IErrors.InvalidTimelockDelay();
        if (quorumVotes == 0) revert IErrors.InvalidQuorumVotes();
    }

    /**
     * @notice Deploy timelock contract
     */
    function _deployTimelock(uint256 timelockDelay) internal returns (address) {
        address timelockAddress = timelockImplementation.clone();
        if (timelockAddress == address(0)) revert IErrors.ContractDeploymentFailed();

        ITimelock(timelockAddress).initialize(address(this), timelockDelay);
        emit ContractDeployed(timelockAddress);
        return timelockAddress;
    }

    /**
     * @notice Deploy governance token contract
     */
    function _deployGovernanceToken(address communityToken) internal returns (address) {
        address governanceTokenAddress = governanceTokenImplementation.clone();
        if (governanceTokenAddress == address(0)) revert IErrors.ContractDeploymentFailed();

        IToken(governanceTokenAddress).initialize(communityToken);
        emit ContractDeployed(governanceTokenAddress);
        return governanceTokenAddress;
    }

    /**
     * @notice Deploy multiple voting contract
     */
    function _deployMultipleVoting(address governor, address admin) internal returns (address) {
        address multipleVotingAddress = multipleVotingImplementation.clone();
        if (multipleVotingAddress == address(0)) revert IErrors.ContractDeploymentFailed();
        emit ContractDeployed(multipleVotingAddress);
        IMultipleVoting(multipleVotingAddress).initialize(governor, admin);
        return multipleVotingAddress;
    }

    /**
     * @notice Deploy SBT contract
     */
    function _deploySbt(address owner) internal returns (address) {
        address sbtAddress = sbtImplementation.clone();
        if (sbtAddress == address(0)) revert IErrors.ContractDeploymentFailed();
        INFTInterface(sbtAddress).initialize(uri_, address(this), owner, true);
        emit ContractDeployed(sbtAddress);
        return sbtAddress;
    }

    /**
     * @notice Deploy NFT contract
     */
    function _deployNft(address owner) internal returns (address) {
        address nftAddress = nftImplementation.clone();
        if (nftAddress == address(0)) revert IErrors.ContractDeploymentFailed();
        INFTInterface(nftAddress).initialize(uri_, address(this), owner, false);
        emit ContractDeployed(nftAddress);
        return nftAddress;
    }

    /**
     * @notice Deploy governor contract
     */
    function _deployGovernor(
        string memory daoName,
        address governanceTokenAddress,
        address sbtAddress,
        address nftAddress,
        address timelockAddress,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumVotes,
        address guardian,
        IDAOFactory.SocialConfig memory _socialConfig
    ) internal returns (address) {
        address governorAddress = governorImplementation.clone();
        if (governorAddress == address(0)) revert IErrors.ContractDeploymentFailed();

        ICommunityGovernance(governorAddress).initialize(
            daoName,
            governanceTokenAddress,
            sbtAddress,
            nftAddress,
            timelockAddress,
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumVotes,
            guardian,
            _socialConfig
        );
        emit ContractDeployed(governorAddress);
        return governorAddress;
    }
}

// ============ Interfaces ============

interface IToken {
    function owner() external view returns (address);
    function initialize(address _communityToken) external;
}

interface IMultipleVoting {
    function initialize(address _governor, address _admin) external;
}

interface ITimelock {
    function setPendingAdmin(address newAdmin) external;
    function initialize(address _owner, uint256 _delay) external;
}

interface ICommunityGovernance {
    function acceptAdmin() external;
    function initialize(
        string memory daoName,
        address tokenAddress,
        address sbtAddress,
        address nftAddress,
        address timelockAddress,
        uint256 votingDelayBlocks,
        uint256 votingPeriodBlocks,
        uint256 proposalThresholdTokens,
        uint256 quorumVotesAmount,
        address guardianAddress,
        IDAOFactory.SocialConfig memory socialConfig
    ) external;
}
