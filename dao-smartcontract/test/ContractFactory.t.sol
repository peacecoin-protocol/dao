// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {ContractFactory} from "../src/ContractFactory.sol";
import "forge-std/console.sol";

contract Example {
    constructor(address _factoryAddress) {}

    function deployNewContract() public {}
}

contract ContractFactoryTest is Test {
    address alice = makeAddr("Alice"); // Owner
    address bob = makeAddr("Bob");

    bytes bytecode = type(Example).creationCode;
    bytes _arguments = abi.encode(0x7D01D10d894B36dBA00E5ecc1e54ff32e83F84D5);

    event ContractDeployed(address contractAddress);

    ContractFactory contractFactory;

    function setUp() public {
        contractFactory = new ContractFactory(alice);
    }

    function testDeploy() public {
        vm.prank(bob);
        vm.expectRevert("Ownable Error");

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

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = logs[0].topics[0];
        address contractAddressFromLog = abi.decode(logs[0].data, (address));
        assertEq(eventSignature, ContractDeployed.selector);
        assertEq(contractAddressFromLog, deployedAddress);
    }

    function testDeploy_Reverts_WhenByteCodeIsInvalid() public {
        vm.prank(alice);
        vm.expectRevert("Contract deployment failed");
        contractFactory.deploy(bytes("Invalid EVM bytecode"));
    }

    function getBytecodeWithConstructorArgs(
        bytes memory _bytecode,
        bytes memory _constructorArgs
    ) public pure returns (bytes memory) {
        return abi.encodePacked(_bytecode, _constructorArgs);
    }
}
