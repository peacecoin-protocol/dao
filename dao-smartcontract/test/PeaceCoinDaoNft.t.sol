// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PeaceCoinDaoNft} from "../src/Governance/PeaceCoinDaoNft.sol";
import {DAOFactory} from "../src/DAOFactory.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {Campaigns} from "../src/Campaigns.sol";

/**
 * @title PeaceCoinDaoNftTest
 * @notice Comprehensive test suite for the PeaceCoinDaoNft contract
 * @dev Tests cover token creation, minting, delegation, revocation, batch operations, and voting power
 */
contract PeaceCoinDaoNftTest is Test {
    // ============ State Variables ============

    /// @notice NFT and SBT contracts
    PeaceCoinDaoNft public nft;
    DAOFactory public daoFactory;
    Campaigns public campaigns;

    /// @notice Test accounts
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    // ============ Constants ============

    string private constant BASE_URI = "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/";
    uint256 private constant VOTING_POWER = 100;
    string private constant TOKEN_URI = "test-uri";

    // ============ Setup ============

    /**
     * @notice Sets up the test environment before each test
     * @dev Deploys and initializes all necessary contracts for testing
     */
    function setUp() public {
        daoFactory = new DAOFactory();
        daoFactory.initialize();
        campaigns = new Campaigns();
        campaigns.initialize(address(daoFactory));
        daoFactory.setCampaignFactory(address(campaigns));

        // Deploy core contracts
        nft = new PeaceCoinDaoNft();
        nft.initialize(BASE_URI, address(daoFactory), address(this), false);
        nft.setMinter(address(this));
    }

    // ============ Helper Functions ============

    /**
     * @notice Helper function to create a token for testing
     * @param tokenId The token ID to create
     * @return The created token ID
     */
    function _createToken(uint256 tokenId) private returns (uint256) {
        nft.createToken(TOKEN_URI, VOTING_POWER);
        assertEq(nft.numberOfTokens(), tokenId, "Token count should match");
        return tokenId;
    }

    /**
     * @notice Helper function to mint a token to an address
     * @param to The address to mint to
     * @param tokenId The token ID to mint
     * @param amount The amount to mint
     */
    function _mintToken(address to, uint256 tokenId, uint256 amount) private {
        nft.mint(to, tokenId, amount);
        assertEq(nft.balanceOf(to, tokenId), amount, "Balance should match minted amount");
    }

    // ============ Token Creation Tests ============

    /**
     * @notice Tests successful token creation by authorized user
     * @dev Verifies that a token can be created and the token count increments correctly
     */
    function test_createToken_Success() public {
        // Act: Create a token
        nft.createToken(TOKEN_URI, VOTING_POWER);

        // Assert: Verify token was created
        assertEq(nft.numberOfTokens(), 1, "Should have one token");
        assertEq(nft.votingPowerPerId(1), VOTING_POWER, "Voting power should be set correctly");
    }

    /**
     * @notice Tests that unauthorized users cannot create tokens
     * @dev Verifies that only authorized users can create tokens
     */
    function test_createToken_Unauthorized() public {
        // Act & Assert: Unauthorized user should not be able to create token
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        nft.createToken(TOKEN_URI, VOTING_POWER);
    }

    // ============ Minting Tests ============

    /**
     * @notice Tests successful token minting
     * @dev Verifies that tokens can be minted to addresses and balances update correctly
     */
    function test_mint_Success() public {
        // Arrange: Create a token first
        _createToken(1);

        // Act: Mint token to alice
        _mintToken(alice, 1, 1);

        // Assert: Verify balance
        assertEq(nft.balanceOf(alice, 1), 1, "Alice should have 1 token");
    }

    /**
     * @notice Tests that unauthorized users cannot mint tokens
     * @dev Verifies that only authorized minters can mint tokens
     */
    function test_mint_Unauthorized() public {
        // Arrange: Create a token and set up unauthorized user
        _createToken(1);

        // Act & Assert: Unauthorized user should not be able to mint
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidMinter.selector));
        nft.mint(alice, 1, 1);
    }

    /**
     * @notice Tests that minting to invalid token ID reverts
     * @dev Verifies that minting to non-existent token IDs fails
     */
    function test_mint_InvalidTokenId() public {
        // Arrange: Create token ID 1
        _createToken(1);

        // Act & Assert: Minting to non-existent token ID should revert
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidTokenId.selector));
        nft.mint(alice, 2, 1);
    }

    /**
     * @notice Tests that minting to token ID 0 reverts
     * @dev Verifies that minting to token ID 0 fails
     */
    function test_mint_TokenIdZero() public {
        // Act & Assert: Minting to token ID 0 should revert
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidTokenId.selector));
        nft.mint(alice, 0, 1);
    }

    // ============ Delegation Tests ============

    /**
     * @notice Tests successful delegation of voting power
     * @dev Verifies that users can delegate their voting power to another address
     */
    function test_delegation_Success() public {
        // Arrange: Create and mint token to alice
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Act: Alice delegates to bob
        vm.prank(alice);
        nft.delegate(bob);

        // Assert: Verify delegation and voting power
        assertEq(nft.delegateOf(alice), bob, "Alice should delegate to bob");
        assertEq(
            nft.getVotes(bob),
            VOTING_POWER,
            "Bob should have voting power from alice's token"
        );
    }

    // ============ Revocation Tests ============

    /**
     * @notice Tests token revocation functionality
     * @dev Verifies that tokens can be revoked and unrevoked
     */
    function test_revoke_Success() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Act: Revoke token
        nft.revoke(1, true);

        // Assert: Verify token is revoked
        assertTrue(nft.isTokenRevoked(1), "Token should be revoked");

        // Act: Unrevoke token
        nft.revoke(1, false);

        // Assert: Verify token is not revoked
        assertFalse(nft.isTokenRevoked(1), "Token should not be revoked");
    }

    // ============ Batch Operations Tests ============

    /**
     * @notice Tests batch minting functionality
     * @dev Verifies that multiple tokens can be minted to multiple recipients in a single transaction
     */
    function test_batchMint_Success() public {
        // Arrange: Create token
        _createToken(1);

        // Prepare batch minting data
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 3;
        amounts[1] = 2;

        // Act: Batch mint tokens
        nft.batchMint(recipients, tokenIds, amounts);

        // Assert: Verify balances
        assertEq(nft.balanceOf(alice, 1), 3, "Alice should have 3 tokens");
        assertEq(nft.balanceOf(bob, 1), 2, "Bob should have 2 tokens");
    }

    // ============ Burn Tests ============

    /**
     * @notice Tests token burning functionality
     * @dev Verifies that tokens can be burned and balances decrease correctly
     */
    function test_burn_Success() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Act: Burn token
        nft.burn(alice, 1, 1);

        // Assert: Verify balance is zero
        assertEq(nft.balanceOf(alice, 1), 0, "Alice's balance should be zero after burn");
    }

    // ============ Voting Power Tests ============

    /**
     * @notice Tests voting power calculation
     * @dev Verifies that voting power is calculated correctly based on token holdings
     */
    function test_votingPower_Calculation() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Assert: Verify voting power
        assertEq(
            nft.getTotalVotingPower(alice),
            VOTING_POWER,
            "Alice should have voting power equal to token voting power"
        );
    }

    /**
     * @notice Tests voting power with multiple tokens
     * @dev Verifies that voting power is calculated correctly for multiple token types
     */
    function test_votingPower_MultipleTokens() public {
        // Arrange: Create multiple tokens with different voting powers
        _createToken(1);
        nft.createToken(TOKEN_URI, 200);

        // Mint different amounts of each token
        _mintToken(alice, 1, 2); // 2 * 100 = 200
        _mintToken(alice, 2, 1); // 1 * 200 = 200

        // Assert: Total voting power should be sum
        assertEq(nft.getTotalVotingPower(alice), 400, "Alice should have 400 voting power");
    }

    /**
     * @notice Tests voting power with zero voting power token
     * @dev Verifies that tokens with zero voting power don't contribute to voting power
     */
    function test_votingPower_ZeroVotingPower() public {
        // Arrange: Create token with zero voting power
        nft.createToken(TOKEN_URI, 0);
        _mintToken(alice, 1, 5);

        // Assert: Voting power should be zero
        assertEq(nft.getTotalVotingPower(alice), 0, "Alice should have zero voting power");
    }

    /**
     * @notice Tests getTokenWeight function
     * @dev Verifies that token weight can be retrieved correctly
     */
    function test_getTokenWeight() public {
        // Arrange: Create token
        _createToken(1);

        // Assert: Verify token weight
        assertEq(nft.getTokenWeight(1), VOTING_POWER, "Token weight should match");
    }

    /**
     * @notice Tests getVotes function
     * @dev Verifies that past votes can be retrieved at a specific block
     */
    function test_getVotes() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Delegate to bob
        vm.prank(alice);
        nft.delegate(bob);
        // Move to next block
        vm.roll(block.number + 1);

        // Assert: Past votes should be available
        assertEq(nft.getVotes(bob), VOTING_POWER, "Past votes should match");
    }

    /**
     * @notice Tests getVotes for future block returns zero
     * @dev Verifies that getVotes returns zero for future blocks
     */
    function test_getVotes_FutureBlock() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Assert: Future block should return zero
        assertEq(nft.getVotes(alice), 0, "Future block should return zero");
    }

    /**
     * @notice Tests getVotes for address with no checkpoints returns zero
     * @dev Verifies that getVotes returns zero for addresses that never had votes
     */
    function test_getVotes_NoCheckpoints() public view {
        // Assert: Address with no votes should return zero
        assertEq(nft.getVotes(alice), 0, "Should return zero for no checkpoints");
    }

    // ============ URI Tests ============

    /**
     * @notice Tests uri function
     * @dev Verifies that token URI is constructed correctly
     */
    function test_uri() public {
        // Arrange: Create token
        _createToken(1);

        // Assert: Verify URI
        string memory expectedUri = string(abi.encodePacked(BASE_URI, TOKEN_URI));
        assertEq(nft.uri(1), expectedUri, "URI should match");
    }

    // ============ setTokenURI Tests ============

    /**
     * @notice Tests successful token URI update
     * @dev Verifies that admin can update token URI and voting power
     */
    function test_setTokenURI_Success() public {
        // Arrange: Create token
        _createToken(1);
        string memory newURI = "new-uri";
        uint256 newVotingPower = 200;

        // Act: Update token URI
        nft.setTokenURI(1, newURI, newVotingPower);

        // Assert: Verify updates
        assertEq(nft.getTokenWeight(1), newVotingPower, "Voting power should be updated");
        string memory expectedUri = string(abi.encodePacked(BASE_URI, newURI));
        assertEq(nft.uri(1), expectedUri, "URI should be updated");
    }

    /**
     * @notice Tests that unauthorized users cannot set token URI
     * @dev Verifies that only admin can update token URI
     */
    function test_setTokenURI_Unauthorized() public {
        // Arrange: Create token
        _createToken(1);

        // Act & Assert: Unauthorized user should not be able to set URI
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        nft.setTokenURI(1, "new-uri", 200);
    }

    /**
     * @notice Tests setTokenURI with invalid token ID
     * @dev Verifies that setting URI for non-existent token reverts
     */
    function test_setTokenURI_InvalidTokenId() public {
        // Act & Assert: Should revert with invalid token ID
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidTokenId.selector));
        nft.setTokenURI(999, "new-uri", 200);
    }

    // ============ Delegation Edge Cases ============

    /**
     * @notice Tests delegation when user has no tokens
     * @dev Verifies that delegation works even without tokens
     */
    function test_delegate_NoTokens() public {
        // Act: Delegate without tokens
        vm.prank(alice);
        nft.delegate(bob);

        // Assert: Delegation should be set
        assertEq(nft.delegateOf(alice), bob, "Alice should delegate to bob");
        assertEq(nft.getVotes(bob), 0, "Bob should have zero votes");
    }

    /**
     * @notice Tests delegation change
     * @dev Verifies that changing delegation moves votes correctly
     */
    function test_delegate_ChangeDelegation() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Act: Delegate to bob
        vm.prank(alice);
        nft.delegate(bob);

        // Assert: Bob has votes
        assertEq(nft.getVotes(bob), VOTING_POWER, "Bob should have votes");

        // Act: Change delegation to charlie
        address charlie = makeAddr("charlie");
        vm.prank(alice);
        nft.delegate(charlie);

        // Assert: Votes moved from bob to charlie
        assertEq(nft.getVotes(bob), 0, "Bob should have zero votes");
        assertEq(nft.getVotes(charlie), VOTING_POWER, "Charlie should have votes");
    }

    /**
     * @notice Tests delegation with tokens but prev is address(0)
     * @dev Verifies that first-time delegation with tokens moves votes correctly
     */
    function test_delegate_FirstTimeWithTokens() public {
        // Arrange: Create and mint token (no delegation yet)
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Act: Delegate to bob (first time, prev is address(0))
        vm.prank(alice);
        nft.delegate(bob);

        // Assert: Votes should be moved to bob
        assertEq(nft.getVotes(bob), VOTING_POWER, "Bob should have votes");
        assertEq(nft.getVotes(alice), 0, "Alice should have zero votes");
    }

    /**
     * @notice Tests delegation with tokens and prev delegatee
     * @dev Verifies that changing delegation moves votes from prev to new delegatee
     */
    function test_delegate_WithPrevDelegatee() public {
        // Arrange: Create and mint token, delegate to bob
        _createToken(1);
        _mintToken(alice, 1, 1);
        vm.prank(alice);
        nft.delegate(bob);

        // Assert: Bob has votes
        assertEq(nft.getVotes(bob), VOTING_POWER, "Bob should have votes");

        // Act: Change to charlie (prev is bob, not address(0))
        address charlie = makeAddr("charlie");
        vm.prank(alice);
        nft.delegate(charlie);

        // Assert: Votes moved from bob to charlie
        assertEq(nft.getVotes(bob), 0, "Bob should have zero votes");
        assertEq(nft.getVotes(charlie), VOTING_POWER, "Charlie should have votes");
    }

    /**
     * @notice Tests delegation with zero total votes
     * @dev Verifies that delegation with zero votes doesn't move votes
     */
    function test_delegate_ZeroTotalVotes() public {
        // Arrange: Create token with zero voting power and mint
        nft.createToken(TOKEN_URI, 0);
        _mintToken(alice, 1, 1);

        // Act: Delegate to bob
        vm.prank(alice);
        nft.delegate(bob);

        // Assert: No votes should be moved
        assertEq(nft.getVotes(bob), 0, "Bob should have zero votes");
        assertEq(nft.delegateOf(alice), bob, "Delegation should still be set");
    }

    // ============ Mint Edge Cases ============

    /**
     * @notice Tests minting with zero amount reverts
     * @dev Verifies that minting zero amount reverts
     */
    function test_mint_ZeroAmount() public {
        // Arrange: Create token
        _createToken(1);

        // Act & Assert: Minting zero amount should revert
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidAmount.selector));
        nft.mint(alice, 1, 0);
    }

    /**
     * @notice Tests minting to zero address reverts
     * @dev Verifies that minting to address(0) reverts
     */
    function test_mint_ZeroAddress() public {
        // Arrange: Create token
        _createToken(1);

        // Act & Assert: Minting to zero address should revert
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidAddress.selector));
        nft.mint(address(0), 1, 1);
    }

    /**
     * @notice Tests minting updates voting power for delegatee
     * @dev Verifies that minting updates voting power when user has delegatee
     */
    function test_mint_UpdatesVotingPowerForDelegatee() public {
        // Arrange: Create token and set up delegation
        _createToken(1);
        vm.prank(alice);
        nft.delegate(bob);

        // Act: Mint token to alice
        _mintToken(alice, 1, 1);

        // Assert: Bob should have voting power
        assertEq(nft.getVotes(bob), VOTING_POWER, "Bob should have voting power");
    }

    /**
     * @notice Tests minting with zero voting power doesn't update votes
     * @dev Verifies that minting tokens with zero voting power doesn't affect votes
     */
    function test_mint_ZeroVotingPower() public {
        // Arrange: Create token with zero voting power
        nft.createToken(TOKEN_URI, 0);
        vm.prank(alice);
        nft.delegate(bob);

        // Act: Mint token
        _mintToken(alice, 1, 1);

        // Assert: Bob should have zero votes
        assertEq(nft.getVotes(bob), 0, "Bob should have zero votes");
    }

    /**
     * @notice Tests minting without delegatee doesn't update votes
     * @dev Verifies that minting tokens when user has no delegatee doesn't affect votes
     */
    function test_mint_NoDelegatee() public {
        // Arrange: Create token
        _createToken(1);

        // Act: Mint token without delegation
        _mintToken(alice, 1, 1);

        // Assert: No votes should be recorded
        assertEq(nft.getVotes(alice), 0, "Alice should have zero votes without delegation");
    }

    /**
     * @notice Tests minting with delegatee but zero voting power doesn't update votes
     * @dev Verifies the combined condition: delegatee exists but voting power is zero
     */
    function test_mint_DelegateeButZeroVotingPower() public {
        // Arrange: Create token with zero voting power and set up delegation
        nft.createToken(TOKEN_URI, 0);
        vm.prank(alice);
        nft.delegate(bob);

        // Act: Mint token
        _mintToken(alice, 1, 1);

        // Assert: Bob should have zero votes
        assertEq(nft.getVotes(bob), 0, "Bob should have zero votes");
    }

    // ============ Burn Edge Cases ============

    /**
     * @notice Tests burning with insufficient balance reverts
     * @dev Verifies that burning more than balance reverts
     */
    function test_burn_InsufficientBalance() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Act & Assert: Burning more than balance should revert
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidBalance.selector));
        nft.burn(alice, 1, 2);
    }

    /**
     * @notice Tests burning with zero amount reverts
     * @dev Verifies that burning zero amount reverts
     */
    function test_burn_ZeroAmount() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Act & Assert: Burning zero amount should revert
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidAmount.selector));
        nft.burn(alice, 1, 0);
    }

    /**
     * @notice Tests burning updates voting power for delegatee
     * @dev Verifies that burning reduces voting power when user has delegatee
     */
    function test_burn_UpdatesVotingPowerForDelegatee() public {
        // Arrange: Create token, mint, and delegate
        _createToken(1);
        _mintToken(alice, 1, 2);
        vm.prank(alice);
        nft.delegate(bob);

        // Assert: Bob has voting power
        assertEq(nft.getVotes(bob), VOTING_POWER * 2, "Bob should have voting power");

        // Act: Burn one token
        nft.burn(alice, 1, 1);

        // Assert: Voting power reduced
        assertEq(nft.getVotes(bob), VOTING_POWER, "Bob should have reduced voting power");
    }

    /**
     * @notice Tests burning without delegatee doesn't update votes
     * @dev Verifies that burning tokens when user has no delegatee doesn't affect votes
     */
    function test_burn_NoDelegatee() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Act: Burn token without delegation
        nft.burn(alice, 1, 1);

        // Assert: No votes should be affected
        assertEq(nft.getVotes(alice), 0, "Alice should have zero votes");
    }

    /**
     * @notice Tests burning with delegatee but zero voting power doesn't update votes
     * @dev Verifies the combined condition: delegatee exists but voting power is zero
     */
    function test_burn_DelegateeButZeroVotingPower() public {
        // Arrange: Create token with zero voting power, mint, and delegate
        nft.createToken(TOKEN_URI, 0);
        _mintToken(alice, 1, 1);
        vm.prank(alice);
        nft.delegate(bob);

        // Act: Burn token
        nft.burn(alice, 1, 1);

        // Assert: Bob should still have zero votes
        assertEq(nft.getVotes(bob), 0, "Bob should have zero votes");
    }

    // ============ Batch Mint Edge Cases ============

    /**
     * @notice Tests batch mint with mismatched array lengths reverts
     * @dev Verifies that batch mint reverts when arrays have different lengths
     */
    function test_batchMint_MismatchedArrays() public {
        // Arrange: Create token
        _createToken(1);

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // Act & Assert: Should revert with mismatched arrays
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidArrayLength.selector));
        nft.batchMint(recipients, tokenIds, amounts);
    }

    /**
     * @notice Tests batch mint with empty arrays reverts
     * @dev Verifies that batch mint reverts with empty arrays
     */
    function test_batchMint_EmptyArrays() public {
        // Arrange: Create empty arrays
        address[] memory recipients = new address[](0);
        uint256[] memory tokenIds = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        // Act & Assert: Should revert with empty arrays
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidArrayLength.selector));
        nft.batchMint(recipients, tokenIds, amounts);
    }

    /**
     * @notice Tests batch mint with invalid token ID reverts
     * @dev Verifies that batch mint reverts with invalid token ID
     */
    function test_batchMint_InvalidTokenId() public {
        // Arrange: Create token
        _createToken(1);

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 999; // Invalid token ID

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // Act & Assert: Should revert with invalid token ID
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidTokenId.selector));
        nft.batchMint(recipients, tokenIds, amounts);
    }

    /**
     * @notice Tests batch mint with zero amount reverts
     * @dev Verifies that batch mint reverts with zero amount
     */
    function test_batchMint_ZeroAmount() public {
        // Arrange: Create token
        _createToken(1);

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        // Act & Assert: Should revert with zero amount
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidAmount.selector));
        nft.batchMint(recipients, tokenIds, amounts);
    }

    /**
     * @notice Tests batch mint with zero address reverts
     * @dev Verifies that batch mint reverts with zero address
     */
    function test_batchMint_ZeroAddress() public {
        // Arrange: Create token
        _createToken(1);

        address[] memory recipients = new address[](1);
        recipients[0] = address(0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // Act & Assert: Should revert with zero address
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidAddress.selector));
        nft.batchMint(recipients, tokenIds, amounts);
    }

    /**
     * @notice Tests batch mint updates voting power for delegatees
     * @dev Verifies that batch mint updates voting power correctly
     */
    function test_batchMint_UpdatesVotingPower() public {
        // Arrange: Create token and set up delegations
        _createToken(1);
        vm.prank(alice);
        nft.delegate(bob);

        address charlie = makeAddr("charlie");
        vm.prank(charlie);
        nft.delegate(bob);

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = charlie;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // Act: Batch mint
        nft.batchMint(recipients, tokenIds, amounts);

        // Assert: Bob should have combined voting power
        assertEq(nft.getVotes(bob), VOTING_POWER * 2, "Bob should have combined voting power");
    }

    /**
     * @notice Tests batch mint without delegatees doesn't update votes
     * @dev Verifies that batch mint when recipients have no delegatees doesn't affect votes
     */
    function test_batchMint_NoDelegatees() public {
        // Arrange: Create token
        _createToken(1);

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // Act: Batch mint without delegations
        nft.batchMint(recipients, tokenIds, amounts);

        // Assert: No votes should be recorded
        assertEq(nft.getVotes(alice), 0, "Alice should have zero votes");
        assertEq(nft.getVotes(bob), 0, "Bob should have zero votes");
    }

    /**
     * @notice Tests batch mint with zero voting power doesn't update votes
     * @dev Verifies that batch mint with zero voting power tokens doesn't affect votes
     */
    function test_batchMint_ZeroVotingPower() public {
        // Arrange: Create token with zero voting power and set up delegation
        nft.createToken(TOKEN_URI, 0);
        vm.prank(alice);
        nft.delegate(bob);

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // Act: Batch mint
        nft.batchMint(recipients, tokenIds, amounts);

        // Assert: Bob should have zero votes
        assertEq(nft.getVotes(bob), 0, "Bob should have zero votes");
    }

    /**
     * @notice Tests batch mint with token ID 0 reverts
     * @dev Verifies that batch mint with token ID 0 fails
     */
    function test_batchMint_TokenIdZero() public {
        // Arrange: Create token
        _createToken(1);

        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0; // Invalid token ID

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // Act & Assert: Should revert with invalid token ID
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidTokenId.selector));
        nft.batchMint(recipients, tokenIds, amounts);
    }

    // ============ Create Token Edge Cases ============

    /**
     * @notice Tests createToken with invalid creator reverts
     * @dev Verifies that only the DAO creator can create tokens
     */
    function test_createToken_InvalidCreator() public {
        // Act & Assert: Should revert when not the default admin
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        nft.createToken(TOKEN_URI, VOTING_POWER);
    }

    // ============ SupportsInterface Tests ============

    /**
     * @notice Tests supportsInterface function
     * @dev Verifies that supportsInterface returns correct values
     */
    function test_supportsInterface() public view {
        // Test ERC1155 interface
        assertTrue(nft.supportsInterface(0xd9b67a26), "Should support ERC1155 interface");

        // Test AccessControl interface
        assertTrue(nft.supportsInterface(0x7965db0b), "Should support AccessControl interface");

        // Test invalid interface
        assertFalse(nft.supportsInterface(0x12345678), "Should not support invalid interface");
    }

    // ============ Additional Edge Cases ============

    /**
     * @notice Tests minting with id > numberOfTokens reverts
     * @dev Verifies the redundant check in mint function
     */
    function test_mint_IdGreaterThanNumberOfTokens() public {
        // Arrange: Create token (numberOfTokens = 1)
        _createToken(1);

        // Act & Assert: Minting to ID 2 should revert (even though modifier checks this)
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidTokenId.selector));
        nft.mint(alice, 2, 1);
    }

    // ============ Complex Scenarios ============

    /**
     * @notice Tests that revoke doesn't affect voting power
     * @dev Verifies that revoking a token doesn't change voting power calculations
     */
    function test_revoke_DoesNotAffectVotingPower() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);
        vm.prank(alice);
        nft.delegate(bob);

        uint256 votesBefore = nft.getVotes(bob);

        // Act: Revoke token
        nft.revoke(1, true);

        // Assert: Voting power should remain the same
        assertEq(nft.getVotes(bob), votesBefore, "Voting power should not change");
        assertTrue(nft.isTokenRevoked(1), "Token should be revoked");
    }

    // ============ Initialization Tests ============

    /**
     * @notice Tests initialize for NFT configuration
     * @dev Verifies name, symbol, and admin role when _isSBT is false
     */
    function test_initialize_NFT_Config() public {
        PeaceCoinDaoNft nftLocal = new PeaceCoinDaoNft();
        nftLocal.initialize(BASE_URI, address(daoFactory), alice, false);

        assertEq(nftLocal.name(), "PEACECOIN DAO NFT", "NFT name should match");
        assertEq(nftLocal.symbol(), "PCE_NFT", "NFT symbol should match");
        assertTrue(nftLocal.hasRole(nftLocal.DEFAULT_ADMIN_ROLE(), alice), "Alice should be admin");
    }

    /**
     * @notice Tests initialize for SBT configuration
     * @dev Verifies name and symbol when _isSBT is true
     */
    function test_initialize_SBT_Config() public {
        PeaceCoinDaoNft nftLocal = new PeaceCoinDaoNft();
        nftLocal.initialize(BASE_URI, address(daoFactory), alice, true);

        assertEq(nftLocal.name(), "PEACECOIN DAO SBT", "SBT name should match");
        assertEq(nftLocal.symbol(), "PCE_SBT", "SBT symbol should match");
    }

    // ============ Minter Role Tests ============

    /**
     * @notice Tests campaignFactory can mint even if not set as a minter
     * @dev Verifies onlyMinter allows the DAOFactory campaignFactory address
     */
    function test_mint_AllowsCampaignFactory() public {
        _createToken(1);

        vm.prank(address(campaigns));
        nft.mint(alice, 1, 1);

        assertEq(nft.balanceOf(alice, 1), 1, "Alice should receive token from campaignFactory");
    }

    // ============ Overflow Tests ============

    /**
     * @notice Tests mint reverts when votes exceed uint224 max
     * @dev Verifies VoteOverflow on delegate checkpoint update
     */
    function test_mint_VoteOverflow() public {
        _createToken(1);
        nft.setTokenURI(1, TOKEN_URI, uint256(type(uint224).max) + 1);

        vm.prank(alice);
        nft.delegate(bob);

        vm.expectRevert(abi.encodeWithSelector(PeaceCoinDaoNft.VoteOverflow.selector));
        nft.mint(alice, 1, 1);
    }

    /**
     * @notice Tests mint reverts when vote calculation overflows uint256
     * @dev Verifies VoteCalculationOverflow in _update
     */
    function test_mint_VoteCalculationOverflow() public {
        _createToken(1);
        nft.setTokenURI(1, TOKEN_URI, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(PeaceCoinDaoNft.VoteCalculationOverflow.selector));
        nft.mint(alice, 1, 2);
    }

    /**
     * @notice Tests total voting power calculation overflow after multiple mints
     * @dev Verifies VoteCalculationOverflow in _calculateTotalVotes
     */
    function test_getTotalVotingPower_Overflow() public {
        _createToken(1);
        nft.setTokenURI(1, TOKEN_URI, type(uint256).max);

        nft.mint(alice, 1, 1);
        nft.mint(alice, 1, 1);

        vm.expectRevert(abi.encodeWithSelector(PeaceCoinDaoNft.VoteCalculationOverflow.selector));
        nft.getTotalVotingPower(alice);
    }
}
