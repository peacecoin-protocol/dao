// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../Campaigns.sol";
import "../mocks/PCEGovTokenTest.sol";
import "../Governance/PEACECOINDAO_SBT.sol";
import "../Governance/PCE.sol";

contract CampaignsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PCE pce = new PCE();

        string memory uri = "https://orange-elegant-takin-78.mypinata.cloud/ipfs/";
        string memory name = "PEACECOIN DAO SBT";
        string memory symbol = "PCE_SBT";
        string[7] memory tokenURIs = [
            "bafkreiemebhm4rsa2h3ivxjvg6xycwz3jfl7m2dfj6h7htzeeswekrr4r4",
            "bafkreibbu4ugqte65bjjzgkv2uhvlwek3gkbbdh4j5m6rtd7qo34bz4rpq",
            "bafkreibpdsixtlfwhfj3hiiv4t5yaycfyqg5hahcnnothjeldvqf62in6e",
            "bafkreiezfjmfeohthnblftkdrxubrmy2wmd5rbp3m7o6mqwnn5fppftanm",
            "bafkreic5r3h5y2silktxghus445j4zw5huy7ctsl5n45evnhq7zi3y652u",
            "bafkreibu7xidyph2v7wpti3s2ryompecpma4fztga4wzgue7ls32m32acm",
            "bafkreihrxyxbhn4vmizft4bgm5thvgofuisruc2ixhlusbrigg27acdm2i"
        ];

        PEACECOINDAO_SBT sbt = new PEACECOINDAO_SBT();
        sbt.initialize(uri, name, symbol);

        vm.roll(block.number + 1);

        sbt.setMinter(address(this));
        for (uint256 i = 1; i < tokenURIs.length; i++) {
            sbt.setTokenURI(i, tokenURIs[i], 10 * i);
            vm.roll(block.number + 1);
        }

        sbt.mint(msg.sender, 1, 1);

        Campaigns campaigns = new Campaigns();
        campaigns.initialize(ERC20Upgradeable(address(pce)), sbt);

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
            isNFT: true
        });

        campaigns.createCampaign(_campaign);

        vm.roll(block.number + 1);

        _campaign.sbtId = 2;
        _campaign.title = "Airdrop Contributor NFTs 2";
        _campaign.description = "We will airdrop Contributor NFTs to PEACECOIN Contributors 2";
        _campaign.claimAmount = 1;
        _campaign.totalAmount = 10;
        _campaign.validateSignatures = true;
        _campaign.isNFT = true;
        campaigns.createCampaign(_campaign);

        console.log("Campaigns deployed at", address(campaigns));
        console.log("SBT deployed at", address(sbt));
        vm.stopBroadcast();
    }
}
