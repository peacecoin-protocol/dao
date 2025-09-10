// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Bounty} from "../src/Bounty.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockGovernance} from "../src/mocks/MockGovernance.sol";

contract BountyTest is Test {
    Bounty public bounty;
    MockERC20 public token;
    MockGovernance public governance;

    address public owner = address(this);
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public constant BOUNTY_AMOUNT = 0;
    uint256 public constant INITIAL_BALANCE = 1000e18;

    event UpdatedBountyAmount(uint256 bountyAmount);
    event AddedContributorBounty(address indexed user, address indexed contributor, uint256 amount);
    event AddedProposalBounty(address indexed user, uint256 indexed proposalId, uint256 amount);
    event ClaimedBounty(address indexed user, uint256 amount);

    function setUp() public {
        // Deploy mock contracts
        token = new MockERC20();
        token.initialize();
        governance = new MockGovernance();

        // Deploy and initialize Bounty contract
        bounty = new Bounty();
        bounty.initialize(token, BOUNTY_AMOUNT, address(governance));

        // Setup initial balances
        token.mint(owner, INITIAL_BALANCE);
        token.mint(user1, INITIAL_BALANCE);
        token.mint(user2, INITIAL_BALANCE);

        // Approve bounty contract to spend tokens
        token.approve(address(bounty), type(uint256).max);
        vm.prank(user1);
        token.approve(address(bounty), type(uint256).max);
        vm.prank(user2);
        token.approve(address(bounty), type(uint256).max);
    }

    function test_Initialize() public view {
        assertEq(address(bounty.bountyToken()), address(token));
        assertEq(bounty.bountyAmount(), BOUNTY_AMOUNT);
        assertEq(bounty.governance(), address(governance));
        assertEq(bounty.owner(), owner);
    }

    function test_SetBountyAmount() public {
        uint256 newAmount = 200e18;
        vm.expectEmit(true, true, true, true);
        emit UpdatedBountyAmount(newAmount);
        bounty.setBountyAmount(newAmount);
        assertEq(bounty.bountyAmount(), newAmount);
    }

    function test_SetContributor() public {
        bounty.setContributor(user1, true);
        assertTrue(bounty.isContributor(user1));

        bounty.setContributor(user1, false);
        assertFalse(bounty.isContributor(user1));
    }

    function test_SetContributor_RevertWhen_AddressIsZero() public {
        vm.expectRevert("Invalid contributor");
        bounty.setContributor(address(0), true);
    }

    function test_AddProposalBounty_SucceededState() public {
        uint256 proposalId = 0;
        uint256 amount = 50e18;

        // Setup mock governance
        governance.setProposalState(proposalId, uint8(4)); // Succeeded state

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit AddedProposalBounty(user1, proposalId, amount);
        bounty.addProposalBounty(proposalId, amount);

        assertEq(bounty.proposalBounties(proposalId), amount);
        assertEq(token.balanceOf(address(bounty)), amount);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - amount);
    }

    function test_AddProposalBounty_ExecutedState() public {
        uint256 proposalId = 0;
        uint256 amount = 50e18;

        // Setup mock governance
        governance.setProposalState(proposalId, uint8(7)); // Executed state

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit AddedProposalBounty(user1, proposalId, amount);
        bounty.addProposalBounty(proposalId, amount);

        assertEq(bounty.proposalBounties(proposalId), amount);
        assertEq(token.balanceOf(address(bounty)), amount);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - amount);
    }

    function test_AddContributorBounty() public {
        uint256 amount = 50e18;

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit AddedContributorBounty(user1, user2, amount);
        bounty.addContributorBounty(user2, amount);

        (uint256 bountyAmount, uint256 withdrawn) = bounty.contributorBounties(user2);
        assertEq(bountyAmount, amount);
        assertEq(withdrawn, 0);
        assertEq(token.balanceOf(address(bounty)), amount);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - amount);
    }

    function test_AddContributorBounty_RevertWhen_AddressIsZero() public {
        uint256 amount = 50e18;
        vm.expectRevert("Invalid contributor");
        bounty.addContributorBounty(address(0), amount);
    }

    function test_ClaimProposalBounty() public {
        uint256 proposalId = 0;
        uint256 amount = 50e18;
        uint256 userClaimableAmount = amount + BOUNTY_AMOUNT;

        // Setup proposal and bounty
        governance.setProposalState(proposalId, uint8(4)); // Succeeded state
        governance.setProposer(proposalId, user1);

        bounty.addProposalBounty(proposalId, amount);
        uint256 bountyInitialBalance = token.balanceOf(address(bounty));

        // Claim bounty
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit ClaimedBounty(user1, userClaimableAmount);
        bounty.claimProposalBounty();
        assertEq(token.balanceOf(address(bounty)), bountyInitialBalance - userClaimableAmount);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE + userClaimableAmount);
        assertEq(bounty.proposalBountyWithdrawn(user1), userClaimableAmount);
    }

    function test_ClaimContributorBounty() public {
        uint256 amount = 50e18;
        uint256 userClaimableAmount = amount + BOUNTY_AMOUNT;

        // Setup contributor and bounty
        bounty.setContributor(user1, true);
        token.approve(address(bounty), amount);
        bounty.addContributorBounty(user1, amount);

        uint256 bountyInitialBalance = token.balanceOf(address(bounty));

        // Claim bounty
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit ClaimedBounty(user1, userClaimableAmount);
        bounty.claimContributorBounty();

        assertEq(token.balanceOf(user1), INITIAL_BALANCE + userClaimableAmount);
        assertEq(token.balanceOf(address(bounty)), bountyInitialBalance - userClaimableAmount);
        (, uint256 withdrawn) = bounty.contributorBounties(user1);
        assertEq(withdrawn, userClaimableAmount);
    }

    function test_RecoverERC20() public {
        uint256 amount = 50e18;
        token.transfer(address(bounty), amount);

        uint256 initialOwnerBalance = token.balanceOf(owner);

        bounty.recoverERC20(token);
        assertEq(token.balanceOf(address(bounty)), 0);
        assertEq(token.balanceOf(owner), initialOwnerBalance + amount);
    }

    function test_RevertWhen_NonOwnerSetsContributor() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        bounty.setContributor(user2, true);
    }

    function test_RevertWhen_NonOwnerSetsBountyAmount() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        bounty.setBountyAmount(100e18);
    }

    function test_RevertWhen_AddingProposalBountyForInvalidProposal() public {
        uint256 proposalId = 0;
        uint256 amount = 50e18;

        // Set proposal state to something other than Succeeded (4) and Executed(7)
        governance.setProposalState(proposalId, uint8(3)); // Pending state

        vm.prank(user1);
        vm.expectRevert("Invalid proposal state");
        bounty.addProposalBounty(proposalId, amount);
    }

    function test_RevertWhen_AddingZeroBounty() public {
        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        bounty.addContributorBounty(user2, 0);

        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        bounty.addProposalBounty(0, 0);
    }

    function test_RevertWhen_NonContributorClaimsBounty() public {
        uint256 amount = 50e18;
        bounty.addContributorBounty(user1, amount);

        vm.prank(user2);
        vm.expectRevert("Nothing to withdraw");
        bounty.claimContributorBounty();
    }

    function test_RevertWhen_ClaimingProposalBountyWithoutValidProposal() public {
        vm.prank(user1);
        vm.expectRevert("Nothing to withdraw");
        bounty.claimProposalBounty();
    }

    function test_MultipleContributorBounties() public {
        uint256 amount1 = 50e18;
        uint256 amount2 = 30e18;

        // Setup contributor
        bounty.setContributor(user1, true);

        // Add multiple bounties
        bounty.addContributorBounty(user1, amount1);
        bounty.addContributorBounty(user1, amount2);

        // Verify total bounty
        (uint256 bountyAmount, uint256 withdrawn) = bounty.contributorBounties(user1);
        assertEq(bountyAmount, amount1 + amount2);
        assertEq(withdrawn, 0);

        // Claim bounty
        vm.prank(user1);
        bounty.claimContributorBounty();

        // Verify claim
        (bountyAmount, withdrawn) = bounty.contributorBounties(user1);
        assertEq(withdrawn, amount1 + amount2);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE + amount1 + amount2 + BOUNTY_AMOUNT);
    }

    function test_claimableProposalAmount(uint256 bountyAmount, uint256 proposalAmount) public {
        bountyAmount = bound(bountyAmount, 1e18, 5e18);
        proposalAmount = bound(proposalAmount, 30e18, INITIAL_BALANCE / 4);
        bounty.setBountyAmount(bountyAmount);

        uint256 proposalId0 = 0;
        uint256 proposalId1 = 1;
        uint256 proposalId2 = 2;

        // Setup proposal and bounty
        governance.setProposalState(proposalId0, uint8(4)); // Succeeded state
        governance.setProposalState(proposalId1, uint8(4)); // Succeeded state
        governance.setProposalState(proposalId2, uint8(4)); // Succeeded state
        governance.setProposer(proposalId0, user1);
        governance.setProposer(proposalId1, user1);
        governance.setProposer(proposalId2, user2); // Another user

        bounty.addProposalBounty(proposalId0, proposalAmount);
        bounty.addProposalBounty(proposalId1, proposalAmount);
        bounty.addProposalBounty(proposalId2, proposalAmount);
        assertEq(bounty.claimableProposalAmount(user1), proposalAmount * 2 + bountyAmount * 2);

        // Claim all bounties
        vm.prank(user1);
        bounty.claimProposalBounty();
        assertEq(bounty.claimableProposalAmount(user1), 0);
    }

    function test_claimableContributorAmount(
        uint256 bountyAmount,
        uint256 contributionAmount
    ) public {
        bountyAmount = bound(bountyAmount, 1e18, 5e18);
        contributionAmount = bound(contributionAmount, 30e18, 50e18);
        bounty.setBountyAmount(bountyAmount);

        bounty.setContributor(user1, true);
        bounty.addContributorBounty(user1, contributionAmount);

        uint256 claimableAmountUser1 = bounty.claimableContributorAmount(user1);
        assertEq(claimableAmountUser1, contributionAmount + bountyAmount);

        // Not a contributor
        bounty.addContributorBounty(user2, contributionAmount);
        uint256 claimableAmountUser2 = bounty.claimableContributorAmount(user2);
        assertEq(claimableAmountUser2, contributionAmount); // No bounty
    }

    function test_RevertWhen_NonOwnerRecoversERC20() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        bounty.recoverERC20(token);
    }
}
