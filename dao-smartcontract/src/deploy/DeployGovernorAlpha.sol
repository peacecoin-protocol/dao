// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GovernorAlpha} from "../Governance/GovernorAlpha.sol";

contract DeployGovernorAlpha is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        GovernorAlpha governorAlpha = new GovernorAlpha();

        vm.stopBroadcast();

        console.log("Governor Alpha deployed at", address(governorAlpha));
    }
}
