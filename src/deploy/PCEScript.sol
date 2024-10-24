// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {PCETokenV2} from "../PCETokenV2.sol";
import {PCECommunityToken} from "lib/v1-core/src/PCECommunityToken.sol";

contract PCEScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PCECommunityToken communityToken = new PCECommunityToken();
        PCETokenV2 pceToken = new PCETokenV2();
        pceToken.initialize(
            "PCE Coin",
            "PCE",
            address(communityToken),
            address(0)
        );

        vm.stopBroadcast();
    }
}
