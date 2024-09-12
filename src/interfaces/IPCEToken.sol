// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IPCEToken {
    function getSwapRate(address fromToken) external returns (uint256);
}
