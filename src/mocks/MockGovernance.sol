// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract MockGovernance {
    mapping(uint256 => uint8) public proposalStates;
    mapping(uint256 => address) public proposers;
    uint256 public proposalCount;

    function setProposalState(uint256 proposalId, uint8 state) external {
        proposalStates[proposalId] = state;
        if (proposalId >= proposalCount) {
            proposalCount = proposalId + 1;
        }
    }

    function setProposer(uint256 proposalId, address proposer) external {
        proposers[proposalId] = proposer;
    }

    function state(uint256 proposalId) external view returns (uint8) {
        return proposalStates[proposalId];
    }

    function proposer(uint256 proposalId) external view returns (address) {
        return proposers[proposalId];
    }
}
