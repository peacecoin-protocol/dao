// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MockGovernance {
    mapping(uint256 => uint8) public proposalStates;
    mapping(uint256 => address) public proposers;
    uint256 public proposalCount;

    function setProposalState(uint256 _proposalId, uint8 _state) external {
        proposalStates[_proposalId] = _state;
        if (_proposalId >= proposalCount) {
            proposalCount = _proposalId + 1;
        }
    }

    function setProposer(uint256 _proposalId, address _proposer) external {
        proposers[_proposalId] = _proposer;
    }

    function state(uint256 _proposalId) external view returns (uint8) {
        return proposalStates[_proposalId];
    }

    function proposer(uint256 _proposalId) external view returns (address) {
        return proposers[_proposalId];
    }
}
