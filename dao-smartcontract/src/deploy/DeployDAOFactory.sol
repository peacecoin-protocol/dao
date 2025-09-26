// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DAOFactory} from "../DAOFactory.sol";
import {IDAOFactory} from "../interfaces/IDAOFactory.sol";
import {PCECommunityGovToken} from "../mocks/PCECommunityGovToken.sol";
import {GovernorAlpha} from "../Governance/GovernorAlpha.sol";
import {Timelock} from "../Governance/Timelock.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract DeployDAOFactory is Script {
    function deployDAOFactory() public returns (address, address, address, address, address) {
        address timelockAddress = address(new Timelock());
        address governorAddress = address(new GovernorAlpha());
        address governanceTokenAddress = address(new PCECommunityGovToken());

        MockERC20 mockERC20 = new MockERC20();
        mockERC20.initialize();

        DAOFactory daoFactory = new DAOFactory();
        daoFactory.setImplementation(timelockAddress, governorAddress, governanceTokenAddress);

        console.log("DAOFactory deployed at", address(daoFactory));
        console.log("Timelock deployed at", address(timelockAddress));
        console.log("GovernorAlpha deployed at", address(governorAddress));
        console.log("GovernanceToken deployed at", address(governanceTokenAddress));
        console.log("MockERC20 deployed at", address(mockERC20));

        return (
            address(daoFactory),
            address(timelockAddress),
            address(governorAddress),
            address(governanceTokenAddress),
            address(mockERC20)
        );
    }
}
