// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../Governance/PEACECOINDAO_SBT.sol";
import "../Governance/PEACECOINDAO_GOVERNOR.sol";
import "../Governance/Timelock.sol";
import "../mocks/PCEGovTokenTest.sol";
import "../Staking.sol";
import "../Governance/WPCE.sol";
import "../Governance/PCE.sol";

contract PEACECOINDAO_SBTScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        uint256 _rewardPerBlock = 1e18;
        address deployerAddress = vm.addr(deployerPrivateKey);
        string memory name = "PEACECOIN DAO SBT";
        string memory symbol = "PCE_SBT";
        string memory uri = "https://orange-elegant-takin-78.mypinata.cloud/ipfs/";

        vm.roll(block.number + 1); // Wait for 1 block

        vm.roll(block.number + 1);

        PEACECOINDAO_SBT peacecoinDaoSbt = new PEACECOINDAO_SBT();
        peacecoinDaoSbt.initialize(uri, name, symbol);

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

        vm.roll(block.number + 1);

        wPCE.delegate(deployerAddress);

        vm.roll(block.number + 1);

        // Deploy Governor
        string memory daoName = "PEACECOIN DAO";
        uint256 _votingDelay = 1;
        uint256 _votingPeriod = 10; // 1 week
        uint256 _proposalThreshold = 10_000 * 1e18; // 10,000 PCE
        uint256 _quorumVotes = 100_000 * 1e18; // 100,000 PCE
        uint256 _timelockDelay = 1 days;

        PEACECOINDAO_GOVERNOR governor = new PEACECOINDAO_GOVERNOR();
        Timelock timelock = new Timelock();

        timelock.initialize(deployerAddress, _timelockDelay);
        governor.initialize(
            daoName,
            address(wPCE),
            address(peacecoinDaoSbt),
            address(timelock),
            _votingDelay,
            _votingPeriod,
            _proposalThreshold,
            _quorumVotes,
            deployerAddress
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
