// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {console} from "forge-std/console.sol";

contract Timelock is Initializable {
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta
    );

    uint256 public GRACE_PERIOD;
    uint256 public MINIMUM_DELAY;
    uint256 public MAXIMUM_DELAY;

    address public admin;
    address public pendingAdmin;
    uint256 public delay;

    bool public adminInitialized;

    mapping(bytes32 => bool) public queuedTransactions;

    function initialize(address admin_, uint256 delay_) external initializer {
        GRACE_PERIOD = 14 days;
        MINIMUM_DELAY = 1 minutes;
        MAXIMUM_DELAY = 30 hours;

        require(delay_ >= MINIMUM_DELAY, "Timelock::constructor: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");

        admin = admin_;
        delay = delay_;
    }

    function updateVariables(uint256 gracePeriod_, uint256 minDelay_, uint256 maxDelay_) public {
        require(msg.sender == address(this), "Timelock::updateVariables: Call must come from Timelock.");
        require(minDelay_ >= MINIMUM_DELAY, "Timelock::updateVariables: Minimum delay must exceed minimum delay.");
        require(maxDelay_ <= MAXIMUM_DELAY, "Timelock::updateVariables: Maximum delay must not exceed maximum delay.");
        GRACE_PERIOD = gracePeriod_;
        MINIMUM_DELAY = minDelay_;
        MAXIMUM_DELAY = maxDelay_;
    }

    function setDelay(uint256 delay_) public {
        require(msg.sender == address(this), "Timelock::setDelay: Call must come from Timelock.");
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "Timelock::acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        require(pendingAdmin_ != address(0), "Timelock::setPendingAdmin: Invalid address");
        if (adminInitialized) {
            require(msg.sender == address(this), "Timelock::setPendingAdmin: Call must come from Timelock.");
        } else {
            require(msg.sender == admin, "Timelock::setPendingAdmin: First call must come from admin.");
            adminInitialized = true;
        }
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
        public
        returns (bytes32)
    {
        require(msg.sender == admin, "Timelock::queueTransaction: Call must come from admin.");
        require(
            eta >= getBlockTimestamp() + delay,
            "Timelock::queueTransaction: Estimated execution block must satisfy delay."
        );

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
        public
    {
        require(msg.sender == admin, "Timelock::cancelTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
        public
        payable
        returns (bytes memory)
    {
        require(msg.sender == admin, "Timelock::executeTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock::executeTransaction: Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta + GRACE_PERIOD, "Timelock::executeTransaction: Transaction is stale.");

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}
