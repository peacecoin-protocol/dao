// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../Governance/PEACECOINDAO_SBT.sol";

contract DeployPEACECOINDAO_SBT is Script {
    function run() external {
        string memory baseUri = "https://orange-elegant-takin-78.mypinata.cloud/ipfs/";
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        PEACECOINDAO_SBT peacecoinDaoSbt = new PEACECOINDAO_SBT();
        peacecoinDaoSbt.initialize(baseUri, "PEACECOIN DAO SBT", "PCE_SBT");
        vm.stopBroadcast();
    }
}
