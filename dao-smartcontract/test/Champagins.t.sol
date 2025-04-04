// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {Champagins} from "../src/Champagins.sol";
import {console} from "forge-std/console.sol";

contract ChampaginsTest is Test {
    Champagins public champagin;
    MockERC20 public token;

    address public alice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bob = makeAddr("Bob");
    address public charlie = makeAddr("Charlie");

    function setUp() public {
        token = new MockERC20();
        champagin = new Champagins();

        champagin.initialize(token);

        token.mint(address(champagin), 10e18);
    }

    function test_createChampagin() public {
        Champagins.Champagin memory champ = Champagins.Champagin({
            title: "Test Champagin",
            description: "Test Description",
            amount: 10e18,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: true
        });
        champagin.createChampagin(champ);

        (string memory title, string memory description, uint256 amount, uint256 startDate, uint256 endDate, bool validateSignatures) = champagin.champagins(0);

        assertEq(title, "Test Champagin");
        assertEq(description, "Test Description");
        assertEq(amount, 10e18);
        assertGt(startDate, 0);
        assertGt(endDate, startDate);
        assertEq(validateSignatures, true);
        assertEq(champagin.champaginId(), 1);
    }

    function test_createChampagin_shouldRevertIfNotOwner() public {
        vm.prank(address(alice));
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(alice)));
        champagin.createChampagin(Champagins.Champagin({
            title: "Test Champagin",
            description: "Test Description",
            amount: 10e18,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: true
        }));
    }

    function test_addChampWinners() public {
        test_createChampagin();

        address[] memory _winners = new address[](2);
        _winners[0] = alice;
        _winners[1] = bob;

        champagin.addChampWinners(0, _winners);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        champagin.addChampWinners(0, _winners);
    }

    function test_claimChampWinner() public {
        test_addChampWinners();

        uint256 champaginId = 0;
        string memory message = "Claim Bounty for dApp.xyz";
        
        uint256 signerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", 
            keccak256(abi.encodePacked(message))));

        // Sign the hash using Foundry's vm.sign
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(alice);
        champagin.claimChampagin(champaginId, message, signature);

        assertEq(token.balanceOf(alice), 10e18);

        vm.prank(bob);
        vm.expectRevert("Invalid signature");
        champagin.claimChampagin(champaginId, message, signature);

        vm.prank(alice);    
        vm.expectRevert("You have already claimed your prize");
        champagin.claimChampagin(champaginId, message, signature);

        vm.prank(charlie);    
        vm.expectRevert("Invalid signature");
        champagin.claimChampagin(champaginId, message, signature);
    }   
}