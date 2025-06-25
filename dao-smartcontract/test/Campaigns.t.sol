// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {Campaigns} from "../src/Campaigns.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {console} from "forge-std/console.sol";
import {SBT} from "../src/SBT.sol";
contract CampaignsTest is Test {
    using Strings for uint256;
    Campaigns public campaigns;
    MockERC20 public token;
    SBT public nft;
    address public alice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bob = makeAddr("Bob");
    address public charlie = makeAddr("Charlie");
    bytes32 public gist = keccak256(abi.encodePacked("testGist"));

    function setUp() public {
        token = new MockERC20();
        nft = new SBT(
            "PCE Contributor NFT",
            "PCE_CONTRIBUTOR",
            "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/"
        );

        // Deploy Campaigns contract
        campaigns = new Campaigns();

        // Set Campaigns as minter for NFT
        nft.setMinter(address(campaigns));

        campaigns.initialize(token, nft);

        token.mint(address(campaigns), 1000e18);
    }

    function test_createCampaign() public {
        Campaigns.Campaign memory campaign = Campaigns.Campaign({
            title: "Test Campaign",
            description: "Test Description",
            amount: 3,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: true,
            isNFT: true
        });
        campaigns.createCampaign(campaign);

        (
            string memory title,
            string memory description,
            uint256 amount,
            uint256 startDate,
            uint256 endDate,
            bool validateSignatures,
            bool isNFT
        ) = campaigns.campaigns(1);

        assertEq(title, "Test Campaign");
        assertEq(description, "Test Description");
        assertEq(amount, 3);
        assertGt(startDate, 0);
        assertGt(endDate, startDate);
        assertEq(validateSignatures, true);
        assertEq(isNFT, true);
        assertEq(campaigns.campaignId(), 1);
    }

    function test_createCampaign_shouldRevertIfNotOwner() public {
        vm.prank(address(alice));
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(alice))
        );
        campaigns.createCampaign(
            Campaigns.Campaign({
                title: "Test Campaign",
                description: "Test Description",
                amount: 10e18,
                startDate: block.timestamp + 100,
                endDate: block.timestamp + 1000,
                validateSignatures: true,
                isNFT: true
            })
        );
    }

    function test_addCampWinners() public {
        test_createCampaign();

        address[] memory _winners = new address[](2);
        _winners[0] = alice;
        _winners[1] = bob;

        bytes32[] memory _gists = new bytes32[](1);
        _gists[0] = gist;

        campaigns.addCampWinners(1, _winners, _gists);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        campaigns.addCampWinners(1, _winners, _gists);

        vm.prank(address(this));
        campaigns.addCampWinners(1, new address[](0), _gists);
    }

    function test_claimCampWinner() public {
        test_addCampWinners();

        vm.warp(block.timestamp + 1500);

        uint256 campaignId = 1;
        string memory message = "Claim Bounty for dApp.xyz";

        uint256 signerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        bytes memory messageBytes = bytes(message);
        uint256 messageLength = messageBytes.length;

        bytes32 messageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n", messageLength.toString(), message)
        );

        vm.prank(alice);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        campaigns.claimCampaign(campaignId, gist, message, signature);

        assertEq(nft.balanceOf(alice, campaignId), 3);

        vm.prank(bob);
        vm.expectRevert("Invalid signature");
        campaigns.claimCampaign(campaignId, gist, message, signature);

        vm.prank(alice);
        vm.expectRevert("You have already claimed your prize");
        campaigns.claimCampaign(campaignId, gist, message, signature);

        vm.prank(charlie);
        vm.expectRevert("Invalid signature");
        campaigns.claimCampaign(campaignId, gist, message, signature);
    }
}
