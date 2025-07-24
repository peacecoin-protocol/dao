// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../SBT.sol";

contract SBTScript is Script {
    function run() external {
        string memory baseUri = "https://orange-elegant-takin-78.mypinata.cloud/ipfs/";
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        new SBT("SBT", "SBT", baseUri);
        vm.stopBroadcast();
    }
}
