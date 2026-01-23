// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @title MultipleVotings
/// @notice Contract for handling multiple choice voting proposals in the governance system
/// @dev Supports up to 20 options per proposal, allows users to allocate voting power across options
contract MultipleVotings is Initializable, ReentrancyGuardUpgradeable {
    /// @notice Maximum number of options allowed per proposa
    uint256 public constant MAX_OPTIONS = 20;

    /// @notice The address of the governor contract
    address public governor;

    /// @notice The address of the admin
    address public admin;

    /// @notice The proposal threshold
    uint256 public proposalThreshold;

    /// @notice Multiple choice proposal structure
    struct MultipleChoiceProposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice Proposal start timestamp
        uint256 startTimestamp;
        /// @notice Proposal end timestamp
        uint256 endTimestamp;
        /// @notice Array of option descriptions (up to 20)
        string[] options;
        /// @notice Total voting power allocated to each option
        mapping(uint256 => uint256) optionVotes;
        /// @notice Total voting power cast in this proposal
        uint256 totalVotesCast;
        /// @notice Proposal description
        string description;
        /// @notice Receipts of ballots for voters (tracks their vote allocations)
        mapping(address => bool) hasVoted;
        /// @notice Proposal state
        ProposalState state;
        /// @notice Proposal created at
        uint256 createdAt;
    }

    /// @notice The total number of multiple choice proposals
    uint256 public proposalCount;

    /// @notice Mapping from proposal ID to multiple choice proposal
    mapping(uint256 => MultipleChoiceProposal) public proposals;

    /// @notice Events
    event MultipleChoiceProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        string[] options,
        uint256 startTimestamp,
        uint256 endTimestamp,
        string description,
        uint256 createdAt
    );

    event MultipleChoiceVoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint256 selectedOption,
        uint256 availableVotes
    );

    event ProposalCanceled(uint256 indexed id);
    event ProposalFinalized(uint256 indexed id, ProposalState state);

    /// @notice Initialize the contract
    /// @param _governor Address of the governor contract
    /// @param _admin The address of the admin
    function initialize(address _governor, address _admin) external initializer {
        require(_governor != address(0), "Multiple_Votings: invalid governor address");
        require(_admin != address(0), "Multiple_Votings: invalid admin address");

        governor = _governor;
        admin = _admin;

        proposalThreshold = IGovernor(_governor).proposalThreshold();

        __ReentrancyGuard_init();
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Multiple_Votings: only admin can call this function");
        _;
    }

    /// @notice Set the admin address
    /// @param _admin The new admin address
    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    /// @notice Create a new multiple choice proposal
    /// @param options Array of option descriptions (max 20)
    /// @param description Proposal description
    /// @return proposalId The ID of the created proposal
    function proposeMultipleChoice(
        string[] memory options,
        string memory description,
        uint256 startTimestamp,
        uint256 endTimestamp
    ) external nonReentrant returns (uint256) {
        require(options.length > 1, "Multiple_Votings: must have at least 2 options");
        require(options.length <= MAX_OPTIONS, "Multiple_Votings: too many options");
        require(bytes(description).length > 0, "Multiple_Votings: description required");

        // Check proposer has enough voting power (using governor's threshold)
        require(
            getPastVotes(msg.sender, block.number - 1) > proposalThreshold,
            "Multiple_Votings: proposer votes below proposal threshold"
        );

        proposalCount++;
        uint256 proposalId = proposalCount;

        MultipleChoiceProposal storage newProposal = proposals[proposalId];

        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.startTimestamp = startTimestamp;
        newProposal.endTimestamp = endTimestamp;
        newProposal.createdAt = block.number;
        newProposal.state = ProposalState.Active;
        newProposal.description = description;
        newProposal.totalVotesCast = 0;

        // Copy options array
        for (uint256 i = 0; i < options.length; i++) {
            require(bytes(options[i]).length > 0, "Multiple_Votings: empty option");
            newProposal.options.push(options[i]);
            newProposal.optionVotes[i] = 0;
        }

        emit MultipleChoiceProposalCreated(
            proposalId,
            msg.sender,
            options,
            newProposal.startTimestamp,
            newProposal.endTimestamp,
            description,
            newProposal.createdAt
        );

        return proposalId;
    }

    /// @notice Cast a vote on a multiple choice proposal
    /// @param proposalId The ID of the proposal
    /// @param selectedOption The index of the selected option
    function castMultipleChoiceVote(
        uint256 proposalId,
        uint256 selectedOption
    ) external nonReentrant {
        MultipleChoiceProposal storage proposal = proposals[proposalId];
        require(proposal.proposer != address(0), "Multiple_Votings: proposal does not exist");
        require(selectedOption < proposal.options.length, "Multiple_Votings: invalid option index");
        require(proposal.id != 0, "Multiple_Votings: proposal does not exist");
        require(proposal.state == ProposalState.Active, "Multiple_Votings: voting is closed");
        require(block.timestamp >= proposal.startTimestamp, "Multiple_Votings: voting not started");
        require(block.timestamp <= proposal.endTimestamp, "Multiple_Votings: voting ended");
        require(!proposal.hasVoted[msg.sender], "Multiple_Votings: voter already voted");
        require(proposal.state != ProposalState.Canceled, "Multiple_Votings: proposal canceled");

        // Get voter's available voting power at proposal start block
        uint256 availableVotes = getPastVotes(msg.sender, proposal.createdAt);
        require(availableVotes > 0, "Multiple_Votings: no voting power");

        // Allocate votes to the selected option
        proposal.optionVotes[selectedOption] += availableVotes;
        proposal.totalVotesCast += availableVotes;

        proposal.hasVoted[msg.sender] = true;

        emit MultipleChoiceVoteCast(msg.sender, proposalId, selectedOption, availableVotes);
    }

    /// @notice Get vote counts for all options in a proposal
    /// @param proposalId The ID of the proposal
    /// @return optionVotes Array of vote counts for each option
    function getOptionVotes(uint256 proposalId) external view returns (uint256[] memory) {
        MultipleChoiceProposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Multiple_Votings: proposal does not exist");

        uint256[] memory votes = new uint256[](proposal.options.length);
        for (uint256 i = 0; i < proposal.options.length; i++) {
            votes[i] = proposal.optionVotes[i];
        }
        return votes;
    }

    /// @notice Get proposal details
    /// @param proposalId The ID of the proposal
    /// @return id Proposal ID
    /// @return proposer Proposal creator
    /// @return options Array of option descriptions
    /// @return startTimestamp Voting start timestamp
    /// @return endTimestamp Voting end timestamp
    /// @return totalVotesCasted Total votes cast
    /// @return state Proposal state
    /// @return description Proposal description
    /// @return hasVoted Whether the sender has voted
    /// @return createdAt Proposal creation timestamp
    function getProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            uint256 id,
            address proposer,
            string[] memory options,
            uint256 startTimestamp,
            uint256 endTimestamp,
            uint256 totalVotesCasted,
            ProposalState state,
            string memory description,
            bool hasVoted,
            uint256 createdAt
        )
    {
        MultipleChoiceProposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Multiple_Votings: proposal does not exist");

        id = proposal.id;
        proposer = proposal.proposer;
        options = proposal.options;
        startTimestamp = proposal.startTimestamp;
        endTimestamp = proposal.endTimestamp;
        totalVotesCasted = proposal.totalVotesCast;
        state = proposal.state;
        description = proposal.description;
        hasVoted = proposal.hasVoted[msg.sender];
        createdAt = proposal.createdAt;
    }

    /// @notice Cancel a proposal (only admin or proposer)
    /// @param proposalId The ID of the proposal
    function cancel(uint256 proposalId) external nonReentrant {
        MultipleChoiceProposal storage proposal = proposals[proposalId];
        require(
            msg.sender == admin || msg.sender == proposal.proposer,
            "Multiple_Votings: only admin or proposer can cancel"
        );
        require(proposal.id != 0, "Multiple_Votings: proposal does not exist");
        require(block.timestamp < proposal.endTimestamp, "Multiple_Votings: voting ended");
        require(
            proposal.state != ProposalState.Canceled,
            "Multiple_Votings: proposal already canceled"
        );

        proposal.state = ProposalState.Canceled;
        emit ProposalCanceled(proposalId);
    }

    /// @notice Get past votes for an account at a specific block
    /// @param account The account to check
    /// @param blockNumber The block number to check at
    /// @return votes The voting power
    function getPastVotes(address account, uint256 blockNumber) public view returns (uint256) {
        return uint256(GovernorInterface(governor).getPastVotes(account, blockNumber));
    }

    /// @notice Proposal state enum (matches Governor)
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Ended
    }

    /// @notice Get the state of a proposal
    /// @dev This function is external to allow for external calls
    /// @param proposalId The ID of the proposal
    /// @return state The state of the proposal
    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        MultipleChoiceProposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Multiple_Votings: proposal does not exist");

        // If already finalized or canceled, return stored state
        if (proposal.state == ProposalState.Canceled || proposal.state == ProposalState.Ended) {
            return proposal.state;
        }

        if (block.timestamp <= proposal.startTimestamp) {
            return ProposalState.Pending;
        }

        if (block.timestamp <= proposal.endTimestamp) {
            return ProposalState.Active;
        }

        return ProposalState.Ended;
    }
}

interface GovernorInterface {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint96);
}
