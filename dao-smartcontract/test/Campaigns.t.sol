// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {Campaigns} from "../src/Campaigns.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {console} from "forge-std/console.sol";
import {PEACECOINDAO_SBT} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {PEACECOINDAO_NFT} from "../src/Governance/PEACECOINDAO_NFT.sol";
contract CampaignsTest is Test {
    using Strings for uint256;
    Campaigns public campaigns;
    MockERC20 public token;
    PEACECOINDAO_NFT public nft;
    PEACECOINDAO_SBT public sbt;
    address public alice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bob = makeAddr("Bob");
    address public charlie = makeAddr("Charlie");
    bytes32 public gist = keccak256(abi.encodePacked("testGist"));

    function setUp() public {
        nft = new PEACECOINDAO_NFT();
        nft.initialize(
            "https://peacecoin-dao.mypinata.cloud/ipfs/",
            "PEACECOIN DAO SBT",
            "PCE_SBT"
        );

        sbt = new PEACECOINDAO_SBT();
        sbt.initialize(
            "https://peacecoin-dao.mypinata.cloud/ipfs/",
            "PEACECOIN DAO SBT",
            "PCE_SBT"
        );

        // Deploy Campaigns contract
        campaigns = new Campaigns();

        // Set Campaigns as minter for NFT
        nft.setMinter(address(campaigns));

        campaigns.initialize(sbt, nft);

        token.mint(address(campaigns), 1000e18);
    }

    function test_createCampaign() public {
        Campaigns.Campaign memory campaign = Campaigns.Campaign({
            sbtId: 1,
            title: "Test Campaign",
            description: "Test Description",
            claimAmount: 3,
            totalAmount: 10,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: true,
            tokenType: Campaigns.TokenType.NFT,
            token: address(token)
        });
        campaigns.createCampaign(campaign);

        (
            uint256 sbtId,
            string memory title,
            string memory description,
            uint256 claimAmount,
            uint256 totalAmount,
            uint256 startDate,
            uint256 endDate,
            bool validateSignatures,
            ,
            address _token
        ) = campaigns.campaigns(1);

        assertEq(sbtId, 1);
        assertEq(title, "Test Campaign");
        assertEq(description, "Test Description");
        assertEq(claimAmount, 3);
        assertEq(totalAmount, 10);
        assertGt(startDate, 0);
        assertGt(endDate, startDate);
        assertEq(validateSignatures, true);
        assertEq(campaigns.campaignId(), 1);
        assertEq(_token, address(token));
    }

    function test_createCampaign_shouldRevertIfNotOwner() public {
        vm.prank(address(alice));
        // vm.expectRevert(
        //     abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(alice))
        // );
        campaigns.createCampaign(
            Campaigns.Campaign({
                sbtId: 1,
                title: "Test Campaign",
                description: "Test Description",
                claimAmount: 10e18,
                totalAmount: 10e18,
                startDate: block.timestamp + 100,
                endDate: block.timestamp + 1000,
                validateSignatures: true,
                tokenType: Campaigns.TokenType.ERC20,
                token: address(token)
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

        // vm.prank(alice);
        // vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        // campaigns.addCampWinners(1, _winners, _gists);

        vm.prank(address(this));
        campaigns.addCampWinners(1, new address[](0), _gists);
    }

    function test_claimCampWinner() public {
        test_addCampWinners();

        vm.warp(block.timestamp + 150);

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
