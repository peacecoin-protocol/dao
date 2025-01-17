// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {MockGovToken} from "../src/mocks/MockGovToken.sol";
import {console} from "forge-std/console.sol";

contract TimelockTest is Test {
    address alice = address(0xABCD);
    address bob = address(0xDCBA);

    MockGovToken pceToken;
    GovernorAlpha gov;
    Timelock timelock;
    uint256 initialAmount = 50000;

    function setUp() public {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        pceToken = new MockGovToken();
        pceToken.initialize();

        timelock = new Timelock();
        timelock.initialize(alice, 2 hours);

        gov = new GovernorAlpha();
        gov.initialize("PCE DAO", address(pceToken), address(timelock), 1, 86400, 100e18, 1000e18);
        pceToken.mint(address(this), initialAmount);

        assertEq(pceToken.totalSupply(), pceToken.balanceOf(address(this)));
    }

    function test__setPendingAdmin() public {
        vm.expectRevert("Timelock::setPendingAdmin: Invalid address");
        timelock.setPendingAdmin(address(0));

        vm.expectRevert("Timelock::setPendingAdmin: First call must come from admin.");
        timelock.setPendingAdmin(address(gov));

        vm.prank(alice);
        timelock.setPendingAdmin(bob);
        assertEq(timelock.pendingAdmin(), bob);
    }

    function test__acceptAdmin() public {
        test__setPendingAdmin();

        vm.prank(alice);
        vm.expectRevert("Timelock::acceptAdmin: Call must come from pendingAdmin.");
        timelock.acceptAdmin();

        vm.prank(bob);
        timelock.acceptAdmin();

        assertEq(timelock.admin(), bob);
        assertEq(timelock.pendingAdmin(), address(0));
    }

    function test__queueTransaction() public {
        address target = address(timelock);

        uint256 value = 0;

        string memory signature = "setDelay(uint256)";

        bytes memory data = abi.encode(3 days);

        uint256 eta = block.timestamp + 2 days;

        vm.prank(bob);
        vm.expectRevert("Timelock::queueTransaction: Call must come from admin.");
        timelock.queueTransaction(target, value, signature, data, eta);

        // Queue Transaction
        vm.prank(alice);
        timelock.queueTransaction(target, value, signature, data, eta);

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        vm.assertEq(timelock.queuedTransactions(txHash), true);
    }

    function test__cancelTransaction() public {
        address target = address(timelock);

        uint256 value = 0;

        string memory signature = "setDelay(uint256)";

        bytes memory data = abi.encode(3 days);

        uint256 eta = block.timestamp + 2 days;

        // Queue Transaction
        vm.prank(alice);
        timelock.queueTransaction(target, value, signature, data, eta);

        // Execute Transaction
        vm.prank(address(this));
        vm.expectRevert("Timelock::executeTransaction: Call must come from admin.");
        timelock.executeTransaction(target, value, signature, data, eta);

        vm.prank(alice);

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        vm.assertEq(timelock.queuedTransactions(txHash), true);

        vm.assertEq(timelock.delay(), 2 hours);
    }

    function test__executeTransaction() public {
        address target = address(timelock);
        uint256 value = 0;
        string memory signature = "setDelay(uint256)";
        bytes memory data = abi.encode(timelock.MAXIMUM_DELAY() - 1);
        uint256 eta = block.timestamp + 2 days;

        // Queue Transaction
        vm.prank(alice);
        timelock.queueTransaction(target, value, signature, data, eta);

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        vm.assertEq(timelock.queuedTransactions(txHash), true);
        // Try to execute too early
        vm.prank(alice);
        vm.expectRevert("Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        timelock.executeTransaction(target, value, signature, data, eta);

        // Warp to after timelock period
        vm.warp(block.timestamp + 2 days + timelock.delay() + 1);
    }

    function test__executeExpiredTransaction() public {
        address target = address(timelock);
        uint256 value = 0;
        string memory signature = "setDelay(uint256)";
        bytes memory data = abi.encode(3 days);
        uint256 eta = block.timestamp + 2 days;

        // Queue Transaction
        vm.prank(alice);
        timelock.queueTransaction(target, value, signature, data, eta);

        // Warp to after grace period
        vm.warp(eta + 14 days + 1);

        // Try to execute expired transaction
        vm.prank(alice);
        vm.expectRevert("Timelock::executeTransaction: Transaction is stale.");
        timelock.executeTransaction(target, value, signature, data, eta);
    }
}
