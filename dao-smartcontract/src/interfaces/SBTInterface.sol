// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface SBTInterface {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint96);
}
