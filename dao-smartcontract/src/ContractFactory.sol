// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IErrors} from "./interfaces/IErrors.sol";

/**
 * @title ContractFactory
 * @dev Factory contract for deploying contracts using bytecode
 * @notice This contract allows the owner to deploy contracts using provided bytecode
 * @author Your Name
 */
contract ContractFactory is IErrors {
    // ============ Events ============
    event ContractDeployed(address contractAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ State Variables ============
    address public owner;

    // ============ Modifiers ============
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != owner) revert PermissionDenied();
    }

    // ============ Constructor ============
    constructor(address _owner) {
        if (_owner == address(0)) revert InvalidAddress();
        owner = _owner;
    }

    // ============ External Functions ============

    /**
     * @notice Deploy a contract using bytecode
     * @dev Only callable by the contract owner
     * @param bytecode Bytecode of the contract to deploy
     * @return deployedAddress Address of the deployed contract
     */
    function deploy(bytes memory bytecode) external onlyOwner returns (address deployedAddress) {
        if (bytecode.length == 0) revert InvalidArrayLength();

        // Create a new contract using assembly
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Create a new contract using the `create` opcode
            deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        // Check if deployment was successful
        if (deployedAddress == address(0)) revert ContractDeploymentFailed();

        // Emit an event with the address of the new contract
        emit ContractDeployed(deployedAddress);
    }

    /**
     * @notice Transfer ownership of the contract
     * @dev Only callable by the current owner
     * @param _owner Address of the new owner
     */
    function transferOwnership(address _owner) external onlyOwner {
        if (_owner == address(0)) revert InvalidAddress();

        address previousOwner = owner;
        owner = _owner;

        emit OwnershipTransferred(previousOwner, _owner);
    }
}
