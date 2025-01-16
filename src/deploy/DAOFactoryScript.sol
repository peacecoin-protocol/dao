// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

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

        DAOFactory daoFactory = new DAOFactory();
        daoFactory.setByteCodes(type(GovernorAlpha).creationCode, type(Timelock).creationCode, type(PCECommunityGovToken).creationCode);

        vm.stopBroadcast();
    }
}
