// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SBTERC721} from "../src/SBTERC721.sol";

contract SBTERC721Test is Test {
    SBTERC721 public sbt;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        sbt = new SBTERC721();
    }

    function test_owner() public view {
        assertEq(address(sbt.owner()), address(this));
    }

    function test_Mint() public {
        sbt.mint(alice);
        assertEq(sbt.balanceOf(alice), 1);
    }

    function test_TransferFrom() public {
        vm.prank(address(this));
        sbt.mint(alice);

        vm.prank(alice);
        vm.expectRevert("SBT: non-transferable");
        sbt.transferFrom(alice, bob, 0);

        vm.prank(alice);
        vm.expectRevert("SBT: non-transferable");
        sbt.safeTransferFrom(alice, bob, 0);
    }
}
