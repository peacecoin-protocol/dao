// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract TestContract {
    event ContractDeployed(address contractAddress);
    error OwnableError();

    address public owner;

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != owner) revert OwnableError();
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
