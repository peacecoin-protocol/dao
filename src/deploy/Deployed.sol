// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../PCEGovTokenTest.sol";

contract Deployed is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PCEGovTokenTest bounty = new PCEGovTokenTest();
        bounty.initialize();
        vm.stopBroadcast();
    }
}
