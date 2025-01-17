// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../mocks/MockERC20.sol";

contract MockERC20Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 mockERC20 = new MockERC20();
        mockERC20.initialize();
        // mockERC20.mint();

        vm.stopBroadcast();
    }
}
