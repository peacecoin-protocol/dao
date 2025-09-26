// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PEACECOINDAO_NFT} from "../src/Governance/PEACECOINDAO_NFT.sol";
import {DeployDAOFactory} from "../src/deploy/DeployDAOFactory.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";

contract PEACECOINDAO_NFTTest is Test, DeployDAOFactory {
    PEACECOINDAO_NFT public token;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public daoFactory;

    string constant DAO_NAME = "Test DAO";
    string constant DAO_DESCRIPTION = "Test DAO";
    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST_SBT";
    string constant URI = "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/";
    bytes32 public DAO_MANAGER_ROLE = keccak256("DAO_MANAGER_ROLE");

    function setUp() public {
        (daoFactory, , , , ) = deployDAOFactory();

        token = new PEACECOINDAO_NFT();
        token.initialize(TOKEN_NAME, TOKEN_SYMBOL, URI, daoFactory);

        IAccessControl(daoFactory).grantRole(DAO_MANAGER_ROLE, address(this));
        token.setMinter(address(this));
    }

    function test_createToken() public {
        token.createToken();
        assertEq(token.numberOfTokens(), 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        token.createToken();
    }

    function test_mint() public {
        test_createToken();

        token.mint(alice, 1, 1);
        assertEq(token.balanceOf(alice, 1), 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidMinter.selector));
        token.mint(alice, 1, 1);

        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidTokenId.selector));
        token.mint(alice, 2, 1);
    }

    function test_setTokenURI() public {
        test_createToken();

        token.setTokenURI(1, "test-uri", 100);
        assertEq(token.getTokenWeight(1), 100);
        assertEq(token.uri(1), string(abi.encodePacked(URI, "test-uri")));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        token.setTokenURI(1, "test-uri", 100);

        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidTokenId.selector));
        token.setTokenURI(2, "test-uri", 100);
    }

    function test_delegation() public {
        test_mint();
        token.setTokenURI(1, "test-uri", 100);

        vm.prank(alice);
        token.delegate(bob);

        assertEq(token.delegateOf(alice), bob);
        assertEq(token.getVotes(bob), 100); // 1 token * 100 weight
    }

    function test_revoke() public {
        test_mint();

        token.revoke(1, true);
        assertTrue(token.isTokenRevoked(1));

        token.revoke(1, false);
        assertFalse(token.isTokenRevoked(1));
    }

    function test_batchMint() public {
        test_createToken();
        token.setTokenURI(1, "test-uri", 50);

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 3;
        amounts[1] = 2;

        token.batchMint(recipients, ids, amounts);

        assertEq(token.balanceOf(alice, 1), 3);
        assertEq(token.balanceOf(bob, 1), 2);
    }

    function test_burn() public {
        test_mint();

        token.burn(alice, 1, 1);
        assertEq(token.balanceOf(alice, 1), 0);
    }

    function test_votingPower() public {
        test_mint();
        token.setTokenURI(1, "test-uri", 100);

        assertEq(token.getTotalVotingPower(alice), 100);
    }
}
