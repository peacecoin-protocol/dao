// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {ContractFactory} from "../ContractFactory.sol";
import {Campaigns} from "../Campaigns.sol";
import {DeployDAOFactory} from "../deploy/DeployDAOFactory.s.sol";
import {IDAOFactory} from "../interfaces/IDAOFactory.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {console} from "forge-std/console.sol";

contract Deploy is Script, DeployDAOFactory {
    function run() external {
        (address daoFactoryAddress, , ) = deployDaoFactory();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address proxyAdminAddress = address(new ProxyAdmin(deployerAddress));
        vm.startBroadcast(deployerPrivateKey);

        vm.roll(block.number + 1);

        ContractFactory contractFactory = new ContractFactory(deployerAddress);

        vm.roll(block.number + 1); // Wait for 1 block

        Campaigns campaigns = new Campaigns();
        address campaignsAddress = address(
            new TransparentUpgradeableProxy(address(campaigns), proxyAdminAddress, "")
        );
        Campaigns(campaignsAddress).initialize(daoFactoryAddress);
        IDAOFactory(daoFactoryAddress).setCampaignFactory(campaignsAddress);

        console.log("Campaigns deployed at", campaignsAddress);
        console.log("ContractFactory: ", address(contractFactory));
        console.log("ProxyAdmin: ", proxyAdminAddress);
    }
}
