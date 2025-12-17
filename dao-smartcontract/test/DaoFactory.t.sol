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

contract DaoFactoryTest is Test {
    DAOFactory public daoFactory;
    Timelock public timelock;
    GovernorAlpha public governor;
    MockERC20 public mockERC20;
    PCECommunityGovToken public governanceToken;

    uint256 public VOTING_DELAY = 10;
    uint256 public VOTING_PERIOD = 100;
    uint256 public PROPOSAL_THRESHOLD = 1000;
    uint256 public QUORUM_VOTES = 2000;
    uint256 public TIMELOCK_DELAY = 100;
    string public DAO_NAME = "Test DAO";

    IDAOFactory.SocialConfig public SOCIAL_CONFIG =
        IDAOFactory.SocialConfig({
            description: "Test Description",
            website: "https://website.com",
            linkedin: "https://linkedin.com",
            twitter: "https://twitter.com",
            telegram: "https://telegram.com"
        });

    address public defaultAdmin = makeAddr("defaultAdmin");
    address public nonDefaultAdmin = makeAddr("nonDefaultAdmin");

    function setUp() public {
        vm.prank(defaultAdmin);
        daoFactory = new DAOFactory(address(0), address(0));

        vm.startPrank(nonDefaultAdmin);
        timelock = new Timelock();
        governor = new GovernorAlpha();
        governanceToken = new PCECommunityGovToken();

        mockERC20 = new MockERC20();
        mockERC20.initialize();
        vm.stopPrank();
    }

    function test_setImplementation() public {
        // Default Admin can set implementation
        vm.prank(defaultAdmin);
        daoFactory.setImplementation(
            address(timelock),
            address(governor),
            address(governanceToken)
        );

        // Non-Default Admin cannot set implementation
        vm.prank(nonDefaultAdmin);
        vm.expectRevert();
        daoFactory.setImplementation(
            address(timelock),
            address(governor),
            address(governanceToken)
        );

        // Zero address cannot be set as implementation
        vm.startPrank(defaultAdmin);
        vm.expectRevert();
        daoFactory.setImplementation(address(0), address(governor), address(governanceToken));

        // Zero address cannot be set as implementation
        vm.expectRevert();
        daoFactory.setImplementation(address(timelock), address(0), address(governanceToken));

        // Zero address cannot be set as implementation
        vm.expectRevert();
        daoFactory.setImplementation(address(timelock), address(governor), address(0));

        // Check that ImplementationUpdated event is emitted with correct arguments
        vm.expectEmit(true, true, true, true);
        emit DAOFactory.ImplementationUpdated(
            address(timelock),
            address(governor),
            address(governanceToken)
        );
        daoFactory.setImplementation(
            address(timelock),
            address(governor),
            address(governanceToken)
        );
        vm.stopPrank();
    }

    function test_createDAO() public {
        // Revert if implementation is not set
        vm.expectRevert(IErrors.TimelockImplementationNotSet.selector);
        daoFactory.createDAO(
            DAO_NAME,
            SOCIAL_CONFIG,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            TIMELOCK_DELAY,
            QUORUM_VOTES
        );

        // Set implementation
        test_setImplementation();

        // only token owner can create DAO
        vm.startPrank(nonDefaultAdmin);
        daoFactory.createDAO(
            DAO_NAME,
            SOCIAL_CONFIG,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            TIMELOCK_DELAY,
            QUORUM_VOTES
        );

        // Revert if community token address is zero
        vm.expectRevert(IErrors.InvalidAddress.selector);
        daoFactory.createDAO(
            DAO_NAME,
            SOCIAL_CONFIG,
            address(0),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            TIMELOCK_DELAY,
            QUORUM_VOTES
        );

        // Revert if dao name is empty
        vm.expectRevert(IErrors.InvalidName.selector);
        daoFactory.createDAO(
            "",
            SOCIAL_CONFIG,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            TIMELOCK_DELAY,
            QUORUM_VOTES
        );

        // Revert if dao name already exists
        vm.expectRevert(IErrors.DAOAlreadyExists.selector);
        daoFactory.createDAO(
            DAO_NAME,
            SOCIAL_CONFIG,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            TIMELOCK_DELAY,
            QUORUM_VOTES
        );

        string memory secondDAOName = string(abi.encodePacked(DAO_NAME, "1"));
        // Revert if voting delay is greater than max voting delay
        vm.expectRevert(IErrors.InvalidVotingDelay.selector);
        daoFactory.createDAO(
            secondDAOName,
            SOCIAL_CONFIG,
            address(mockERC20),
            1000 days,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            TIMELOCK_DELAY,
            QUORUM_VOTES
        );

        // Revert if voting period is greater than max voting period
        vm.expectRevert(IErrors.InvalidVotingPeriod.selector);
        daoFactory.createDAO(
            secondDAOName,
            SOCIAL_CONFIG,
            address(mockERC20),
            VOTING_DELAY,
            1000 days,
            PROPOSAL_THRESHOLD,
            TIMELOCK_DELAY,
            QUORUM_VOTES
        );

        // Revert if timelock delay is greater than max timelock delay
        vm.expectRevert(IErrors.InvalidTimelockDelay.selector);
        daoFactory.createDAO(
            secondDAOName,
            SOCIAL_CONFIG,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            1000 days,
            QUORUM_VOTES
        );

        // Revert if quorum votes is zero
        vm.expectRevert(IErrors.InvalidQuorumVotes.selector);
        daoFactory.createDAO(
            secondDAOName,
            SOCIAL_CONFIG,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            TIMELOCK_DELAY,
            0
        );

        vm.stopPrank();

        // Revert if community token owner is not the msg.sender
        vm.prank(defaultAdmin);
        vm.expectRevert(IErrors.InvalidCommunityTokenOwner.selector);
        daoFactory.createDAO(
            DAO_NAME,
            SOCIAL_CONFIG,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            TIMELOCK_DELAY,
            QUORUM_VOTES
        );
    }

    function test_getDAO() public {
        test_createDAO();

        address daoAddress = daoFactory.getDAOAddress(keccak256(abi.encodePacked(DAO_NAME)));
        assertEq(daoAddress != address(0), true);
    }

    function test_isDaoExists() public {
        test_createDAO();

        bool daoExists = daoFactory.isDaoExists(keccak256(abi.encodePacked(DAO_NAME)));
        assertEq(daoExists, true);
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
