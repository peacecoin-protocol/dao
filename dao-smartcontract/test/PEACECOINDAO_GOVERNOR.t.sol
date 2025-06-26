// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {PEACECOINDAO_SBT} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {PEACECOINDAO_GOVERNOR} from "../src/Governance/PEACECOINDAO_GOVERNOR.sol";
import {Timelock} from "../src/Governance/Timelock.sol";

contract PEACECOINDAO_GOVERNOR_TEST is Test {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address guardian = makeAddr("guardian");

    PEACECOINDAO_SBT sbt;
    PEACECOINDAO_GOVERNOR gov;
    Timelock timelock;
    uint256 constant INITIAL_BALANCE = 50000e18;
    uint256 constant TIME_LOCK_DELAY = 10 minutes;
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 1 days;
    uint256 constant PROPOSAL_THRESHOLD = 5;
    uint256 constant QUORUM_VOTES = 1000;
    uint256 constant PROPOSAL_MAX_OPERATIONS = 10;
    uint256 constant EXECUTE_TRANSFER_VALUE = 1;
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

        sbt = new PEACECOINDAO_SBT();
        sbt.initialize(
            "PEACECOIN DAO SBT",
            "PCE_SBT",
            "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/"
        );

        sbt.setTokenURI(1, "https://peacecoin.io/sbt/1", 10);
        sbt.setTokenURI(2, "https://peacecoin.io/sbt/2", 10);
        sbt.setTokenURI(3, "https://peacecoin.io/sbt/3", 10);
        sbt.setTokenURI(4, "https://peacecoin.io/sbt/4", 10);
        sbt.setTokenURI(5, "https://peacecoin.io/sbt/5", 10);
        sbt.setTokenURI(6, "https://peacecoin.io/sbt/6", 10);
        sbt.setTokenURI(7, "https://peacecoin.io/sbt/7", 10);
        sbt.setTokenURI(8, "https://peacecoin.io/sbt/8", 10);

        timelock = new Timelock();
        timelock.initialize(alice, TIME_LOCK_DELAY);

        // Updated constructor parameters
        gov = new PEACECOINDAO_GOVERNOR();
        gov.initialize(
            "PEACECOIN DAO",
            address(sbt),
            address(sbt),
            address(timelock),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_VOTES,
            guardian
        );

        sbt.mint(guardian, 1, 1);
        sbt.mint(alice, 1, 1);
        sbt.mint(bob, 1, 1);

        vm.prank(alice);
        sbt.delegate(alice);

        vm.prank(bob);
        sbt.delegate(alice);

        vm.prank(guardian);
        sbt.delegate(guardian);

        vm.roll(block.number + 1);
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
        targets[0] = address(sbt);

        values = new uint256[](1);
        values[0] = 0;

        signatures = new string[](1);
        signatures[0] = "safeTransferFrom(address,address,uint256)";

        data = new bytes[](1);
        data[0] = abi.encode(alice, bob, EXECUTE_TRANSFER_VALUE, "");

        description = "Transfer SBT";
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

        vm.expectRevert("Governor::propose: proposer votes below proposal threshold");
        gov.propose(targets, values, signatures, data, description);

        bytes[] memory inv_data = new bytes[](2);
        inv_data[0] = new bytes(1);
        inv_data[1] = new bytes(2);

        vm.startPrank(alice);
        vm.expectRevert("Governor::propose: proposal function information arity mismatch");
        gov.propose(targets, values, signatures, inv_data, description);

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

        // Create Proposal
        vm.expectEmit(true, true, true, true);
        emit ProposalCreated(
            PROPOSAL_ID,
            alice,
            targets,
            values,
            signatures,
            data,
            block.number + VOTING_DELAY,
            block.number + VOTING_DELAY + VOTING_PERIOD,
            description
        );
        gov.propose(targets, values, signatures, data, description);

        assertEq(gov.proposalCount(), 1);
        assertEq(gov.latestProposalIds(alice), 1);

        // Can't create new proposal if user has active/pending proposal
        vm.expectRevert(
            "Governor::propose: one live proposal per proposer, found an already pending proposal"
        );
        gov.propose(targets, values, signatures, data, description);

        vm.stopPrank();
    }

    function test__acceptAdmin() public {
        vm.startPrank(alice);
        timelock.setPendingAdmin(address(gov));

        vm.expectRevert("Governor::__acceptAdmin: sender must be gov guardian");
        gov.__acceptAdmin();

        vm.stopPrank();

        vm.prank(guardian);
        gov.__acceptAdmin();
        assertEq(timelock.admin(), address(gov));

        vm.stopPrank();
    }

    function test__abdicate() public {
        vm.prank(alice);
        vm.expectRevert("Governor::__abdicate: sender must be gov guardian");
        gov.__abdicate();

        vm.prank(guardian);
        gov.__abdicate();
        assertEq(gov.guardian(), address(0));
    }

    function test__cancel() public {
        test__propose();
        test__acceptAdmin();

        vm.prank(bob);
        vm.expectRevert("Governor::cancel: proposer above threshold");
        gov.cancel(PROPOSAL_ID);

        // Guardian can Cancel
        vm.prank(guardian);
        vm.expectEmit(false, false, false, true);
        emit ProposalCanceled(PROPOSAL_ID);
        gov.cancel(PROPOSAL_ID);
        assertEq(
            uint256(gov.state(PROPOSAL_ID)),
            uint256(PEACECOINDAO_GOVERNOR.ProposalState.Canceled)
        );
    }
}
