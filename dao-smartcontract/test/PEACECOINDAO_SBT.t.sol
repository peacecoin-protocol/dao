// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PEACECOINDAO_SBT} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {PEACECOINDAO_NFT} from "../src/Governance/PEACECOINDAO_NFT.sol";
import {DAOFactory} from "../src/DAOFactory.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {IDAOFactory} from "../src/interfaces/IDAOFactory.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {PCECommunityGovToken} from "../src/mocks/PCECommunityGovToken.sol";

/**
 * @title PEACECOINDAO_SBTTest
 * @notice Comprehensive test suite for the PEACECOINDAO_SBT contract
 * @dev Tests cover token creation, minting, non-transferability, and access control
 */
contract PEACECOINDAO_SBTTest is Test {
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
        daoFactory = address(factory);
        factory.setImplementation(address(timelock), address(governor), address(governanceToken));

        // Initialize SBT and NFT contracts
        sbt.initialize("PEACECOIN DAO SBT", "PCE_SBT", BASE_URI, address(factory));
        nft.initialize("PEACECOIN DAO NFT", "PCE_NFT", BASE_URI, address(factory));

        // Grant necessary permissions
        IAccessControl(address(factory)).grantRole(DAO_MANAGER_ROLE, address(this));
        nft.setMinter(address(this));
        sbt.setMinter(address(this));

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
        sbt.createToken(TOKEN_URI, VOTING_POWER, daoId);
        assertEq(sbt.numberOfTokens(), tokenId, "Token count should match");
        return tokenId;
    }

    /**
     * @notice Helper function to mint a token to an address
     * @param to The address to mint to
     * @param tokenId The token ID to mint
     * @param amount The amount to mint
     */
    function _mintToken(address to, uint256 tokenId, uint256 amount) private {
        sbt.mint(to, tokenId, amount);
        assertEq(sbt.balanceOf(to, tokenId), amount, "Balance should match minted amount");
    }

    // ============ Token Creation Tests ============

    /**
     * @notice Tests successful token creation by authorized user
     * @dev Verifies that a token can be created and the token count increments correctly
     */
    function test_createToken_Success() public {
        // Act: Create a token
        sbt.createToken(TOKEN_URI, VOTING_POWER, daoId);

        // Assert: Verify token was created
        assertEq(sbt.numberOfTokens(), 1, "Should have one token");
    }

    /**
     * @notice Tests that unauthorized users cannot create tokens
     * @dev Verifies that only authorized users can create tokens
     */
    function test_createToken_Unauthorized() public {
        // Act & Assert: Unauthorized user should not be able to create token
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        sbt.createToken(TOKEN_URI, VOTING_POWER, daoId);
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
        assertEq(sbt.balanceOf(alice, 1), 1, "Alice should have 1 token");
    }

    // ============ Transfer Tests ============

    /**
     * @notice Tests that SBT tokens cannot be transferred
     * @dev Verifies that safeTransferFrom reverts with NonTransferable error
     */
    function test_transferFrom_Reverts() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Act & Assert: Transfer should revert
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.NonTransferable.selector));
        sbt.safeTransferFrom(alice, bob, 1, 1, "");
    }

    /**
     * @notice Tests that SBT tokens cannot be batch transferred
     * @dev Verifies that safeBatchTransferFrom reverts with NonTransferable error
     */
    function test_safeBatchTransferFrom_Reverts() public {
        // Arrange: Create and mint token
        _createToken(1);
        _mintToken(alice, 1, 1);

        // Prepare batch transfer data
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // Act & Assert: Batch transfer should revert
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.NonTransferable.selector));
        sbt.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }
}
