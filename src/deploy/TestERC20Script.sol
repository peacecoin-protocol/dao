// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../TestERC20.sol";

contract TestERC20Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        TestERC20 testERC20 = new TestERC20();
        testERC20.initialize();

        vm.stopBroadcast();
    }
}
