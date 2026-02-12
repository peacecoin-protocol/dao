// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MockGovernance {
    mapping(uint256 => uint8) public proposalStates;
    mapping(uint256 => address) public proposers;
    uint256 public proposalCount;

    function setProposalState(uint256 proposalId, uint8 newState) external {
        proposalStates[proposalId] = newState;
        if (proposalId >= proposalCount) {
            proposalCount = proposalId + 1;
        }
    }

    function setProposer(uint256 proposalId, address newProposer) external {
        proposers[proposalId] = newProposer;
    }

    function state(uint256 proposalId) external view returns (uint8) {
        return proposalStates[proposalId];
    }

    function proposer(uint256 proposalId) external view returns (address) {
        return proposers[proposalId];
    }
}
