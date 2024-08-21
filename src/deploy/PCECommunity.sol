// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../PCECommunityToken.sol";

contract PCECommunityScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PCECommunityToken comminity = new PCECommunityToken();
        vm.stopBroadcast();
    }
}
