// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TestContract {
    event ContractDeployed(address contractAddress);

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable Error");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function transferOwnership(address _owner) external onlyOwner {
        owner = _owner;
    }
}
