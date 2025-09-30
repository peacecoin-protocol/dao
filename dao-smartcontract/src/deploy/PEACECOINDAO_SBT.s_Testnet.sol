// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../Governance/PEACECOINDAO_SBT.sol";
import "../Governance/PEACECOINDAO_GOVERNOR.sol";
import "../Governance/Timelock.sol";
import "../mocks/PCEGovTokenTest.sol";
import "../Staking.sol";
import "../Governance/WPCE.sol";
import "../Governance/PCE.sol";
import {DeployDAOFactory} from "./DeployDAOFactory.sol";
import {console} from "forge-std/console.sol";
contract PEACECOINDAO_SBTScript is Script, DeployDAOFactory {
    uint256 _rewardPerBlock = 1e18;
    string name = "PEACECOIN DAO SBT";
    string symbol = "PCE_SBT";
    string uri = "https://peacecoin-dao.mypinata.cloud/ipfs/";

    // Deploy Governor
    string daoName = "PEACECOIN DAO";
    uint256 _votingDelay = 1;
    uint256 _votingPeriod = 10; // 1 week
    uint256 _proposalThreshold = 10_000 * 1e18; // 10,000 PCE
    uint256 _quorumVotes = 100_000 * 1e18; // 100,000 PCE
    uint256 _timelockDelay = 1 days;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        (address daoFactory, , , , ) = deployDAOFactory();

        vm.roll(block.number + 1); // Wait for 1 block

        PEACECOINDAO_SBT peacecoinDaoSbt = new PEACECOINDAO_SBT();
        peacecoinDaoSbt.initialize(uri, name, symbol, daoFactory);

        vm.roll(block.number + 1);
        peacecoinDaoSbt.delegate(deployerAddress);

        vm.roll(block.number + 10);

        // Deploy Staking
        Staking staking = new Staking();

        // Deploy PCE
        PCE pce = new PCE();
        pce.initialize();

        vm.roll(block.number + 1);

        // Deploy WPCE
        WPCE wPCE = new WPCE();
        wPCE.initialize();
        wPCE.addMinter(address(staking));

        staking.initialize(_rewardPerBlock, address(pce), address(wPCE));

        vm.roll(block.number + 1);

        // Stake PCE Tokens

        uint256 _amount = 1_000_000 * 1e18;
        pce.mint(deployerAddress, _amount * 10);
        pce.approve(address(staking), _amount);
        staking.stake(_amount);

        wPCE.delegate(deployerAddress);

        vm.roll(block.number + 1);

        address _peacecoinDaoSbt = address(peacecoinDaoSbt);

        PEACECOINDAO_GOVERNOR governor = new PEACECOINDAO_GOVERNOR();
        Timelock timelock = new Timelock();
        address _deployerAddress = deployerAddress;

        timelock.initialize(_deployerAddress, _timelockDelay);
        governor.initialize(
            daoName,
            address(wPCE),
            address(_peacecoinDaoSbt),
            address(timelock),
            _votingDelay,
            _votingPeriod,
            _proposalThreshold,
            _quorumVotes,
            _deployerAddress
        );
        timelock.setPendingAdmin(address(governor));
        governor.__acceptAdmin();

        console.log("PCE deployed", address(pce));
        console.log("WPCE deployed", address(wPCE));
        console.log("Staking deployed", address(staking));
        console.log("PEACECOINDAO_SBT deployed", address(peacecoinDaoSbt));
        console.log("PEACECOINDAO_GOVERNOR deployed", address(governor));
        console.log("Timelock deployed", address(timelock));

        vm.stopBroadcast();
    }
}
