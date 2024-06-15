// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../Governance/GovernorAlpha.sol";
import "../Governance/Timelock.sol";

contract DAOScript is Script {
    function run() external {
        address pceToken = 0x09114706E2b7338a09279D4AC984E859B964633c;
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
