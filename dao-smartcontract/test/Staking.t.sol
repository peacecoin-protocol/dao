// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";
import {PCE} from "../src/Governance/PCE.sol";
import {WPCE} from "../src/Governance/WPCE.sol";
import {console} from "forge-std/console.sol";

contract StakingTest is Test {
    Staking public staking;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    PCE public pce;
    WPCE public wPCE;

    uint256 public INITIAL_BALANCE = 1_000_000_000 * 1e18;
    uint256 public REWARD_PER_BLOCK = 100 * 1e18;

    function setUp() public {
        pce = new PCE();
        pce.initialize();
        wPCE = new WPCE();

        wPCE.initialize();
        staking = new Staking();
        staking.initialize(REWARD_PER_BLOCK, address(pce), address(wPCE));

        wPCE.addMinter(address(staking));

        pce.mint(alice, INITIAL_BALANCE);
        pce.mint(address(staking), INITIAL_BALANCE);
    }

    function test_stake() public {
        vm.startPrank(alice);
        pce.approve(address(staking), INITIAL_BALANCE);
        staking.stake(INITIAL_BALANCE);
        assertEq(staking.getStakedPEACECOIN(alice), INITIAL_BALANCE);

        staking.withdraw(wPCE.balanceOf(alice));
        assertEq(pce.balanceOf(alice), INITIAL_BALANCE);

        pce.approve(address(staking), INITIAL_BALANCE);
        staking.stake(INITIAL_BALANCE);
        assertEq(staking.getStakedPEACECOIN(alice), INITIAL_BALANCE);

        vm.roll(block.number + 1000);
        staking.withdraw(wPCE.balanceOf(alice));
        assertEq(pce.balanceOf(alice), INITIAL_BALANCE + REWARD_PER_BLOCK * 1000);
    }
}
