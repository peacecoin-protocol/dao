// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IDAOFactory {
    struct DAOConfig {
        address timelock;
        address multipleVoting;
        address sbt;
        address nft;
        address governor;
        address governanceToken;
        address communityToken;
        address creator;
    }

    struct SocialConfig {
        string description;
        string website;
        string linkedin;
        string twitter;
        string telegram;
    }

    function setImplementation(
        address _timelockImplementation,
        address _governorImplementation,
        address _governanceTokenImplementation,
        address _multipleVotingImplementation,
        address _sbtImplementation,
        address _nftImplementation
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

    function campaignFactory() external view returns (address);
    function setCampaignFactory(address _campaignFactory) external;
    function daoConfigs(
        bytes32 daoID
    )
        external
        view
        returns (address, address, address, address, address, address, address, address);
}
