// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../mocks/MockERC20.sol";
import "../PCEGovTokenTest.sol";
import "../Bounty.sol";
import "../Governance/GovernorAlpha.sol";
import "../Governance/Timelock.sol";
import "../ContractFactory.sol";
import "../DAOFactory.sol";
import "../PCECommunityGovToken.sol";

import {console} from "forge-std/console.sol";

contract script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        address alice = address(0xABCD);

        uint256 pceTokenAmount = 1000000e18;
        uint256 _bountyAmount = 0;

        MockERC20 mockERC20 = new MockERC20(); // PCE Token
        mockERC20.initialize();
        mockERC20.mint(deployerAddress, pceTokenAmount);

        PCEGovTokenTest pceGovToken = new PCEGovTokenTest();
        pceGovToken.initialize();
        pceGovToken.delegate(deployerAddress);

        Timelock timelock = new Timelock();
        GovernorAlpha gov = new GovernorAlpha();

        Bounty bounty = new Bounty(); // Deploy Bounty Contract
        bounty.initialize(ERC20Upgradeable(address(mockERC20)), _bountyAmount, address(gov));

        timelock.initialize(address(this), 10 minutes);
        gov.initialize("PCE DAO", address(pceGovToken), address(timelock), 1, 86400, 100e18, 1000e18);

        ContractFactory contractFactory = new ContractFactory(deployerAddress);
        DAOFactory daoFactory = new DAOFactory();

        PCECommunityGovToken pceCommunityGovToken = new PCECommunityGovToken();

        daoFactory.setImplementation(address(timelock), address(gov), address(pceCommunityGovToken));

        DAOFactory.SocialConfig memory socialConfig = DAOFactory.SocialConfig({
            description: "PCE DAO",
            website: "https://pce.com",
            linkedin: "",
            twitter: "",
            telegram: ""
        });

        uint256 votingDelay = 1; // 1 block
        uint256 votingPeriod = 100; // ~100 blocks
        uint256 proposalThreshold = 100e18;
        uint256 quorum = 1000e18;
        uint256 timelockDelay = 100;

        daoFactory.createDAO(
            "PCE DAO",
            socialConfig,
            address(mockERC20),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorum,
            timelockDelay
        );

        console.log("PCE Token: ", address(mockERC20));
        console.log("PCE Gov Token: ", address(pceGovToken));
        console.log("Timelock: ", address(timelock));
        console.log("Governor: ", address(gov));
        console.log("Bounty: ", address(bounty));
        console.log("ContractFactory: ", address(contractFactory));
        console.log("DAOFactory: ", address(daoFactory));
    }
}
