// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {PCETokenV2} from "../src/PCETokenV2.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {Bounty, ERC20Upgradeable} from "../src/Bounty.sol";
import {Timelock} from "../src/Governance/Timelock.sol";

contract BountyTest is Test {
    address alice = address(0xABCD);
    address bob = address(0xDCBA);
    address trent = address(this);

    PCETokenV2 pceToken;
    GovernorAlpha gov;
    Timelock timelock;
    Bounty bounty;

    uint256 constant BOUNTY_AMOUNT = 1000;
    uint256 constant INITIAL_AMOUNT = 2000e18;
    uint256 constant bountyAmount = 2000;
    uint256 constant proposalBountyAmount = 1500;

    function setUp() public {
        vm.startPrank(alice);
        pceToken = new PCETokenV2();
        pceToken.initialize("PEACE COIN", "PCE", address(1), address(0));

        timelock = new Timelock(alice, 10 minutes);
        gov = new GovernorAlpha(address(timelock), address(pceToken), alice);
        bounty = new Bounty();
        bounty.initialize(
            ERC20Upgradeable(pceToken),
            BOUNTY_AMOUNT,
            address(gov)
        );

        pceToken.transfer(address(this), INITIAL_AMOUNT);
        pceToken.transfer(alice, INITIAL_AMOUNT);
        pceToken.transfer(bob, INITIAL_AMOUNT);
        pceToken.transfer(address(timelock), INITIAL_AMOUNT);
        pceToken.transfer(address(bounty), INITIAL_AMOUNT);

        pceToken.delegate(alice);
        vm.stopPrank();

        vm.startPrank(bob);
        pceToken.delegate(bob);
        vm.stopPrank();

        pceToken.delegate(trent);
    }

    function testPropose() public {
        address[] memory targets = new address[](1);
        targets[0] = address(pceToken);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "transfer(address,uint256)";

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(alice, 100);

        string memory description = "Transfer PCE";

        vm.startPrank(trent);
        pceToken.delegate(trent);
        vm.roll(block.number + 10);
        gov.propose(targets, values, signatures, data, description);
        vm.stopPrank();

        vm.prank(bob);
        gov.propose(targets, values, signatures, data, description);
    }

    function testCastVote() public {
        testPropose();

        vm.roll(block.timestamp + gov.votingPeriod());

        vm.prank(alice);
        gov.castVote(1, true);

        (, , , , , uint256 forVotes, uint256 againstVotes, , , ) = gov
            .proposals(1);
        assertEq(forVotes, INITIAL_AMOUNT);
        assertEq(againstVotes, 0);

        vm.prank(bob);
        gov.castVote(1, false);

        (, , , , , forVotes, againstVotes, , , ) = gov.proposals(1);
        assertEq(forVotes, INITIAL_AMOUNT);
        assertEq(againstVotes, INITIAL_AMOUNT);

        vm.prank(trent);
        gov.castVote(1, true);
    }

    function testAcceptAdmin() public {
        vm.prank(alice);
        timelock.setPendingAdmin(address(gov));

        vm.expectRevert(
            "GovernorAlpha::__acceptAdmin: sender must be gov guardian"
        );
        gov.__acceptAdmin();

        vm.prank(alice);
        gov.__acceptAdmin();
    }

    function testQueue() public {
        testAcceptAdmin();
        testCastVote();

        vm.roll(gov.votingPeriod() * 2);
        gov.queue(1);
    }

    function testExecute() public {
        testQueue();

        skip(timelock.delay() * 2);

        gov.execute(1);
    }

    // Unit test for the Bounty Contract
    function testSetBountyAmount() public {
        bytes4 selector = bytes4(
            keccak256("OwnableUnauthorizedAccount(address)")
        );

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(selector, bob));
        bounty.setBountyAmount(bountyAmount);

        vm.prank(alice);
        bounty.setBountyAmount(bountyAmount);
        assertEq(bounty.bountyAmount(), bountyAmount);
    }

    function testSetContributor() public {
        vm.prank(alice);
        bounty.setContributor(trent, true);

        bytes4 selector = bytes4(
            keccak256("OwnableUnauthorizedAccount(address)")
        );

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(selector, bob));
        bounty.setContributor(trent, true);
    }

    function testAddProposalBounty() public {
        testExecute();

        uint256 id = 1;

        vm.expectRevert("Amount must be greater than 0");
        bounty.addProposalBounty(id, 0);

        vm.expectRevert("Invalid proposal state");
        bounty.addProposalBounty(2, proposalBountyAmount);

        vm.startPrank(alice);
        pceToken.approve(address(bounty), proposalBountyAmount);
        vm.stopPrank();

        uint256 prevBounty = bounty.proposalBounties(id);
        uint256 prevWithdrawn = bounty.proposalBounties(id);
        assertEq(prevBounty, 0);
        assertEq(prevWithdrawn, 0);

        vm.prank(alice);
        bounty.addProposalBounty(id, proposalBountyAmount);

        uint256 currentBounty = bounty.proposalBounties(id);
        uint256 currentWithdrawn = bounty.proposalBounties(id);
        assertEq(currentBounty, proposalBountyAmount);
        assertEq(currentWithdrawn, proposalBountyAmount);
    }

    function testClaimProposalBounty() public {
        testExecute();
        testSetBountyAmount();

        uint256 balanceBefore = pceToken.balanceOf(trent);

        vm.prank(alice);
        vm.expectRevert("Nothing to withdraw");
        bounty.claimProposalBounty();

        vm.prank(trent);
        bounty.claimProposalBounty();

        uint256 balanceAfter = pceToken.balanceOf(trent);

        assertEq(balanceAfter, bountyAmount + balanceBefore);

        vm.expectRevert("Nothing to withdraw");
        vm.prank(trent);
        bounty.claimProposalBounty();
    }

    function testClaimContributorBounty() public {
        testExecute();
        testSetBountyAmount();

        uint256 balanceBefore = pceToken.balanceOf(trent);

        vm.prank(trent);
        vm.expectRevert("Nothing to withdraw");
        bounty.claimContributorBounty();

        testSetContributor();

        vm.prank(trent);
        bounty.claimContributorBounty();

        uint256 balanceAfter = pceToken.balanceOf(trent);

        assertEq(balanceAfter, bountyAmount + balanceBefore);

        vm.expectRevert("Nothing to withdraw");
        vm.prank(trent);
        bounty.claimContributorBounty();
    }

    function testAddContributorBounty() public {
        uint256 amount = 1500;

        vm.startPrank(bob);
        pceToken.approve(address(bounty), amount);

        vm.expectRevert("Invalid contributor");
        bounty.addContributorBounty(address(0), amount);

        vm.expectRevert("Amount must be greater than 0");
        bounty.addContributorBounty(bob, 0);

        (uint256 currentBounty, uint256 withdrawn) = bounty.contributorBounties(
            bob
        );
        assertEq(currentBounty, 0);
        assertEq(withdrawn, 0);

        bounty.addContributorBounty(bob, amount);

        (uint256 _bounty, uint256 _withdrawn) = bounty.contributorBounties(bob);

        assertEq(_bounty, amount);
        assertEq(_withdrawn, 0);
        vm.stopPrank();
    }
}
