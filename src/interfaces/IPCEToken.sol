// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IPCEToken {
    struct LocalToken {
        bool isExists;
        uint256 exchangeRate;
        uint256 depositedPCEToken;
    }

    function getLocalToken(address communityToken) external view returns (LocalToken memory);

    function owner() external view returns (address);
}
