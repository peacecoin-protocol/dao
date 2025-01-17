// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract ContractFactory {
    event ContractDeployed(address contractAddress);

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable Error");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    // Deploy a contract using bytecode and constructor arguments
    function deploy(bytes memory bytecode) external onlyOwner returns (address deployedAddress) {
        // Create a new contract using assembly
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Create a new contract using the `create` opcode
            deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        // Check if deployment was successful
        require(deployedAddress != address(0), "Contract deployment failed");

        // Emit an event with the address of the new contract
        emit ContractDeployed(deployedAddress);
    }

    function transferOwnership(address _owner) external onlyOwner {
        owner = _owner;
    }
}
