// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SBT} from "../src/SBT.sol";

contract SBTTest is Test {
    SBT public sbt;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        sbt = new SBT(
            "PCE Contributor NFT",
            "PCE_CONTRIBUTOR",
            "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/"
        );
    }

    function test_owner() public view {
        assertEq(address(sbt.owner()), address(this));
    }

    function test_Mint() public {
        sbt.mint(alice, 1, 1);
        assertEq(sbt.balanceOf(alice, 1), 1);
    }

    function test_safeTransferFrom() public {
        vm.prank(address(this));
        sbt.mint(alice, 1, 1);

        vm.prank(alice);
        vm.expectRevert("SBT: non-transferable");
        sbt.safeTransferFrom(alice, bob, 0, 1, "");

        vm.prank(alice);
        vm.expectRevert("SBT: non-transferable");
        sbt.safeTransferFrom(alice, bob, 0, 1, "");
    }
}
