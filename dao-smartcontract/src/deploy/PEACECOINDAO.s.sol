// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../mocks/PCEGovTokenTest.sol";
import "../Governance/PEACECOINDAO_GOVERNOR.sol";
import "../Governance/Timelock.sol";
import "../Governance/PEACECOINDAO_SBT.sol";

contract PEACECOINDAOScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        PCEGovTokenTest pceGovToken = new PCEGovTokenTest();
        pceGovToken.initialize();

        string memory daoName = "PEACECOIN DAO";
        uint256 _votingDelay = 1;
        uint256 _votingPeriod = 288000; // 1 week
        uint256 _proposalThreshold = 1e18; // 1 PCE
        uint256 _quorumVotes = 1000e18; // 1000 PCE
        uint256 _timelockDelay = 1 days;

        PEACECOINDAO_SBT sbt = new PEACECOINDAO_SBT();
        sbt.initialize(
            "PEACECOIN DAO SBT",
            "PCE_SBT",
            "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/"
        );

        PEACECOINDAO_GOVERNOR governor = new PEACECOINDAO_GOVERNOR();
        Timelock timelock = new Timelock();

        timelock.initialize(deployerAddress, _timelockDelay);
        governor.initialize(
            daoName,
            address(pceGovToken),
            address(sbt),
            address(timelock),
            _votingDelay,
            _votingPeriod,
            _proposalThreshold,
            _quorumVotes,
            deployerAddress
        );
        timelock.setPendingAdmin(address(governor));
        governor.__acceptAdmin();

        vm.stopBroadcast();
    }
}
