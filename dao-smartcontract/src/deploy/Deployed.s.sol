// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Campaigns} from "../Campaigns.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IDAOFactory} from "../interfaces/IDAOFactory.sol";
import {console} from "forge-std/console.sol";

contract Deployed is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        address daoFactoryAddress = 0x167F0B2D2aA5e76170201d0a14BA7fDA649EA25E;

        address proxyAdmin = address(new ProxyAdmin(deployerAddress));

        Campaigns campaigns = new Campaigns();
        address campaignsAddress = address(
            new TransparentUpgradeableProxy(address(campaigns), proxyAdmin, "")
        );
        Campaigns(campaignsAddress).initialize(daoFactoryAddress);
        IDAOFactory(daoFactoryAddress).setCampaignFactory(campaignsAddress);

        console.log("Campaigns deployed at", campaignsAddress);

        vm.stopBroadcast();
    }
}
