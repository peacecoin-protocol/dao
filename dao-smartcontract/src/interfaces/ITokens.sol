// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface ITokens {
    function creators(uint256 _tokenId) external view returns (address);
    function owner() external view returns (address);
}
