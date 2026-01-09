// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PEACECOINDAO_SBT} from "../src/Governance/PEACECOINDAO_SBT.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";

/**
 * @title PEACECOINDAO_SBTTest
 * @notice Comprehensive test suite for the PEACECOINDAO_SBT contract
 * @dev Tests cover non-transferability
 */
contract PEACECOINDAO_SBTTest is Test {
    /// @notice SBT contract
    PEACECOINDAO_SBT public sbt;

    /// @notice Test accounts
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    // ============ Constants ============

    /// @notice SBT configuration constants
    string private constant TOKEN_URI = "test-uri";
    uint256 private constant VOTING_POWER = 100;
    string private constant BASE_URI = "https://nftdata.parallelnft.com/api/parallel-alpha/ipfs/";
    // ============ Setup ============

    /**
     * @notice Sets up the test environment before each test
     * @dev Deploys and initializes all necessary contracts for testing
     */
    function setUp() public {
        // Deploy core contracts
        sbt = new PEACECOINDAO_SBT();

        // Initialize SBT contract
        sbt.initialize(BASE_URI, address(this), address(this), true);
        sbt.setMinter(address(this));
    }

    // ============ Token Transferability Tests ============

    /**
     * @notice Tests that SBTs are not transferable
     * @dev Verifies that SBTs are not transferable
     */
    function test_safeTransferFrom_NonTransferable() public {
        sbt.createToken(TOKEN_URI, VOTING_POWER);
        sbt.mint(alice, 1, 1);
        vm.expectRevert(abi.encodeWithSelector(IErrors.NonTransferable.selector));
        sbt.safeTransferFrom(alice, bob, 1, 1, "");
    }

    function test_safeBatchTransferFrom_NonTransferable() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        sbt.createToken(TOKEN_URI, VOTING_POWER);
        sbt.mint(alice, 1, 1);
        vm.expectRevert(abi.encodeWithSelector(IErrors.NonTransferable.selector));
        sbt.safeBatchTransferFrom(alice, bob, tokenIds, amounts, "");
    }
}
