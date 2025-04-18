// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DAOFactory} from "../src/DAOFactory.sol";
import {PCECommunityGovToken} from "../src/PCECommunityGovToken.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {Timelock} from "../src/Governance/Timelock.sol";

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
    uint256 constant INITIAL_BALANCE = 1000000;
    uint256 constant VOTING_DELAY = 10;
    uint256 constant VOTING_PERIOD = 100;
    uint256 constant PROPOSAL_THRESHOLD = 1000;
    uint256 constant QUORUM_PERCENTAGE = 400;
    uint256 constant TIMELOCK_DELAY = 100;
    string constant DAO_NAME = "Test DAO";
    DAOFactory.SocialConfig socialConfig = DAOFactory.SocialConfig({
        description: "Test Description",
        website: "https://test.com",
        linkedin: "https://linkedin.com/test",
        twitter: "https://twitter.com/test",
        telegram: "https://t.me/test"
    });

    bytes bytecode = type(Example).creationCode;
    bytes _arguments = abi.encode(0x7D01D10d894B36dBA00E5ecc1e54ff32e83F84D5);

    DAOFactory daoFactory;
    MockERC20 testERC20;
    PCECommunityGovToken pceToken;

    event DAOSocialConfigUpdated(
        bytes32 indexed daoId, string description, string website, string linkedin, string twitter, string telegram
    );
    event ContractDeployed(address contractAddress);

    function setUp() public {
        testERC20 = new MockERC20();
        testERC20.mint(alice, INITIAL_BALANCE);

        daoFactory = new DAOFactory();
        pceToken = new PCECommunityGovToken();
        pceToken.initialize(address(testERC20));

        Timelock _timelock = new Timelock();
        GovernorAlpha _gov = new GovernorAlpha();
        daoFactory.setImplementation(address(_timelock), address(_gov), address(pceToken));

        testERC20.approve(address(pceToken), INITIAL_BALANCE);
        pceToken.deposit(INITIAL_BALANCE);
        pceToken.delegate(address(alice));
        vm.roll(block.number + 10000);
    }

    function testSetsOwner() public view {
        assertEq(daoFactory.owner(), alice);
    }

    function testSetImplementation() public {
        Timelock timelock = new Timelock();
        GovernorAlpha gov = new GovernorAlpha();
        daoFactory.setImplementation(address(timelock), address(gov), address(pceToken));

        assertEq(daoFactory.timelockImplementation(), address(timelock));
        assertEq(daoFactory.governorImplementation(), address(gov));
        assertEq(daoFactory.governanceTokenImplementation(), address(pceToken));
    }

    function testSetImplementation_RevertsWhen_NotOwner() public {
        Timelock _timelock = new Timelock();
        GovernorAlpha _gov = new GovernorAlpha();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob));
        daoFactory.setImplementation(address(_timelock), address(_gov), address(pceToken));
    }

    function testDaoCreation() public {
        bytes32 newDaoId = daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(pceToken),
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

        assertEq(daoConfig.communityToken, address(pceToken));
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
        // Create DAO
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(pceToken),
            VOTING_DELAY, // votingDelay
            VOTING_PERIOD, // votingPeriod
            PROPOSAL_THRESHOLD, // proposalThreshold
            QUORUM_PERCENTAGE, // quorumPercentage
            TIMELOCK_DELAY // timelockDelay
        );

        // Verify DAO creation
        bytes32 daoId = keccak256(abi.encodePacked(DAO_NAME));
        DAOFactory.DAOConfig memory daoConfig = daoFactory.getDAO(daoId);

        // Get governor and timelock instances
        GovernorAlpha governor = GovernorAlpha(daoConfig.governor);
        Timelock timelock = Timelock(daoConfig.timelock);
        address governorToken = daoConfig.governanceToken;

        // Validates timelock permitions
        assertEq(timelock.admin(), address(governor));

        pceToken.approve(governorToken, pceToken.balanceOf(address(alice)));
        PCECommunityGovToken(governorToken).deposit(pceToken.balanceOf(address(alice)));

        PCECommunityGovToken(governorToken).delegate(address(alice));

        vm.roll(block.number + 10000);

        // Create proposal parameters
        address[] memory targets = new address[](1);
        targets[0] = address(pceToken);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "approve(address,uint256)";

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(address(bob), 1000000);

        // Submit proposal
        uint256 proposalId = governor.propose(targets, values, signatures, calldatas, "Test Proposal");

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
            pceToken.allowance(address(timelock), address(bob)), 1000000, "Bob should have allowance for 1000000 tokens"
        );
    }

    function testCannotCreateDAOIfNotOwner() public {
        vm.prank(bob);
        vm.expectRevert("Invalid community token owner");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(pceToken),
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

        daoFactory.setImplementation(address(timelock), address(gov), address(pceToken));

        vm.expectRevert("Empty name not allowed");
        daoFactory.createDAO(
            "",
            socialConfig,
            address(pceToken),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDAOWithInvalidParameters() public {
        Timelock timelock = new Timelock();
        GovernorAlpha gov = new GovernorAlpha();

        daoFactory.setImplementation(address(timelock), address(gov), address(pceToken));

        // Test with zero address for governance token
        vm.expectRevert("Invalid governance token");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(0), // zero address
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
            address(pceToken),
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
            address(pceToken),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDAOWithInvalidTimeLock() public {
        daoFactory.setImplementation(address(0), address(0), address(pceToken));
        vm.expectRevert("Timelock implementation not set");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(pceToken),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDAOWithInvalidGovernor() public {
        Timelock timelock = new Timelock();
        GovernorAlpha gov = new GovernorAlpha();
        daoFactory.setImplementation(address(timelock), address(gov), address(0));
        vm.expectRevert("Governor token address not set");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(pceToken),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDAOWithInvalidGovernorToken() public {
        Timelock timelock = new Timelock();
        daoFactory.setImplementation(address(timelock), address(0), address(pceToken));
        vm.expectRevert("Governor implementation not set");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(pceToken),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE,
            TIMELOCK_DELAY
        );
    }

    function testCannotCreateDAOWithInvalidQuorum() public {
        vm.expectRevert("Quorum cannot be zero");
        daoFactory.createDAO(
            DAO_NAME,
            socialConfig,
            address(pceToken),
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
            address(pceToken),
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
        emit DAOSocialConfigUpdated(
            daoId, newConfig.description, newConfig.website, newConfig.linkedin, newConfig.twitter, newConfig.telegram
        );
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
            address(pceToken),
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

    // internal deploy()
    function testDeploy_EmitsEventWithAddress() public {
        DaoFactoryDeployable daoFactoryDeployable = new DaoFactoryDeployable();
        // We check the logs instead of using vm.expectEmit because we need the newly created address
        vm.recordLogs();

        address deployedAddress =
            daoFactoryDeployable.deployPublic(getBytecodeWithConstructorArgs(bytecode, _arguments));

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

    function getBytecodeWithConstructorArgs(bytes memory _bytecode, bytes memory _constructorArgs)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(_bytecode, _constructorArgs);
    }
}
