// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {DAOFactory} from "../src/DAOFactory.sol";
import {PCECommunityGovToken} from "../src/PCECommunityGovToken.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {GovernorAlpha} from "../src/Governance/GovernorAlpha.sol";
import {Timelock} from "../src/Governance/Timelock.sol";
import "forge-std/console.sol";

contract DaoFactoryTest is Test {
    address alice = address(0xABCD);
    address bob = address(0xDCBA);
    address trent = address(this);

    DAOFactory daoFactory;
    MockERC20 testERC20;
    PCECommunityGovToken pceToken;

    function setUp() public {
        vm.startPrank(alice);

        testERC20 = new MockERC20();
        testERC20.mint(alice, 1000000);

        daoFactory = new DAOFactory();
        pceToken = new PCECommunityGovToken();
        pceToken.initialize(address(testERC20));
        testERC20.approve(address(pceToken), 1000000);
        pceToken.deposit(1000000);
        pceToken.delegate(address(alice));
        vm.roll(block.number + 10000);
    }

    function testDAOCreationAndProposalFlow() public {
        // Set bytecode for governor token
        console.log("Setting bytecode for governor token");
        console.logBytes(type(PCECommunityGovToken).creationCode);
        daoFactory.setBytecodeForGovernorToken(type(PCECommunityGovToken).creationCode);

        // Create DAO
        daoFactory.createDAO(
            "Test DAO",
            DAOFactory.SocialConfig({
                description: "Test Description",
                website: "https://test.com",
                linkedin: "https://linkedin.com/test",
                twitter: "https://twitter.com/test",
                telegram: "https://t.me/test"
            }),
            address(pceToken),
            10, // votingDelay
            100, // votingPeriod
            1000, // proposalThreshold
            400, // quorumPercentage
            100 // timelockDelay
        );

        // Verify DAO creation
        bytes32 daoId = keccak256(abi.encodePacked("Test DAO"));
        DAOFactory.DAOConfig memory daoConfig = daoFactory.getDAO(daoId);

        // Get governor and timelock instances
        GovernorAlpha governor = GovernorAlpha(daoConfig.governor);
        Timelock timelock = Timelock(daoConfig.timelock);
        address governorToken = daoConfig.governanceToken;

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
        calldatas[0] = abi.encode(address(timelock), 1000000);

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
    }

    function testCannotCreateDAOWithInvalidParameters() public {
        daoFactory.setBytecodeForGovernorToken(type(PCECommunityGovToken).creationCode);

        // Test with zero address for governance token
        vm.expectRevert("Invalid governance token");
        daoFactory.createDAO(
            "Test DAO",
            DAOFactory.SocialConfig({
                description: "Test Description",
                website: "https://test.com",
                linkedin: "https://linkedin.com/test",
                twitter: "https://twitter.com/test",
                telegram: "https://t.me/test"
            }),
            address(0), // zero address
            10,
            100,
            1000,
            400,
            100
        );
    }

    function testCannotCreateDuplicateDAO() public {
        daoFactory.setBytecodeForGovernorToken(type(PCECommunityGovToken).creationCode);

        // Create first DAO
        daoFactory.createDAO(
            "Test DAO",
            DAOFactory.SocialConfig({
                description: "Test Description",
                website: "https://test.com",
                linkedin: "https://linkedin.com/test",
                twitter: "https://twitter.com/test",
                telegram: "https://t.me/test"
            }),
            address(pceToken),
            10,
            100,
            1000,
            400,
            100
        );

        // Attempt to create DAO with same name
        vm.expectRevert("DAO name already exists");
        daoFactory.createDAO(
            "Test DAO", // same name
            DAOFactory.SocialConfig({
                description: "Different Description",
                website: "https://test2.com",
                linkedin: "https://linkedin.com/test2",
                twitter: "https://twitter.com/test2",
                telegram: "https://t.me/test2"
            }),
            address(pceToken),
            10,
            100,
            1000,
            400,
            100
        );
    }
}