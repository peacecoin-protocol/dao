// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {PCEToken} from "../src/PCEToken.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {console} from "forge-std/console.sol";

contract GovernorAlphaTest is Test {
    address alice = address(0xABCD);
    address bob = address(0xDCBA);
    address trent = address(this);

    PCEToken pceToken;
    GovernorAlpha gov;
    Timelock timelock;
    uint256 initialAmount = 50000;
    address communityToken = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;

    event ProposalCreated(
        uint id,
        address proposer,
        address[] targets,
        uint[] values,
        string[] signatures,
        bytes[] calldatas,
        uint startBlock,
        uint endBlock,
        string description
    );

    function setUp() public {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        pceToken = new PCEToken();
        pceToken.initialize("PEACE COIN", "PCE", address(1));

        timelock = new Timelock(alice, 2 days);
        gov = new GovernorAlpha(address(timelock), address(pceToken), alice);

        pceToken.transfer(address(this), initialAmount);
        pceToken.transfer(alice, initialAmount);
        pceToken.transfer(bob, initialAmount);
        pceToken.transfer(address(timelock), initialAmount);

        vm.prank(alice);
        pceToken.delegate(alice);

        vm.prank(bob);
        pceToken.delegate(bob);

        vm.prank(trent);
        pceToken.delegate(trent);
    }

    function test__quorumVotes() public view {
        assertEq(gov.quorumVotes(), 4000e18);
    }

    function test__proposalThreshold() public view {
        assertEq(gov.proposalThreshold(), 1000e18);
    }

    function test__proposalMaxOperations() public view {
        assertEq(gov.proposalMaxOperations(), 10);
    }

    function test__votingDelay() public view {
        assertEq(gov.votingDelay(), 1);
    }

    function test__votingPeriod() public view {
        assertEq(gov.votingPeriod(), 17280);
    }

    function test__proposalCount() public view {
        assertEq(gov.proposalCount(), 0);
    }

    function test__guardian() public view {
        assertEq(gov.guardian(), alice);
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

        vm.expectRevert(
            "GovernorAlpha::propose: proposer votes below proposal threshold"
        );
        gov.propose(targets, values, signatures, data, description);

        vm.prank(address(this));
        pceToken.delegate(address(this));
        vm.roll(block.number + 10);

        bytes[] memory inv_data = new bytes[](2);
        inv_data[0] = new bytes(1);
        inv_data[0] = new bytes(2);

        vm.expectRevert(
            "GovernorAlpha::propose: proposal function information arity mismatch"
        );
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
        gov.propose(targets, values, signatures, data, description);

        assertEq(gov.proposalCount(), 1);
        assertEq(gov.latestProposalIds(msg.sender), 0);

        // Cant create new proposal if user has active/pending proposal
        vm.expectRevert(
            "GovernorAlpha::propose: one live proposal per proposer, found an already pending proposal"
        );
        gov.propose(targets, values, signatures, data, description);
    }

    function test__castVote() public {
        //Create Proposal
        test__propose();

        vm.roll(block.timestamp + gov.votingPeriod());
        vm.prank(alice);
        gov.castVote(1, true);

        {
            (, , , , , uint256 _forVotes, uint256 _againstVotes, , ) = gov
                .proposals(1);
            assertEq(_forVotes, initialAmount);
            assertEq(_againstVotes, 0);

            vm.prank(bob);
            gov.castVote(1, false);
        }

        {
            (, , , , , uint256 _forVotes, uint256 _againstVotes, , ) = gov
                .proposals(1);
            assertEq(_forVotes, initialAmount);
            assertEq(_againstVotes, initialAmount);
        }

        vm.prank(trent);
        gov.castVote(1, true);
    }
    function test__acceptAdmin() public {
        vm.prank(alice);
        timelock.setPendingAdmin(address(gov));

        vm.expectRevert(
            "GovernorAlpha::__acceptAdmin: sender must be gov guardian"
        );
        gov.__acceptAdmin();

        vm.prank(alice);
        gov.__acceptAdmin();
    }

    function test__abdicate() public {
        vm.expectRevert(
            "GovernorAlpha::__abdicate: sender must be gov guardian"
        );
        gov.__abdicate();

        vm.prank(alice);
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
        vm.prank(alice);

        gov.cancel(1);
        (, , , , , , , bool isCanceled, ) = gov.proposals(1);
        assertEq(isCanceled, true);
    }

    function test__queue() public {
        //Accept Admin
        test__acceptAdmin();

        //Create Proposal
        test__castVote();

        vm.roll(gov.votingPeriod() * 2);
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
}
