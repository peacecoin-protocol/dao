// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";
import {PCE} from "../src/mocks/PCE.sol";
import {WPCE} from "../src/mocks/WPCE.sol";

contract StakingTest is Test {
    Staking public staking;

    address public alice = makeAddr("alice");
    PCE public pce;
    WPCE public wPce;

    uint256 public initialBalance = 1_000_000_000 * 1e18;
    uint256 public rewardPerBlock = 100 * 1e18;

    function setUp() public {
        pce = new PCE();
        pce.initialize();
        wPce = new WPCE();

        wPce.initialize();
        staking = new Staking();
        staking.initialize(rewardPerBlock, address(pce), address(wPce));

        wPce.addMinter(address(staking));

        pce.mint(alice, initialBalance);
        pce.mint(address(staking), initialBalance);
    }

    function test_stake() public {
        vm.startPrank(alice);
        pce.approve(address(staking), initialBalance);
        staking.stake(initialBalance);
        assertEq(staking.getStakedPeacecoin(alice), initialBalance);

        staking.withdraw(wPce.balanceOf(alice));
        assertEq(pce.balanceOf(alice), initialBalance);

        pce.approve(address(staking), initialBalance);
        staking.stake(initialBalance);
        assertEq(staking.getStakedPeacecoin(alice), initialBalance);

        vm.roll(block.number + 1000);
        staking.withdraw(wPce.balanceOf(alice));
        assertEq(pce.balanceOf(alice), initialBalance + rewardPerBlock * 1000);
    }
}
