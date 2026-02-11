// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {ContractFactory} from "../ContractFactory.sol";
import {console} from "forge-std/console.sol";

contract ContractFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        ContractFactory factory = new ContractFactory(deployerAddress);

        vm.stopBroadcast();

        console.log("ContractFactory deployed at", address(factory));
    }
}
