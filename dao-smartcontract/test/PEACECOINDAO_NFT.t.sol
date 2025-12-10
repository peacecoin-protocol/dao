// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PEACECOINDAO_NFT} from "../src/Governance/PEACECOINDAO_NFT.sol";
import {PEACECOINDAO_SBT} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {DAOFactory} from "../src/DAOFactory.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {IDAOFactory} from "../src/interfaces/IDAOFactory.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {PCECommunityGovToken} from "../src/mocks/PCECommunityGovToken.sol";

/**
 * @title PEACECOINDAO_NFTTest
 * @notice Comprehensive test suite for the PEACECOINDAO_NFT contract
 * @dev Tests cover token creation, minting, delegation, revocation, batch operations, and voting power
 */
contract PEACECOINDAO_NFTTest is Test {
    // ============ State Variables ============

    /// @notice Governance contracts
    Timelock public timelock;
    GovernorAlpha public governor;
    PCECommunityGovToken public governanceToken;

    /// @notice NFT and SBT contracts
    PEACECOINDAO_NFT public nft;
    PEACECOINDAO_SBT public sbt;

    /// @notice Test accounts
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public daoFactory;

    /// @notice Mock ERC20 token for DAO creation
    MockERC20 public mockERC20;

    /// @notice DAO identifier
    bytes32 public daoId;

    // ============ Constants ============

    /// @notice DAO configuration constants
    string private constant DAO_NAME = "Test DAO";
    string private constant TOKEN_URI = "test-uri";
    uint256 private constant VOTING_POWER = 100;
    string private constant BASE_URI = "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/";
    bytes32 private constant DAO_MANAGER_ROLE = keccak256("DAO_MANAGER_ROLE");

    /// @notice Governance parameters
    uint256 private constant VOTING_DELAY = 1;
    uint256 private constant VOTING_PERIOD = 1000;
    uint256 private constant PROPOSAL_THRESHOLD = 1000;
    uint256 private constant QUORUM_VOTES = 1000;
    uint256 private constant TIMELOCK_DELAY = 1000;

    /// @notice Social media configuration for DAO
    IDAOFactory.SocialConfig SOCIAL_CONFIG =
        IDAOFactory.SocialConfig({
            description: "Test Description",
            website: "https://website.com",
            linkedin: "https://linkedin.com",
            twitter: "https://twitter.com",
            telegram: "https://telegram.com"
        });

    // ============ Setup ============

    /**
     * @notice Sets up the test environment before each test
     * @dev Deploys and initializes all necessary contracts for testing
     */
    function setUp() public {
        // Deploy core contracts
        sbt = new PEACECOINDAO_SBT();
        nft = new PEACECOINDAO_NFT();
        timelock = new Timelock();
        governor = new GovernorAlpha();
        governanceToken = new PCECommunityGovToken();

        // Deploy and configure DAO factory
        DAOFactory factory = new DAOFactory(address(sbt), address(nft));
        factory.setImplementation(address(timelock), address(governor), address(governanceToken));

        // Initialize SBT and NFT contracts
        sbt.initialize("PEACECOIN DAO SBT", "PCE_SBT", BASE_URI, address(factory));
        nft.initialize("PEACECOIN DAO NFT", "PCE_NFT", BASE_URI, address(factory));

        // Grant necessary permissions
        IAccessControl(address(factory)).grantRole(DAO_MANAGER_ROLE, address(this));
        nft.setMinter(address(this));

        // Deploy and initialize mock ERC20 token
        mockERC20 = new MockERC20();
        mockERC20.initialize();

        // Create a test DAO
        daoId = factory.createDAO(
            DAO_NAME,
            SOCIAL_CONFIG,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_VOTES,
            TIMELOCK_DELAY
        );
    }

    // ============ Helper Functions ============

    /**
     * @notice Helper function to create a token for testing
     * @param tokenId The token ID to create
     * @return The created token ID
     */
    function _createToken(uint256 tokenId) private returns (uint256) {
        nft.createToken(TOKEN_URI, VOTING_POWER, daoId);
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
        nft.createToken(TOKEN_URI, VOTING_POWER, daoId);

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
        nft.createToken(TOKEN_URI, VOTING_POWER, daoId);
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
}
