// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, Vm} from "forge-std/Test.sol";
import {ContractFactory} from "../src/ContractFactory.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";

contract Example {
    constructor(address _factoryAddress) {}

    function deployNewContract() public {}
}

contract ContractFactoryTest is Test {
    address alice = makeAddr("Alice"); // Owner
    address bob = makeAddr("Bob");

    bytes bytecode = type(Example).creationCode;
    bytes _arguments = abi.encode(0x7D01D10d894B36dBA00E5ecc1e54ff32e83F84D5);

    event ContractDeployed(address indexed contractAddress);

    ContractFactory contractFactory;

    function setUp() public {
        contractFactory = new ContractFactory(alice);
    }

    function testDeploy() public {
        vm.prank(bob);
        vm.expectRevert(IErrors.PermissionDenied.selector);

        contractFactory.deploy(getBytecodeWithConstructorArgs(bytecode, _arguments));

        vm.prank(alice);
        contractFactory.deploy(getBytecodeWithConstructorArgs(bytecode, _arguments));
    }

    function testDeploy_EmitsEventWithAddress() public {
        // We check the logs instead of using vm.expectEmit because we need the newly created address
        vm.recordLogs();

        vm.prank(alice);
        address deployedAddress = contractFactory.deploy(
            getBytecodeWithConstructorArgs(bytecode, _arguments)
        );

        // Assert: Verify event was emitted with correct address
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = logs[0].topics[0];
        address contractAddressFromLog = address(uint160(uint256(logs[0].topics[1])));
        assertEq(eventSignature, ContractDeployed.selector);
        assertEq(contractAddressFromLog, deployedAddress);
    }

    /**
     * @notice Tests that deployment reverts with invalid bytecode
     * @dev Verifies that invalid bytecode causes deployment to fail
     */
    function test_deploy_RevertsWhen_InvalidBytecode() public {
        // Act & Assert: Invalid bytecode should cause revert
        vm.prank(alice);
        vm.expectRevert(IErrors.ContractDeploymentFailed.selector);
        contractFactory.deploy(bytes("Invalid EVM bytecode"));
    }

    function getBytecodeWithConstructorArgs(
        bytes memory _bytecode,
        bytes memory _constructorArgs
    ) public pure returns (bytes memory) {
        return abi.encodePacked(_bytecode, _constructorArgs);
    }
}
