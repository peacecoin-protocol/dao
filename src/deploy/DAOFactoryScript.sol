// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {DAOFactory} from "../DAOFactory.sol";
import {PCECommunityGovToken} from "../PCECommunityGovToken.sol";
import {GovernorAlpha} from "../Governance/GovernorAlpha.sol";
import {Timelock} from "../Governance/Timelock.sol";

contract DAOFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);
        address timelockAddress = address(new Timelock());
        address governorAddress = address(new GovernorAlpha());
        address governanceTokenAddress = address(new PCECommunityGovToken());

        DAOFactory daoFactory = new DAOFactory();
        daoFactory.setImplementation(timelockAddress, governorAddress, governanceTokenAddress);

        vm.stopBroadcast();
    }
}
