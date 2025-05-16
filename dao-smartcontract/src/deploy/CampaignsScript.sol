// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../Campaigns.sol";
import "../PCEGovTokenTest.sol";

contract CampaignsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address PCE = 0x1F9FcC5f8DF936b8E3c9617565FfAd7fF6222b14;

        string memory uri = "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/";
        string memory name = "PCE Contributor NFT";
        string memory symbol = "PCE_CONTRIBUTOR";
        string[8] memory tokenURIs = [
            "QmbUVVQ88V4kTK15yEpfTv2Bm28Pmo1DPtusffeMNqrSxx",
            "QmeRTdBRWeeP1Tpea8KMLC6zDh53boU7MJgqSdsnWGLFye",
            "QmR2dLjCdD7wjyxSmWbWd7uVqBtNZ4C8iu51uxYpVp4Gyw",
            "QmQT95WxczcqVaHkrtgeBfRgdikrVfAu1XPc6LnE2Jgw51",
            "QmQhwbUsjoWCWRC4mpiMNjie8PFNzMyzPb32wvVbEVx2sb",
            "QmQKdjT3PXnS3HqhcbYTfrP8cHNRGXQbRijL6d8fpK7EoA",
            "QmPvFgQXCcQy8ZL52n8MKWKRuK8Emy1S1yprA3u25f4uLC",
            "QmTu4k191oMPMKKj7VfZrLyamyoBXm56bhn4z5AMfnbEiw"
        ];

        SBT sbt = new SBT(name, symbol, uri);

        vm.roll(block.number + 1);
        
        sbt.setMinter(address(this));
        for (uint256 i = 0; i < tokenURIs.length; i++) {
            sbt.setTokenURI(i, tokenURIs[i]);
            vm.roll(block.number + 1);
        }

        sbt.mint(msg.sender, 1, 1);

        Campaigns campaigns = new Campaigns();
        campaigns.initialize(
            ERC20Upgradeable(PCE),
            sbt
        );

        sbt.setMinter(address(campaigns));

        vm.roll(block.number + 1);

        Campaigns.Campaign memory _campaign = Campaigns.Campaign({
            title: "Airdrop Contributor NFTs",
            description: "We will airdrop Contributor NFTs to PEACECOIN Contributors",
            amount: 5,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: false,
            isNFT: true
        });

        campaigns.createCampaign(_campaign);
        campaigns.createCampaign(_campaign);
        campaigns.createCampaign(_campaign);
        campaigns.createCampaign(_campaign);

        vm.roll(block.number + 1);

        _campaign.title = "Airdrop Contributor NFTs 2";
        _campaign.description = "We will airdrop Contributor NFTs to PEACECOIN Contributors 2";
        _campaign.amount = 2;
        _campaign.validateSignatures = true;

        campaigns.createCampaign(_campaign);
        campaigns.createCampaign(_campaign);
        campaigns.createCampaign(_campaign);
        
        address[] memory winners = new address[](3);
        winners[0] = 0x6fD12d4d7E8e1D3E5EE6B3A6e8c7DD426Bb24BF5;
        winners[1] = 0x59178bAc7A9BBfa287F39887EAA2826666f14A2a;
        winners[2] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

        bytes32[] memory gist = new bytes32[](1);
        gist[0] = keccak256(abi.encodePacked("pwollemi"));

        vm.roll(block.number + 1);
        campaigns.addCampWinners(1, winners, gist);

        vm.roll(block.number + 1);
        campaigns.addCampWinners(3, winners, gist);
        campaigns.addCampWinners(4, winners, gist);
        campaigns.addCampWinners(5, winners, gist);

        vm.roll(block.number + 1);
        campaigns.addCampWinners(6, winners, gist);
        campaigns.addCampWinners(7, winners, gist);

        console.log("Campaigns deployed at", address(campaigns));
        console.log("SBT deployed at", address(sbt));
        vm.stopBroadcast();
    }
}
