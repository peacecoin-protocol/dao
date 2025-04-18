// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {Campagins} from "../src/Campagins.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {console} from "forge-std/console.sol";

contract CampaginsTest is Test {
    using Strings for uint256;
    Campagins public campagins;
    MockERC20 public token;

    address public alice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bob = makeAddr("Bob");
    address public charlie = makeAddr("Charlie");

    function setUp() public {
        token = new MockERC20();
        campagins = new Campagins();

        campagins.initialize(token);

        token.mint(address(campagins), 10e18);
    }

    function test_createCampagin() public {
        Campagins.Campagin memory champ = Campagins.Campagin({
            title: "Test Campagin",
            description: "Test Description",
            amount: 10e18,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: true
        });
        campagins.createCampagin(champ);

        (string memory title, string memory description, uint256 amount, uint256 startDate, uint256 endDate, bool validateSignatures) = campagins.campagins(0);

        assertEq(title, "Test Campagin");
        assertEq(description, "Test Description");
        assertEq(amount, 10e18);
        assertGt(startDate, 0);
        assertGt(endDate, startDate);
        assertEq(validateSignatures, true);
        assertEq(campagins.campaginId(), 1);
    }

    function test_createCampagin_shouldRevertIfNotOwner() public {
        vm.prank(address(alice));
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(alice)));
        campagins.createCampagin(Campagins.Campagin({
            title: "Test Campagin",
            description: "Test Description",
            amount: 10e18,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: true
        }));
    }

    function test_addCampWinners() public {
        test_createCampagin();

        address[] memory _winners = new address[](2);
        _winners[0] = alice;
        _winners[1] = bob;

        campagins.addCampWinners(0, _winners);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        campagins.addCampWinners(0, _winners);
    }

    function test_claimCampWinner() public {
        test_addCampWinners();

        uint256 campaginId = 0;
        string memory message = "Claim Bounty for dApp.xyz";
        
        uint256 signerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        bytes memory messageBytes = bytes(message);
        uint256 messageLength = messageBytes.length;

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", messageLength.toString(), message));
        
        vm.prank(alice);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        campagins.claimCampagin(campaginId, message, signature);

        assertEq(token.balanceOf(alice), 10e18);

        vm.prank(bob);
        vm.expectRevert("Invalid signature");
        campagins.claimCampagin(campaginId, message, signature);

        vm.prank(alice);    
        vm.expectRevert("You have already claimed your prize");
        campagins.claimCampagin(campaginId, message, signature);

        vm.prank(charlie);    
        vm.expectRevert("Invalid signature");
        campagins.claimCampagin(campaginId, message, signature);
    }   
}