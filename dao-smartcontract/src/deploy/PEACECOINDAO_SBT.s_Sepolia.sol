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

contract PEACECOINDAO_SBTScript is Script, DeployDAOFactory {
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

        string memory name = "PEACECOIN DAO SBT";
        string memory symbol = "PCE_SBT";
        string memory uri = "https://peacecoin-dao.mypinata.cloud/ipfs/";

        address pce = 0x8253f538d2C5a011ee32098a539903992f61Dce9;

        PEACECOINDAO_SBT peacecoinDaoSbt = new PEACECOINDAO_SBT();
        peacecoinDaoSbt.initialize(uri, name, symbol, daoFactory);

        // Deploy Staking
        Staking staking = new Staking();

        vm.roll(block.number + 1);

        // Deploy WPCE
        WPCE wPCE = new WPCE();
        wPCE.initialize();
        wPCE.addMinter(address(staking));

        uint256 _rewardPerBlock = 1e18;

        staking.initialize(_rewardPerBlock, address(pce), address(wPCE));

        wPCE.delegate(deployerAddress);

        vm.roll(block.number + 1);

        address _pceAddress = pce;
        address _peacecoinDAOSbt = address(peacecoinDaoSbt);
        address _deployerAddress = deployerAddress;

        PEACECOINDAO_GOVERNOR governor = new PEACECOINDAO_GOVERNOR();
        Timelock timelock = new Timelock();

        address __pceAddress = _pceAddress;

        address _staking = address(staking);
        address _wPCE = address(wPCE);
        address __deployerAddress = _deployerAddress;
        address __timelock = address(timelock);
        address __peacecoinDAOSbt = _peacecoinDAOSbt;
        timelock.initialize(__deployerAddress, _timelockDelay);

        governor.initialize(
            daoName,
            address(__pceAddress),
            __peacecoinDAOSbt,
            address(__timelock),
            _votingDelay,
            _votingPeriod,
            _proposalThreshold,
            _quorumVotes,
            __deployerAddress
        );
        timelock.setPendingAdmin(address(governor));
        governor.__acceptAdmin();

        console.log("PCE deployed", address(__pceAddress));
        console.log("WPCE deployed", address(_wPCE));
        console.log("Staking deployed", address(_staking));

        console.log("PEACECOINDAO_SBT deployed", __peacecoinDAOSbt);
        console.log("PEACECOINDAO_GOVERNOR deployed", address(governor));
        console.log("Timelock deployed", address(timelock));
        console.log("Deployer PCE Voting Power", wPCE.getVotes(__deployerAddress));

        vm.stopBroadcast();
    }
}
