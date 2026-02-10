// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {MockGovToken} from "../src/mocks/MockGovToken.sol";
import {PeaceCoinDaoSbt} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {PeaceCoinDaoNft} from "../src/Governance/PEACECOINDAO_NFT.sol";
import {IDAOFactory} from "../src/interfaces/IDAOFactory.sol";

contract PublicTimelock is Timelock {
    function getBlockTimestampPublic() public view returns (uint256) {
        return super.getBlockTimestamp();
    }
}

contract TimelockTest is Test {
    address alice = makeAddr("alice"); // admin
    address bob = makeAddr("bob");

    MockGovToken governanceToken;
    PeaceCoinDaoSbt sbt;
    PeaceCoinDaoNft nft;
    GovernorAlpha governor;
    Timelock timelock;
    uint256 constant INITIAL_AMOUNT = 50000;
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 1 days;
    uint256 constant PROPOSAL_THRESHOLD = 100e18;
    uint256 constant QUORUM_VOTES = 1000e18;
    string constant URI = "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/";
    IDAOFactory.SocialConfig public socialConfig =
        IDAOFactory.SocialConfig({
            description: "PEACECOIN DAO",
            website: "https://peacecoin.com",
            linkedin: "https://linkedin.com/peacecoin",
            twitter: "https://twitter.com/peacecoin",
            telegram: "https://t.me/peacecoin"
        });
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    function setUp() public {
        vm.label(alice, "alice");
        vm.label(bob, "bob");

        governanceToken = new MockGovToken();
        governanceToken.initialize();

        sbt = new PeaceCoinDaoSbt();
        nft = new PeaceCoinDaoNft();

        sbt.initialize(URI, address(this), address(this), true);
        nft.initialize(URI, address(this), address(this), false);

        timelock = new Timelock();
        timelock.initialize(alice, 2 hours);

        governor = new GovernorAlpha();
        governor.initialize(
            "PCE DAO",
            address(governanceToken),
            address(sbt),
            address(nft),
            address(timelock),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_VOTES,
            address(this),
            socialConfig
        );
        governanceToken.mint(address(this), INITIAL_AMOUNT);

        assertEq(governanceToken.totalSupply(), governanceToken.balanceOf(address(this)));
    }

    // Helper functions
    function _buildTransactionParams()
        private
        view
        returns (
            address target,
            uint256 value,
            string memory signature,
            bytes memory data,
            uint256 eta
        )
    {
        target = address(timelock);
        value = 0;
        signature = "setDelay(uint256)";
        data = abi.encode(3 days);
        eta = block.timestamp + 2 days;
    }

    function test_initialize() public {
        Timelock _timelock = new Timelock();
        _timelock.initialize(alice, 2 hours);
        assertEq(_timelock.admin(), alice);
        assertEq(_timelock.delay(), 2 hours);
        assertEq(_timelock.minimumDelay(), 1 minutes);
        assertEq(_timelock.maximumDelay(), 30 hours);
        assertEq(_timelock.gracePeriod(), 14 days);
    }

    function test_initialize_RevertsWhen_DelayIsInvalid() public {
        Timelock _timelock = new Timelock();
        vm.expectRevert("Timelock::setDelay: Delay must not exceed maximum delay.");
        _timelock.initialize(alice, 31 hours);

        vm.expectRevert("Timelock::constructor: Delay must exceed minimum delay.");
        _timelock.initialize(alice, 2 seconds);
    }

    function test__setPendingAdmin() public {
        vm.expectRevert("Timelock::setPendingAdmin: Invalid address");
        timelock.setPendingAdmin(address(0));

        vm.expectRevert("Timelock::setPendingAdmin: First call must come from admin.");
        timelock.setPendingAdmin(address(governor));

        vm.prank(alice);
        vm.expectEmit(true, false, false, false);
        emit NewPendingAdmin(bob);
        timelock.setPendingAdmin(bob);
        assertEq(timelock.pendingAdmin(), bob);

        // adminInitialized is true
        vm.prank(alice);
        vm.expectRevert("Timelock::setPendingAdmin: Call must come from Timelock.");
        timelock.setPendingAdmin(bob);
    }

    function test__acceptAdmin() public {
        test__setPendingAdmin();

        vm.prank(alice);
        vm.expectRevert("Timelock::acceptAdmin: Call must come from pendingAdmin.");
        timelock.acceptAdmin();

        vm.prank(bob);
        vm.expectEmit(true, false, false, false);
        emit NewAdmin(bob);
        timelock.acceptAdmin();

        assertEq(timelock.admin(), bob);
        assertEq(timelock.pendingAdmin(), address(0));
    }

    function test__queueTransaction() public {
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory data,
            uint256 eta
        ) = _buildTransactionParams();

        vm.prank(bob);
        vm.expectRevert("Timelock::queueTransaction: Call must come from admin.");
        timelock.queueTransaction(target, value, signature, data, eta);

        // Queue Transaction
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit QueueTransaction(
            keccak256(abi.encode(target, value, signature, data, eta)),
            target,
            value,
            signature,
            data,
            eta
        );
        timelock.queueTransaction(target, value, signature, data, eta);

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        vm.assertEq(timelock.queuedTransactions(txHash), true);
    }

    function test__queueTransaction_RevertsWhen_DelayNotSatisfied() public {
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory data,
            uint256 eta
        ) = _buildTransactionParams();
        eta = block.timestamp + 1 minutes;

        vm.prank(alice);
        vm.expectRevert(
            "Timelock::queueTransaction: Estimated execution block must satisfy delay."
        );
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    function test__cancelTransaction() public {
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory data,
            uint256 eta
        ) = _buildTransactionParams();

        // Queue Transaction
        vm.prank(alice);
        timelock.queueTransaction(target, value, signature, data, eta);

        vm.prank(bob);
        vm.expectRevert("Timelock::cancelTransaction: Call must come from admin.");
        timelock.cancelTransaction(target, value, signature, data, eta);

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit CancelTransaction(txHash, target, value, signature, data, eta);
        timelock.cancelTransaction(target, value, signature, data, eta);

        vm.assertEq(timelock.queuedTransactions(txHash), false);
    }

    function test__executeTransaction() public {
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory data,
            uint256 eta
        ) = _buildTransactionParams();
        data = abi.encode(timelock.maximumDelay() - 1);

        vm.prank(bob);
        vm.expectRevert("Timelock::executeTransaction: Call must come from admin.");
        timelock.executeTransaction(target, value, signature, data, eta);

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
        vm.warp(eta + timelock.delay() + 1);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ExecuteTransaction(txHash, target, value, signature, data, eta);
        timelock.executeTransaction(target, value, signature, data, eta);
        vm.assertEq(timelock.queuedTransactions(txHash), false);
        vm.assertEq(timelock.delay(), timelock.maximumDelay() - 1);
    }

    function test__executeTransactionWithoutSignature() public {
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory data,
            uint256 eta
        ) = _buildTransactionParams();
        signature = "";
        data = abi.encodeWithSignature("setDelay(uint256)", timelock.maximumDelay() - 1);

        // Queue Transaction
        vm.prank(alice);
        timelock.queueTransaction(target, value, signature, data, eta);

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        // Warp to after timelock period
        vm.warp(eta + timelock.delay() + 1);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ExecuteTransaction(txHash, target, value, signature, data, eta);
        timelock.executeTransaction(target, value, signature, data, eta);

        vm.assertEq(timelock.queuedTransactions(txHash), false);
        vm.assertEq(timelock.delay(), timelock.maximumDelay() - 1);
    }

    function test__executeExpiredTransaction() public {
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory data,
            uint256 eta
        ) = _buildTransactionParams();

        // Queue Transaction
        vm.prank(alice);
        timelock.queueTransaction(target, value, signature, data, eta);

        // Warp to after grace period
        vm.warp(eta + timelock.gracePeriod() + 1);

        // Try to execute expired transaction
        vm.prank(alice);
        vm.expectRevert("Timelock::executeTransaction: Transaction is stale.");
        timelock.executeTransaction(target, value, signature, data, eta);
    }

    function test__executeNotQueuedTransaction() public {
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory data,
            uint256 eta
        ) = _buildTransactionParams();

        // Try to execute expired transaction
        vm.prank(alice);
        vm.expectRevert("Timelock::executeTransaction: Transaction hasn't been queued.");
        timelock.executeTransaction(target, value, signature, data, eta);
    }

    function test__executeFailedTransaction() public {
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory data,
            uint256 eta
        ) = _buildTransactionParams();
        signature = "invalid(uint256)";

        // Queue Transaction
        vm.prank(alice);
        timelock.queueTransaction(target, value, signature, data, eta);

        // Warp to after grace period
        vm.warp(eta + timelock.delay() + 1);

        // Try to execute expired transaction
        vm.prank(alice);
        vm.expectRevert("Timelock::executeTransaction: Transaction execution reverted.");
        timelock.executeTransaction(target, value, signature, data, eta);
    }

    function test__getBlockTimestamp() public {
        PublicTimelock publicTimelock = new PublicTimelock();
        uint256 blockTimestamp = publicTimelock.getBlockTimestampPublic();
        assertEq(blockTimestamp, block.timestamp);
    }

    function test_setDelay() public {
        uint256 validDelay = 15 hours;
        vm.expectRevert("Timelock::setDelay: Call must come from Timelock.");
        timelock.setDelay(validDelay);

        vm.startPrank(address(timelock));
        vm.expectRevert("Timelock::setDelay: Delay must not exceed maximum delay.");
        timelock.setDelay(31 hours);

        vm.expectRevert("Timelock::setDelay: Delay must exceed minimum delay.");
        timelock.setDelay(2 seconds);

        vm.expectEmit(true, false, false, false);
        emit NewDelay(validDelay);
        timelock.setDelay(validDelay);
        assertEq(timelock.delay(), validDelay);
        vm.stopPrank();
    }

    function test_updateVariables() public {
        uint256 newGracePeriod = timelock.gracePeriod() + 2 days;
        uint256 newMinDelay = timelock.minimumDelay() + 1 minutes;
        uint256 newMaxDelay = timelock.maximumDelay() - 1 hours;

        vm.expectRevert("Timelock::updateVariables: Call must come from Timelock.");
        timelock.updateVariables(newGracePeriod, newMinDelay, newMaxDelay);

        vm.startPrank(address(timelock));
        vm.expectRevert("Timelock::updateVariables: Minimum delay must exceed minimum delay.");
        timelock.updateVariables(newGracePeriod, 1 seconds, newMaxDelay);

        vm.expectRevert("Timelock::updateVariables: Maximum delay must not exceed maximum delay.");
        timelock.updateVariables(newGracePeriod, newMinDelay, 31 hours);

        timelock.updateVariables(newGracePeriod, newMinDelay, newMaxDelay);
        assertEq(timelock.gracePeriod(), newGracePeriod);
        assertEq(timelock.minimumDelay(), newMinDelay);
        assertEq(timelock.maximumDelay(), newMaxDelay);
        vm.stopPrank();
    }
}
