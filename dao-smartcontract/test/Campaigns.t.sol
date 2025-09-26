// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {Campaigns} from "../src/Campaigns.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PEACECOINDAO_SBT} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {PEACECOINDAO_NFT} from "../src/Governance/PEACECOINDAO_NFT.sol";
import {DeployDAOFactory} from "../src/deploy/DeployDAOFactory.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {ITokens} from "../src/interfaces/ITokens.sol";

contract CampaignsTest is Test, DeployDAOFactory {
    using Strings for uint256;
    Campaigns public campaigns;
    MockERC20 public token;
    PEACECOINDAO_NFT public nft;
    PEACECOINDAO_SBT public sbt;
    address public daoManager = makeAddr("DaoManager");
    address public user = makeAddr("User");
    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");
    address public notWhitelistedUser = makeAddr("NotWhitelisted");

    bytes32 public gist = keccak256(abi.encodePacked("testGist"));

    string public uri = "https://peacecoin-dao.mypinata.cloud/ipfs/";
    string public name = "PEACECOIN DAO SBT";
    string public symbol = "PCE_SBT";

    string public _title = "Test Campaign";
    string public _description = "Test Description";

    bytes32 public DAO_MANAGER_ROLE = keccak256("DAO_MANAGER_ROLE");

    Campaigns.Campaign _campaign =
        Campaigns.Campaign({
            sbtId: 1,
            title: _title,
            description: _description,
            token: address(0),
            tokenType: Campaigns.TokenType.NFT,
            claimAmount: 2,
            totalAmount: 10,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: false,
            creator: address(0)
        });

    function setUp() public {
        (address daoFactory, , , , ) = deployDAOFactory();

        nft = new PEACECOINDAO_NFT();
        nft.initialize(name, symbol, uri, daoFactory);

        sbt = new PEACECOINDAO_SBT();
        sbt.initialize(name, symbol, uri, daoFactory);

        // Deploy Campaigns contract
        campaigns = new Campaigns();
        campaigns.initialize(daoFactory, sbt, nft);

        // Set minter for NFT
        nft.setMinter(address(campaigns));

        IAccessControl(daoFactory).grantRole(DAO_MANAGER_ROLE, daoManager);

        vm.prank(daoManager);

        token = new MockERC20();
        token.mint(daoManager, 1000 ether);

        vm.prank(daoManager);
        token.approve(address(campaigns), 1000 ether);

        IAccessControl(daoFactory).grantRole(DAO_MANAGER_ROLE, address(this));
    }

    function test_createCampaign() public {
        // Create Token & Create Campaign
        vm.startPrank(daoManager);
        nft.createToken();
        campaigns.createCampaign(_campaign);
        vm.stopPrank();

        // Check if creator is set
        assertEq(ITokens(address(nft)).creators(1), daoManager);

        (
            uint256 sbtId,
            string memory title_,
            string memory description_,
            address _token,
            Campaigns.TokenType _tokenType,
            uint256 claimAmount,
            uint256 totalAmount,
            uint256 startDate,
            uint256 endDate,
            bool validateSignatures,
            address creator
        ) = campaigns.campaigns(1);

        assertEq(sbtId, 1);
        assertEq(title_, _title);
        assertEq(description_, _description);
        assertEq(_token, address(0));
        assertEq(uint256(_tokenType), uint256(Campaigns.TokenType.NFT));
        assertEq(claimAmount, 2);
        assertEq(totalAmount, 10);
        assertGt(startDate, 0);
        assertGt(endDate, startDate);
        assertEq(validateSignatures, false);
        assertEq(campaigns.campaignId(), 1);
        assertEq(creator, daoManager);

        // Revert if normal users try to create a campaign
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        campaigns.createCampaign(_campaign);
        vm.stopPrank();

        Campaigns.Campaign memory invalidCampaign = _campaign;

        // Revert if start date is greater than end date
        vm.startPrank(daoManager);
        invalidCampaign.startDate = block.timestamp + 1000;
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidStartDate.selector));
        campaigns.createCampaign(invalidCampaign);
        vm.stopPrank();

        // Revert if total amount is zero
        invalidCampaign = _campaign;
        vm.startPrank(daoManager);
        invalidCampaign.totalAmount = 0;
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidAmount.selector));
        campaigns.createCampaign(invalidCampaign);
        vm.stopPrank();

        // Revert if claim amount is greater than total amount
        invalidCampaign = _campaign;
        vm.startPrank(daoManager);
        invalidCampaign.claimAmount = 15;
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidClaimAmount.selector));
        campaigns.createCampaign(invalidCampaign);
        vm.stopPrank();

        // Balance of NFT on Campaigns contract
        assertEq(nft.balanceOf(address(campaigns), 1), _campaign.totalAmount);

        // Get Creator of Campaign
        assertEq(campaigns.getCreator(1), daoManager);
    }

    function test_addCampWinners() public {
        test_createCampaign();

        address[] memory _winners = new address[](2);
        _winners[0] = alice;
        _winners[1] = bob;

        bytes32[] memory _gists = new bytes32[](1);
        _gists[0] = gist;

        vm.prank(daoManager);
        campaigns.addCampWinners(1, _winners, _gists);

        assertEq(campaigns.campWinners(1, 0), alice);
        assertEq(campaigns.campWinners(1, 1), bob);

        // Should revert if normal users try to add winners
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        campaigns.addCampWinners(1, _winners, _gists);
        vm.stopPrank();

        // Should emit event
        vm.startPrank(daoManager);
        vm.expectEmit(true, true, true, true);
        emit Campaigns.CampWinnersAdded(1, _winners);
        campaigns.addCampWinners(1, _winners, _gists);
        vm.stopPrank();
    }

    function test_claimCampaign() public {
        test_addCampWinners();

        // Should revert if campaign is not started
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.CampaignNotStarted.selector));
        campaigns.claimCampaign(1, gist, "Test Message", bytes(""));
        vm.stopPrank();

        // Warp to after start date
        vm.warp(block.timestamp + 200);

        // Should revert if not listed as a winner
        vm.startPrank(notWhitelistedUser);
        vm.expectRevert(abi.encodeWithSelector(IErrors.NotWhitelisted.selector));
        campaigns.claimCampaign(1, gist, "Test Message", bytes(""));
        vm.stopPrank();

        // Should claim if listed as a winner
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Campaigns.CampWinnersClaimed(1, alice);
        campaigns.claimCampaign(1, gist, "Test Message", bytes(""));
        vm.stopPrank();

        // Should revert if already claimed
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.AlreadyClaimed.selector));
        campaigns.claimCampaign(1, gist, "Test Message", bytes(""));
        vm.stopPrank();

        // Should revert if campaign is ended
        vm.warp(block.timestamp + 1200);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.CampaignEnded.selector));
        campaigns.claimCampaign(1, gist, "Test Message", bytes(""));
        vm.stopPrank();

        // Check if balance of NFT is correct
        assertEq(nft.balanceOf(alice, 1), _campaign.claimAmount);

        // Check if balance of NFT on Campaigns contract is correct
        assertEq(
            nft.balanceOf(address(campaigns), 1),
            _campaign.totalAmount - _campaign.claimAmount
        );

        // Check if total claimed is correct
        assertEq(campaigns.totalClaimed(1), _campaign.claimAmount);
    }

    function test_checkWinner() public {
        test_addCampWinners();

        // Should return true if listed as a winner
        assertEq(campaigns.isWinner(1, alice), true);
        assertEq(campaigns.isWinner(1, bob), true);

        // Should return false if not listed as a winner
        assertEq(campaigns.isWinner(1, notWhitelistedUser), false);
    }

    function test_getCreator() public {
        test_createCampaign();

        // Should return creator of campaign
        assertEq(campaigns.getCreator(1), daoManager);
    }

    function test_getStatus() public {
        test_createCampaign();

        // Should return pending status
        assertEq(uint256(campaigns.getStatus(1)), uint256(Campaigns.Status.Pending));

        // Should return active status
        vm.warp(block.timestamp + 200);
        assertEq(uint256(campaigns.getStatus(1)), uint256(Campaigns.Status.Active));

        // Should return ended status
        vm.warp(block.timestamp + 1200);
        assertEq(uint256(campaigns.getStatus(1)), uint256(Campaigns.Status.Ended));
    }
}
