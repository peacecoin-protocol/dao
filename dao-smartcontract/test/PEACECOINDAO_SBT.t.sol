// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {PEACECOINDAO_SBT} from "../src/Governance/PEACECOINDAO_SBT.sol";
import "forge-std/console.sol";

contract PEACECOINDAO_SBTTest is Test {
    PEACECOINDAO_SBT public sbt;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        sbt = new PEACECOINDAO_SBT();
        sbt.initialize(
            "PEACECOIN DAO SBT",
            "PCE_SBT",
            "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/"
        );
        sbt.setTokenURI(1, "https://peacecoin.io/sbt/1", 10);
    }

    function test_owner() public view {
        assertEq(address(sbt.owner()), address(this));
    }

    function test_Mint() public {
        sbt.mint(alice, 1, 1);
        assertEq(sbt.balanceOf(alice, 1), 1);
        assertEq(sbt.votingPowerPerId(1), 10);

        vm.prank(alice);
        sbt.delegate(alice);
        vm.roll(block.number + 1);
        assertEq(sbt.getPastVotes(alice, block.number - 1), 10);

        sbt.mint(bob, 1, 1);
        assertEq(sbt.balanceOf(bob, 1), 1);
        assertEq(sbt.votingPowerPerId(1), 10);

        vm.prank(bob);
        sbt.delegate(alice);
        vm.roll(block.number + 1);
        assertEq(sbt.getPastVotes(alice, block.number - 1), 10);
        assertEq(sbt.getPastVotes(bob, block.number - 1), 0);
    }
}
