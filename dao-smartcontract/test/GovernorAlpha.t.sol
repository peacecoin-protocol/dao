// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockGovToken} from "../src/mocks/MockGovToken.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {Timelock} from "../src/Governance/Timelock.sol";

contract GovernorAlphaTest is Test {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address guardian = address(this);

    MockGovToken pceToken;
    GovernorAlpha gov;
    Timelock timelock;
    uint256 constant INITIAL_BALANCE = 50000e18;
    uint256 constant TIME_LOCK_DELAY = 10 minutes;
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 1 days;
    uint256 constant PROPOSAL_THRESHOLD = 100e18;
    uint256 constant QUORUM_VOTES = 1000e18;
    uint256 constant PROPOSAL_MAX_OPERATIONS = 10;
    uint256 constant EXECUTE_TRANSFER_VALUE = 100;
    uint256 constant PROPOSAL_ID = 1;

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

    event VoteCast(address voter, uint256 proposalId, bool support, uint256 votes);
    event ProposalCanceled(uint256 id);
    event ProposalQueued(uint256 id, uint256 eta);
    event ProposalExecuted(uint256 id);

    function setUp() public {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(guardian, "guardian");

        pceToken = new MockGovToken();
        pceToken.initialize();

        timelock = new Timelock();
        timelock.initialize(alice, TIME_LOCK_DELAY);

        // Updated constructor parameters
        gov = new GovernorAlpha();
        gov.initialize(
            "PCE DAO",
            address(pceToken),
            address(timelock),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_VOTES
        );

        pceToken.mint(guardian, INITIAL_BALANCE);
        pceToken.mint(alice, INITIAL_BALANCE);
        pceToken.mint(bob, INITIAL_BALANCE);
        pceToken.mint(address(timelock), INITIAL_BALANCE);

        vm.prank(alice);
        pceToken.delegate(alice);

        vm.prank(bob);
        pceToken.delegate(alice);

        vm.prank(guardian);
        pceToken.delegate(guardian);
    }

    // Helper methods
    function _buildProposalParams()
        private
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory data,
            string memory description
        )
    {
        targets = new address[](1);
        targets[0] = address(pceToken);

        values = new uint256[](1);
        values[0] = 0;

        signatures = new string[](1);
        signatures[0] = "transfer(address,uint256)";

        data = new bytes[](1);
        data[0] = abi.encode(alice, EXECUTE_TRANSFER_VALUE);

        description = "Transfer PCE";
    }

    function _createProposal() private returns (uint256 proposalId) {
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory data,
            string memory description
        ) = _buildProposalParams();

        proposalId = _createProposalWithParams(targets, values, signatures, data, description);
    }

    function _createProposalWithParams(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory data,
        string memory description
    ) private returns (uint256 proposalId) {
        vm.roll(block.number + 10);

        proposalId = gov.propose(targets, values, signatures, data, description);
    }

    function test__quorumVotes() public view {
        assertEq(gov.quorumVotes(), QUORUM_VOTES);
    }

    function test__proposalThreshold() public view {
        assertEq(gov.proposalThreshold(), PROPOSAL_THRESHOLD);
    }

    function test__proposalMaxOperations() public view {
        assertEq(gov.proposalMaxOperations(), PROPOSAL_MAX_OPERATIONS);
    }

    function test__votingDelay() public view {
        assertEq(gov.votingDelay(), VOTING_DELAY);
    }

    function test__votingPeriod() public view {
        assertEq(gov.votingPeriod(), VOTING_PERIOD);
    }

    function test__proposalCount() public view {
        assertEq(gov.proposalCount(), 0);
    }

    function test__guardian() public view {
        assertEq(gov.guardian(), guardian); // Now the deployer is the guardian
    }

    function test__propose() public {
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory data,
            string memory description
        ) = _buildProposalParams();

        vm.expectRevert("GovernorAlpha::propose: proposer votes below proposal threshold");
        gov.propose(targets, values, signatures, data, description);

        vm.roll(block.number + 10);

        bytes[] memory inv_data = new bytes[](2);
        inv_data[0] = new bytes(1);
        inv_data[1] = new bytes(2);

        vm.expectRevert("GovernorAlpha::propose: proposal function information arity mismatch");
        gov.propose(targets, values, signatures, inv_data, description);

        vm.expectRevert("GovernorAlpha::propose: must provide actions");
        gov.propose(
            new address[](0),
            new uint256[](0),
            new string[](0),
            new bytes[](0),
            description
        );

        vm.expectRevert("GovernorAlpha::propose: too many actions");
        gov.propose(
            new address[](11),
            new uint256[](11),
            new string[](11),
            new bytes[](11),
            description
        );

        // Create Proposal
        vm.expectEmit(true, true, true, true);
        emit ProposalCreated(
            PROPOSAL_ID,
            guardian,
            targets,
            values,
            signatures,
            data,
            block.number + gov.votingDelay(),
            block.number + gov.votingDelay() + gov.votingPeriod(),
            description
        );
        gov.propose(targets, values, signatures, data, description);

        assertEq(gov.proposalCount(), 1);
        assertEq(gov.latestProposalIds(guardian), PROPOSAL_ID);

        // Can't create new proposal if user has active/pending proposal
        vm.expectRevert(
            "GovernorAlpha::propose: one live proposal per proposer, found an already pending proposal"
        );
        
        gov.propose(targets, values, signatures, data, description);
    }

    function test_propose_Reverts_WhenUserHasActiveProposal() public {
        _createProposal();
        (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _data) =
            gov.getActions(PROPOSAL_ID);
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.expectRevert("GovernorAlpha::propose: one live proposal per proposer, found an already active proposal");
        gov.propose(_targets, _values, _signatures, _data, "Transfer PCE");
    }

    function test__castVote() public {
        _createProposal();

        uint256 aliceVotes = pceToken.getPastVotes(alice, block.number - 1); // alice's and bob's delegated votes
        uint256 guardianVotes = pceToken.getPastVotes(guardian, block.number - 1);

        vm.roll(block.timestamp + gov.votingPeriod());
        vm.prank(alice);
        vm.expectEmit(false, false, false, true);
        emit VoteCast(alice, PROPOSAL_ID, true, aliceVotes);
        gov.castVote(PROPOSAL_ID, true);

        vm.prank(guardian);
        vm.expectEmit(false, false, false, true);
        emit VoteCast(guardian, PROPOSAL_ID, true, guardianVotes);
        gov.castVote(PROPOSAL_ID, true);
    }

    function test__getReceipt() public {
        _createProposal();

        uint256 aliceVotes = pceToken.getPastVotes(alice, block.number - 1);

        vm.roll(block.timestamp + gov.votingPeriod());
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, true);

        GovernorAlpha.Receipt memory receipt = gov.getReceipt(PROPOSAL_ID, alice);
        assertEq(receipt.hasVoted, true);
        assertEq(receipt.support, true);
        assertEq(receipt.votes, aliceVotes);
    }

    function test__acceptAdmin() public {
        vm.prank(alice);
        timelock.setPendingAdmin(address(gov));

        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::__acceptAdmin: sender must be gov guardian");
        gov.__acceptAdmin();

        vm.prank(guardian);
        gov.__acceptAdmin();
        assertEq(timelock.admin(), address(gov));
    }

    function test__abdicate() public {
        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::__abdicate: sender must be gov guardian");
        gov.__abdicate();

        vm.prank(guardian);
        gov.__abdicate();
        assertEq(gov.guardian(), address(0));
    }

    function test__cancel() public {
        _createProposal();
        test__acceptAdmin();

        vm.prank(bob);
        vm.expectRevert("GovernorAlpha::cancel: proposer above threshold");
        gov.cancel(PROPOSAL_ID);

        // Guardian can Cancel
        vm.prank(guardian);
        vm.expectEmit(false, false, false, true);
        emit ProposalCanceled(PROPOSAL_ID);
        gov.cancel(PROPOSAL_ID);
        assertEq(uint256(gov.state(PROPOSAL_ID)), uint256(GovernorAlpha.ProposalState.Canceled));
    }

    function test__cancel_RevertsWhenExecuted() public {
        // Can't cancel a proposal that has been executed
        test__execute();
        vm.prank(guardian);
        vm.expectRevert("GovernorAlpha::cancel: cannot cancel executed proposal");
        gov.cancel(PROPOSAL_ID);
    }

    function test__queue() public {
        //Accept Admin
        test__acceptAdmin();

        uint256 proposalId = _createProposal();
        vm.roll(block.timestamp + gov.votingPeriod());
        vm.prank(alice);
        gov.castVote(proposalId, true);

        vm.roll(block.number + gov.votingPeriod());
        vm.expectEmit(false, false, false, true);
        emit ProposalQueued(proposalId, block.timestamp + timelock.delay());
        gov.queue(proposalId);

        assertEq(uint256(gov.state(proposalId)), uint256(GovernorAlpha.ProposalState.Queued));
    }

    function test__execute() public {
        //Queue TX
        test__queue();

        skip(timelock.delay() * 2);
        vm.expectEmit(false, false, false, true);
        emit ProposalExecuted(PROPOSAL_ID);
        gov.execute(PROPOSAL_ID);
        assertEq(INITIAL_BALANCE + EXECUTE_TRANSFER_VALUE, pceToken.balanceOf(alice));
        assertEq(INITIAL_BALANCE - EXECUTE_TRANSFER_VALUE, pceToken.balanceOf(address(timelock)));
        assertEq(uint256(gov.state(PROPOSAL_ID)), uint256(GovernorAlpha.ProposalState.Executed));
    }

    function test__execute_WithInvalidState() public {
        //Accept Admin
        test__acceptAdmin();
        _createProposal();

        vm.roll(block.number + gov.votingPeriod());
        skip(timelock.delay() * 2);
        vm.expectRevert("GovernorAlpha::execute: proposal can only be executed if it is queued");
        gov.execute(PROPOSAL_ID);
    }

    function test__proposalState() public {
        _createProposal();

        // Should be Pending right after creation
        assertEq(uint256(gov.state(PROPOSAL_ID)), uint256(GovernorAlpha.ProposalState.Pending));

        // Move to Active state
        vm.roll(block.number + gov.votingDelay() + 1);
        assertEq(uint256(gov.state(PROPOSAL_ID)), uint256(GovernorAlpha.ProposalState.Active));

        // Cast some votes
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, true);

        // Move to end of voting period
        vm.roll(block.number + gov.votingPeriod());
        assertEq(uint256(gov.state(PROPOSAL_ID)), uint256(GovernorAlpha.ProposalState.Succeeded));
    }

    function test__doubleVotePrevention() public {
        _createProposal();

        vm.roll(block.timestamp + gov.votingPeriod());

        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, true);

        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::_castVote: voter already voted");
        gov.castVote(PROPOSAL_ID, true);
    }

    function test__votingPeriodBoundaries() public {
        _createProposal();

        // Too early to vote
        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::_castVote: voting is closed");
        gov.castVote(PROPOSAL_ID, true);

        // Move to just after voting delay
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, true); // Should succeed

        // Move past voting period
        vm.roll(block.number + gov.votingPeriod() + 1);
        vm.prank(bob);
        vm.expectRevert("GovernorAlpha::_castVote: voting is closed");
        gov.castVote(PROPOSAL_ID, true);
    }

    function test__queueInvalidStates() public {
        _createProposal();

        // Can't queue before voting period ends
        vm.expectRevert("GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        gov.queue(PROPOSAL_ID);

        // Move to voting period and defeat the proposal
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, false);

        vm.roll(block.number + gov.votingPeriod());
        vm.expectRevert("GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        gov.queue(PROPOSAL_ID);
    }

    function test__proposer() public {
        _createProposal();
        assertEq(gov.proposer(PROPOSAL_ID), guardian);
    }

    function test__updateVariables(uint256 quorumVotes_, uint256 proposalThreshold_, uint256 proposalMaxOperations_)
        public
    {
        quorumVotes_ = bound(quorumVotes_, 0, type(uint32).max);
        proposalThreshold_ = bound(proposalThreshold_, 0, type(uint32).max);
        proposalMaxOperations_ = bound(proposalMaxOperations_, 0, type(uint32).max);

        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::updateVariables: only guardian or timelock can update variables");
        gov.updateGovernanceParameters(quorumVotes_, proposalThreshold_, proposalMaxOperations_);

        vm.prank(guardian);
        gov.updateGovernanceParameters(quorumVotes_, proposalThreshold_, proposalMaxOperations_);
        assertEq(gov.quorumVotes(), quorumVotes_);
        assertEq(gov.proposalThreshold(), proposalThreshold_);
        assertEq(gov.proposalMaxOperations(), proposalMaxOperations_);

        vm.prank(address(timelock));
        gov.updateGovernanceParameters(quorumVotes_ + 1, proposalThreshold_ + 1, proposalMaxOperations_ + 1);
        assertEq(gov.quorumVotes(), quorumVotes_ + 1);
        assertEq(gov.proposalThreshold(), proposalThreshold_ + 1);
        assertEq(gov.proposalMaxOperations(), proposalMaxOperations_ + 1);
    }

    function test__queueSetTimelockPendingAdmin__RevertsWhen__NotGuardian() public {
        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::__queueSetTimelockPendingAdmin: sender must be gov guardian");
        gov.__queueSetTimelockPendingAdmin(alice, 0);
    }

    function test__executeSetTimelockPendingAdmin__RevertsWhen__NotGuardian() public {
        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::__executeSetTimelockPendingAdmin: sender must be gov guardian");
        gov.__executeSetTimelockPendingAdmin(alice, 0);
    }

    function test__getActions() public {
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory data,
            string memory description
        ) = _buildProposalParams();
        _createProposalWithParams(targets, values, signatures, data, description);

        (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _data) =
            gov.getActions(PROPOSAL_ID);
        assertEq(_targets[0], targets[0]);
        assertEq(_values[0], values[0]);
        assertEq(_signatures[0], signatures[0]);
        assertEq(_data[0], data[0]);
        assertEq(_targets.length, targets.length);
        assertEq(_values.length, values.length);
        assertEq(_signatures.length, signatures.length);
        assertEq(_data.length, data.length);
    }

    function test__batchQueue() public {
        //Accept Admin
        test__acceptAdmin();

        // Create proposal 1
        uint256 proposalIdOne = _createProposal();

        // Create proposal 2 with different data
        vm.startPrank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory data,
            string memory description
        ) = _buildProposalParams();
        data[0] = abi.encode(bob, EXECUTE_TRANSFER_VALUE);
        // Adding different data to avoid having duplicated proposal actions queued
        uint256 proposalIdTwo = _createProposalWithParams(targets, values, signatures, data, description);
        vm.stopPrank();

        // Proposals votes
        vm.roll(block.timestamp + gov.votingPeriod());
        vm.prank(alice);
        gov.castVote(proposalIdOne, true);

        vm.prank(guardian);
        gov.castVote(proposalIdTwo, true);

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = proposalIdOne;
        proposalIds[1] = proposalIdTwo;

        vm.roll(block.number + gov.votingPeriod());
        vm.expectEmit(false, false, false, true);
        emit ProposalQueued(proposalIdOne, block.timestamp + timelock.delay());

        vm.expectEmit(false, false, false, true);
        emit ProposalQueued(proposalIdTwo, block.timestamp + timelock.delay());
        gov.batchQueue(proposalIds);

        assertEq(uint256(gov.state(proposalIdOne)), uint256(GovernorAlpha.ProposalState.Queued));
        assertEq(uint256(gov.state(proposalIdTwo)), uint256(GovernorAlpha.ProposalState.Queued));
    }

    function test__batchQueue_WithInvalidStates() public {
        _createProposal();

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = PROPOSAL_ID;

        // Can't queue before voting period ends
        vm.expectRevert("GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        gov.batchQueue(proposalIds);

        // Move to voting period and defeat the proposal
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, false);

        vm.roll(block.number + gov.votingPeriod());
        vm.expectRevert("GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        gov.batchQueue(proposalIds);
    }

    function test__batchExecute() public {
        // Batch proposal 1 and 2
        // Proposal 1 transfers to Alice and propsal 2 to Bob
        test__batchQueue();
        skip(timelock.delay() * 2);

        uint256 proposalIdOne = 1;
        uint256 proposalIdTwo = 2;

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = proposalIdOne;
        proposalIds[1] = proposalIdTwo;

        vm.expectEmit(false, false, false, true);
        emit ProposalExecuted(proposalIdOne);

        vm.expectEmit(false, false, false, true);
        emit ProposalExecuted(proposalIdTwo);
        gov.batchExecute(proposalIds);

        assertEq(INITIAL_BALANCE + EXECUTE_TRANSFER_VALUE, pceToken.balanceOf(alice));
        assertEq(INITIAL_BALANCE + EXECUTE_TRANSFER_VALUE, pceToken.balanceOf(bob));
        assertEq(INITIAL_BALANCE - EXECUTE_TRANSFER_VALUE * 2, pceToken.balanceOf(address(timelock)));
        assertEq(uint256(gov.state(proposalIdOne)), uint256(GovernorAlpha.ProposalState.Executed));
        assertEq(uint256(gov.state(proposalIdTwo)), uint256(GovernorAlpha.ProposalState.Executed));
    }

    function test__batchExecute_WithInvalidState() public {
        _createProposal();

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = PROPOSAL_ID;

        vm.roll(block.number + gov.votingPeriod());
        skip(timelock.delay() * 2);
        vm.expectRevert("GovernorAlpha::execute: proposal can only be executed if it is queued");
        gov.batchExecute(proposalIds);
    }
}
