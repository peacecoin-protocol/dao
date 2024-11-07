// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../DAOStudio.sol";

contract DAOStudioScript is Script {
    function run() external {
        address pceToken = 0xf939595726798393F63Dbe098a54C7948DEF8faF;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        DAOStudio daoStudio = new DAOStudio();
        daoStudio.initialize(deployerAddress, pceToken);

        vm.stopBroadcast();
    }
}
