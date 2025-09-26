// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../Governance/PEACECOINDAO_NFT.sol";
import {DeployDAOFactory} from "./DeployDAOFactory.sol";

contract NFTScript is Script, DeployDAOFactory {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (address daoFactory, , , , ) = deployDAOFactory();

        string memory name = "PEACECOIN DAO NFT";
        string memory symbol = "PCE_NFT";
        string memory uri = "https://peacecoin-dao.mypinata.cloud/ipfs/";

        PEACECOINDAO_NFT peacecoinDaoNft = new PEACECOINDAO_NFT();
        peacecoinDaoNft.initialize(uri, name, symbol, address(daoFactory));
        vm.stopBroadcast();
    }
}
