// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Bounty} from "../Bounty.sol";
import {ContractFactory} from "../ContractFactory.sol";
import {Campaigns} from "../Campaigns.sol";
import {DeployDAOFactory} from "../deploy/DeployDAOFactory.s.sol";
import {IDAOFactory} from "../interfaces/IDAOFactory.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {console} from "forge-std/console.sol";

contract deploy is Script, DeployDAOFactory {
    // Metadata for SBT

    string public constant daoName = "PCE DAO";
    uint256 public constant votingDelay = 1;
    uint256 public constant votingPeriod = 50; // 3 blocks
    uint256 public constant proposalThreshold = 30 ether;
    uint256 public constant quorumVotes = 200 ether;
    uint256 public constant bountyAmount = 0;

    IDAOFactory.SocialConfig public socialConfig =
        IDAOFactory.SocialConfig({
            description: "PEACECOIN DAO",
            website: "https://peacecoin.com",
            linkedin: "https://linkedin.com/peacecoin",
            twitter: "https://twitter.com/peacecoin",
            telegram: "https://t.me/peacecoin"
        });
    address pceToken = 0x951E69b565924c0b846Ed0E779f190c53d29F62e;

    function run() external {
        (address daoFactoryAddress, , address governorAddress) = deployDaoFactory();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address proxyAdminAddress = address(new ProxyAdmin(deployerAddress));
        vm.startBroadcast(deployerPrivateKey);

        vm.roll(block.number + 1);

        Bounty bounty = new Bounty(); // Deploy Bounty Contract
        bounty.initialize({
            token: ERC20Upgradeable(pceToken),
            initialBountyAmount: bountyAmount,
            governanceAddress: address(governorAddress)
        });

        ContractFactory contractFactory = new ContractFactory(deployerAddress);

        vm.roll(block.number + 1); // Wait for 1 block

        Campaigns campaigns = new Campaigns();
        address campaignsAddress = address(
            new TransparentUpgradeableProxy(address(campaigns), proxyAdminAddress, "")
        );
        Campaigns(campaignsAddress).initialize(daoFactoryAddress);
        IDAOFactory(daoFactoryAddress).setCampaignFactory(campaignsAddress);

        console.log("DAO Name: ", daoName);
        console.log("Voting Delay: ", votingDelay);
        console.log("Voting Period: ", votingPeriod);
        console.log("Proposal Threshold: ", proposalThreshold);
        console.log("Quorum Votes: ", quorumVotes);
        console.log("Campaigns deployed at", campaignsAddress);
        console.log("PCE Token: ", pceToken);
        console.log("Bounty: ", address(bounty));
        console.log("ContractFactory: ", address(contractFactory));
        console.log("ProxyAdmin: ", proxyAdminAddress);
    }
}
