// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPCEToken {
    function moveVotingPower(address from, address to, uint256 amount) external;
    function getSwapRate(
        address fromToken
    ) external returns (uint256);
}
