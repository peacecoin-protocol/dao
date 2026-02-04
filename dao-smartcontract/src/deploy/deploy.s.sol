// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../Bounty.sol";
import "../Governance/GovernorAlpha.sol";
import "../Governance/Timelock.sol";
import "../ContractFactory.sol";
import "../DAOFactory.sol";
import "../mocks/PCECommunityGovToken.sol";
import "../Campaigns.sol";
import "../Governance/PEACECOINDAO_SBT.sol";
import "../Governance/PCE.sol";
import "../Governance/PEACECOINDAO_NFT.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {console} from "forge-std/console.sol";
import {DeployDAOFactory} from "../deploy/DeployDAOFactory.sol";
import {IDAOFactory} from "../interfaces/IDAOFactory.sol";

contract deploy is Script, DeployDAOFactory {
    // Metadata for SBT

    string daoName = "PCE DAO";
    uint256 _votingDelay = 1;
    uint256 _votingPeriod = 50; // 3 blocks
    uint256 _proposalThreshold = 30 ether;
    uint256 _quorumVotes = 200 ether;
    uint256 _bountyAmount = 0;

    IDAOFactory.SocialConfig public SOCIAL_CONFIG =
        IDAOFactory.SocialConfig({
            description: "PEACECOIN DAO",
            website: "https://peacecoin.com",
            linkedin: "https://linkedin.com/peacecoin",
            twitter: "https://twitter.com/peacecoin",
            telegram: "https://t.me/peacecoin"
        });
    address PCE_TOKEN = 0x951E69b565924c0b846Ed0E779f190c53d29F62e;

    function run() external {
        (
            address daoFactoryAddress,
            address timelockAddress,
            address governorAddress
        ) = deployDAOFactory();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address proxyAdminAddress = address(new ProxyAdmin(deployerAddress));
        vm.startBroadcast(deployerPrivateKey);

        vm.roll(block.number + 1);

        Bounty bounty = new Bounty(); // Deploy Bounty Contract
        bounty.initialize(ERC20Upgradeable(PCE_TOKEN), _bountyAmount, address(governorAddress));

        ContractFactory contractFactory = new ContractFactory(deployerAddress);

        address _deployerAddress = deployerAddress;
        vm.roll(block.number + 1); // Wait for 1 block

        Campaigns campaigns = new Campaigns();
        address campaignsAddress = address(
            new TransparentUpgradeableProxy(address(campaigns), proxyAdminAddress, "")
        );
        Campaigns(campaignsAddress).initialize(daoFactoryAddress);
        IDAOFactory(daoFactoryAddress).setCampaignFactory(campaignsAddress);

        console.log("Campaigns deployed at", campaignsAddress);
        console.log("PCE Token: ", PCE_TOKEN);
        console.log("Bounty: ", address(bounty));
        console.log("ContractFactory: ", address(contractFactory));
        console.log("ProxyAdmin: ", proxyAdminAddress);
    }
}
