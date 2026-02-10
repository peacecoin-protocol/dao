// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DAOFactory} from "../DAOFactory.sol";
import {PCECommunityGovToken} from "../mocks/PCECommunityGovToken.sol";
import {GovernorAlpha} from "../Governance/GovernorAlpha.sol";
import {Timelock} from "../Governance/Timelock.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {PeaceCoinDaoSbt} from "../Governance/PEACECOINDAO_SBT.sol";
import {PeaceCoinDaoNft} from "../Governance/PEACECOINDAO_NFT.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {MultipleVotings} from "../Governance/MultipleVotings.sol";

contract DeployDAOFactory is Script {
    function deployDaoFactory() public returns (address, address, address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        string memory URI = "https://ipfs-dao-studio.mypinata.cloud/ipfs/";

        // Import OpenZeppelin's TransparentUpgradeableProxy (make sure you added import statement at the top if not present)
        address timelockImplementation = address(new Timelock());
        address governorImplementation = address(new GovernorAlpha());
        address governanceTokenImplementation = address(new PCECommunityGovToken());
        address multipleVotingImplementation = address(new MultipleVotings());

        // Deploy simple admin (deployer will be the proxy admin for now)
        address proxyAdmin = address(new ProxyAdmin(deployerAddress));

        // Deploy proxies
        address timelockAddress = address(
            new TransparentUpgradeableProxy(timelockImplementation, proxyAdmin, "")
        );
        address governorAddress = address(
            new TransparentUpgradeableProxy(governorImplementation, proxyAdmin, "")
        );
        address governanceTokenAddress = address(
            new TransparentUpgradeableProxy(governanceTokenImplementation, proxyAdmin, "")
        );
        address multipleVotingAddress = address(
            new TransparentUpgradeableProxy(multipleVotingImplementation, proxyAdmin, "")
        );

        address proxyAdminAddress = address(proxyAdmin);

        PeaceCoinDaoSbt sbtImplementation = new PeaceCoinDaoSbt();
        PeaceCoinDaoNft nftImplementation = new PeaceCoinDaoNft();

        MockERC20 mockERC20 = new MockERC20();
        mockERC20.initialize();

        DAOFactory daoFactoryImplementation = new DAOFactory();

        address daoFactoryAddress = address(
            new TransparentUpgradeableProxy(
                address(daoFactoryImplementation),
                proxyAdminAddress,
                ""
            )
        );

        address _timelockAddress = timelockAddress;
        address _governorAddress = governorAddress;
        address _governanceTokenAddress = governanceTokenAddress;

        DAOFactory(daoFactoryAddress).initialize();
        DAOFactory(daoFactoryAddress).setImplementation(
            timelockImplementation,
            governorImplementation,
            governanceTokenImplementation,
            multipleVotingImplementation,
            address(sbtImplementation),
            address(nftImplementation)
        );
        DAOFactory(daoFactoryAddress).setURI(URI);

        vm.stopBroadcast();

        console.log("DAOFactory deployed at", daoFactoryAddress);
        console.log("Timelock deployed at", _timelockAddress);
        console.log("GovernorAlpha deployed at", _governorAddress);
        console.log("GovernanceToken deployed at", _governanceTokenAddress);
        console.log("MultipleVoting deployed at", multipleVotingAddress);
        console.log("MockERC20 deployed at", address(mockERC20));

        return (daoFactoryAddress, timelockAddress, governorAddress);
    }
}
