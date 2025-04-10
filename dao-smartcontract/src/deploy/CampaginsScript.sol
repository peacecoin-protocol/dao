// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../Campagins.sol";
import "../PCEGovTokenTest.sol";

contract CampaginsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PCEGovTokenTest token = new PCEGovTokenTest();
        token.initialize();

        Campagins campagins = new Campagins();
        campagins.initialize(ERC20Upgradeable(address(token)));

        console.log("Campagins deployed at", address(campagins));

        vm.stopBroadcast();
    }
}
