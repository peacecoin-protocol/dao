// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
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
    bytes32 public constant DAO_MANAGER_ROLE = keccak256("DAO_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Maximum values for safety
    uint256 public constant MAX_VOTING_DELAY = 30 days;
    uint256 public constant MAX_VOTING_PERIOD = 30 days;
    uint256 public constant MAX_TIMELOCK_DELAY = 30 days;

    // ============ State Variables ============

    /// @notice Mapping to track DAO names to prevent duplicates
    mapping(string => bool) public daoNames;

    /// @notice Mapping from DAO ID to its creator
    mapping(bytes32 => DAOConfig) public daoConfigs;

    string public uri_;

    /// @notice Implementation addresses for cloning
    address public timelockImplementation;
    address public governorImplementation;
    address public governanceTokenImplementation;
    address public sbtImplementation;
    address public nftImplementation;

    address public campaignFactory;

    // ============ Events ============
    event ContractDeployed(address indexed contractAddress);
    event DAOCreated(bytes32 indexed daoId, string daoName, address creator);

    event ImplementationUpdated(
        address timelockImplementation,
        address governorImplementation,
        address governanceTokenImplementation,
        address sbtImplementation,
        address nftImplementation
    );

    // ============ Modifiers ============
    modifier validDAO(bytes32 daoId) {
        IDAOFactory.DAOConfig memory daoConfig = daoConfigs[daoId];
        if (daoConfig.timelock == address(0)) revert IErrors.DAODoesNotExist();
        _;
    }

    modifier validImplementation() {
        if (timelockImplementation == address(0)) revert IErrors.TimelockImplementationNotSet();
        if (governorImplementation == address(0)) revert IErrors.GovernorImplementationNotSet();
        if (governanceTokenImplementation == address(0))
            revert IErrors.GovernanceTokenImplementationNotSet();
        if (sbtImplementation == address(0)) revert IErrors.InvalidAddress();
        if (nftImplementation == address(0)) revert IErrors.InvalidAddress();
        _;
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
     * @param _timelockImplementation Address of the timelock implementation
     * @param _governorImplementation Address of the governor implementation
     * @param _governanceTokenImplementation Address of the governance token implementation
     * @param _sbtImplementation Address of the SBT implementation
     * @param _nftImplementation Address of the NFT implementation
     */
    function setImplementation(
        address _timelockImplementation,
        address _governorImplementation,
        address _governanceTokenImplementation,
        address _sbtImplementation,
        address _nftImplementation
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_timelockImplementation == address(0)) revert IErrors.TimelockImplementationNotSet();
        if (_governorImplementation == address(0)) revert IErrors.GovernorImplementationNotSet();
        if (_governanceTokenImplementation == address(0))
            revert IErrors.GovernanceTokenImplementationNotSet();
        if (_sbtImplementation == address(0)) revert IErrors.InvalidAddress();
        if (_nftImplementation == address(0)) revert IErrors.InvalidAddress();

        timelockImplementation = _timelockImplementation;
        governorImplementation = _governorImplementation;
        governanceTokenImplementation = _governanceTokenImplementation;
        sbtImplementation = _sbtImplementation;
        nftImplementation = _nftImplementation;

        emit ImplementationUpdated(
            _timelockImplementation,
            _governorImplementation,
            _governanceTokenImplementation,
            _sbtImplementation,
            _nftImplementation
        );
    }

    function setURI(string memory _uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uri_ = _uri;
    }

    function setCampaignFactory(address _campaignFactory) external onlyRole(DEFAULT_ADMIN_ROLE) {
        campaignFactory = _campaignFactory;
        grantRole(DEFAULT_ADMIN_ROLE, campaignFactory);
    }

    function removeCampaignFactory() external onlyRole(DEFAULT_ADMIN_ROLE) {
        campaignFactory = address(0);
        revokeRole(DEFAULT_ADMIN_ROLE, campaignFactory);
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
    function createDAO(
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
        _validateCreateDAOInputs(
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
        uint256 _votingDelay = votingDelay;
        uint256 _votingPeriod = votingPeriod;
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
        address sbtAddress = _deploySBT(msg.sender);
        address nftAddress = _deployNFT(msg.sender);
        address governorAddress = _deployGovernor(
            _daoName,
            governanceTokenAddress,
            sbtAddress,
            nftAddress,
            timelockAddress,
            _votingDelay,
            _votingPeriod,
            _proposalThreshold,
            _quorumVotes,
            address(this),
            _socialConfig
        );

        // Store DAO address

        daoConfigs[daoId] = IDAOFactory.DAOConfig({
            timelock: timelockAddress,
            sbt: sbtAddress,
            nft: nftAddress,
            governor: governorAddress,
            governanceToken: governanceTokenAddress,
            communityToken: _communityToken,
            creator: msg.sender
        });

        // Set up governance hierarchy
        ITimelock(timelockAddress).setPendingAdmin(governorAddress);
        ICommunityGovernance(governorAddress).__acceptAdmin();

        // Grant DAO manager role
        _grantRole(DAO_MANAGER_ROLE, msg.sender);
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

    function _validateCreateDAOInputs(
        string memory daoName,
        address communityToken,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 timelockDelay,
        uint256 quorumVotes,
        address creator
    ) internal view {
        _validateAddresses(communityToken, creator);
        _validateName(daoName);
        _validateParameters(votingDelay, votingPeriod, timelockDelay, quorumVotes);
    }

    /**
     * @notice Validate address inputs
     */
    function _validateAddresses(address communityToken, address creator) internal view {
        if (communityToken == address(0)) revert IErrors.InvalidAddress();
        if (creator != IToken(communityToken).owner()) revert IErrors.InvalidCommunityTokenOwner();
    }

    /**
     * @notice Validate DAO name
     */
    function _validateName(string memory daoName) internal view {
        if (bytes(daoName).length == 0) revert IErrors.InvalidName();
        if (daoNames[daoName]) revert IErrors.DAONameAlreadyExists();
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
        if (votingDelay > MAX_VOTING_DELAY) revert IErrors.InvalidVotingDelay();
        if (votingPeriod > MAX_VOTING_PERIOD) revert IErrors.InvalidVotingPeriod();
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
     * @notice Deploy SBT contract
     */
    function _deploySBT(address owner) internal returns (address) {
        address sbtAddress = sbtImplementation.clone();
        if (sbtAddress == address(0)) revert IErrors.ContractDeploymentFailed();
        INFTInterface(sbtAddress).initialize(uri_, address(this), owner, true);
        emit ContractDeployed(sbtAddress);
        return sbtAddress;
    }

    /**
     * @notice Deploy NFT contract
     */
    function _deployNFT(address owner) internal returns (address) {
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

interface ITimelock {
    function setPendingAdmin(address newAdmin) external;
    function initialize(address _owner, uint256 _delay) external;
}

interface ICommunityGovernance {
    function __acceptAdmin() external;
    function initialize(
        string memory daoName,
        address _token,
        address _sbt,
        address _nft,
        address _timelock,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumVotes,
        address _guardian,
        IDAOFactory.SocialConfig memory _socialConfig
    ) external;
}
