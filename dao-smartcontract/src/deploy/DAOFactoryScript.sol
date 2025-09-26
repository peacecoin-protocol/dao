// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import {DAOFactory} from "../DAOFactory.sol";
import {IDAOFactory} from "../interfaces/IDAOFactory.sol";
import {PCECommunityGovToken} from "../mocks/PCECommunityGovToken.sol";
import {GovernorAlpha} from "../Governance/GovernorAlpha.sol";
import {Timelock} from "../Governance/Timelock.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract DAOFactoryScript is Script {
    IDAOFactory.SocialConfig socialConfig =
        IDAOFactory.SocialConfig({
            description: "Test Description",
            website: "https://test.com",
            linkedin: "https://linkedin.com/test",
            twitter: "https://twitter.com/test",
            telegram: "https://t.me/test"
        });

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address timelockAddress = address(new Timelock());
        address governorAddress = address(new GovernorAlpha());
        address governanceTokenAddress = address(new PCECommunityGovToken());

        // MockERC20 mockERC20 = new MockERC20();
        // mockERC20.initialize();

        address mockERC20 = 0xa96A6195d94cD304fe10bdB696b9a8c301eDf662;

        DAOFactory daoFactory = new DAOFactory();
        daoFactory.setImplementation(timelockAddress, governorAddress, governanceTokenAddress);

        uint256 VOTING_DELAY = 10;
        uint256 VOTING_PERIOD = 100;
        uint256 PROPOSAL_THRESHOLD = 1000;
        uint256 TIMELOCK_DELAY = 100;
        uint256 QUORUM_VOTES = 1000;
        string memory DAO_NAME = "Test DAO";

        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            TIMELOCK_DELAY,
            QUORUM_VOTES
        );

        vm.stopBroadcast();

        console.log("DAOFactory deployed at", address(daoFactory));
        console.log("Timelock deployed at", address(timelockAddress));
        console.log("GovernorAlpha deployed at", address(governorAddress));
        console.log("GovernanceToken deployed at", address(governanceTokenAddress));
    }
}
