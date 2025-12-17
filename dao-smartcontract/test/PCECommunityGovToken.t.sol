// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {PCECommunityGovToken} from "../src/mocks/PCECommunityGovToken.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title PCECommunityGovTokenTest
 * @notice Comprehensive test suite for PCECommunityGovToken contract
 * @dev Tests initialization, deposit, and withdraw functionality
 */
contract PCECommunityGovTokenTest is Test {
    // State variables
    MockERC20 public erc20CommunityToken;
    PCECommunityGovToken public pceToken;
    address public owner;
    address public user;
    uint256 public constant INITIAL_BALANCE = 5e18;

    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    /**
     * @notice Sets up the test environment before each test
     * @dev Deploys contracts, initializes token, and prepares user with balance
     */
    function setUp() public {
        owner = address(this);
        user = makeAddr("User");

        erc20CommunityToken = new MockERC20();
        pceToken = new PCECommunityGovToken();
        pceToken.initialize(address(erc20CommunityToken));

        // Mint tokens to user and approve spending
        erc20CommunityToken.mint(user, INITIAL_BALANCE);
        vm.prank(user);
        erc20CommunityToken.approve(address(pceToken), INITIAL_BALANCE);
    }

    // ============================================================================
    // Initialization Tests
    // ============================================================================

    /**
     * @notice Tests that the contract initializes with correct parameters
     * @dev Verifies token name, symbol, owner, and community token address
     */
    function test_Initialization() public view {
        assertEq(pceToken.name(), "Community Governance Token", "Token name should match");
        assertEq(pceToken.symbol(), "COM_GOV", "Token symbol should match");
        assertEq(pceToken.owner(), owner, "Owner should be set correctly");
        assertEq(
            address(pceToken.communityToken()),
            address(erc20CommunityToken),
            "Community token address should match"
        );
    }

    // ============================================================================
    // Deposit Tests
    // ============================================================================

    /**
     * @notice Tests that deposit reverts when amount is zero
     * @dev Ensures zero amount deposits are rejected
     */
    function test_Deposit_RevertsWhen_AmountIsZero() public {
        vm.expectRevert("Stake: can't stake 0");
        pceToken.deposit(0);
    }

    /**
     * @notice Tests successful deposit functionality
     * @dev Verifies token transfer, balance updates, and event emission
     */
    function test_Deposit() public {
        vm.prank(user);
        vm.expectEmit(true, false, false, false);
        emit Deposited(user, INITIAL_BALANCE);
        pceToken.deposit(INITIAL_BALANCE);

        // Verify token balances
        assertEq(
            erc20CommunityToken.balanceOf(address(pceToken)),
            INITIAL_BALANCE,
            "Contract should hold deposited tokens"
        );
        assertEq(erc20CommunityToken.balanceOf(user), 0, "User should have no ERC20 tokens");
        assertEq(
            pceToken.balanceOf(user),
            INITIAL_BALANCE,
            "User should receive governance tokens"
        );
        assertEq(pceToken.totalSupply(), INITIAL_BALANCE, "Total supply should match deposit");
    }

    // ============================================================================
    // Withdraw Tests
    // ============================================================================

    /**
     * @notice Tests that withdraw reverts when amount is zero
     * @dev Ensures zero amount withdrawals are rejected
     */
    function test_Withdraw_RevertsWhen_AmountIsZero() public {
        vm.expectRevert("Amount should be greater then 0");
        pceToken.withdraw(0);
    }

    /**
     * @notice Tests successful withdraw functionality
     * @dev Verifies token return, balance updates, and event emission
     */
    function test_Withdraw() public {
        // First deposit tokens
        vm.prank(user);
        pceToken.deposit(INITIAL_BALANCE);

        // Then withdraw
        vm.prank(user);
        vm.expectEmit(true, false, false, false);
        emit Withdrawn(user, INITIAL_BALANCE);
        pceToken.withdraw(INITIAL_BALANCE);

        // Verify token balances after withdrawal
        assertEq(
            erc20CommunityToken.balanceOf(address(pceToken)),
            0,
            "Contract should have no tokens after withdrawal"
        );
        assertEq(
            erc20CommunityToken.balanceOf(user),
            INITIAL_BALANCE,
            "User should receive ERC20 tokens back"
        );
        assertEq(pceToken.balanceOf(user), 0, "User should have no governance tokens");
        assertEq(pceToken.totalSupply(), 0, "Total supply should be zero after withdrawal");
    }
}
