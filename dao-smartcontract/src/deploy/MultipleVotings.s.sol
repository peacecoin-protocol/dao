// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import {MultipleVotings} from "../Governance/MultipleVotings.sol";

contract MultipleVotingsScript is Script {
    address public token = 0x152A9180a0cbC56B26dFF467D21433e14ce67Ffd;
    address public sbt = 0x152A9180a0cbC56B26dFF467D21433e14ce67Ffd;
    address public nft = 0x46859A3955926197cD99D31060024C05CE36f600;
    uint256 public votingDelay = 1;
    uint256 public votingPeriod = 30;
    uint256 public quorumVotes = 100;
    uint256 public proposalThreshold = 30;
    address public admin = 0x97A88179485e81d623C5421e2F231338C663f7e0;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MultipleVotings multipleVotings = new MultipleVotings();
        multipleVotings.initialize(
            address(token),
            address(sbt),
            address(nft),
            votingDelay,
            votingPeriod,
            quorumVotes,
            proposalThreshold,
            admin
        );

        vm.stopBroadcast();
    }
}
