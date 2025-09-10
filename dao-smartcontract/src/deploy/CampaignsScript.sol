// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../Campaigns.sol";
import "../mocks/PCEGovTokenTest.sol";
import "../Governance/PEACECOINDAO_SBT.sol";
import "../Governance/PEACECOINDAO_NFT.sol";
import "../Governance/PCE.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract CampaignsScript is Script {
    // PCE pce = PCE(0x951E69b565924c0b846Ed0E779f190c53d29F62e);
    string uri = "https://peacecoin-dao.mypinata.cloud/ipfs/";
    string name = "PEACECOIN DAO SBT";
    string symbol = "PCE_SBT";

    PEACECOINDAO_SBT public sbt;
    PEACECOINDAO_NFT public nft;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);
        PCE pce = new PCE();

        sbt = PEACECOINDAO_SBT(0x27E2A35C5f7fEa1BD9d90e61Ded262781b0045A3);
        nft = PEACECOINDAO_NFT(0x76a3eD980e49AEB2785F0Eb914688FB273857EAF);

        Campaigns campaigns = new Campaigns();
        campaigns.initialize(sbt, nft);

        Campaigns.Campaign memory _campaign = Campaigns.Campaign({
            sbtId: 1,
            title: "Airdrop Contributor NFTs",
            description: "We will airdrop Contributor NFTs to PEACECOIN Contributors",
            claimAmount: 1,
            totalAmount: 10,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 86400,
            validateSignatures: false,
            tokenType: Campaigns.TokenType.NFT,
            token: address(pce)
        });

        campaigns.createCampaign(_campaign);

        vm.roll(block.number + 1);

        _campaign.sbtId = 2;
        _campaign.title = "Airdrop Contributor SBTs 2";
        _campaign.description = "We will airdrop Contributor SBT to PEACECOIN Contributors 2";
        _campaign.validateSignatures = true;
        _campaign.tokenType = Campaigns.TokenType.SBT;
        _campaign.token = address(pce);

        vm.roll(block.number + 1);
        campaigns.createCampaign(_campaign);

        pce.mint(deployerAddress, 1000 ether);
        pce.approve(address(campaigns), 1000 ether);

        _campaign.sbtId = 3;
        _campaign.title = "Airdrop Contributor Token 3";
        _campaign.description = "We will airdrop Contributor Token to PEACECOIN Contributors 3";
        _campaign.claimAmount = 10 ether;
        _campaign.totalAmount = 100 ether;
        _campaign.validateSignatures = true;
        _campaign.tokenType = Campaigns.TokenType.ERC20;
        _campaign.token = address(pce);

        vm.roll(block.number + 1);
        campaigns.createCampaign(_campaign);

        console.log("Campaigns deployed at", address(campaigns));
        console.log("SBT deployed at", address(sbt));
        console.log("NFT deployed at", address(nft));
        // vm.stopBroadcast();
    }
}
