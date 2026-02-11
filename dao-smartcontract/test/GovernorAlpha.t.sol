// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockGovToken} from "../src/mocks/MockGovToken.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {PeaceCoinDaoSbt} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {PeaceCoinDaoNft} from "../src/Governance/PEACECOINDAO_NFT.sol";
import {IDAOFactory} from "../src/interfaces/IDAOFactory.sol";

contract GovernorAlphaTest is Test {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address guardian = address(this);

    string constant URI = "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/";
    IDAOFactory.SocialConfig public socialConfig =
        IDAOFactory.SocialConfig({
            description: "PEACECOIN DAO",
            website: "https://peacecoin.com",
            linkedin: "https://linkedin.com/peacecoin",
            twitter: "https://twitter.com/peacecoin",
            telegram: "https://t.me/peacecoin"
        });
    MockGovToken governanceToken;
    PeaceCoinDaoSbt sbt;
    PeaceCoinDaoNft nft;

    GovernorAlpha gov;
    Timelock timelock;

    uint256 constant INITIAL_BALANCE = 50000 ether;
    uint256 constant TIME_LOCK_DELAY = 10 minutes;
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 1000;
    uint256 constant PROPOSAL_THRESHOLD = 100 ether;
    uint256 constant QUORUM_VOTES = 1000 ether;
    uint256 constant PROPOSAL_MAX_OPERATIONS = 10;
    uint256 constant EXECUTE_TRANSFER_VALUE = 100;
    uint256 constant PROPOSAL_ID = 1;

    function setUp() public {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(guardian, "guardian");

        governanceToken = new MockGovToken();
        governanceToken.initialize();

        sbt = new PeaceCoinDaoSbt();
        nft = new PeaceCoinDaoNft();

        sbt.initialize(URI, address(this), address(this), true);
        nft.initialize(URI, address(this), address(this), false);

        timelock = new Timelock();
        timelock.initialize(alice, TIME_LOCK_DELAY);

        // Initialize GovernorAlpha with required parameters
        gov = new GovernorAlpha();
        gov.initialize(
            "PCE DAO",
            address(governanceToken),
            address(sbt),
            address(nft),
            address(timelock),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_VOTES,
            guardian,
            socialConfig
        );

        governanceToken.mint(guardian, INITIAL_BALANCE);
        governanceToken.mint(alice, INITIAL_BALANCE);
        governanceToken.mint(bob, INITIAL_BALANCE);
        governanceToken.mint(address(timelock), INITIAL_BALANCE);

        vm.prank(alice);
        governanceToken.delegate(alice);

        vm.prank(bob);
        governanceToken.delegate(alice);

        vm.prank(guardian);
        governanceToken.delegate(guardian);
    }

    // ============ Helper Methods ============

    /**
     * @notice Builds proposal parameters for testing
     * @return targets Array of target addresses
     * @return values Array of values to send with each call
     * @return signatures Array of function signatures
     * @return data Array of calldata
     * @return description Proposal description
     */
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
        targets[0] = address(governanceToken);

        values = new uint256[](1);
        values[0] = 0;

        signatures = new string[](1);
        signatures[0] = "transfer(address,uint256)";

        data = new bytes[](1);
        data[0] = abi.encode(alice, EXECUTE_TRANSFER_VALUE);

        description = "Transfer PCE";
    }

    /**
     * @notice Creates a proposal using default parameters
     * @return proposalId The ID of the created proposal
     */
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

    /**
     * @notice Creates a proposal with custom parameters
     * @param targets Array of target addresses
     * @param values Array of values to send with each call
     * @param signatures Array of function signatures
     * @param data Array of calldata
     * @param description Proposal description
     * @return proposalId The ID of the created proposal
     */
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

    /**
     * @notice Tests that quorum votes returns the expected constant value
     */
    function test_quorumVotes() public view {
        assertEq(gov.quorumVotes(), QUORUM_VOTES);
    }

    /**
     * @notice Tests that proposal threshold returns the expected constant value
     */
    function test_proposalThreshold() public view {
        assertEq(gov.proposalThreshold(), PROPOSAL_THRESHOLD);
    }

    /**
     * @notice Tests that proposal max operations returns the expected constant value
     */
    function test_proposalMaxOperations() public view {
        assertEq(gov.proposalMaxOperations(), PROPOSAL_MAX_OPERATIONS);
    }

    /**
     * @notice Tests that voting delay returns the expected constant value
     */
    function test_votingDelay() public view {
        assertEq(gov.votingDelay(), VOTING_DELAY);
    }

    /**
     * @notice Tests that voting period returns the expected constant value
     */
    function test_votingPeriod() public view {
        assertEq(gov.votingPeriod(), VOTING_PERIOD);
    }

    /**
     * @notice Tests that proposal count is zero initially
     */
    function test_proposalCount() public view {
        assertEq(gov.proposalCount(), 0);
    }

    /**
     * @notice Tests that guardian address is set correctly
     */
    function test_guardian() public view {
        assertEq(gov.guardian(), guardian);
    }

    /**
     * @notice Tests proposal creation with various validation scenarios
     * @dev Verifies proposal threshold, arity mismatch, empty actions, max operations, and duplicate proposal prevention
     */
    function test_propose() public {
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory data,
            string memory description
        ) = _buildProposalParams();

        vm.expectRevert("Governor::propose: proposer votes below proposal threshold");
        gov.propose(targets, values, signatures, data, description);

        vm.roll(block.number + 10);

        // Create invalid data array with mismatched length
        bytes[] memory invalidData = new bytes[](2);
        invalidData[0] = new bytes(1);
        invalidData[1] = new bytes(2);

        vm.expectRevert("Governor::propose: proposal function information arity mismatch");
        gov.propose(targets, values, signatures, invalidData, description);

        vm.expectRevert("Governor::propose: must provide actions");
        gov.propose(
            new address[](0),
            new uint256[](0),
            new string[](0),
            new bytes[](0),
            description
        );

        vm.expectRevert("Governor::propose: too many actions");
        gov.propose(
            new address[](11),
            new uint256[](11),
            new string[](11),
            new bytes[](11),
            description
        );

        // Create proposal successfully
        gov.propose(targets, values, signatures, data, description);

        assertEq(gov.proposalCount(), 1);
        assertEq(gov.latestProposalIds(guardian), PROPOSAL_ID);

        // Cannot create a new proposal if proposer has an active or pending proposal
        vm.expectRevert(
            "Governor::propose: one live proposal per proposer, found an already pending proposal"
        );

        gov.propose(targets, values, signatures, data, description);
    }

    /**
     * @notice Tests that proposing fails when user has an active proposal
     */
    function test_propose_RevertsWhenUserHasActiveProposal() public {
        _createProposal();
        (
            address[] memory _targets,
            uint256[] memory _values,
            string[] memory _signatures,
            bytes[] memory _data
        ) = gov.getActions(PROPOSAL_ID);
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.expectRevert(
            "Governor::propose: one live proposal per proposer, found an already active proposal"
        );
        gov.propose(_targets, _values, _signatures, _data, "Transfer PCE");
    }

    /**
     * @notice Tests casting votes on a proposal
     * @dev Verifies that votes can be cast by different voters during the voting period
     */
    function test_castVote() public {
        _createProposal();

        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, true);

        vm.prank(guardian);
        gov.castVote(PROPOSAL_ID, true);
    }

    /**
     * @notice Tests retrieving vote receipt for a voter
     * @dev Verifies receipt contains correct voting status, support, and vote count
     */
    function test_getReceipt() public {
        _createProposal();

        uint256 aliceVotes = governanceToken.getPastVotes(alice, block.number - 1);
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, true);

        GovernorAlpha.Receipt memory receipt = gov.getReceipt(PROPOSAL_ID, alice);
        assertEq(receipt.hasVoted, true);
        assertEq(receipt.support, true);
        assertEq(receipt.votes, aliceVotes);
    }

    /**
     * @notice Tests accepting admin role from timelock
     * @dev Verifies only guardian can accept admin role
     */
    function test_acceptAdmin() public {
        vm.prank(alice);
        timelock.setPendingAdmin(address(gov));

        vm.prank(alice);
        vm.expectRevert("Governor::acceptAdmin: sender must be gov guardian");
        gov.acceptAdmin();

        vm.prank(guardian);
        gov.acceptAdmin();
        assertEq(timelock.admin(), address(gov));
    }

    /**
     * @notice Tests guardian abdication functionality
     * @dev Verifies only guardian can abdicate and guardian is set to zero address
     */
    function test_abdicate() public {
        vm.prank(alice);
        vm.expectRevert("Governor::abdicate: sender must be gov guardian");
        gov.abdicate();

        vm.prank(guardian);
        gov.abdicate();
        assertEq(gov.guardian(), address(0));
    }

    /**
     * @notice Tests proposal cancellation functionality
     * @dev Verifies guardian can cancel proposals and non-guardian cannot cancel when proposer is above threshold
     */
    function test_cancel() public {
        _createProposal();
        test_acceptAdmin();

        // Non-guardian cannot cancel proposal when proposer is above threshold
        vm.prank(bob);
        vm.expectRevert("Governor::cancel: proposer above threshold");
        gov.cancel(PROPOSAL_ID);

        // Guardian can cancel the proposal
        vm.prank(guardian);
        gov.cancel(PROPOSAL_ID);
        assertEq(uint256(gov.state(PROPOSAL_ID)), uint256(GovernorAlpha.ProposalState.Canceled));
    }

    /**
     * @notice Tests that canceling an executed proposal reverts
     */
    function test_cancel_RevertsWhenExecuted() public {
        test_execute();
        vm.prank(guardian);
        vm.expectRevert("Governor::cancel: cannot cancel executed proposal");
        gov.cancel(PROPOSAL_ID);
    }

    /**
     * @notice Tests queueing a successful proposal
     * @dev Verifies proposal transitions to Queued state after voting period ends
     */
    function test_queue() public {
        test_acceptAdmin();

        uint256 proposalId = _createProposal();
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(proposalId, true);

        vm.roll(block.number + gov.votingPeriod());
        gov.queue(proposalId);

        assertEq(uint256(gov.state(proposalId)), uint256(GovernorAlpha.ProposalState.Queued));
    }

    /**
     * @notice Tests executing a queued proposal
     * @dev Verifies proposal execution updates token balances and proposal state
     */
    function test_execute() public {
        test_queue();

        skip(timelock.delay() * 2);
        gov.execute(PROPOSAL_ID);
        assertEq(INITIAL_BALANCE + EXECUTE_TRANSFER_VALUE, governanceToken.balanceOf(alice));
        assertEq(
            INITIAL_BALANCE - EXECUTE_TRANSFER_VALUE,
            governanceToken.balanceOf(address(timelock))
        );
        assertEq(uint256(gov.state(PROPOSAL_ID)), uint256(GovernorAlpha.ProposalState.Executed));
    }

    /**
     * @notice Tests that executing a proposal in invalid state reverts
     */
    function test_execute_RevertsWithInvalidState() public {
        test_acceptAdmin();
        _createProposal();

        vm.roll(block.number + gov.votingPeriod());
        skip(timelock.delay() * 2);
        vm.expectRevert("Governor::execute: proposal can only be executed if it is queued");
        gov.execute(PROPOSAL_ID);
    }

    /**
     * @notice Tests proposal state transitions
     * @dev Verifies proposal moves through Pending -> Active -> Succeeded states correctly
     */
    function test_proposalState() public {
        _createProposal();

        // Proposal should be in Pending state immediately after creation
        assertEq(uint256(gov.state(PROPOSAL_ID)), uint256(GovernorAlpha.ProposalState.Pending));

        // Move past voting delay to transition to Active state
        vm.roll(block.number + gov.votingDelay() + 1);
        assertEq(uint256(gov.state(PROPOSAL_ID)), uint256(GovernorAlpha.ProposalState.Active));

        // Cast votes during active period
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, true);

        // Move to end of voting period to transition to Succeeded state
        vm.roll(block.number + gov.votingPeriod());
        assertEq(uint256(gov.state(PROPOSAL_ID)), uint256(GovernorAlpha.ProposalState.Succeeded));
    }

    /**
     * @notice Tests that double voting is prevented
     * @dev Verifies a voter cannot cast multiple votes on the same proposal
     */
    function test_doubleVotePrevention() public {
        _createProposal();

        vm.roll(block.number + gov.votingDelay() + 1);

        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, true);

        vm.prank(alice);
        vm.expectRevert("Governor::_castVote: voter already voted");
        gov.castVote(PROPOSAL_ID, true);
    }

    /**
     * @notice Tests voting period boundaries
     * @dev Verifies voting is only allowed during the active voting period
     */
    function test_votingPeriodBoundaries() public {
        _createProposal();

        // Attempt to vote before voting delay has passed
        vm.prank(alice);
        vm.expectRevert("Governor::_castVote: voting is closed");
        gov.castVote(PROPOSAL_ID, true);

        // Move to just after voting delay - voting should now be open
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, true);

        // Move past voting period - voting should now be closed
        vm.roll(block.number + gov.votingPeriod() + 1);
        vm.prank(bob);
        vm.expectRevert("Governor::_castVote: voting is closed");
        gov.castVote(PROPOSAL_ID, true);
    }

    /**
     * @notice Tests that queueing proposals in invalid states reverts
     * @dev Verifies proposals can only be queued when in Succeeded state
     */
    function test_queue_RevertsWithInvalidStates() public {
        _createProposal();

        // Cannot queue proposal before voting period ends
        vm.expectRevert("Governor::queue: proposal can only be queued if it is succeeded");
        gov.queue(PROPOSAL_ID);

        // Move to voting period and vote against the proposal to defeat it
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, false);

        // Cannot queue a defeated proposal
        vm.roll(block.number + gov.votingPeriod());
        vm.expectRevert("Governor::queue: proposal can only be queued if it is succeeded");
        gov.queue(PROPOSAL_ID);
    }

    /**
     * @notice Tests retrieving the proposer address for a proposal
     */
    function test_proposer() public {
        _createProposal();
        assertEq(gov.proposer(PROPOSAL_ID), guardian);
    }

    /**
     * @notice Tests updating governance parameters
     * @dev Verifies only guardian or timelock can update parameters, and updates are applied correctly
     * @param newQuorumVotes New quorum votes value
     * @param newProposalThreshold New proposal threshold value
     * @param newProposalMaxOperations New proposal max operations value
     */
    function test_updateVariables(
        uint256 newQuorumVotes,
        uint256 newProposalThreshold,
        uint256 newProposalMaxOperations
    ) public {
        newQuorumVotes = bound(newQuorumVotes, 0, type(uint32).max);
        newProposalThreshold = bound(newProposalThreshold, 0, type(uint32).max);
        newProposalMaxOperations = bound(newProposalMaxOperations, 0, type(uint32).max);

        vm.prank(alice);
        vm.expectRevert(
            "Governor::updateVariables: only guardian or timelock can update variables"
        );
        gov.updateGovernanceParameters(
            newQuorumVotes,
            newProposalThreshold,
            newProposalMaxOperations
        );

        vm.prank(guardian);
        gov.updateGovernanceParameters(
            newQuorumVotes,
            newProposalThreshold,
            newProposalMaxOperations
        );
        assertEq(gov.quorumVotes(), newQuorumVotes);
        assertEq(gov.proposalThreshold(), newProposalThreshold);
        assertEq(gov.proposalMaxOperations(), newProposalMaxOperations);

        vm.prank(address(timelock));
        gov.updateGovernanceParameters(
            newQuorumVotes + 1,
            newProposalThreshold + 1,
            newProposalMaxOperations + 1
        );
        assertEq(gov.quorumVotes(), newQuorumVotes + 1);
        assertEq(gov.proposalThreshold(), newProposalThreshold + 1);
        assertEq(gov.proposalMaxOperations(), newProposalMaxOperations + 1);
    }

    /**
     * @notice Tests that queueing timelock pending admin reverts when caller is not guardian
     */
    function test_queueSetTimelockPendingAdmin_RevertsWhenNotGuardian() public {
        vm.prank(alice);
        vm.expectRevert(
            "Governor::queueSetTimelockPendingAdmin: sender must be gov guardian"
        );
        gov.queueSetTimelockPendingAdmin(alice, 0);
    }

    /**
     * @notice Tests that executing timelock pending admin reverts when caller is not guardian
     */
    function test_executeSetTimelockPendingAdmin_RevertsWhenNotGuardian() public {
        vm.prank(alice);
        vm.expectRevert(
            "Governor::executeSetTimelockPendingAdmin: sender must be gov guardian"
        );
        gov.executeSetTimelockPendingAdmin(alice, 0);
    }

    /**
     * @notice Tests retrieving proposal actions
     * @dev Verifies all proposal action components are returned correctly
     */
    function test_getActions() public {
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory data,
            string memory description
        ) = _buildProposalParams();
        _createProposalWithParams(targets, values, signatures, data, description);

        (
            address[] memory _targets,
            uint256[] memory _values,
            string[] memory _signatures,
            bytes[] memory _data
        ) = gov.getActions(PROPOSAL_ID);
        assertEq(_targets[0], targets[0]);
        assertEq(_values[0], values[0]);
        assertEq(_signatures[0], signatures[0]);
        assertEq(_data[0], data[0]);
        assertEq(_targets.length, targets.length);
        assertEq(_values.length, values.length);
        assertEq(_signatures.length, signatures.length);
        assertEq(_data.length, data.length);
    }

    /**
     * @notice Tests batch queueing multiple proposals
     * @dev Verifies multiple proposals can be queued simultaneously
     */
    function test_batchQueue() public {
        test_acceptAdmin();

        // Create first proposal
        uint256 proposalIdOne = _createProposal();

        // Create second proposal with different data to avoid duplicate proposal actions
        vm.startPrank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory data,
            string memory description
        ) = _buildProposalParams();
        data[0] = abi.encode(bob, EXECUTE_TRANSFER_VALUE);
        uint256 proposalIdTwo = _createProposalWithParams(
            targets,
            values,
            signatures,
            data,
            description
        );
        vm.stopPrank();

        // Cast votes on both proposals
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(proposalIdOne, true);

        vm.prank(guardian);
        gov.castVote(proposalIdTwo, true);

        // Prepare proposal IDs array for batch queue
        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = proposalIdOne;
        proposalIds[1] = proposalIdTwo;

        vm.roll(block.number + gov.votingPeriod());

        // Batch queue both proposals
        gov.batchQueue(proposalIds);

        assertEq(uint256(gov.state(proposalIdOne)), uint256(GovernorAlpha.ProposalState.Queued));
        assertEq(uint256(gov.state(proposalIdTwo)), uint256(GovernorAlpha.ProposalState.Queued));
    }

    /**
     * @notice Tests that batch queueing proposals in invalid states reverts
     */
    function test_batchQueue_RevertsWithInvalidStates() public {
        _createProposal();

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = PROPOSAL_ID;

        // Cannot batch queue before voting period ends
        vm.expectRevert("Governor::queue: proposal can only be queued if it is succeeded");
        gov.batchQueue(proposalIds);

        // Move to voting period and vote against the proposal to defeat it
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(PROPOSAL_ID, false);

        // Cannot batch queue a defeated proposal
        vm.roll(block.number + gov.votingPeriod());
        vm.expectRevert("Governor::queue: proposal can only be queued if it is succeeded");
        gov.batchQueue(proposalIds);
    }

    /**
     * @notice Tests batch executing multiple queued proposals
     * @dev Verifies multiple proposals can be executed simultaneously and token balances are updated correctly
     */
    function test_batchExecute() public {
        test_batchQueue();
        skip(timelock.delay() * 2);

        uint256 proposalIdOne = 1;
        uint256 proposalIdTwo = 2;

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = proposalIdOne;
        proposalIds[1] = proposalIdTwo;

        gov.batchExecute(proposalIds);

        assertEq(INITIAL_BALANCE + EXECUTE_TRANSFER_VALUE, governanceToken.balanceOf(alice));
        assertEq(INITIAL_BALANCE + EXECUTE_TRANSFER_VALUE, governanceToken.balanceOf(bob));
        assertEq(
            INITIAL_BALANCE - EXECUTE_TRANSFER_VALUE * 2,
            governanceToken.balanceOf(address(timelock))
        );
        assertEq(uint256(gov.state(proposalIdOne)), uint256(GovernorAlpha.ProposalState.Executed));
        assertEq(uint256(gov.state(proposalIdTwo)), uint256(GovernorAlpha.ProposalState.Executed));
    }

    /**
     * @notice Tests that batch executing proposals in invalid state reverts
     */
    function test_batchExecute_RevertsWithInvalidState() public {
        _createProposal();

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = PROPOSAL_ID;

        vm.roll(block.number + gov.votingPeriod());
        skip(timelock.delay() * 2);
        vm.expectRevert("Governor::execute: proposal can only be executed if it is queued");
        gov.batchExecute(proposalIds);
    }
}
