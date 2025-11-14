// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PEACECOINDAO_SBT} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {DeployDAOFactory} from "../src/deploy/DeployDAOFactory.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";

contract PEACECOINDAO_SBTTest is Test, DeployDAOFactory {
    PEACECOINDAO_SBT public token;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public daoFactory;

    string constant DAO_NAME = "Test DAO";
    string constant DAO_DESCRIPTION = "Test DAO";
    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST_Token";
    string constant URI = "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/";
    string public TOKEN_URI = "test-uri";
    uint256 public VOTING_POWER = 100;
    bytes32 public daoId = keccak256(abi.encodePacked(DAO_NAME));

    function setUp() public {
        (daoFactory, , , , , , ) = deployDAOFactory();

        token = new PEACECOINDAO_SBT();
        token.initialize(TOKEN_NAME, TOKEN_SYMBOL, URI, daoFactory);

        IAccessControl(daoFactory).grantRole(keccak256("DAO_MANAGER_ROLE"), address(this));
        token.setMinter(bob);
    }

    function test_createToken() public {
        token.createToken(TOKEN_URI, VOTING_POWER, daoId);
        assertEq(token.numberOfTokens(), 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.PermissionDenied.selector));
        token.createToken(TOKEN_URI, VOTING_POWER, daoId);
    }

    function test_mint() public {
        test_createToken();

        vm.prank(bob);
        token.mint(alice, 1, 1);
        assertEq(token.balanceOf(alice, 1), 1);
    }

    function test_transferFrom() public {
        test_mint();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.NonTransferable.selector));
        token.safeTransferFrom(alice, bob, 1, 1, "");
    }

    function test_safeBatchTransferFrom() public {
        test_mint();

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IErrors.NonTransferable.selector));
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }
}
