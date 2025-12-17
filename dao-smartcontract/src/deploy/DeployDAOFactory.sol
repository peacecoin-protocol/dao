// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DAOFactory} from "../DAOFactory.sol";
import {IDAOFactory} from "../interfaces/IDAOFactory.sol";
import {PCECommunityGovToken} from "../mocks/PCECommunityGovToken.sol";
import {GovernorAlpha} from "../Governance/GovernorAlpha.sol";
import {Timelock} from "../Governance/Timelock.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {PEACECOINDAO_SBT} from "../Governance/PEACECOINDAO_SBT.sol";
import {PEACECOINDAO_NFT} from "../Governance/PEACECOINDAO_NFT.sol";

contract DeployDAOFactory is Script {
    function deployDAOFactory()
        public
        returns (address, address, address, address, address, address)
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        string memory URI = "https://peacecoin-dao.mypinata.cloud/ipfs/";

        address timelockAddress = address(new Timelock());
        address governorAddress = address(new GovernorAlpha());
        address governanceTokenAddress = address(new PCECommunityGovToken());

        PEACECOINDAO_SBT peacecoinDaoSbt = new PEACECOINDAO_SBT();
        PEACECOINDAO_NFT peacecoinDaoNft = new PEACECOINDAO_NFT();

        MockERC20 mockERC20 = new MockERC20();
        mockERC20.initialize();

        DAOFactory daoFactory = new DAOFactory(address(peacecoinDaoSbt), address(peacecoinDaoNft));
        daoFactory.setImplementation(timelockAddress, governorAddress, governanceTokenAddress);

        peacecoinDaoSbt.initialize("PEACECOIN DAO SBT", "PCE_SBT", URI, address(daoFactory));
        peacecoinDaoNft.initialize("PEACECOIN DAO NFT", "PCE_NFT", URI, address(daoFactory));

        peacecoinDaoSbt.setMinter(deployerAddress);
        peacecoinDaoNft.setMinter(deployerAddress);

        vm.stopBroadcast();

        console.log("DAOFactory deployed at", address(daoFactory));
        console.log("Timelock deployed at", address(timelockAddress));
        console.log("GovernorAlpha deployed at", address(governorAddress));
        console.log("GovernanceToken deployed at", address(governanceTokenAddress));
        console.log("MockERC20 deployed at", address(mockERC20));

        return (
            address(daoFactory),
            address(timelockAddress),
            address(governorAddress),
            address(mockERC20),
            address(peacecoinDaoSbt),
            address(peacecoinDaoNft)
        );
    }
}
