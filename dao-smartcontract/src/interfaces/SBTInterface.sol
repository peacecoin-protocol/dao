// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface SBTInterface {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint96);
}
