// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../Campaigns.sol";

contract DeployContract is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Campaigns campaigns = new Campaigns();
        campaigns.initialize(0x05cc398C83852BdDE741590bc8Aa64851BFDB3A8);
        vm.stopBroadcast();

        console.log("Campaigns deployed at", address(campaigns));
    }
}
