// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IErrors {
    error AlreadyDelegated();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidArrayLength();
    error InvalidBalance();
    error InvalidCampaign();
    error InvalidName();
    error InvalidSymbol();
    error InvalidTokenId();
    error NonTransferable();
    error PermissionDenied();
    error InvalidMinter();
    error InvalidStartDate();
    error InvalidClaimAmount();
    error InvalidCampaignId();
    error CampaignNotStarted();
    error CampaignEnded();
    error CampaignFullyClaimed();
    error AlreadyClaimed();
    error InvalidSignature();
    error NotWhitelisted();
    error NoWinners();
    error InvalidGistsLength();
    error InvalidAddressesLength();
    error InvalidSignatureLength();
    error InvalidCommunityTokenOwner();
    error InvalidCommunityToken();
    error EmptyNameNotAllowed();
    error DAONameAlreadyExists();
    error DAOAlreadyExists();
    error TimelockImplementationNotSet();
    error GovernorImplementationNotSet();
    error GovernanceTokenImplementationNotSet();
    error InvalidVotingDelay();
    error InvalidVotingPeriod();
    error InvalidTimelockDelay();
    error InvalidQuorumVotes();
    error DAODoesNotExist();
    error InvalidDAOManager();
    error ContractDeploymentFailed();
    error InvalidProposalState();
    error ZeroAmount();
    error NothingToWithdraw();
    error InvalidContributor();
    error InvalidPCEAddress();
    error InvalidWPCEAddress();
    error InvalidRewardPerBlock();
    error InsufficientBalance();
    error TransferFailed();
    error NoUnusedTokens();
    error InvalidCreator();
}
