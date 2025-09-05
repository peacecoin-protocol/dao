// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SBTInterface} from "../interfaces/SBTInterface.sol";

contract PEACECOINDAO_GOVERNOR {
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
    GovInterface public token;

    /// @notice The address of the Governor Guardian
    address public guardian;

    /// @notice The address of the SBT
    SBTInterface public sbt;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    bool public initialized;

    struct SocialConfig {
        string description;
        string website;
        string linkedin;
        string twitter;
        string telegram;
    }

    SocialConfig public socialConfig;

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
        uint96 votes;
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
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(address voter, uint256 proposalId, bool support, uint256 votes);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

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
        address _token,
        address _sbt,
        address _timelock,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumVotes,
        address _guardian
    ) external {
        require(!initialized, "Governor::initialize: already initialized");
        initialized = true;

        name = daoName;
        token = GovInterface(address(_token));
        sbt = SBTInterface(_sbt);
        timelock = TimelockInterface(_timelock);
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumVotes = _quorumVotes;
        guardian = _guardian;
        proposalMaxOperations = 10;
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        require(
            token.getPastVotes(msg.sender, sub256(block.number, 1)) +
                sbt.getPastVotes(msg.sender, sub256(block.number, 1)) >
                proposalThreshold,
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
                token.getPastVotes(proposal.proposer, sub256(block.number, 1)) +
                    sbt.getPastVotes(proposal.proposer, sub256(block.number, 1)) <
                proposalThreshold,
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
        } else if (block.timestamp >= add256(proposal.eta, timelock.GRACE_PERIOD())) {
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
        uint96 votes = token.getPastVotes(voter, proposal.startBlock) +
            sbt.getPastVotes(voter, proposal.startBlock);

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

        quorumVotes = quorumVotes_;
        proposalThreshold = proposalThreshold_;
        proposalMaxOperations = proposalMaxOperations_;

        emit QuorumVotesSet(quorumVotes, quorumVotes_);
        emit ProposalThresholdSet(proposalThreshold, proposalThreshold_);
        emit ProposalMaxOperationsSet(proposalMaxOperations, proposalMaxOperations_);
    }

    function updateSocialConfig(
        string memory description,
        string memory website,
        string memory linkedin,
        string memory twitter,
        string memory telegram
    ) public {
        socialConfig.description = description;
        socialConfig.website = website;
        socialConfig.linkedin = linkedin;
        socialConfig.twitter = twitter;
        socialConfig.telegram = telegram;

        emit SocialConfigUpdated(description, website, linkedin, twitter, telegram);
    }

    function getSocialConfig() public view returns (SocialConfig memory) {
        return socialConfig;
    }

    function __acceptAdmin() public {
        require(msg.sender == guardian, "Governor::__acceptAdmin: sender must be gov guardian");
        timelock.acceptAdmin();
    }

    function __abdicate() public {
        require(msg.sender == guardian, "Governor::__abdicate: sender must be gov guardian");
        guardian = address(0);
    }

    function __queueSetTimelockPendingAdmin(address newPendingAdmin, uint256 eta) public {
        require(
            msg.sender == guardian,
            "Governor::__queueSetTimelockPendingAdmin: sender must be gov guardian"
        );
        timelock.queueTransaction(
            address(timelock),
            0,
            "setPendingAdmin(address)",
            abi.encode(newPendingAdmin),
            eta
        );
    }

    function __executeSetTimelockPendingAdmin(address newPendingAdmin, uint256 eta) public {
        require(
            msg.sender == guardian,
            "Governor::__executeSetTimelockPendingAdmin: sender must be gov guardian"
        );
        timelock.executeTransaction(
            address(timelock),
            0,
            "setPendingAdmin(address)",
            abi.encode(newPendingAdmin),
            eta
        );
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

    function getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}

interface TimelockInterface {
    function delay() external view returns (uint256);
    function GRACE_PERIOD() external view returns (uint256);
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

interface GovInterface {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint96);
}
