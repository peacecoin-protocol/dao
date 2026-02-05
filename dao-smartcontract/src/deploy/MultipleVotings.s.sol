// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {MultipleVotings} from "../Governance/MultipleVotings.sol";
import {console} from "forge-std/console.sol";

contract MultipleVotingsScript is Script {
    address public governor = 0xceA083fC0516461042bFA60F6Cb23BA6460619e8;
    address public admin = 0x97A88179485e81d623C5421e2F231338C663f7e0;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MultipleVotings multipleVotings = new MultipleVotings();
        multipleVotings.initialize(governor, admin);

        console.log("MultipleVotings deployed at", address(multipleVotings));

        vm.stopBroadcast();
    }
}
