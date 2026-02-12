// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DAOFactory} from "../src/DAOFactory.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PCECommunityGovToken} from "../src/mocks/PCECommunityGovToken.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {IDAOFactory} from "../src/interfaces/IDAOFactory.sol";
import {PeaceCoinDaoSbt} from "../src/Governance/PeaceCoinDaoSbt.sol";
import {PeaceCoinDaoNft} from "../src/Governance/PeaceCoinDaoNft.sol";
import {MultipleVotings} from "../src/Governance/MultipleVotings.sol";

contract DaoFactoryTest is Test {
    DAOFactory public daoFactory;
    Timelock public timelock;
    GovernorAlpha public governor;
    MockERC20 public mockERC20;
    PCECommunityGovToken public governanceToken;
    PeaceCoinDaoSbt public sbt;
    PeaceCoinDaoNft public nft;
    MultipleVotings public multipleVoting;

    uint256 public votingDelay = 10;
    uint256 public votingPeriod = 7200;
    uint256 public proposalThreshold = 1000;
    uint256 public quorumVotes = 2000;
    uint256 public timelockDelay = 100;

    string public daoName = "Test DAO";

    IDAOFactory.SocialConfig public socialConfig =
        IDAOFactory.SocialConfig({
            description: "Test Description",
            website: "https://website.com",
            linkedin: "https://linkedin.com",
            twitter: "https://twitter.com",
            telegram: "https://telegram.com"
        });

    string public baseUri = "https://ipfs-dao-studio.mypinata.cloud/ipfs/";

    address public defaultAdmin = makeAddr("defaultAdmin");
    address public nonDefaultAdmin = makeAddr("nonDefaultAdmin");

    function setUp() public {
        vm.startPrank(defaultAdmin);
        daoFactory = new DAOFactory();
        daoFactory.initialize();
        vm.stopPrank();

        vm.startPrank(nonDefaultAdmin);
        timelock = new Timelock();
        governor = new GovernorAlpha();
        governanceToken = new PCECommunityGovToken();
        sbt = new PeaceCoinDaoSbt();
        nft = new PeaceCoinDaoNft();
        multipleVoting = new MultipleVotings();
        vm.stopPrank();

        vm.prank(defaultAdmin);
        daoFactory.setImplementation(
            address(timelock),
            address(governor),
            address(governanceToken),
            address(multipleVoting),
            address(sbt),
            address(nft)
        );

        mockERC20 = new MockERC20();
        mockERC20.initialize();
    }

    function test_setImplementation() public {
        // Non-Default Admin cannot set implementation
        vm.prank(nonDefaultAdmin);
        vm.expectRevert();
        daoFactory.setImplementation(
            address(timelock),
            address(governor),
            address(governanceToken),
            address(multipleVoting),
            address(sbt),
            address(nft)
        );

        // Zero address cannot be set as implementation
        vm.startPrank(defaultAdmin);
        vm.expectRevert();
        daoFactory.setImplementation(
            address(0),
            address(governor),
            address(governanceToken),
            address(multipleVoting),
            address(sbt),
            address(nft)
        );

        // Zero address cannot be set as implementation
        vm.expectRevert();
        daoFactory.setImplementation(
            address(timelock),
            address(0),
            address(governanceToken),
            address(multipleVoting),
            address(sbt),
            address(nft)
        );

        // Zero address cannot be set as implementation
        vm.expectRevert();
        daoFactory.setImplementation(
            address(timelock),
            address(governor),
            address(0),
            address(multipleVoting),
            address(sbt),
            address(nft)
        );

        // Check that ImplementationUpdated event is emitted with correct arguments
        vm.expectEmit(true, true, true, true);
        emit DAOFactory.ImplementationUpdated(
            address(timelock),
            address(governor),
            address(governanceToken),
            address(multipleVoting),
            address(sbt),
            address(nft)
        );
        daoFactory.setImplementation(
            address(timelock),
            address(governor),
            address(governanceToken),
            address(multipleVoting),
            address(sbt),
            address(nft)
        );
        vm.stopPrank();
    }

    function test_createDAO() public {
        // only token owner can create DAO
        daoFactory.createDao(
            daoName,
            socialConfig,
            address(mockERC20),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            timelockDelay,
            quorumVotes
        );

        // Revert if community token address is zero
        vm.expectRevert(IErrors.InvalidAddress.selector);
        daoFactory.createDao(
            daoName,
            socialConfig,
            address(0),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            timelockDelay,
            quorumVotes
        );

        // Revert if dao name already exists
        vm.expectRevert(IErrors.DAOAlreadyExists.selector);
        daoFactory.createDao(
            daoName,
            socialConfig,
            address(mockERC20),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            timelockDelay,
            quorumVotes
        );

        string memory secondDaoName = string(abi.encodePacked(daoName, "1"));

        // Revert if quorum votes is zero
        vm.expectRevert(IErrors.InvalidQuorumVotes.selector);
        daoFactory.createDao(
            secondDaoName,
            socialConfig,
            address(mockERC20),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            timelockDelay,
            0
        );

        // Revert if community token owner is not the msg.sender
        vm.prank(defaultAdmin);
        vm.expectRevert(IErrors.InvalidCommunityTokenOwner.selector);
        daoFactory.createDao(
            daoName,
            socialConfig,
            address(mockERC20),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            timelockDelay,
            quorumVotes
        );
    }

    function test_pause() public {
        test_createDAO();

        // Revert if not admin
        vm.prank(nonDefaultAdmin);
        vm.expectRevert();
        daoFactory.pause();

        // Default admin can pause
        vm.prank(defaultAdmin);
        daoFactory.pause();
    }

    function test_unpause() public {
        test_pause();

        // Revert if not admin
        vm.prank(nonDefaultAdmin);
        vm.expectRevert();
        daoFactory.unpause();

        // Default admin can unpause
        vm.prank(defaultAdmin);
        daoFactory.unpause();
    }
}
