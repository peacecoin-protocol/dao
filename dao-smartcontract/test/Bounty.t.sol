// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Bounty} from "../src/Bounty.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockGovernance} from "../src/mocks/MockGovernance.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {ProposalState} from "../src/interfaces/IGovernance.sol";

/**
 * @title BountyTest
 * @notice Comprehensive test suite for the Bounty contract
 */
contract BountyTest is Test {
    // ============ State Variables ============
    Bounty public bounty;
    MockERC20 public token;
    MockGovernance public governance;

    // ============ Test Addresses ============
    address public owner = address(this);
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // ============ Constants ============
    uint256 public constant BOUNTY_AMOUNT = 0;
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant TEST_AMOUNT = 50 ether;
    uint256 public constant PROPOSAL_ID = 1;

    // ============ Proposal State Constants ============
    uint8 public constant PROPOSAL_STATE_PENDING = uint8(ProposalState.Pending);
    uint8 public constant PROPOSAL_STATE_ACTIVE = uint8(ProposalState.Active);
    uint8 public constant PROPOSAL_STATE_SUCCEEDED = uint8(ProposalState.Succeeded);
    uint8 public constant PROPOSAL_STATE_EXECUTED = uint8(ProposalState.Executed);

    // ============ Events ============
    event UpdatedBountyAmount(uint256 bountyAmount);
    event AddedContributorBounty(address indexed user, address indexed contributor, uint256 amount);
    event AddedProposalBounty(address indexed user, uint256 indexed proposalId, uint256 amount);
    event ClaimedBounty(address indexed user, uint256 amount);

    // ============ Setup ============
    function setUp() public {
        // Deploy mock contracts
        token = new MockERC20();
        token.initialize();
        governance = new MockGovernance();

        // Deploy and initialize Bounty contract
        bounty = new Bounty();
        bounty.initialize(token, BOUNTY_AMOUNT, address(governance));

        // Setup initial token balances
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

    // ============ Initialization Tests ============

    function test_Initialize() public view {
        assertEq(address(bounty.bountyToken()), address(token));
        assertEq(bounty.bountyAmount(), BOUNTY_AMOUNT);
        assertEq(bounty.governance(), address(governance));
        assertEq(bounty.owner(), owner);
    }

    // ============ Configuration Tests ============
    function test_SetBountyAmount() public {
        uint256 newAmount = 200 ether;
        vm.expectEmit(true, true, true, true);
        emit UpdatedBountyAmount(newAmount);
        bounty.setBountyAmount(newAmount);
        assertEq(bounty.bountyAmount(), newAmount);
    }

    function test_SetContributor_Add() public {
        bounty.setContributor(user1, true);
        assertTrue(bounty.isContributor(user1));
    }

    function test_SetContributor_Remove() public {
        bounty.setContributor(user1, true);
        assertTrue(bounty.isContributor(user1));

        bounty.setContributor(user1, false);
        assertFalse(bounty.isContributor(user1));
    }

    function test_SetContributor_RevertWhen_AddressIsZero() public {
        vm.expectRevert(IErrors.InvalidContributor.selector);
        bounty.setContributor(address(0), true);
    }

    function test_SetBountyAmount_RevertWhen_NonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        bounty.setBountyAmount(100 ether);
    }

    function test_SetContributor_RevertWhen_NonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        bounty.setContributor(user2, true);
    }

    // ============ Proposal Bounty Tests ============
    function test_AddProposalBounty_WhenSucceeded() public {
        uint256 amount = TEST_AMOUNT;

        governance.setProposalState(PROPOSAL_ID, PROPOSAL_STATE_SUCCEEDED);

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit AddedProposalBounty(user1, PROPOSAL_ID, amount);
        bounty.addProposalBounty(PROPOSAL_ID, amount);

        assertEq(bounty.proposalBounties(PROPOSAL_ID), amount);
        assertEq(token.balanceOf(address(bounty)), amount);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - amount);
    }

    function test_AddProposalBounty_WhenExecuted() public {
        uint256 amount = TEST_AMOUNT;

        governance.setProposalState(PROPOSAL_ID, PROPOSAL_STATE_EXECUTED);

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit AddedProposalBounty(user1, PROPOSAL_ID, amount);
        bounty.addProposalBounty(PROPOSAL_ID, amount);

        assertEq(bounty.proposalBounties(PROPOSAL_ID), amount);
        assertEq(token.balanceOf(address(bounty)), amount);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - amount);
    }

    function test_AddProposalBounty_RevertWhen_InvalidProposalState() public {
        uint256 amount = TEST_AMOUNT;

        governance.setProposalState(PROPOSAL_ID, PROPOSAL_STATE_PENDING);

        vm.prank(user1);
        vm.expectRevert(IErrors.InvalidProposalState.selector);
        bounty.addProposalBounty(PROPOSAL_ID, amount);
    }

    function test_AddProposalBounty_RevertWhen_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(IErrors.ZeroAmount.selector);
        bounty.addProposalBounty(0, 0);
    }

    // ============ Contributor Bounty Tests ============
    function test_AddContributorBounty() public {
        uint256 amount = TEST_AMOUNT;

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
        uint256 amount = TEST_AMOUNT;
        vm.expectRevert(IErrors.InvalidContributor.selector);
        bounty.addContributorBounty(address(0), amount);
    }

    function test_AddContributorBounty_RevertWhen_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(IErrors.ZeroAmount.selector);
        bounty.addContributorBounty(user2, 0);
    }

    // ============ Claim Tests ============
    function test_ClaimProposalBounty() public {
        uint256 amount = TEST_AMOUNT;

        governance.setProposalState(PROPOSAL_ID, PROPOSAL_STATE_SUCCEEDED);
        governance.setProposer(PROPOSAL_ID, user1);

        bounty.addProposalBounty(PROPOSAL_ID, amount);

        vm.prank(user1);
        // vm.expectEmit(true, true, true, true);
        // emit ClaimedBounty(user1, claimableAmount);
        bounty.claimProposalBounty();

        // assertEq(token.balanceOf(address(bounty)), bountyInitialBalance - claimableAmount);
        // assertEq(token.balanceOf(user1), INITIAL_BALANCE + claimableAmount);
        // assertEq(bounty.proposalBountyWithdrawn(user1), claimableAmount);
    }

    function test_ClaimContributorBounty() public {
        uint256 amount = TEST_AMOUNT;
        uint256 claimableAmount = amount + BOUNTY_AMOUNT;

        bounty.setContributor(user1, true);
        token.approve(address(bounty), amount);
        bounty.addContributorBounty(user1, amount);

        uint256 bountyInitialBalance = token.balanceOf(address(bounty));

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit ClaimedBounty(user1, claimableAmount);
        bounty.claimContributorBounty();

        assertEq(token.balanceOf(user1), INITIAL_BALANCE + claimableAmount);
        assertEq(token.balanceOf(address(bounty)), bountyInitialBalance - claimableAmount);
        (, uint256 withdrawn) = bounty.contributorBounties(user1);
        assertEq(withdrawn, claimableAmount);
    }

    function test_ClaimProposalBounty_RevertWhen_NoValidProposal() public {
        vm.prank(user1);
        vm.expectRevert(IErrors.NothingToWithdraw.selector);
        bounty.claimProposalBounty();
    }

    function test_ClaimContributorBounty_RevertWhen_NonContributor() public {
        uint256 amount = TEST_AMOUNT;
        bounty.addContributorBounty(user1, amount);

        vm.prank(user2);
        vm.expectRevert(IErrors.NothingToWithdraw.selector);
        bounty.claimContributorBounty();
    }

    // ============ Multiple Bounties Tests ============
    function test_MultipleContributorBounties() public {
        uint256 amount1 = TEST_AMOUNT;
        uint256 amount2 = 30 ether;

        bounty.setContributor(user1, true);
        bounty.addContributorBounty(user1, amount1);
        bounty.addContributorBounty(user1, amount2);

        (uint256 bountyAmount, uint256 withdrawn) = bounty.contributorBounties(user1);
        assertEq(bountyAmount, amount1 + amount2);
        assertEq(withdrawn, 0);

        vm.prank(user1);
        bounty.claimContributorBounty();

        (bountyAmount, withdrawn) = bounty.contributorBounties(user1);
        assertEq(withdrawn, amount1 + amount2);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE + amount1 + amount2 + BOUNTY_AMOUNT);
    }

    // ============ Claimable Amount Tests ============
    function test_ClaimableProposalAmount(uint256 bountyAmount, uint256 proposalAmount) public {
        bountyAmount = bound(bountyAmount, 1 ether, 5 ether);
        proposalAmount = bound(proposalAmount, 30 ether, INITIAL_BALANCE / 4);
        bounty.setBountyAmount(bountyAmount);

        uint256 proposalId1 = 1;
        uint256 proposalId2 = 2;
        uint256 proposalId3 = 3;

        governance.setProposalState(proposalId1, PROPOSAL_STATE_SUCCEEDED);
        governance.setProposalState(proposalId2, PROPOSAL_STATE_SUCCEEDED);
        governance.setProposalState(proposalId3, PROPOSAL_STATE_SUCCEEDED);

        governance.setProposer(proposalId1, user1);
        governance.setProposer(proposalId2, user2);
        governance.setProposer(proposalId3, user1);

        bounty.addProposalBounty(proposalId1, proposalAmount);
        bounty.addProposalBounty(proposalId2, proposalAmount);
        bounty.addProposalBounty(proposalId3, proposalAmount);

        assertEq(bounty.claimableProposalAmount(user1), proposalAmount * 2 + bountyAmount * 2);

        vm.prank(user1);
        bounty.claimProposalBounty();
        assertEq(bounty.claimableProposalAmount(user1), 0);
    }

    function test_ClaimableContributorAmount(
        uint256 bountyAmount,
        uint256 contributionAmount
    ) public {
        bountyAmount = bound(bountyAmount, 1 ether, 5 ether);
        contributionAmount = bound(contributionAmount, 30 ether, 50 ether);
        bounty.setBountyAmount(bountyAmount);

        bounty.setContributor(user1, true);
        bounty.addContributorBounty(user1, contributionAmount);

        uint256 claimableAmountUser1 = bounty.claimableContributorAmount(user1);
        assertEq(claimableAmountUser1, contributionAmount + bountyAmount);

        bounty.addContributorBounty(user2, contributionAmount);
        uint256 claimableAmountUser2 = bounty.claimableContributorAmount(user2);
        assertEq(claimableAmountUser2, contributionAmount);
    }

    // ============ Recovery Tests ============
    function test_RecoverERC20() public {
        uint256 amount = TEST_AMOUNT;
        bool success = token.transfer(address(bounty), amount);
        assertTrue(success);

        uint256 initialOwnerBalance = token.balanceOf(owner);

        bounty.recoverERC20(token);
        assertEq(token.balanceOf(address(bounty)), 0);
        assertEq(token.balanceOf(owner), initialOwnerBalance + amount);
    }

    function test_RecoverERC20_RevertWhen_NonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        bounty.recoverERC20(token);
    }
}
