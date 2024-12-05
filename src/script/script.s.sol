// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../mocks/MockERC20.sol";
import "../PCEGovTokenTest.sol";
import "../Bounty.sol";
import "../Governance/GovernorAlpha.sol";
import "../Governance/Timelock.sol";
import "../ContractFactory.sol";
import "../DAOFactory.sol";

import {console} from "forge-std/console.sol";

contract script is Script {
    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        vm.startBroadcast(deployerPrivateKey);

        address alice = address(0xABCD);

        uint256 pceTokenAmount = 1000000e18;
        uint256 _bountyAmount = 0;

        MockERC20 mockERC20 = new MockERC20(); // PCE Token
        mockERC20.initialize();
        mockERC20.mint(address(this), pceTokenAmount);

        PCEGovTokenTest pceGovToken = new PCEGovTokenTest();
        pceGovToken.initialize(address(this));
        pceGovToken.delegate(address(this));

        Timelock timelock = new Timelock(alice, 10 minutes);
        GovernorAlpha gov = new GovernorAlpha(
            "PCE DAO",
            IERC20(address(pceGovToken)),
            address(timelock),
            1,
            86400,
            100e18,
            1000e18
        );

        Bounty bounty = new Bounty();   // Deploy Bounty Contract
        bounty.initialize(ERC20Upgradeable(address(mockERC20)), _bountyAmount, address(gov));

        ContractFactory contractFactory = new ContractFactory(msg.sender);
        DAOFactory daoFactory = new DAOFactory();

        console.log("PCE Token: ", address(mockERC20));
        console.log("PCE Gov Token: ", address(pceGovToken));
        console.log("Timelock: ", address(timelock));
        console.log("Governor: ", address(gov));
        console.log("Bounty: ", address(bounty));
        console.log("ContractFactory: ", address(contractFactory));
        console.log("DAOFactory: ", address(daoFactory));
    }
}
