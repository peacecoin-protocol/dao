// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {PCETokenV2} from "../src/PCETokenV2.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {console} from "forge-std/console.sol";

contract TimelockTest is Test {
    address alice = address(0xABCD);
    address bob = address(0xDCBA);

    PCETokenV2 pceToken;
    GovernorAlpha gov;
    Timelock timelock;
    uint256 initialAmount = 50000;

    function setUp() public {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        pceToken = new PCETokenV2();
        pceToken.initialize("PEACE COIN", "PCE", address(1), address(0));

        timelock = new Timelock(alice, 2 hours);
        gov = new GovernorAlpha(address(timelock), address(pceToken), alice);

        pceToken.transfer(address(this), initialAmount);

        assertEq(pceToken.totalSupply(), pceToken.balanceOf(address(this)));
    }

    function test__setPendingAdmin() public {
        vm.expectRevert("Timelock::setPendingAdmin: Invalid address");
        timelock.setPendingAdmin(address(0));

        vm.expectRevert(
            "Timelock::setPendingAdmin: First call must come from admin."
        );
        timelock.setPendingAdmin(address(gov));

        vm.prank(alice);
        timelock.setPendingAdmin(address(gov));
        assertEq(timelock.pendingAdmin(), address(gov));
    }

    function test__acceptAdmin() public {
        test__setPendingAdmin();

        vm.prank(bob);
        vm.expectRevert(
            "Timelock::acceptAdmin: Call must come from pendingAdmin."
        );
        timelock.acceptAdmin();

        vm.prank(alice);
        gov.__acceptAdmin();
        assertEq(timelock.admin(), address(gov));
        assertEq(timelock.pendingAdmin(), address(0));
    }

    function test__queueTransaction() public {
        address target = address(timelock);

        uint256 value = 0;

        string memory signature = "setDelay(uint256)";

        bytes memory data = abi.encode(3 days);

        uint eta = block.timestamp + 2 days;

        vm.prank(bob);
        vm.expectRevert(
            "Timelock::queueTransaction: Call must come from admin."
        );
        timelock.queueTransaction(target, value, signature, data, eta);

        // Queue Transaction
        vm.prank(alice);
        timelock.queueTransaction(target, value, signature, data, eta);

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );

        vm.assertEq(timelock.queuedTransactions(txHash), true);
    }

    function test__cancelTransaction() public {
        address target = address(timelock);

        uint256 value = 0;

        string memory signature = "setDelay(uint256)";

        bytes memory data = abi.encode(3 days);

        uint eta = block.timestamp + 2 days;

        // Queue Transaction
        vm.prank(alice);
        timelock.queueTransaction(target, value, signature, data, eta);

        // Execute Transaction

        vm.prank(address(this));
        vm.expectRevert(
            "Timelock::executeTransaction: Call must come from admin."
        );
        timelock.executeTransaction(target, value, signature, data, eta);

        vm.prank(alice);
        vm.expectRevert(
            "Timelock::executeTransaction: Transaction hasn't been queued."
        );
        timelock.executeTransaction(target, value + 1, signature, data, eta);

        vm.prank(alice);
        vm.warp(block.timestamp + 20 days);
        vm.expectRevert("Timelock::executeTransaction: Transaction is stale.");
        timelock.executeTransaction(target, value, signature, data, eta);

        vm.warp(block.timestamp - 5 days);
        vm.prank(alice);

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        vm.assertEq(timelock.queuedTransactions(txHash), true);

        vm.assertEq(timelock.delay(), 2 hours);
    }
}
