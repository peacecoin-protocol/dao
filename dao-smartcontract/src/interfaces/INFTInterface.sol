// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface INFTInterface {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint96);
    function initialize(
        string memory _uri,
        address _daoFactory,
        address _owner,
        bool _isSbt
    ) external;
}
