// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDAOFactory} from "../interfaces/IDAOFactory.sol";

contract GovernorAlpha {
    /// @notice The name of this contract
    string public name;

    uint256 public proposalMaxOperations;
    uint256 public votingDelay;
    uint256 public votingPeriod;
    uint256 public proposalThreshold;
    uint256 public quorumVotes;

    /// @notice The address of the Timelock
    TimelockInterface public timelock;

    /// @notice The address of the PCE governance token
    GovernorTokenInterface public token;

    /// @notice The address of the SBT
    GovernorTokenInterface public sbt;

    /// @notice The address of the NFT
    GovernorTokenInterface public nft;

    /// @notice The address of the Governor Guardian
    address public guardian;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    bool public initialized;

    IDAOFactory.SocialConfig public socialConfig;

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;
        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint256[] values;
        /// @notice The ordered list of function signatures to be called
        string[] signatures;
        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;
        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;
        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;
        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;
        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;
        /// @notice Flag marking whether the proposal has been executed
        bool executed;
        string description;
        /// @notice Receipts of ballots for the entire set of voters
        mapping(address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;
        /// @notice Whether or not the voter supports the proposal
        bool support;
        /// @notice The number of votes the voter had, which were cast
        uint256 votes;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;

    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votes);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 indexed id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 indexed id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 indexed id);

    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
    event QuorumVotesSet(uint256 oldQuorumVotes, uint256 newQuorumVotes);
    event ProposalMaxOperationsSet(
        uint256 oldProposalMaxOperations,
        uint256 newProposalMaxOperations
    );

    event SocialConfigUpdated(
        string description,
        string website,
        string linkedin,
        string twitter,
        string telegram
    );

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
        IDAOFactory.SocialConfig memory socialConfigInput
    ) external {
        require(!initialized, "Governor::initialize: already initialized");
        initialized = true;

        name = daoName;
        token = GovernorTokenInterface(address(tokenAddress));
        sbt = GovernorTokenInterface(sbtAddress);
        nft = GovernorTokenInterface(nftAddress);
        timelock = TimelockInterface(timelockAddress);
        votingDelay = votingDelayBlocks;
        votingPeriod = votingPeriodBlocks;
        proposalThreshold = proposalThresholdTokens;
        quorumVotes = quorumVotesAmount;
        guardian = guardianAddress;
        proposalMaxOperations = 10;
        socialConfig = socialConfigInput;
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        require(
            getPastVotes(msg.sender, sub256(block.number, 1)) > proposalThreshold,
            "Governor::propose: proposer votes below proposal threshold"
        );
        require(
            targets.length == values.length &&
                targets.length == signatures.length &&
                targets.length == calldatas.length,
            "Governor::propose: proposal function information arity mismatch"
        );
        require(targets.length != 0, "Governor::propose: must provide actions");
        require(targets.length <= proposalMaxOperations, "Governor::propose: too many actions");

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active,
                "Governor::propose: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "Governor::propose: one live proposal per proposer, found an already pending proposal"
            );
        }

        uint256 startBlock = add256(block.number, votingDelay);
        uint256 endBlock = add256(startBlock, votingPeriod);

        proposalCount++;
        uint256 proposalId = proposalCount;
        Proposal storage newProposal = proposals[proposalId];
        // This should never happen but add a check in case.
        require(newProposal.id == 0, "Governor::propose: ProposalID collsion");
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.eta = 0;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;
        newProposal.description = description;

        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );
        return newProposal.id;
    }

    function batchQueue(uint256[] calldata proposalIds) public {
        for (uint256 id = 0; id < proposalIds.length; id++) {
            require(
                state(proposalIds[id]) == ProposalState.Succeeded,
                "Governor::queue: proposal can only be queued if it is succeeded"
            );
            Proposal storage proposal = proposals[proposalIds[id]];
            uint256 eta = add256(block.timestamp, timelock.delay());
            for (uint256 i = 0; i < proposal.targets.length; i++) {
                _queueOrRevert(
                    proposal.targets[i],
                    proposal.values[i],
                    proposal.signatures[i],
                    proposal.calldatas[i],
                    eta
                );
            }
            proposal.eta = eta;
            emit ProposalQueued(proposalIds[id], eta);
        }
    }

    function queue(uint256 proposalId) public {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "Governor::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = add256(block.timestamp, timelock.delay());
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function _queueOrRevert(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        require(
            !timelock.queuedTransactions(
                keccak256(abi.encode(target, value, signature, data, eta))
            ),
            "Governor::_queueOrRevert: proposal action already queued at eta"
        );
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    function batchExecute(uint256[] calldata proposalIds) public payable {
        for (uint256 id = 0; id < proposalIds.length; id++) {
            require(
                state(proposalIds[id]) == ProposalState.Queued,
                "Governor::execute: proposal can only be executed if it is queued"
            );
            Proposal storage proposal = proposals[proposalIds[id]];
            proposal.executed = true;
            for (uint256 i = 0; i < proposal.targets.length; i++) {
                timelock.executeTransaction{value: proposal.values[i]}(
                    proposal.targets[i],
                    proposal.values[i],
                    proposal.signatures[i],
                    proposal.calldatas[i],
                    proposal.eta
                );
            }
            emit ProposalExecuted(proposalIds[id]);
        }
    }

    function execute(uint256 proposalId) public payable {
        require(
            state(proposalId) == ProposalState.Queued,
            "Governor::execute: proposal can only be executed if it is queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction{value: proposal.values[i]}(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) public {
        ProposalState _state = state(proposalId);
        require(
            _state != ProposalState.Executed,
            "Governor::cancel: cannot cancel executed proposal"
        );

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == guardian ||
                getPastVotes(proposal.proposer, sub256(block.number, 1)) < proposalThreshold,
            "Governor::cancel: proposer above threshold"
        );

        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(proposalId);
    }

    function getActions(
        uint256 proposalId
    )
        public
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(
            proposalCount >= proposalId && proposalId > 0,
            "Governor::state: invalid proposal id"
        );
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= add256(proposal.eta, timelock.gracePeriod())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function castVote(uint256 proposalId, bool support) public {
        return _castVote(msg.sender, proposalId, support);
    }

    function proposer(uint256 proposalId) public view returns (address) {
        return proposals[proposalId].proposer;
    }

    function _castVote(address voter, uint256 proposalId, bool support) internal {
        require(state(proposalId) == ProposalState.Active, "Governor::_castVote: voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "Governor::_castVote: voter already voted");

        uint256 votes = getPastVotes(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes = add256(proposal.forVotes, votes);
        } else {
            proposal.againstVotes = add256(proposal.againstVotes, votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes);
    }

    function updateGovernanceParameters(
        uint256 quorumVotes_,
        uint256 proposalThreshold_,
        uint256 proposalMaxOperations_
    ) public {
        require(
            msg.sender == guardian || msg.sender == address(timelock),
            "Governor::updateVariables: only guardian or timelock can update variables"
        );

        emit QuorumVotesSet(quorumVotes, quorumVotes_);
        emit ProposalThresholdSet(proposalThreshold, proposalThreshold_);
        emit ProposalMaxOperationsSet(proposalMaxOperations, proposalMaxOperations_);

        quorumVotes = quorumVotes_;
        proposalThreshold = proposalThreshold_;
        proposalMaxOperations = proposalMaxOperations_;
    }

    function updateSocialConfig(IDAOFactory.SocialConfig memory newSocialConfig) public {
        require(
            msg.sender == guardian || msg.sender == address(timelock),
            "Governor::updateSocialConfig: sender must be gov guardian or timelock"
        );

        socialConfig = newSocialConfig;
        emit SocialConfigUpdated(
            newSocialConfig.description,
            newSocialConfig.website,
            newSocialConfig.linkedin,
            newSocialConfig.twitter,
            newSocialConfig.telegram
        );
    }

    function getSocialConfig() public view returns (IDAOFactory.SocialConfig memory) {
        return socialConfig;
    }

    function acceptAdmin() public {
        require(msg.sender == guardian, "Governor::acceptAdmin: sender must be gov guardian");
        timelock.acceptAdmin();
    }

    function abdicate() public {
        require(msg.sender == guardian, "Governor::abdicate: sender must be gov guardian");
        guardian = address(0);
    }

    function queueSetTimelockPendingAdmin(address newPendingAdmin, uint256 eta) public {
        require(
            msg.sender == guardian,
            "Governor::queueSetTimelockPendingAdmin: sender must be gov guardian"
        );
        timelock.queueTransaction(
            address(timelock),
            0,
            "setPendingAdmin(address)",
            abi.encode(newPendingAdmin),
            eta
        );
    }

    function executeSetTimelockPendingAdmin(address newPendingAdmin, uint256 eta) public {
        require(
            msg.sender == guardian,
            "Governor::executeSetTimelockPendingAdmin: sender must be gov guardian"
        );
        timelock.executeTransaction(
            address(timelock),
            0,
            "setPendingAdmin(address)",
            abi.encode(newPendingAdmin),
            eta
        );
    }

    function getPastVotes(address account, uint256 blockNumber) public view returns (uint256) {
        return
            token.getPastVotes(account, blockNumber) +
            sbt.getPastVotes(account, blockNumber) +
            nft.getPastVotes(account, blockNumber);
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    function sub256(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }
}

interface TimelockInterface {
    function delay() external view returns (uint256);
    function gracePeriod() external view returns (uint256);
    function acceptAdmin() external;
    function queuedTransactions(bytes32 hash) external view returns (bool);
    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);
    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;
    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable returns (bytes memory);
}

interface GovernorTokenInterface {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
}
