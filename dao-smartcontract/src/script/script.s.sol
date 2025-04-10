// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../mocks/MockERC20.sol";
import "../Bounty.sol";
import "../Governance/GovernorAlpha.sol";
import "../Governance/Timelock.sol";
import "../ContractFactory.sol";
import "../DAOFactory.sol";
import "../PCECommunityGovToken.sol";
import "../Campagins.sol";

import {console} from "forge-std/console.sol";

contract script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        uint256 _bountyAmount = 0;

        address PCE_TOKEN = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
        Timelock timelock = new Timelock();
        GovernorAlpha gov = new GovernorAlpha();

        Bounty bounty = new Bounty(); // Deploy Bounty Contract
        bounty.initialize(ERC20Upgradeable(PCE_TOKEN), _bountyAmount, address(gov));

        ContractFactory contractFactory = new ContractFactory(deployerAddress);
        DAOFactory daoFactory = new DAOFactory();

        vm.roll(block.number + 1); // Wait for 1 block

        PCECommunityGovToken pceCommunityGovToken = new PCECommunityGovToken();

        daoFactory.setImplementation(address(timelock), address(gov), address(pceCommunityGovToken));

        pceCommunityGovToken.initialize(PCE_TOKEN);

        timelock.initialize(deployerAddress, 1 minutes);

        vm.roll(block.number + 1); // Wait for 1 block

        string memory daoName = "PCE DAO";
        uint256 _votingDelay = 1;
        uint256 _votingPeriod = 3; // 3 blocks
        uint256 _proposalThreshold = 1000e18;
        uint256 _quorumVotes = 2000e18;
        gov.initialize(daoName, address(pceCommunityGovToken), address(timelock), _votingDelay, _votingPeriod, _proposalThreshold, _quorumVotes);
        timelock.setPendingAdmin(address(gov));
        gov.__acceptAdmin();

        vm.roll(block.number + 1); // Wait for 1 block

        Campagins campagins = new Campagins();
        campagins.initialize(ERC20Upgradeable(PCE_TOKEN));

        ERC20Upgradeable(PCE_TOKEN).transfer(address(campagins), 10000e18);

        Campagins.Campagin memory campagin = Campagins.Campagin({
            title: "Airdrop Announcement: PCE Tokens for Top 10 Holders",
            description: "The Peace Coin Foundation is pleased to announce an exclusive airdrop of PCE tokens to the top 10 PCE token holders. A snapshot of eligible wallets will be taken on February 25, 2025. Stay tuned for more details and ensure your holdings are up to date!",
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 3000,
            amount: 10e18,
            validateSignatures: false
        });

        campagins.createCampagin(campagin);
        vm.roll(block.number + 1); // Wait for 1 block

        campagins.createCampagin(campagin);
        campagins.createCampagin(campagin);
        
        campagin.validateSignatures = true;
        campagins.createCampagin(campagin);
        vm.roll(block.number + 1); // Wait for 1 block

        address[] memory winners = new address[](1);
        winners[0] = deployerAddress;

        campagins.addCampWinners(0, winners);
        campagins.addCampWinners(1, winners);
        campagins.addCampWinners(3, winners);
        vm.roll(block.number + 1); // Wait for 1 block


        console.log("PCE Token: ", PCE_TOKEN);
        console.log("Timelock: ", address(timelock));
        console.log("Governor: ", address(gov));
        console.log("Bounty: ", address(bounty));
        console.log("ContractFactory: ", address(contractFactory));
        console.log("DAOFactory: ", address(daoFactory));
        console.log("PCE Community Gov Token: ", address(pceCommunityGovToken));
        console.log("Campagins: ", address(campagins));
    }
}
