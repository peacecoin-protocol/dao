// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../Governance/GovernorAlpha.sol";
import "../Governance/Timelock.sol";

contract DAOScript is Script {
    function run() external {
        address pceToken = 0x1A9ed93e12730F7dcdCF5F8cFFEb94c48fe34350;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        Timelock timelock = new Timelock(deployerAddress, 2 days);
        GovernorAlpha governance = new GovernorAlpha(
            address(timelock),
            pceToken,
            deployerAddress
        );

        timelock.setPendingAdmin(address(governance));

        vm.stopBroadcast();
    }
}
