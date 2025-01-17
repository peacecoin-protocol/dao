// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockGovToken} from "../src/mocks/MockGovToken.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {console} from "forge-std/console.sol";

contract GovernorAlphaTest is Test {
    address alice = address(0xABCD);
    address bob = address(0xDCBA);
    address trent = address(this);

    MockGovToken pceToken;
    GovernorAlpha gov;
    Timelock timelock;
    uint256 initialAmount = 50000e18;
    address communityToken = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;

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

    function setUp() public {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        pceToken = new MockGovToken();
        pceToken.initialize();

        timelock = new Timelock();
        timelock.initialize(alice, 10 minutes);

        // Updated constructor parameters
        gov = new GovernorAlpha();
        gov.initialize("PCE DAO", address(pceToken), address(timelock), 1, 86400, 100e18, 1000e18);

        pceToken.mint(address(this), initialAmount);
        pceToken.mint(alice, initialAmount);
        pceToken.mint(bob, initialAmount);
        pceToken.mint(address(timelock), initialAmount);

        vm.prank(alice);
        pceToken.delegate(alice);

        vm.prank(bob);
        pceToken.delegate(alice);

        vm.prank(trent);
        pceToken.delegate(trent);
    }

    function test__quorumVotes() public view {
        assertEq(gov.quorumVotes(), 1000e18);
    }

    function test__proposalThreshold() public view {
        assertEq(gov.proposalThreshold(), 100e18);
    }

    function test__proposalMaxOperations() public view {
        assertEq(gov.proposalMaxOperations(), 10);
    }

    function test__votingDelay() public view {
        assertEq(gov.votingDelay(), 1);
    }

    function test__votingPeriod() public view {
        assertEq(gov.votingPeriod(), 86400);
    }

    function test__proposalCount() public view {
        assertEq(gov.proposalCount(), 0);
    }

    function test__guardian() public view {
        assertEq(gov.guardian(), trent); // Now the deployer is the guardian
    }

    function test__propose() public {
        address[] memory targets = new address[](1);
        targets[0] = address(pceToken);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "transfer(address,uint256)";

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(alice, 100);

        string memory description = "Transfer PCE";

        vm.expectRevert("GovernorAlpha::propose: proposer votes below proposal threshold");
        gov.propose(targets, values, signatures, data, description);

        vm.prank(address(this));
        pceToken.delegate(address(this));
        vm.roll(block.number + 10);

        bytes[] memory inv_data = new bytes[](2);
        inv_data[0] = new bytes(1);
        inv_data[1] = new bytes(2);

        vm.expectRevert("GovernorAlpha::propose: proposal function information arity mismatch");
        gov.propose(targets, values, signatures, inv_data, description);

        vm.expectRevert("GovernorAlpha::propose: must provide actions");
        gov.propose(new address[](0), new uint256[](0), new string[](0), new bytes[](0), description);

        vm.expectRevert("GovernorAlpha::propose: too many actions");
        gov.propose(new address[](11), new uint256[](11), new string[](11), new bytes[](11), description);

        // Create Proposal
        vm.expectEmit(true, true, true, true);
        emit ProposalCreated(
            1,
            address(this),
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
        assertEq(gov.latestProposalIds(address(this)), 1);

        // Can't create new proposal if user has active/pending proposal
        vm.expectRevert("GovernorAlpha::propose: one live proposal per proposer, found an already pending proposal");
        gov.propose(targets, values, signatures, data, description);
    }

    function test__castVote() public {
        //Create Proposal
        test__propose();

        vm.roll(block.timestamp + gov.votingPeriod());
        vm.prank(alice);
        gov.castVote(1, true);

        vm.prank(trent);
        gov.castVote(1, true);
    }

    function test__acceptAdmin() public {
        vm.prank(alice);
        timelock.setPendingAdmin(address(gov));

        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::__acceptAdmin: sender must be gov guardian");
        gov.__acceptAdmin();

        vm.prank(trent);
        gov.__acceptAdmin();
    }

    function test__abdicate() public {
        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::__abdicate: sender must be gov guardian");
        gov.__abdicate();

        vm.prank(trent);
        gov.__abdicate();
        assertEq(gov.guardian(), address(0));
    }

    function test__cancel() public {
        //Create Proposal
        test__propose();
        test__acceptAdmin();

        vm.prank(bob);
        vm.expectRevert("GovernorAlpha::cancel: proposer above threshold");
        gov.cancel(1);

        // Guardian can Cancel
        vm.prank(trent);
        gov.cancel(1);
    }

    function test__queue() public {
        //Accept Admin
        test__acceptAdmin();

        //Create Proposal
        test__castVote();

        vm.roll(block.number + gov.votingPeriod());
        gov.queue(1);
    }

    function test__execute() public {
        //Queue TX
        test__queue();

        skip(timelock.delay() * 2);

        gov.execute(1);
        assertEq(initialAmount + 100, pceToken.balanceOf(alice));
        assertEq(initialAmount - 100, pceToken.balanceOf(address(timelock)));
    }

    function test__proposalState() public {
        test__propose();

        // Should be Pending right after creation
        assertEq(uint256(gov.state(1)), uint256(GovernorAlpha.ProposalState.Pending));

        // Move to Active state
        vm.roll(block.number + gov.votingDelay() + 1);
        assertEq(uint256(gov.state(1)), uint256(GovernorAlpha.ProposalState.Active));

        // Cast some votes
        vm.prank(alice);
        gov.castVote(1, true);

        // Move to end of voting period
        vm.roll(block.number + gov.votingPeriod());
        assertEq(uint256(gov.state(1)), uint256(GovernorAlpha.ProposalState.Succeeded));
    }

    function test__doubleVotePrevention() public {
        test__propose();

        vm.roll(block.timestamp + gov.votingPeriod());

        vm.prank(alice);
        gov.castVote(1, true);

        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::_castVote: voter already voted");
        gov.castVote(1, true);
    }

    function test__votingPeriodBoundaries() public {
        test__propose();

        // Too early to vote
        vm.prank(alice);
        vm.expectRevert("GovernorAlpha::_castVote: voting is closed");
        gov.castVote(1, true);

        // Move to just after voting delay
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(1, true); // Should succeed

        // Move past voting period
        vm.roll(block.number + gov.votingPeriod() + 1);
        vm.prank(bob);
        vm.expectRevert("GovernorAlpha::_castVote: voting is closed");
        gov.castVote(1, true);
    }

    function test__queueInvalidStates() public {
        test__propose();

        // Can't queue before voting period ends
        vm.expectRevert("GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        gov.queue(1);

        // Move to voting period and defeat the proposal
        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(alice);
        gov.castVote(1, false);

        vm.roll(block.number + gov.votingPeriod());
        vm.expectRevert("GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        gov.queue(1);
    }
}
