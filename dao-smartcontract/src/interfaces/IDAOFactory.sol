// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IDAOFactory {
    struct SocialConfig {
        string description;
        string website;
        string linkedin;
        string twitter;
        string telegram;
    }

    struct GovernorConfig {
        string name;
        address governor;
        address timelock;
        address governanceToken;
        address communityToken;
    }

    function setImplementation(
        address _timelockImplementation,
        address _governorImplementation,
        address _governanceTokenImplementation
    ) external;

    function createDAO(
        string memory daoName,
        SocialConfig memory socialConfig,
        address communityToken,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 timelockDelay,
        uint256 quorumVotes
    ) external returns (bytes32);
}
