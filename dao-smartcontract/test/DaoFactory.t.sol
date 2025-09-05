// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DAOFactory} from "../src/DAOFactory.sol";
import {PCECommunityGovToken} from "../src/mocks/PCECommunityGovToken.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract Example {
    constructor(address _factoryAddress) {}

    function deployNewContract() public {}
}

contract DaoFactoryDeployable is DAOFactory {
    // Public function to be able to test internal deploy function
    function deployPublic(bytes memory bytecode) public returns (address) {
        return super.deploy(bytecode);
    }
}

contract DaoFactoryTest is Test {
    address alice = address(this); // Owner
    address bob = makeAddr("Bob");
    uint256 constant INITIAL_BALANCE = 1000000 * 1e18;
    uint256 constant VOTING_DELAY = 10;
    uint256 constant VOTING_PERIOD = 100;
    uint256 constant PROPOSAL_THRESHOLD = 1000;
    uint256 constant QUORUM_PERCENTAGE = 400;
    uint256 constant TIMELOCK_DELAY = 100;
    string constant DAO_NAME = "Test DAO";

    string constant URI = "https://peacecoin.io/sbt";
    DAOFactory.SocialConfig socialConfig =
        DAOFactory.SocialConfig({
            description: "Test Description",
            website: "https://test.com",
            linkedin: "https://linkedin.com/test",
            twitter: "https://twitter.com/test",
            telegram: "https://t.me/test"
        });

    bytes bytecode = type(Example).creationCode;
    bytes _arguments = abi.encode(0x7D01D10d894B36dBA00E5ecc1e54ff32e83F84D5);

    DAOFactory daoFactory;
    PCECommunityGovToken pceCommunityGovToken;
    MockERC20 mockERC20;

    event DAOSocialConfigUpdated(bytes32 indexed daoId, DAOFactory.SocialConfig socialConfig);
    event ContractDeployed(address contractAddress);
    event DAOCreated(
        bytes32 indexed daoId,
        string description,
        string website,
        string linkedin,
        string twitter,
        string telegram,
        string name,
        address governor,
        address timelock,
        address governanceToken,
        address communityToken
    );

    function setUp() public {
        daoFactory = new DAOFactory();

        pceCommunityGovToken = new PCECommunityGovToken();

        mockERC20 = new MockERC20();
        mockERC20.initialize();

        Timelock _timelock = new Timelock();
        GovernorAlpha _gov = new GovernorAlpha();
        daoFactory.setImplementation(
            address(_timelock),
            address(_gov),
            address(pceCommunityGovToken)
        );

        vm.roll(block.number + 10000);
    }

    function testSetsOwner() public view {
        assertEq(daoFactory.owner(), alice);
    }

    function testSetImplementation() public {
        Timelock timelock = new Timelock();
        GovernorAlpha gov = new GovernorAlpha();
        daoFactory.setImplementation(
            address(timelock),
            address(gov),
            address(pceCommunityGovToken)
        );

        assertEq(daoFactory.timelockImplementation(), address(timelock));
        assertEq(daoFactory.governorImplementation(), address(gov));
        assertEq(daoFactory.governanceTokenImplementation(), address(pceCommunityGovToken));
    }

    function testSetImplementation_RevertsWhen_NotOwner() public {
        Timelock _timelock = new Timelock();
        GovernorAlpha _gov = new GovernorAlpha();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob));
        daoFactory.setImplementation(
            address(_timelock),
            address(_gov),
            address(pceCommunityGovToken)
        );
    }

    function testDaoCreation() public {
        testSetImplementation();

        bytes32 newDaoId = daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY, // votingDelay
            VOTING_PERIOD, // votingPeriod
            PROPOSAL_THRESHOLD, // proposalThreshold
            QUORUM_PERCENTAGE, // quorumPercentage
            TIMELOCK_DELAY // timelockDelay
        );

        assertEq(daoFactory.totalDAOs(), 1);
        assertTrue(daoFactory.daoNames(DAO_NAME));

        bytes32 daoId = keccak256(abi.encodePacked(DAO_NAME));
        assertEq(daoId, newDaoId);

        DAOFactory.DAOConfig memory daoConfig = daoFactory.getDAO(daoId);

        assertEq(daoConfig.communityToken, address(mockERC20));
        assertEq(daoConfig.votingDelay, VOTING_DELAY);
        assertEq(daoConfig.votingPeriod, VOTING_PERIOD);
        assertEq(daoConfig.proposalThreshold, PROPOSAL_THRESHOLD);
        assertEq(daoConfig.quorum, QUORUM_PERCENTAGE);
        assertTrue(daoConfig.exists);
        assertEq(daoConfig.socialConfig.description, socialConfig.description);
        assertEq(daoConfig.socialConfig.website, socialConfig.website);
        assertEq(daoConfig.socialConfig.linkedin, socialConfig.linkedin);
        assertEq(daoConfig.socialConfig.twitter, socialConfig.twitter);
        assertEq(daoConfig.socialConfig.telegram, socialConfig.telegram);
    }

    function testDAOCreationAndProposalFlow() public {
        testDaoCreation();

        // Verify DAO creation
        bytes32 daoId = keccak256(abi.encodePacked(DAO_NAME));
        DAOFactory.DAOConfig memory daoConfig = daoFactory.getDAO(daoId);

        // Get governor and timelock instances
        GovernorAlpha governor = GovernorAlpha(daoConfig.governor);
        Timelock timelock = Timelock(daoConfig.timelock);
        address governorToken = daoConfig.governanceToken;

        // Validates timelock permitions
        assertEq(timelock.admin(), address(governor));

        vm.startPrank(bob);
        mockERC20.mint(bob, INITIAL_BALANCE);

        mockERC20.approve(address(governorToken), INITIAL_BALANCE);
        PCECommunityGovToken(governorToken).deposit(INITIAL_BALANCE);
        PCECommunityGovToken(governorToken).delegate(bob);

        vm.roll(block.number + 10);

        // Create proposal parameters
        address[] memory targets = new address[](1);
        targets[0] = address(mockERC20);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "approve(address,uint256)";

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(bob, 1000000);

        // Submit proposal
        uint256 proposalId = governor.propose(
            targets,
            values,
            signatures,
            calldatas,
            "Test Proposal"
        );

        // Move past voting delay
        vm.roll(block.number + 11); // voting delay + 1

        // Verify proposal state
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(GovernorAlpha.ProposalState.Active),
            "Proposal should be active"
        );

        // Cast vote
        governor.castVote(proposalId, true);

        // Move past voting period
        vm.roll(block.number + 101); // voting period + 1

        // Verify proposal succeeded
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(GovernorAlpha.ProposalState.Succeeded),
            "Proposal should have succeeded"
        );

        // Queue proposal
        governor.queue(proposalId);

        // Verify proposal queued
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(GovernorAlpha.ProposalState.Queued),
            "Proposal should be queued"
        );

        // Move past timelock delay
        vm.warp(block.timestamp + 101); // timelock delay + 1

        // Execute proposal
        governor.execute(proposalId);

        // Verify proposal executed
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(GovernorAlpha.ProposalState.Executed),
            "Proposal should be executed"
        );
        assertEq(
            mockERC20.allowance(address(timelock), bob),
            1000000,
            "Bob should have allowance for 1000000 tokens"
        );

        vm.stopPrank();
    }

    function testCannotCreateDAOIfNotOwner() public {
        vm.prank(bob);
        vm.expectRevert("Invalid community token owner");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDAOWithEmptyName() public {
        Timelock timelock = new Timelock();
        GovernorAlpha gov = new GovernorAlpha();

        daoFactory.setImplementation(
            address(timelock),
            address(gov),
            address(pceCommunityGovToken)
        );

        vm.expectRevert("Empty name not allowed");
        daoFactory.createDAO(
            "",
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDuplicateDAO() public {
        // Create first DAO
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );

        // Attempt to create DAO with same name
        vm.expectRevert("DAO name already exists");
        daoFactory.createDAO(
            DAO_NAME, // same name
            DAOFactory.SocialConfig({
                description: "Different Description",
                website: "https://test2.com",
                linkedin: "https://linkedin.com/test2",
                twitter: "https://twitter.com/test2",
                telegram: "https://t.me/test2"
            }),
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDAOWithInvalidTimeLock() public {
        daoFactory.setImplementation(address(0), address(0), address(pceCommunityGovToken));
        vm.expectRevert("Timelock implementation not set");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDAOWithInvalidGovernor() public {
        Timelock timelock = new Timelock();
        daoFactory.setImplementation(address(timelock), address(0), address(pceCommunityGovToken));
        vm.expectRevert("Governor implementation not set");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDAOWithInvalidGovernorToken() public {
        Timelock timelock = new Timelock();
        GovernorAlpha gov = new GovernorAlpha();
        daoFactory.setImplementation(address(timelock), address(gov), address(0));
        vm.expectRevert("Governor token address not set");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDAOWithInvalidQuorum() public {
        Timelock timelock = new Timelock();
        GovernorAlpha gov = new GovernorAlpha();
        daoFactory.setImplementation(
            address(timelock),
            address(gov),
            address(pceCommunityGovToken)
        );

        vm.expectRevert("Quorum cannot be zero");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            0, // invalid quorum
            TIMELOCK_DELAY
        );
    }

    function testDAOSocialConfigUpdate() public {
        // Create initial DAO
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );

        bytes32 daoId = keccak256(abi.encodePacked(DAO_NAME));

        // Update social config
        DAOFactory.SocialConfig memory newConfig = DAOFactory.SocialConfig({
            description: "Updated Description",
            website: "https://updated.com",
            linkedin: "https://linkedin.com/updated",
            twitter: "https://twitter.com/updated",
            telegram: "https://t.me/updated"
        });

        vm.expectEmit(true, false, false, true);
        emit DAOSocialConfigUpdated(daoId, newConfig);
        daoFactory.updateDAOSocialConfig(daoId, newConfig);

        // Verify update
        DAOFactory.DAOConfig memory updatedDao = daoFactory.getDAO(daoId);
        assertEq(updatedDao.socialConfig.description, "Updated Description");
        assertEq(updatedDao.socialConfig.website, "https://updated.com");
        assertEq(updatedDao.socialConfig.linkedin, "https://linkedin.com/updated");
        assertEq(updatedDao.socialConfig.twitter, "https://twitter.com/updated");
        assertEq(updatedDao.socialConfig.telegram, "https://t.me/updated");
    }

    function testCannotUpdateNonExistentDAO() public {
        bytes32 nonExistentDaoId = keccak256(abi.encodePacked("Non Existent DAO"));

        vm.expectRevert("DAO does not exist");
        daoFactory.updateDAOSocialConfig(
            nonExistentDaoId,
            DAOFactory.SocialConfig({
                description: "Updated Description",
                website: "https://updated.com",
                linkedin: "https://linkedin.com/updated",
                twitter: "https://twitter.com/updated",
                telegram: "https://t.me/updated"
            })
        );
    }

    function testIsDaoExistsReturnsTrue() public {
        // Create DAO
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );

        // Check if DAO exists
        bytes32 daoId = keccak256(abi.encodePacked(DAO_NAME));
        bool exists = daoFactory.isDaoExists(daoId);
        assertTrue(exists, "DAO should exist");
    }

    function testIsDaoExistsReturnsFalse() public view {
        bytes32 nonExistentDaoId = keccak256(abi.encodePacked("Non Existent DAO"));
        bool exists = daoFactory.isDaoExists(nonExistentDaoId);
        assertFalse(exists);
    }

    // Test internal deploy() function
    function testDeploy_EmitsEventWithAddress() public {
        DaoFactoryDeployable daoFactoryDeployable = new DaoFactoryDeployable();
        // We check the logs instead of using vm.expectEmit because we need the newly created address
        vm.recordLogs();

        address deployedAddress = daoFactoryDeployable.deployPublic(
            getBytecodeWithConstructorArgs(bytecode, _arguments)
        );

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = logs[0].topics[0];
        address contractAddressFromLog = abi.decode(logs[0].data, (address));
        assertEq(eventSignature, ContractDeployed.selector);
        assertEq(contractAddressFromLog, deployedAddress);
    }

    function testDeploy_Reverts_WhenByteCodeIsInvalid() public {
        DaoFactoryDeployable daoFactoryDeployable = new DaoFactoryDeployable();
        vm.expectRevert("Contract deployment failed");
        daoFactoryDeployable.deployPublic(bytes("Invalid EVM bytecode"));
    }

    function getBytecodeWithConstructorArgs(
        bytes memory _bytecode,
        bytes memory _constructorArgs
    ) public pure returns (bytes memory) {
        return abi.encodePacked(_bytecode, _constructorArgs);
    }

    // Additional optimized tests
    function testMultipleDAOCreation() public {
        // Create first DAO
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );

        // Create second DAO with different name
        string memory secondDaoName = "Second Test DAO";
        DAOFactory.SocialConfig memory secondSocialConfig = DAOFactory.SocialConfig({
            description: "Second DAO Description",
            website: "https://second.com",
            linkedin: "https://linkedin.com/second",
            twitter: "https://twitter.com/second",
            telegram: "https://t.me/second"
        });

        bytes32 secondDaoId = daoFactory.createDAO(
            secondDaoName,
            secondSocialConfig,
            address(mockERC20),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );

        assertEq(daoFactory.totalDAOs(), 2);
        assertTrue(daoFactory.daoNames(DAO_NAME));
        assertTrue(daoFactory.daoNames(secondDaoName));

        // Verify both DAOs exist
        DAOFactory.DAOConfig memory firstDao = daoFactory.getDAO(
            keccak256(abi.encodePacked(DAO_NAME))
        );
        DAOFactory.DAOConfig memory secondDao = daoFactory.getDAO(secondDaoId);

        assertTrue(firstDao.exists);
        assertTrue(secondDao.exists);
        assertEq(firstDao.socialConfig.description, socialConfig.description);
        assertEq(secondDao.socialConfig.description, secondSocialConfig.description);
    }

    function testGetDAORevertsForNonExistentDAO() public {
        bytes32 nonExistentDaoId = keccak256(abi.encodePacked("Non Existent DAO"));
        vm.expectRevert("DAO does not exist");
        daoFactory.getDAO(nonExistentDaoId);
    }
}
