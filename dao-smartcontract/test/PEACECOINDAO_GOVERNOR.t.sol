// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PEACECOINDAO_SBT} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {PEACECOINDAO_NFT} from "../src/Governance/PEACECOINDAO_NFT.sol";
import {PEACECOINDAO_GOVERNOR} from "../src/Governance/PEACECOINDAO_GOVERNOR.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {MockGovToken} from "../src/mocks/MockGovToken.sol";
import {IDAOFactory} from "../src/interfaces/IDAOFactory.sol";
import {DAOFactory} from "../src/DAOFactory.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {PCECommunityGovToken} from "../src/mocks/PCECommunityGovToken.sol";

/// @title PEACECOINDAO_GOVERNORTEST
/// @notice Comprehensive test suite for PEACECOINDAO_GOVERNOR contract
/// @dev Tests all governance functionality including proposals, voting, queuing, and execution
contract PEACECOINDAO_GOVERNORTEST is Test {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address guardian = makeAddr("guardian");

    MockGovToken govToken;
    PEACECOINDAO_SBT sbt;
    PEACECOINDAO_NFT nft;
    PEACECOINDAO_GOVERNOR gov;
    Timelock timelock;
    uint256 constant INITIAL_BALANCE = 50000e18;
    uint256 constant TIME_LOCK_DELAY = 10 minutes;
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 1000;
    uint256 constant PROPOSAL_THRESHOLD = 5;
    uint256 constant QUORUM_VOTES = 1000;
    uint256 constant PROPOSAL_MAX_OPERATIONS = 10;
    uint256 constant EXECUTE_TRANSFER_VALUE = 1;
    uint256 constant PROPOSAL_ID = 1;
    string public TOKEN_URI = "test-uri";
    uint256 public VOTING_POWER = 100;
    string public DAO_NAME = "Test DAO";
    bytes32 public daoId;

    string constant URI = "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/";
    IDAOFactory.SocialConfig public SOCIAL_CONFIG =
        IDAOFactory.SocialConfig({
            description: "PEACECOIN DAO",
            website: "https://peacecoin.com",
            linkedin: "https://linkedin.com/peacecoin",
            twitter: "https://twitter.com/peacecoin",
            telegram: "https://t.me/peacecoin"
        });

    /// @notice Sets up the test environment with all necessary contracts and configurations
    /// @dev Initializes governance token, SBT, NFT, timelock, and governor contracts
    function setUp() public {
        // Label addresses for better test trace readability
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(guardian, "guardian");

        // Initialize governance token
        govToken = new MockGovToken();
        govToken.initialize();

        // Initialize timelock contract
        timelock = new Timelock();
        timelock.initialize(alice, TIME_LOCK_DELAY);

        // Prepare implementation addresses for DAO factory
        address timelockAddress = address(timelock);
        address governorAddress = address(new GovernorAlpha());
        address governanceTokenAddress = address(new PCECommunityGovToken());

        // Initialize SBT and NFT contracts
        sbt = new PEACECOINDAO_SBT();
        nft = new PEACECOINDAO_NFT();

        // Deploy and configure DAO factory
        DAOFactory daoFactory = new DAOFactory(address(sbt), address(nft));
        daoFactory.setImplementation(timelockAddress, governorAddress, governanceTokenAddress);

        sbt.initialize("PEACECOIN DAO SBT", "PCE_SBT", URI, address(daoFactory));
        nft.initialize("PEACECOIN DAO NFT", "PCE_NFT", URI, address(daoFactory));

        // Re-initialize timelock for governor usage
        timelock = new Timelock();
        timelock.initialize(alice, TIME_LOCK_DELAY);

        // Deploy and initialize governor contract
        gov = new PEACECOINDAO_GOVERNOR();
        gov.initialize(
            "PEACECOIN DAO",
            address(govToken),
            address(sbt),
            address(nft),
            address(timelock),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_VOTES,
            guardian,
            SOCIAL_CONFIG
        );

        // Create DAO through factory
        daoId = daoFactory.createDAO(
            DAO_NAME,
            SOCIAL_CONFIG,
            address(govToken),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            TIME_LOCK_DELAY,
            QUORUM_VOTES
        );

        // Configure SBT permissions and create token
        sbt.setMinter(address(this));
        IAccessControl(daoFactory).grantRole(keccak256("DAO_MANAGER_ROLE"), address(this));
        sbt.createToken(TOKEN_URI, VOTING_POWER, daoId);
        vm.roll(block.number + 1);

        // Mint SBTs to test accounts
        sbt.mint(guardian, 1, 1);
        sbt.mint(alice, 1, 1);
        sbt.mint(bob, 1, 1);

        // Delegate SBT voting power
        vm.prank(alice);
        sbt.delegate(alice);

        vm.prank(bob);
        sbt.delegate(alice);

        vm.prank(guardian);
        sbt.delegate(guardian);

        // Mint governance tokens and delegate
        vm.prank(alice);
        govToken.mint(alice, INITIAL_BALANCE);

        govToken.mint(timelockAddress, INITIAL_BALANCE);
        govToken.mint(address(timelock), INITIAL_BALANCE);

        vm.prank(alice);
        govToken.delegate(alice);

        // Advance block number to ensure proper state
        vm.roll(block.number + 10);
    }

    // ============================================================================
    // Helper Functions
    // ============================================================================

    /// @notice Builds standard proposal parameters for testing
    /// @return targets Array of target addresses for proposal actions
    /// @return values Array of ETH values to send with each action
    /// @return signatures Array of function signatures to call
    /// @return data Array of calldata for each action
    /// @return description Human-readable description of the proposal
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
        targets[0] = address(govToken);

        values = new uint256[](1);
        values[0] = 0;

        signatures = new string[](1);
        signatures[0] = "transfer(address,uint256)";

        data = new bytes[](1);
        data[0] = abi.encode(alice, EXECUTE_TRANSFER_VALUE);

        description = "Transfer PCE";
    }

    /// @notice Creates a proposal using standard parameters
    /// @return proposalId The ID of the newly created proposal
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

    /// @notice Creates a proposal with custom parameters
    /// @param targets Array of target addresses for proposal actions
    /// @param values Array of ETH values to send with each action
    /// @param signatures Array of function signatures to call
    /// @param data Array of calldata for each action
    /// @param description Human-readable description of the proposal
    /// @return proposalId The ID of the newly created proposal
    function _createProposalWithParams(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory data,
        string memory description
    ) private returns (uint256 proposalId) {
        vm.prank(alice);
        proposalId = gov.propose(targets, values, signatures, data, description);
    }

    // ============================================================================
    // Configuration Tests
    // ============================================================================

    /// @notice Tests that quorum votes is correctly initialized
    function test__quorumVotes() public view {
        assertEq(gov.quorumVotes(), QUORUM_VOTES);
    }

    /// @notice Tests that proposal threshold is correctly initialized
    function test__proposalThreshold() public view {
        assertEq(gov.proposalThreshold(), PROPOSAL_THRESHOLD);
    }

    /// @notice Tests that proposal max operations is correctly initialized
    function test__proposalMaxOperations() public view {
        assertEq(gov.proposalMaxOperations(), PROPOSAL_MAX_OPERATIONS);
    }

    /// @notice Tests that voting delay is correctly initialized
    function test__votingDelay() public view {
        assertEq(gov.votingDelay(), VOTING_DELAY);
    }

    /// @notice Tests that voting period is correctly initialized
    function test__votingPeriod() public view {
        assertEq(gov.votingPeriod(), VOTING_PERIOD);
    }

    /// @notice Tests that proposal count starts at zero
    function test__proposalCount() public view {
        assertEq(gov.proposalCount(), 0);
    }

    /// @notice Tests that guardian address is correctly set
    function test__guardian() public view {
        assertEq(gov.guardian(), guardian);
    }

    // ============================================================================
    // Proposal Creation Tests
    // ============================================================================

    /// @notice Tests proposal creation with various validation scenarios
    /// @dev Verifies proposal threshold, parameter validation, and duplicate proposal prevention
    function test__propose() public {
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory data,
            string memory description
        ) = _buildProposalParams();

        // Test: Proposal should revert if proposer doesn't meet threshold
        vm.expectRevert("Governor::propose: proposer votes below proposal threshold");
        gov.propose(targets, values, signatures, data, description);

        // Setup: Delegate SBT and mint tokens to meet threshold
        sbt.delegate(address(this));
        govToken.mint(address(this), 10 ether);
        govToken.delegate(address(this));
        vm.roll(block.number + 10);

        // Test: Proposal should revert with mismatched array lengths
        bytes[] memory invalidData = new bytes[](2);
        invalidData[0] = new bytes(1);
        invalidData[1] = new bytes(2);

        vm.expectRevert("Governor::propose: proposal function information arity mismatch");
        gov.propose(targets, values, signatures, invalidData, description);

        // Test: Proposal should revert with empty actions array
        vm.expectRevert("Governor::propose: must provide actions");
        gov.propose(
            new address[](0),
            new uint256[](0),
            new string[](0),
            new bytes[](0),
            description
        );

        // Test: Proposal should revert when exceeding max operations limit
        vm.expectRevert("Governor::propose: too many actions");
        gov.propose(
            new address[](11),
            new uint256[](11),
            new string[](11),
            new bytes[](11),
            description
        );

        // Test: Successful proposal creation
        vm.prank(alice);
        gov.propose(targets, values, signatures, data, description);

        assertEq(gov.proposalCount(), 1, "Proposal count should be 1");
        assertEq(
            gov.latestProposalIds(address(alice)),
            1,
            "Alice's latest proposal ID should be 1"
        );

        // Test: Cannot create new proposal if user has active/pending proposal
        vm.prank(alice);
        vm.expectRevert(
            "Governor::propose: one live proposal per proposer, found an already pending proposal"
        );
        gov.propose(targets, values, signatures, data, description);
    }

    // ============================================================================
    // Guardian Functions Tests
    // ============================================================================

    /// @notice Tests that only guardian can accept admin role from timelock
    function test__acceptAdmin() public {
        // Setup: Set governor as pending admin in timelock
        vm.prank(alice);
        timelock.setPendingAdmin(address(gov));

        // Test: Non-guardian cannot accept admin
        vm.prank(alice);
        vm.expectRevert("Governor::__acceptAdmin: sender must be gov guardian");
        gov.__acceptAdmin();

        // Test: Guardian can accept admin
        vm.prank(guardian);
        gov.__acceptAdmin();
        assertEq(timelock.admin(), address(gov), "Timelock admin should be governor");
    }

    /// @notice Tests that only guardian can abdicate (renounce) guardian role
    function test__abdicate() public {
        // Test: Non-guardian cannot abdicate
        vm.prank(alice);
        vm.expectRevert("Governor::__abdicate: sender must be gov guardian");
        gov.__abdicate();

        // Test: Guardian can abdicate
        vm.prank(guardian);
        gov.__abdicate();
        assertEq(gov.guardian(), address(0), "Guardian should be zero address after abdication");
    }

    /// @notice Tests proposal cancellation functionality
    function test__cancel() public {
        // Setup: Create proposal and accept admin
        test__propose();
        test__acceptAdmin();

        // Test: Non-proposer above threshold cannot cancel
        vm.prank(bob);
        vm.expectRevert("Governor::cancel: proposer above threshold");
        gov.cancel(PROPOSAL_ID);

        // Test: Guardian can cancel proposal
        vm.prank(guardian);
        gov.cancel(PROPOSAL_ID);
        assertEq(
            uint256(gov.state(PROPOSAL_ID)),
            uint256(PEACECOINDAO_GOVERNOR.ProposalState.Canceled),
            "Proposal state should be Canceled"
        );
    }

    // ============================================================================
    // Voting Tests
    // ============================================================================

    /// @notice Tests vote casting functionality and validation
    function test__castVote() public {
        uint256 proposalId = _createProposal();

        // Move to voting period
        vm.roll(block.number + VOTING_DELAY + 1);

        // Verify proposal is in Active state
        assertEq(
            uint256(gov.state(proposalId)),
            uint256(PEACECOINDAO_GOVERNOR.ProposalState.Active),
            "Proposal should be in Active state"
        );

        // Test: Successful vote in favor
        vm.prank(alice);
        gov.castVote(proposalId, true);

        // Verify receipt
        PEACECOINDAO_GOVERNOR.Receipt memory receipt = gov.getReceipt(proposalId, alice);
        assertTrue(receipt.hasVoted, "Receipt should show vote was cast");
        assertTrue(receipt.support, "Receipt should show support is true");
        assertGt(receipt.votes, 0, "Receipt should show votes were cast");

        // Test: Cannot vote twice
        vm.prank(alice);
        vm.expectRevert("Governor::_castVote: voter already voted");
        gov.castVote(proposalId, false);

        // Test: Vote against (with different voter)
        vm.prank(bob);
        gov.castVote(proposalId, false);

        // Verify receipt
        receipt = gov.getReceipt(proposalId, bob);
        assertTrue(receipt.hasVoted, "Receipt should show vote was cast");
        assertFalse(receipt.support, "Receipt should show support is false");
    }

    /// @notice Tests proposal state transitions through the entire lifecycle
    function test__stateTransitions() public {
        uint256 proposalId = _createProposal();

        // Test: Initial state should be Pending
        assertEq(
            uint256(gov.state(proposalId)),
            uint256(PEACECOINDAO_GOVERNOR.ProposalState.Pending),
            "Proposal should start in Pending state"
        );

        // Move to Active state after voting delay
        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(
            uint256(gov.state(proposalId)),
            uint256(PEACECOINDAO_GOVERNOR.ProposalState.Active),
            "Proposal should be Active after voting delay"
        );

        // Get the proposal's start block
        uint256 startBlock = block.number - 1;

        // Calculate voting power at the proposal's start block
        uint96 aliceVotes = gov.getPastVotes(alice, startBlock);
        uint96 bobVotes = gov.getPastVotes(bob, startBlock);
        uint96 guardianVotes = gov.getPastVotes(guardian, startBlock);

        // Ensure quorum can be met by minting additional tokens if needed
        if (aliceVotes + bobVotes + guardianVotes < QUORUM_VOTES) {
            govToken.mint(alice, QUORUM_VOTES * 1e18);
            vm.prank(alice);
            govToken.delegate(alice);
            vm.roll(block.number + 1);
            // Recalculate after minting
            startBlock = block.number + VOTING_DELAY;
            aliceVotes = gov.getPastVotes(alice, startBlock);
        }

        // Cast vote in favor
        vm.prank(alice);
        gov.castVote(proposalId, true);

        // Move past voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Verify final state based on quorum
        // The state function checks: forVotes > againstVotes && forVotes >= quorumVotes
        PEACECOINDAO_GOVERNOR.ProposalState currentState = gov.state(proposalId);

        // Since alice voted in favor and we ensured quorum can be met, check the state
        if (aliceVotes >= QUORUM_VOTES) {
            assertEq(
                uint256(currentState),
                uint256(PEACECOINDAO_GOVERNOR.ProposalState.Succeeded),
                "Proposal should be Succeeded if quorum is met"
            );
        } else {
            assertEq(
                uint256(currentState),
                uint256(PEACECOINDAO_GOVERNOR.ProposalState.Defeated),
                "Proposal should be Defeated if quorum is not met"
            );
        }
    }

    // ============================================================================
    // Proposal Execution Tests
    // ============================================================================

    /// @notice Tests the complete proposal lifecycle: queue and execute
    function test__queueAndExecute() public {
        // Setup: Accept admin role for timelock
        test__acceptAdmin();
        uint256 proposalId = _createProposal();

        // Move to voting period and cast vote
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        gov.castVote(proposalId, true);

        // Move past voting period to allow queuing
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Queue proposal in timelock
        gov.queue(proposalId);

        assertEq(
            uint256(gov.state(proposalId)),
            uint256(PEACECOINDAO_GOVERNOR.ProposalState.Queued),
            "Proposal should be in Queued state"
        );

        // Move past timelock delay to allow execution
        vm.warp(block.timestamp + TIME_LOCK_DELAY + 1);

        // Execute proposal
        gov.execute(proposalId);

        assertEq(
            uint256(gov.state(proposalId)),
            uint256(PEACECOINDAO_GOVERNOR.ProposalState.Executed),
            "Proposal should be in Executed state"
        );
    }

    /// @notice Tests batch queueing and execution of multiple proposals
    function test__batchQueueAndExecute() public {
        // Setup: Accept admin role for timelock
        test__acceptAdmin();

        // Create first proposal
        uint256 proposalId1 = _createProposal();

        // Move to voting period and vote for proposal 1
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        gov.castVote(proposalId1, true);

        // Move past voting period for proposal 1
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Prepare parameters for second proposal with different recipient
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory data,
            string memory description
        ) = _buildProposalParams();

        data[0] = abi.encode(bob, EXECUTE_TRANSFER_VALUE);

        // Create second proposal with different parameters
        uint256 proposalId2 = _createProposalWithParams(
            targets,
            values,
            signatures,
            data,
            description
        );

        // Move to voting period and vote for proposal 2
        vm.roll(block.number + VOTING_DELAY + 2);

        vm.prank(alice);
        gov.castVote(proposalId2, true);

        // Move past voting period for proposal 2
        vm.roll(block.number + VOTING_PERIOD + 2);

        // Batch queue both proposals
        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = proposalId1;
        proposalIds[1] = proposalId2;

        gov.batchQueue(proposalIds);

        // Move past timelock delay to allow execution
        vm.warp(block.timestamp + TIME_LOCK_DELAY + 1);

        // Batch execute both proposals
        gov.batchExecute(proposalIds);

        // Verify both proposals are executed
        assertEq(
            uint256(gov.state(proposalId1)),
            uint256(PEACECOINDAO_GOVERNOR.ProposalState.Executed),
            "Proposal 1 should be Executed"
        );
        assertEq(
            uint256(gov.state(proposalId2)),
            uint256(PEACECOINDAO_GOVERNOR.ProposalState.Executed),
            "Proposal 2 should be Executed"
        );
    }

    // ============================================================================
    // Governance Parameter Update Tests
    // ============================================================================

    /// @notice Tests updating governance parameters (quorum, threshold, max operations)
    function test__updateGovernanceParameters() public {
        uint256 newQuorum = 2000;
        uint256 newThreshold = 10;
        uint256 newMaxOps = 15;

        // Test: Unauthorized user cannot update parameters
        vm.prank(alice);
        vm.expectRevert(
            "Governor::updateVariables: only guardian or timelock can update variables"
        );
        gov.updateGovernanceParameters(newQuorum, newThreshold, newMaxOps);

        // Test: Guardian can update parameters
        vm.prank(guardian);
        gov.updateGovernanceParameters(newQuorum, newThreshold, newMaxOps);

        assertEq(gov.quorumVotes(), newQuorum, "Quorum votes should be updated");
        assertEq(gov.proposalThreshold(), newThreshold, "Proposal threshold should be updated");
        assertEq(gov.proposalMaxOperations(), newMaxOps, "Max operations should be updated");

        // Test: Timelock can update parameters (after accepting admin)
        test__acceptAdmin();
        uint256 newerQuorum = 3000;

        // For simplicity, test direct timelock call (in production, this would be via proposal)
        vm.prank(address(timelock));
        gov.updateGovernanceParameters(newerQuorum, newThreshold, newMaxOps);
        assertEq(gov.quorumVotes(), newerQuorum, "Quorum votes should be updated by timelock");
    }

    function test__updateSocialConfig() public {
        IDAOFactory.SocialConfig memory newConfig = IDAOFactory.SocialConfig({
            description: "Updated DAO",
            website: "https://updated.com",
            linkedin: "https://linkedin.com/updated",
            twitter: "https://twitter.com/updated",
            telegram: "https://t.me/updated"
        });

        // Test unauthorized access
        vm.prank(alice);
        vm.expectRevert("Governor::updateSocialConfig: sender must be gov guardian or timelock");
        gov.updateSocialConfig(newConfig);

        // Test guardian update
        vm.prank(guardian);
        gov.updateSocialConfig(newConfig);

        IDAOFactory.SocialConfig memory stored = gov.getSocialConfig();
        assertEq(stored.description, newConfig.description);
        assertEq(stored.website, newConfig.website);
        assertEq(stored.linkedin, newConfig.linkedin);
        assertEq(stored.twitter, newConfig.twitter);
        assertEq(stored.telegram, newConfig.telegram);

        // Test individual parameter update
        vm.prank(guardian);
        gov.updateSocialConfig(
            "New Desc",
            "https://new.com",
            "https://li.com/new",
            "https://tw.com/new",
            "https://tg.com/new"
        );

        stored = gov.getSocialConfig();
        assertEq(stored.description, "New Desc");
        assertEq(stored.website, "https://new.com");
    }

    // ============================================================================
    // View Function Tests
    // ============================================================================

    /// @notice Tests retrieving proposal actions
    function test__getActions() public {
        uint256 proposalId = _createProposal();

        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        ) = gov.getActions(proposalId);

        assertEq(targets.length, 1, "Should have 1 target");
        assertEq(targets[0], address(govToken), "Target should be govToken");
        assertEq(values.length, 1, "Should have 1 value");
        assertEq(signatures.length, 1, "Should have 1 signature");
        assertEq(calldatas.length, 1, "Should have 1 calldata");
    }

    /// @notice Tests retrieving proposal proposer address
    function test__proposer() public {
        uint256 proposalId = _createProposal();
        assertEq(gov.proposer(proposalId), alice, "Proposer should be alice");
    }

    /// @notice Tests state function with invalid proposal IDs
    function test__stateInvalidProposalId() public {
        // Test: State should revert for non-existent proposal ID 0
        vm.expectRevert("Governor::state: invalid proposal id");
        gov.state(0);

        // Test: State should revert for non-existent proposal ID 999
        vm.expectRevert("Governor::state: invalid proposal id");
        gov.state(999);
    }

    /// @notice Tests proposal expiration after grace period
    function test__expiredProposal() public {
        // Setup: Accept admin and create proposal
        test__acceptAdmin();
        uint256 proposalId = _createProposal();

        // Move to voting period and vote
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        gov.castVote(proposalId, true);

        // Move past voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Queue proposal
        gov.queue(proposalId);

        // Move past grace period to expire proposal
        vm.warp(block.timestamp + TIME_LOCK_DELAY + timelock.GRACE_PERIOD() + 1);

        assertEq(
            uint256(gov.state(proposalId)),
            uint256(PEACECOINDAO_GOVERNOR.ProposalState.Expired),
            "Proposal should be Expired after grace period"
        );
    }

    /// @notice Tests retrieving past voting power
    function test__getPastVotes() public {
        // Setup: Mint tokens and delegate
        govToken.mint(alice, 1000 ether);
        govToken.delegate(alice);
        vm.roll(block.number + 1);

        // Test: Retrieve past votes
        uint96 votes = gov.getPastVotes(alice, block.number - 1);
        assertGt(votes, 0, "Alice should have voting power");
    }
}
