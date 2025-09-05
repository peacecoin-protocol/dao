// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../Campaigns.sol";
import "../mocks/PCEGovTokenTest.sol";
import "../Governance/PEACECOINDAO_SBT.sol";
import "../Governance/PEACECOINDAO_NFT.sol";
import "../Governance/PCE.sol";

contract CampaignsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // PCE pce = new PCE();
        address pce = 0x951E69b565924c0b846Ed0E779f190c53d29F62e;
        string memory uri = "https://peacecoin-dao.mypinata.cloud/ipfs/";
        string memory name = "PEACECOIN DAO SBT";
        string memory symbol = "PCE_SBT";
        string[1] memory tokenURIs = [
            "bafkreibvgbpgvojcekxyhcdm5o27z7mj5wmwkmqxcrprfd2a4txvb6wsvm"
        ];

        PEACECOINDAO_SBT sbt = new PEACECOINDAO_SBT();
        sbt.initialize(uri, name, symbol);

        PEACECOINDAO_NFT nft = new PEACECOINDAO_NFT();
        nft.initialize(uri, name, symbol);

        vm.roll(block.number + 1);

        for (uint256 i = 1; i <= tokenURIs.length; i++) {
            sbt.setTokenURI(i, tokenURIs[i - 1], 10 * i);
            vm.roll(block.number + 1);
        }

        for (uint256 i = 1; i <= tokenURIs.length; i++) {
            nft.setTokenURI(i, tokenURIs[i - 1], 10 * i);
            vm.roll(block.number + 1);
        }

        sbt.mint(msg.sender, 1, 1);

        Campaigns campaigns = new Campaigns();
        campaigns.initialize(ERC20Upgradeable(address(pce)), sbt, nft);

        sbt.setMinter(address(campaigns));

        vm.roll(block.number + 1);

        Campaigns.Campaign memory _campaign = Campaigns.Campaign({
            sbtId: 1,
            title: "Airdrop Contributor NFTs",
            description: "We will airdrop Contributor NFTs to PEACECOIN Contributors",
            claimAmount: 1,
            totalAmount: 10,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 86400,
            validateSignatures: false,
            tokenType: Campaigns.TokenType.NFT
        });

        campaigns.createCampaign(_campaign);

        vm.roll(block.number + 1);

        _campaign.sbtId = 2;
        _campaign.title = "Airdrop Contributor NFTs 2";
        _campaign.description = "We will airdrop Contributor NFTs to PEACECOIN Contributors 2";
        _campaign.claimAmount = 1;
        _campaign.totalAmount = 10;
        _campaign.validateSignatures = true;
        _campaign.tokenType = Campaigns.TokenType.SBT;
        campaigns.createCampaign(_campaign);

        console.log("Campaigns deployed at", address(campaigns));
        console.log("SBT deployed at", address(sbt));
        console.log("NFT deployed at", address(nft));
        vm.stopBroadcast();
    }
}
