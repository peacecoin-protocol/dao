// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {Campaigns} from "../src/Campaigns.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PEACECOINDAO_SBT} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {PEACECOINDAO_NFT} from "../src/Governance/PEACECOINDAO_NFT.sol";
import {DAOFactory} from "../src/DAOFactory.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {ITokens} from "../src/interfaces/ITokens.sol";
import {IDAOFactory} from "../src/interfaces/IDAOFactory.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {PCECommunityGovToken} from "../src/mocks/PCECommunityGovToken.sol";
import {MultipleVotings} from "../src/Governance/MultipleVotings.sol";

/**
 * @title CampaignsTest
 * @notice Comprehensive test suite for the Campaigns contract
 * @dev Tests campaign creation, winner management, claiming functionality, and access control
 */
contract CampaignsTest is Test {
    using Strings for uint256;

    // ============ Contract Instances ============

    /// @notice Campaigns contract under test
    Campaigns public campaigns;

    /// @notice NFT contract for campaign rewards
    PEACECOINDAO_NFT public nft;

    /// @notice SBT contract for DAO membership
    PEACECOINDAO_SBT public sbt;

    /// @notice Multiple voting contract for DAO governance
    MultipleVotings public multipleVoting;

    // ============ Test Accounts ============

    /// @notice DAO manager with administrative privileges
    address public daoManager = makeAddr("DaoManager");

    /// @notice Regular user account for testing
    address public user = makeAddr("User");

    /// @notice Test account for campaign winners
    address public alice = makeAddr("Alice");

    /// @notice Test account for campaign winners
    address public bob = makeAddr("Bob");

    /// @notice Test account not whitelisted for campaigns
    address public notWhitelistedUser = makeAddr("NotWhitelisted");

    // ============ Test Data ============

    /// @notice Test gist hash for signature validation
    bytes32 public gist = keccak256(abi.encodePacked("testGist"));

    /// @notice Default campaign title for testing
    string public campaignTitle = "Test Campaign";

    /// @notice Default campaign description for testing
    string public campaignDescription = "Test Description";

    // ============ Governance Contracts ============

    /// @notice Timelock contract for governance proposals
    Timelock public timelock;

    /// @notice Governor contract for DAO governance
    GovernorAlpha public governor;

    /// @notice Governance token for voting
    PCECommunityGovToken public governanceToken;

    /// @notice DAO factory contract address
    address public daoFactory;

    /// @notice Mock ERC20 token for DAO creation
    MockERC20 public mockERC20;

    /// @notice DAO identifier for test campaigns
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

    /// @notice Campaign configuration constants
    uint256 private constant CAMPAIGN_START_OFFSET = 100;
    uint256 private constant CAMPAIGN_DURATION = 1000;
    uint256 private constant CAMPAIGN_CLAIM_AMOUNT = 2;
    uint256 private constant CAMPAIGN_TOTAL_AMOUNT = 10;
    uint256 private constant CAMPAIGN_SBT_ID = 1;
    uint256 private constant CAMPAIGN_TOKEN_ID = 1;

    // ============ Configuration Objects ============

    /// @notice Social media configuration for DAO
    IDAOFactory.SocialConfig SOCIAL_CONFIG =
        IDAOFactory.SocialConfig({
            description: "Test Description",
            website: "https://website.com",
            linkedin: "https://linkedin.com",
            twitter: "https://twitter.com",
            telegram: "https://telegram.com"
        });

    /// @notice Default campaign structure for testing
    Campaigns.Campaign public defaultCampaign;

    // ============ Setup ============

    /**
     * @notice Sets up the test environment before each test
     * @dev Deploys and initializes all necessary contracts for testing campaign functionality
     */
    function setUp() public {
        vm.startPrank(daoManager);

        // Deploy core governance contracts
        PEACECOINDAO_SBT sbtImplementation = new PEACECOINDAO_SBT();
        PEACECOINDAO_NFT nftImplementation = new PEACECOINDAO_NFT();
        MultipleVotings multipleVotingImplementation = new MultipleVotings();
        timelock = new Timelock();
        governor = new GovernorAlpha();
        governanceToken = new PCECommunityGovToken();

        // Deploy and configure DAO factory
        DAOFactory factory = new DAOFactory();
        factory.initialize();
        daoFactory = address(factory);
        factory.setImplementation(
            address(timelock),
            address(governor),
            address(governanceToken),
            address(multipleVotingImplementation),
            address(sbtImplementation),
            address(nftImplementation)
        );

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

        defaultCampaign = Campaigns.Campaign({
            daoId: daoId,
            sbtId: CAMPAIGN_SBT_ID,
            title: campaignTitle,
            description: campaignDescription,
            token: address(0),
            tokenType: Campaigns.TokenType.NFT,
            claimAmount: CAMPAIGN_CLAIM_AMOUNT,
            totalAmount: CAMPAIGN_TOTAL_AMOUNT,
            startDate: block.timestamp + CAMPAIGN_START_OFFSET,
            endDate: block.timestamp + CAMPAIGN_START_OFFSET + CAMPAIGN_DURATION,
            validateSignatures: false,
            creator: address(0)
        });

        (, , address sbtAddress, address nftAddress, , , , ) = factory.daoConfigs(daoId);
        sbt = PEACECOINDAO_SBT(sbtAddress);
        nft = PEACECOINDAO_NFT(nftAddress);

        // Deploy and initialize Campaigns contract
        campaigns = new Campaigns();
        campaigns.initialize(address(factory));

        factory.setCampaignFactory(address(campaigns));

        vm.stopPrank();
    }

    // ============ Helper Functions ============

    /**
     * @notice Creates a test campaign with default configuration
     * @dev Helper function to set up a campaign for testing
     * @return campaignId The ID of the created campaign
     */
    function _createTestCampaign() internal returns (uint256 campaignId) {
        vm.startPrank(daoManager);

        // Create NFT token for the campaign
        nft.createToken(TOKEN_URI, VOTING_POWER);
        vm.roll(block.number + 1);

        // Create the campaign
        campaigns.createCampaign(defaultCampaign);
        campaignId = campaigns.campaignId();

        vm.stopPrank();

        return campaignId;
    }

    /**
     * @notice Adds winners to a campaign
     * @dev Helper function to add test winners to a campaign
     * @param campaignId The ID of the campaign
     * @param winners Array of winner addresses
     * @param gists Array of gist hashes for signature validation
     */
    function _addCampaignWinners(
        uint256 campaignId,
        address[] memory winners,
        bytes32[] memory gists
    ) internal {
        vm.prank(daoManager);
        campaigns.addCampWinners(campaignId, winners, gists);
    }

    /**
     * @notice Tests successful campaign creation
     * @dev Verifies that campaigns can be created with valid parameters
     */
    function test_createCampaign() public {
        // Create NFT token and campaign
        vm.startPrank(daoManager);
        nft.createToken(TOKEN_URI, VOTING_POWER);
        vm.roll(block.number + 1);
        campaigns.createCampaign(defaultCampaign);
        vm.stopPrank();

        uint256 campaignId = campaigns.campaignId();

        // Verify NFT creator is set correctly
        assertEq(
            ITokens(address(nft)).creators(CAMPAIGN_TOKEN_ID),
            daoManager,
            "NFT creator should be set to daoManager"
        );

        // Retrieve and verify campaign data
        (
            ,
            uint256 sbtId,
            string memory title,
            string memory description,
            address token,
            Campaigns.TokenType tokenType,
            uint256 claimAmount,
            uint256 totalAmount,
            uint256 startDate,
            uint256 endDate,
            bool validateSignatures,

        ) = campaigns.campaigns(campaignId);

        // Verify all campaign fields
        assertEq(sbtId, CAMPAIGN_SBT_ID, "SBT ID should match");
        assertEq(title, campaignTitle, "Campaign title should match");
        assertEq(description, campaignDescription, "Campaign description should match");
        assertEq(token, address(0), "Token address should be zero for NFT campaigns");
        assertEq(uint256(tokenType), uint256(Campaigns.TokenType.NFT), "Token type should be NFT");
        assertEq(claimAmount, CAMPAIGN_CLAIM_AMOUNT, "Claim amount should match");
        assertEq(totalAmount, CAMPAIGN_TOTAL_AMOUNT, "Total amount should match");
        assertGt(startDate, 0, "Start date should be set");
        assertGt(endDate, startDate, "End date should be after start date");
        assertEq(validateSignatures, false, "Signature validation should be disabled");
        assertEq(campaignId, CAMPAIGN_TOKEN_ID, "Campaign ID should match token ID");

        // Verify NFT balance on Campaigns contract
        assertEq(
            nft.balanceOf(address(campaigns), CAMPAIGN_TOKEN_ID),
            defaultCampaign.totalAmount,
            "Campaigns contract should hold total campaign amount"
        );

        // Verify creator retrieval
        assertEq(
            campaigns.getCreator(campaignId),
            daoManager,
            "getCreator should return correct creator"
        );
    }

    /**
     * @notice Tests access control for campaign creation
     * @dev Verifies that only authorized users can create campaigns
     */
    function test_createCampaign_AccessControl() public {
        // Should revert if unauthorized user tries to create a campaign
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        campaigns.createCampaign(defaultCampaign);
        vm.stopPrank();
    }

    /**
     * @notice Tests campaign creation with invalid parameters
     * @dev Verifies that campaigns cannot be created with invalid data
     */
    function test_createCampaign_InvalidParameters() public {
        vm.startPrank(daoManager);
        nft.createToken(TOKEN_URI, VOTING_POWER);
        vm.roll(block.number + 1);
        vm.stopPrank();

        // Test: Start date after end date
        Campaigns.Campaign memory invalidCampaign = defaultCampaign;
        invalidCampaign.startDate = block.timestamp + 2000;
        invalidCampaign.endDate = block.timestamp + 1000;

        vm.startPrank(daoManager);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidStartDate.selector));
        campaigns.createCampaign(invalidCampaign);
        vm.stopPrank();

        // Test: Total amount is zero
        invalidCampaign = defaultCampaign;
        invalidCampaign.totalAmount = 0;

        vm.startPrank(daoManager);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidAmount.selector));
        campaigns.createCampaign(invalidCampaign);
        vm.stopPrank();

        // Test: Claim amount exceeds total amount
        invalidCampaign = defaultCampaign;
        invalidCampaign.claimAmount = 15;
        invalidCampaign.totalAmount = 10;

        vm.startPrank(daoManager);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidClaimAmount.selector));
        campaigns.createCampaign(invalidCampaign);
        vm.stopPrank();
    }

    /**
     * @notice Tests adding winners to a campaign
     * @dev Verifies that winners can be added and events are emitted correctly
     */
    function test_addCampWinners() public {
        uint256 campaignId = _createTestCampaign();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;

        bytes32[] memory gists = new bytes32[](1);
        gists[0] = gist;

        // Add winners to campaign
        _addCampaignWinners(campaignId, winners, gists);

        // Verify winners were added correctly
        assertEq(campaigns.campWinners(campaignId, 0), alice, "First winner should be alice");
        assertEq(campaigns.campWinners(campaignId, 1), bob, "Second winner should be bob");
    }

    /**
     * @notice Tests access control for adding winners
     * @dev Verifies that only authorized users can add winners
     */
    function test_addCampWinners_AccessControl() public {
        uint256 campaignId = _createTestCampaign();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;

        bytes32[] memory gists = new bytes32[](1);
        gists[0] = gist;

        // Should revert if unauthorized user tries to add winners
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        campaigns.addCampWinners(campaignId, winners, gists);
        vm.stopPrank();
    }

    /**
     * @notice Tests event emission when adding winners
     * @dev Verifies that CampWinnersAdded event is emitted correctly
     */
    function test_addCampWinners_EventEmission() public {
        uint256 campaignId = _createTestCampaign();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;

        bytes32[] memory gists = new bytes32[](1);
        gists[0] = gist;

        // Verify event is emitted
        vm.startPrank(daoManager);
        vm.expectEmit(true, true, true, true);
        emit Campaigns.CampWinnersAdded(campaignId, winners);
        campaigns.addCampWinners(campaignId, winners, gists);
        vm.stopPrank();
    }

    /**
     * @notice Tests successful campaign claim
     * @dev Verifies that winners can claim their rewards after campaign starts
     */
    function test_claimCampaign() public {
        uint256 campaignId = _createTestCampaign();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;

        bytes32[] memory gists = new bytes32[](1);
        gists[0] = gist;

        _addCampaignWinners(campaignId, winners, gists);

        // Advance time to after campaign start date
        vm.warp(block.timestamp + CAMPAIGN_START_OFFSET + 100);

        // Claim campaign reward
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Campaigns.CampWinnersClaimed(campaignId, alice);
        campaigns.claimCampaign(campaignId, gist, "Test Message", bytes(""));
        vm.stopPrank();

        // Verify NFT balance of winner
        assertEq(
            nft.balanceOf(alice, CAMPAIGN_TOKEN_ID),
            defaultCampaign.claimAmount,
            "Winner should receive claim amount"
        );

        // Verify remaining balance on Campaigns contract
        assertEq(
            nft.balanceOf(address(campaigns), CAMPAIGN_TOKEN_ID),
            defaultCampaign.totalAmount - defaultCampaign.claimAmount,
            "Campaigns contract should hold remaining amount"
        );

        // Verify total claimed amount
        assertEq(
            campaigns.totalClaimed(campaignId),
            defaultCampaign.claimAmount,
            "Total claimed should match claim amount"
        );
    }

    /**
     * @notice Tests claim validation and error cases
     * @dev Verifies that claims fail under invalid conditions
     */
    function test_claimCampaign_ValidationErrors() public {
        uint256 campaignId = _createTestCampaign();

        address[] memory winners = new address[](1);
        winners[0] = alice;

        bytes32[] memory gists = new bytes32[](1);
        gists[0] = gist;

        _addCampaignWinners(campaignId, winners, gists);

        // Test: Campaign not started
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.CampaignNotStarted.selector));
        campaigns.claimCampaign(campaignId, gist, "Test Message", bytes(""));
        vm.stopPrank();

        // Advance time to after campaign start date
        vm.warp(block.timestamp + CAMPAIGN_START_OFFSET + 100);

        // Test: Not whitelisted user
        vm.startPrank(notWhitelistedUser);
        vm.expectRevert(abi.encodeWithSelector(IErrors.NotWhitelisted.selector));
        campaigns.claimCampaign(campaignId, gist, "Test Message", bytes(""));
        vm.stopPrank();

        // Test: Successful claim
        vm.prank(alice);
        campaigns.claimCampaign(campaignId, gist, "Test Message", bytes(""));

        // Test: Already claimed
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.AlreadyClaimed.selector));
        campaigns.claimCampaign(campaignId, gist, "Test Message", bytes(""));
        vm.stopPrank();

        // Test: Campaign ended
        vm.warp(block.timestamp + CAMPAIGN_DURATION + 200);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.CampaignEnded.selector));
        campaigns.claimCampaign(campaignId, gist, "Test Message", bytes(""));
        vm.stopPrank();
    }

    /**
     * @notice Tests winner verification functionality
     * @dev Verifies that isWinner correctly identifies campaign winners
     */
    function test_checkWinner() public {
        uint256 campaignId = _createTestCampaign();

        address[] memory winners = new address[](2);
        winners[0] = alice;
        winners[1] = bob;

        bytes32[] memory gists = new bytes32[](1);
        gists[0] = gist;

        _addCampaignWinners(campaignId, winners, gists);

        // Verify winners are correctly identified
        assertEq(
            campaigns.isWinner(campaignId, alice),
            true,
            "Alice should be identified as a winner"
        );
        assertEq(campaigns.isWinner(campaignId, bob), true, "Bob should be identified as a winner");

        // Verify non-winners are correctly identified
        assertEq(
            campaigns.isWinner(campaignId, notWhitelistedUser),
            false,
            "Non-whitelisted user should not be identified as a winner"
        );
    }

    /**
     * @notice Tests campaign creator retrieval
     * @dev Verifies that getCreator returns the correct creator address
     */
    function test_getCreator() public {
        uint256 campaignId = _createTestCampaign();

        // Verify creator is returned correctly
        assertEq(campaigns.getCreator(campaignId), daoManager, "Creator should be daoManager");
    }

    /**
     * @notice Tests campaign status retrieval
     * @dev Verifies that getStatus returns correct status based on current time
     */
    function test_getStatus() public {
        uint256 campaignId = _createTestCampaign();

        // Test: Pending status (before start date)
        assertEq(
            uint256(campaigns.getStatus(campaignId)),
            uint256(Campaigns.Status.Pending),
            "Campaign should be pending before start date"
        );

        // Test: Active status (after start date, before end date)
        vm.warp(block.timestamp + CAMPAIGN_START_OFFSET + 100);
        assertEq(
            uint256(campaigns.getStatus(campaignId)),
            uint256(Campaigns.Status.Active),
            "Campaign should be active between start and end date"
        );

        // Test: Ended status (after end date)
        vm.warp(block.timestamp + CAMPAIGN_DURATION + 200);
        assertEq(
            uint256(campaigns.getStatus(campaignId)),
            uint256(Campaigns.Status.Ended),
            "Campaign should be ended after end date"
        );
    }
}
