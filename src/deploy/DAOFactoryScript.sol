// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {DAOFactory} from "../DAOFactory.sol";

contract DAOFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        DAOFactory daoFactory = new DAOFactory();

        vm.stopBroadcast();
    }
}
