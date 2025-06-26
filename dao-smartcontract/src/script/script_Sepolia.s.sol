// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../mocks/MockERC20.sol";
import "../Bounty.sol";
import "../Governance/GovernorAlpha.sol";
import "../Governance/Timelock.sol";
import "../ContractFactory.sol";
import "../DAOFactory.sol";
import "../mocks/PCECommunityGovToken.sol";
import "../Campaigns.sol";
import "../SBT.sol";
import "../Governance/PEACECOINDAO_SBT.sol";
import {console} from "forge-std/console.sol";

contract scriptSepolia is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        uint256 _bountyAmount = 0;

        address PCE_TOKEN = 0x8d4d8C9192C7df57840129D71c18ED49dda7Fe33;
        Timelock timelock = new Timelock();
        GovernorAlpha gov = new GovernorAlpha();

        vm.roll(block.number + 1);

        Bounty bounty = new Bounty(); // Deploy Bounty Contract
        bounty.initialize(ERC20Upgradeable(PCE_TOKEN), _bountyAmount, address(gov));

        ContractFactory contractFactory = new ContractFactory(deployerAddress);
        DAOFactory daoFactory = new DAOFactory();

        vm.roll(block.number + 1); // Wait for 1 block

        PCECommunityGovToken pceCommunityGovToken = new PCECommunityGovToken();

        PEACECOINDAO_SBT peacecoinDaoSbt = new PEACECOINDAO_SBT();
        // peacecoinDaoSbt.initialize("https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/");

        daoFactory.setImplementation(address(timelock), address(gov), address(peacecoinDaoSbt));

        pceCommunityGovToken.initialize(PCE_TOKEN);

        timelock.initialize(deployerAddress, 1 minutes);

        vm.roll(block.number + 1); // Wait for 1 block

        string memory daoName = "PCE DAO";
        uint256 _votingDelay = 1;
        uint256 _votingPeriod = 50; // 3 blocks
        uint256 _proposalThreshold = 30;
        uint256 _quorumVotes = 200;
        gov.initialize(
            daoName,
            address(peacecoinDaoSbt),
            address(timelock),
            _votingDelay,
            _votingPeriod,
            _proposalThreshold,
            _quorumVotes
        );
        timelock.setPendingAdmin(address(gov));
        gov.__acceptAdmin();

        vm.roll(block.number + 1); // Wait for 1 block

        // Metadata for SBT
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

        peacecoinDaoSbt.initialize(uri, name, symbol);

        for (uint256 i = 1; i <= tokenURIs.length; i++) {
            peacecoinDaoSbt.setTokenURI(i, tokenURIs[i - 1], 10 * i);
            peacecoinDaoSbt.mint(deployerAddress, i, 1);
        }

        vm.roll(block.number + 1);

        // SBT sbt = new SBT(name, symbol, uri);
        // sbt.setMinter(address(this));

        // for (uint256 i = 1; i <= tokenURIs.length; i++) {
        //     sbt.setTokenURI(i, tokenURIs[i]);
        // }

        // vm.roll(block.number + 1);

        Campaigns campaigns = new Campaigns();
        // sbt.setMinter(address(campaigns));
        peacecoinDaoSbt.setMinter(address(campaigns));

        campaigns.initialize(ERC20Upgradeable(PCE_TOKEN), SBT(address(peacecoinDaoSbt)));

        // ERC20Upgradeable(PCE_TOKEN).transfer(address(campaigns), 10000e18);

        vm.roll(block.number + 1);
        Campaigns.Campaign memory _campaign = Campaigns.Campaign({
            title: "Airdrop Contributor NFTs",
            description: "We will airdrop Contributor NFTs to PEACECOIN Contributors",
            amount: 3,
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
        _campaign.amount = 5;
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
        console.log("SBT deployed at", address(peacecoinDaoSbt));

        vm.roll(block.number + 1); // Wait for 1 block

        console.log("PCE Token: ", PCE_TOKEN);
        console.log("Timelock: ", address(timelock));
        console.log("Governor: ", address(gov));
        console.log("Bounty: ", address(bounty));
        console.log("ContractFactory: ", address(contractFactory));
        console.log("DAOFactory: ", address(daoFactory));
        console.log("PCE Community Gov Token: ", address(pceCommunityGovToken));
        console.log("Campaigns: ", address(campaigns));
        console.log("SBT: ", address(peacecoinDaoSbt));
    }
}
