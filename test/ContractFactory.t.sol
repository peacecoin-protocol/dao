// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ContractFactory} from "../src/ContractFactory.sol";
import "forge-std/console.sol";

contract Example {
    constructor(address _factoryAddress) {}

    function deployNewContract() public {}
}

contract ContractFactoryTest is Test {
    address alice = address(0xABCD);
    address bob = address(0xDCBA);
    address trent = address(this);

    bytes bytecode = type(Example).creationCode;
    bytes _arguments = abi.encode(0x7D01D10d894B36dBA00E5ecc1e54ff32e83F84D5);

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

    function getBytecodeWithConstructorArgs(bytes memory _bytecode, bytes memory _constructorArgs)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(_bytecode, _constructorArgs);
    }
}
