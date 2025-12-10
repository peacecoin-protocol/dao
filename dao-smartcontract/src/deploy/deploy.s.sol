// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../mocks/MockERC20.sol";
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
import {MockERC20} from "../mocks/MockERC20.sol";
import {console} from "forge-std/console.sol";
import {DeployDAOFactory} from "../deploy/DeployDAOFactory.sol";
import {IDAOFactory} from "../interfaces/IDAOFactory.sol";

contract deploy is Script, DeployDAOFactory {
    // Metadata for SBT
    string uri = "https://ipfs-dao-studio.peace-coin.org/ipfs/";
    string name = "PCE Contributor NFT";
    string symbol = "PCE_CONTRIBUTOR";
    string daoName = "PCE DAO";
    uint256 _votingDelay = 1;
    uint256 _votingPeriod = 50; // 3 blocks
    uint256 _proposalThreshold = 30;
    uint256 _quorumVotes = 200;
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
    MockERC20 mockERC20;
    function run() external {
        (
            address daoFactory,
            address timelockAddress,
            address governorAddress,
            address governanceTokenAddress,
            address mockERC20Address,
            address peacecoinDaoSbt,
            address peacecoinDaoNft
        ) = deployDAOFactory();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        mockERC20 = MockERC20(mockERC20Address);

        vm.roll(block.number + 1);

        Bounty bounty = new Bounty(); // Deploy Bounty Contract
        bounty.initialize(ERC20Upgradeable(PCE_TOKEN), _bountyAmount, address(governorAddress));

        ContractFactory contractFactory = new ContractFactory(deployerAddress);

        vm.roll(block.number + 1); // Wait for 1 block

        PCECommunityGovToken pceCommunityGovToken = new PCECommunityGovToken();

        DAOFactory(daoFactory).setImplementation(
            address(timelockAddress),
            address(governorAddress),
            address(pceCommunityGovToken)
        );

        pceCommunityGovToken.initialize(PCE_TOKEN);

        Timelock timelock = Timelock(timelockAddress);
        timelock.initialize(deployerAddress, 1 minutes);

        vm.roll(block.number + 1); // Wait for 1 block

        GovernorAlpha governor = GovernorAlpha(governorAddress);
        governor.initialize(
            daoName,
            address(pceCommunityGovToken),
            address(peacecoinDaoSbt),
            address(peacecoinDaoNft),
            address(timelock),
            _votingDelay,
            _votingPeriod,
            _proposalThreshold,
            _quorumVotes,
            deployerAddress,
            SOCIAL_CONFIG
        );
        timelock.setPendingAdmin(address(governor));
        governor.__acceptAdmin();

        vm.roll(block.number + 1); // Wait for 1 block

        // DAOFactory(daoFactory).createDAO(
        //     daoName,
        //     SOCIAL_CONFIG,
        //     address(mockERC20),
        //     _votingDelay,
        //     _votingPeriod,
        //     _proposalThreshold,
        //     1 minutes,
        //     _quorumVotes
        // );

        // bytes32 daoId = keccak256(abi.encodePacked(daoName));

        // PEACECOINDAO_SBT(peacecoinDaoSbt).createToken("test-uri", 100, daoId);
        // PEACECOINDAO_NFT(peacecoinDaoNft).createToken("test-uri", 100, daoId);

        vm.roll(block.number + 1);

        Campaigns campaigns = new Campaigns();

        PEACECOINDAO_NFT(peacecoinDaoNft).setMinter(address(campaigns));
        PEACECOINDAO_SBT(peacecoinDaoSbt).setMinter(address(campaigns));

        campaigns.initialize(
            address(daoFactory),
            PEACECOINDAO_SBT(address(peacecoinDaoSbt)),
            PEACECOINDAO_NFT(address(peacecoinDaoNft))
        );

        // ERC20Upgradeable(PCE_TOKEN).transfer(address(campaigns), 10000e18);

        // vm.roll(block.number + 1);
        // Campaigns.Campaign memory _campaign = Campaigns.Campaign({
        //     sbtId: 1,
        //     title: "Airdrop Contributor NFTs",
        //     description: "We will airdrop Contributor NFTs to PEACECOIN Contributors",
        //     tokenType: Campaigns.TokenType.NFT,
        //     token: address(mockERC20),
        //     claimAmount: 3,
        //     totalAmount: 10,
        //     startDate: block.timestamp + 100,
        //     endDate: block.timestamp + 1000,
        //     validateSignatures: false,
        //     creator: address(0)
        // });

        // campaigns.createCampaign(_campaign);

        // vm.roll(block.number + 1);

        // _campaign.sbtId = 2;
        // _campaign.title = "Airdrop Contributor NFTs 2";
        // _campaign.description = "We will airdrop Contributor NFTs to PEACECOIN Contributors 2";
        // _campaign.claimAmount = 5;
        // _campaign.totalAmount = 10;
        // _campaign.validateSignatures = true;
        // _campaign.tokenType = Campaigns.TokenType.SBT;

        // campaigns.createCampaign(_campaign);
        // address[] memory winners = new address[](3);
        // winners[0] = 0x6fD12d4d7E8e1D3E5EE6B3A6e8c7DD426Bb24BF5;
        // winners[1] = 0x59178bAc7A9BBfa287F39887EAA2826666f14A2a;
        // winners[2] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

        // bytes32[] memory gist = new bytes32[](1);
        // gist[0] = keccak256(abi.encodePacked("pwollemi"));

        // vm.roll(block.number + 1);
        // campaigns.addCampWinners(1, winners, gist);

        // PEACECOINDAO_SBT(peacecoinDaoSbt).mint(winners[1], 1, 1);
        // PEACECOINDAO_NFT(peacecoinDaoNft).mint(winners[1], 1, 1);

        console.log("Campaigns deployed at", address(campaigns));
        console.log("PCE Token: ", PCE_TOKEN);
        console.log("Bounty: ", address(bounty));
        console.log("ContractFactory: ", address(contractFactory));
        console.log("PCE Community Gov Token: ", address(pceCommunityGovToken));
        console.log("SBT: ", address(peacecoinDaoSbt));
        console.log("NFT: ", address(peacecoinDaoNft));
    }
}
