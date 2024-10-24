// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {PCECommunityToken} from "lib/v1-core/src/PCECommunityToken.sol";

contract PCECommunityScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PCECommunityToken comminity = new PCECommunityToken();
        vm.stopBroadcast();
    }
}
