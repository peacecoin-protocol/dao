// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MultipleVotings
/// @notice Contract for handling multiple choice voting proposals in the governance system
/// @dev Supports up to 20 options per proposal, allows users to allocate voting power across options
contract MultipleVotings is Initializable, ReentrancyGuard {
    /// @notice Maximum number of options allowed per proposal
    uint256 public constant MAX_OPTIONS = 20;
    uint256 public constant MAX_VOTING_DELAY = 1;
    uint256 public constant MAX_VOTING_PERIOD = 100;
    uint256 public votingDelay;
    uint256 public votingPeriod;
    uint256 public quorumVotes;
    uint256 public proposalThreshold;
    address public admin;
    mapping(address => uint256) public latestProposalIds;

    /// @notice Multiple choice proposal structure
    struct MultipleChoiceProposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice The block at which voting begins
        uint256 startBlock;
        /// @notice The block at which voting ends
        uint256 endBlock;
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
    }

    /// @notice The address of the PCE governance token
    GovernorTokenInterface public token;

    /// @notice The address of the NFT
    GovernorTokenInterface public nft;

    /// @notice The address of the SBT
    GovernorTokenInterface public sbt;

    /// @notice The total number of multiple choice proposals
    uint256 public proposalCount;

    /// @notice Mapping from proposal ID to multiple choice proposal
    mapping(uint256 => MultipleChoiceProposal) public proposals;

    /// @notice Events
    event MultipleChoiceProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        string[] options,
        uint256 startBlock,
        uint256 endBlock,
        string description
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
    /// @param _token Address of the governance token
    /// @param _sbt Address of the SBT contract
    /// @param _nft Address of the NFT contract
    /// @param _votingDelay The delay before voting starts
    /// @param _votingPeriod The period of the voting
    /// @param _quorumVotes The quorum votes required to succeed a proposal
    /// @param _proposalThreshold The threshold for a proposal to be successful
    /// @param _admin The address of the admin
    function initialize(
        address _token,
        address _sbt,
        address _nft,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _quorumVotes,
        uint256 _proposalThreshold,
        address _admin
    ) external initializer {
        require(_votingDelay <= MAX_VOTING_DELAY, "Multiple_Votings: voting delay too long");
        require(_votingPeriod <= MAX_VOTING_PERIOD, "Multiple_Votings: voting period too long");
        require(_token != address(0), "Multiple_Votings: invalid token address");
        require(_sbt != address(0), "Multiple_Votings: invalid SBT address");
        require(_nft != address(0), "Multiple_Votings: invalid NFT address");
        require(_admin != address(0), "Multiple_Votings: invalid admin address");
        require(_quorumVotes > 0, "Multiple_Votings: quorum votes must be greater than 0");
        require(
            _proposalThreshold > 0,
            "Multiple_Votings: proposal threshold must be greater than 0"
        );

        token = GovernorTokenInterface(_token);
        sbt = GovernorTokenInterface(_sbt);
        nft = GovernorTokenInterface(_nft);

        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        quorumVotes = _quorumVotes;
        proposalThreshold = _proposalThreshold;
        admin = _admin;
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

    /// @notice Set the voting delay
    /// @param _votingDelay The new voting delay
    function setVotingDelay(uint256 _votingDelay) external onlyAdmin {
        votingDelay = _votingDelay;
    }

    /// @notice Set the voting period
    /// @param _votingPeriod The new voting period
    function setVotingPeriod(uint256 _votingPeriod) external onlyAdmin {
        votingPeriod = _votingPeriod;
    }

    /// @notice Set the quorum votes
    /// @param _quorumVotes The new quorum votes
    function setQuorumVotes(uint256 _quorumVotes) external onlyAdmin {
        quorumVotes = _quorumVotes;
    }

    /// @notice Set the proposal threshold
    /// @param _proposalThreshold The new proposal threshold
    function setProposalThreshold(uint256 _proposalThreshold) external onlyAdmin {
        proposalThreshold = _proposalThreshold;
    }

    /// @notice Create a new multiple choice proposal
    /// @param options Array of option descriptions (max 20)
    /// @param description Proposal description
    /// @return proposalId The ID of the created proposal
    function proposeMultipleChoice(
        string[] memory options,
        string memory description
    ) external nonReentrant returns (uint256) {
        require(options.length > 1, "Multiple_Votings: must have at least 2 options");
        require(options.length <= MAX_OPTIONS, "Multiple_Votings: too many options");
        require(bytes(description).length > 0, "Multiple_Votings: description required");

        // Check proposer has enough voting power (using governor's threshold)
        require(
            getPastVotes(msg.sender, block.number - 1) > proposalThreshold,
            "Multiple_Votings: proposer votes below proposal threshold"
        );

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            require(
                proposals[latestProposalId].state != ProposalState.Active,
                "Multiple_Votings: one live proposal per proposer, found an already active proposal"
            );
        }

        proposalCount++;
        uint256 proposalId = proposalCount;

        MultipleChoiceProposal storage newProposal = proposals[proposalId];

        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.startBlock = block.number + votingDelay;
        newProposal.endBlock = block.number + votingDelay + votingPeriod;
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
            newProposal.startBlock,
            newProposal.endBlock,
            description
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
        require(block.number >= proposal.startBlock, "Multiple_Votings: voting not started");
        require(block.number <= proposal.endBlock, "Multiple_Votings: voting ended");
        require(!proposal.hasVoted[msg.sender], "Multiple_Votings: voter already voted");
        require(proposal.state != ProposalState.Canceled, "Multiple_Votings: proposal canceled");

        // Get voter's available voting power at proposal start block
        uint256 availableVotes = getPastVotes(msg.sender, proposal.startBlock);
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
    /// @return startBlock Voting start block
    /// @return endBlock Voting end block
    /// @return totalVotesCasted Total votes cast
    /// @return state Proposal state
    /// @return description Proposal description
    function getProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            uint256 id,
            address proposer,
            string[] memory options,
            uint256 startBlock,
            uint256 endBlock,
            uint256 totalVotesCasted,
            ProposalState state,
            string memory description
        )
    {
        MultipleChoiceProposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Multiple_Votings: proposal does not exist");

        id = proposal.id;
        proposer = proposal.proposer;
        options = proposal.options;
        startBlock = proposal.startBlock;
        endBlock = proposal.endBlock;
        totalVotesCasted = proposal.totalVotesCast;
        state = proposal.state;
        description = proposal.description;
    }

    /// @notice Determine the winning option for a proposal
    /// @param proposalId The ID of the proposal
    /// @return majorityVotes The number of votes for the majority option
    function determineMajority(uint256 proposalId) internal view returns (uint256) {
        MultipleChoiceProposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Multiple_Votings: proposal does not exist");

        uint256 majorityVotes = 0;

        for (uint256 i = 0; i < proposal.options.length; i++) {
            if (proposal.optionVotes[i] > majorityVotes) {
                majorityVotes = proposal.optionVotes[i];
            }
        }

        return majorityVotes;
    }

    /// @notice Finalize proposal and determine winner (callable after voting ends)
    /// @param proposalId The ID of the proposal
    function finalizeProposal(uint256 proposalId) external nonReentrant {
        MultipleChoiceProposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Multiple_Votings: proposal does not exist");

        // Check if already finalized
        require(
            proposal.state == ProposalState.Active,
            "Multiple_Votings: proposal already finalized or canceled"
        );

        // Require voting to have ended
        require(block.number > proposal.endBlock, "Multiple_Votings: voting not ended");

        // Determine winning option (see CRITICAL-2)
        uint256 majorityVotes = determineMajority(proposalId);

        if (majorityVotes >= quorumVotes) {
            proposal.state = ProposalState.Succeeded;
        } else {
            proposal.state = ProposalState.Defeated;
        }

        emit ProposalFinalized(proposalId, proposal.state);
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
        require(block.number < proposal.endBlock, "Multiple_Votings: voting ended");
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
        uint256 tokenVotes = uint256(token.getPastVotes(account, blockNumber));
        uint256 sbtVotes = uint256(sbt.getPastVotes(account, blockNumber));
        uint256 nftVotes = uint256(nft.getPastVotes(account, blockNumber));

        uint256 totalVotes = tokenVotes + sbtVotes + nftVotes;

        return totalVotes;
    }

    /// @notice Proposal state enum (matches Governor)
    enum ProposalState {
        Active,
        Canceled,
        Defeated,
        Succeeded
    }

    /// @notice Get the state of a proposal
    /// @dev This function is external to allow for external calls
    /// @param proposalId The ID of the proposal
    /// @return state The state of the proposal
    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        MultipleChoiceProposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Multiple_Votings: proposal does not exist");

        // If already finalized or canceled, return stored state
        if (
            proposal.state == ProposalState.Canceled ||
            proposal.state == ProposalState.Succeeded ||
            proposal.state == ProposalState.Defeated
        ) {
            return proposal.state;
        }

        if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        }

        // Voting has ended but not finalized - compute state
        uint256 majorityVotes = determineMajority(proposalId);

        if (majorityVotes >= quorumVotes) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }
}

interface GovernorTokenInterface {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint96);
}
