// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../PCEToken.sol";
import "../PCECommunityToken.sol";

contract PCEScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PCECommunityToken communityToken = new PCECommunityToken();
        PCEToken pceToken = new PCEToken();
        pceToken.initialize(
            "PCE Coin",
            "PCE",
            address(communityToken),
            address(0)
        );

        vm.stopBroadcast();
    }
}
