// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../PCEGovTokenTest.sol";

contract Deployed is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PCEGovTokenTest bounty = new PCEGovTokenTest();
        bounty.initialize(0x59178bAc7A9BBfa287F39887EAA2826666f14A2a);
        vm.stopBroadcast();
    }
}
