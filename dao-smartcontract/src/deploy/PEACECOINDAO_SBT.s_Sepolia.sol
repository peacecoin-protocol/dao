// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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

        address deployerAddress = vm.addr(deployerPrivateKey);
        address peacecoinDaoSbt = 0x9C2B5C19c56006773864E79b9007362F39e5b457;

        // Deploy Staking
        Staking staking = new Staking();

        address pce = 0x9C2B5C19c56006773864E79b9007362F39e5b457;

        vm.roll(block.number + 1);

        // Deploy WPCE
        WPCE wPCE = new WPCE();
        wPCE.initialize();
        wPCE.addMinter(address(staking));

        uint256 _rewardPerBlock = 1e18;

        staking.initialize(_rewardPerBlock, address(pce), address(wPCE));

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
            address(pce),
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
        console.log("SBT deployed", address(peacecoinDaoSbt));
        console.log("PEACECOINDAO_SBT deployed", address(peacecoinDaoSbt));
        console.log("PEACECOINDAO_GOVERNOR deployed", address(governor));
        console.log("Timelock deployed", address(timelock));
        console.log("Deployer PCE Voting Power", wPCE.getVotes(deployerAddress));

        vm.stopBroadcast();
    }
}
