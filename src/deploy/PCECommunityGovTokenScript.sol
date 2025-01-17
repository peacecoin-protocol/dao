// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../PCECommunityGovToken.sol";

contract PCECommunityGovTokenScript is Script {
    function run() external {
        address communityToken = 0x7e7887bE34AD96b553E1a16cA76d99697608ce23;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        PCECommunityGovToken pceCommunityGovToken = new PCECommunityGovToken();
        pceCommunityGovToken.initialize(communityToken);
        vm.stopBroadcast();
    }
}
