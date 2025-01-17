// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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

    function test_Initialize() public {
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

    function test_AddProposalBounty() public {
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
    }

    function test_ClaimProposalBounty() public {
        uint256 proposalId = 0;
        uint256 amount = 50e18;

        // Setup proposal and bounty
        governance.setProposalState(proposalId, uint8(4));
        governance.setProposer(proposalId, user1);

        bounty.addProposalBounty(proposalId, amount);

        // Claim bounty
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit ClaimedBounty(user1, amount + BOUNTY_AMOUNT);
        bounty.claimProposalBounty();

        assertEq(token.balanceOf(user1), INITIAL_BALANCE + amount + BOUNTY_AMOUNT);
    }

    function test_ClaimContributorBounty() public {
        uint256 amount = 50e18;

        // Setup contributor and bounty
        bounty.setContributor(user1, true);
        token.approve(address(bounty), amount);
        bounty.addContributorBounty(user1, amount);

        // Claim bounty
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit ClaimedBounty(user1, amount + BOUNTY_AMOUNT);
        bounty.claimContributorBounty();

        assertEq(token.balanceOf(user1), INITIAL_BALANCE + amount + BOUNTY_AMOUNT);
    }

    function test_RecoverERC20() public {
        uint256 amount = 50e18;
        token.transfer(address(bounty), amount);

        bounty.recoverERC20(token);
        assertEq(token.balanceOf(address(bounty)), 0);
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

        // Set proposal state to something other than Succeeded (4)
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

    function test_RevertWhen_NonOwnerRecoversERC20() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        bounty.recoverERC20(token);
    }
}
