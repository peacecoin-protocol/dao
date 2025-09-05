// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../mocks/PCEGovToken.sol";

contract PCEGovTokenScript is Script {
    function run() external {
        address pceToken = 0x7e7887bE34AD96b553E1a16cA76d99697608ce23;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        PCEGovToken pceGovToken = new PCEGovToken();
        pceGovToken.initialize(deployerAddress, pceToken);

        vm.stopBroadcast();
    }
}
