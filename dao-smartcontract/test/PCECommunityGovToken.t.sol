// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PCECommunityGovToken} from "../src/PCECommunityGovToken.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {Test} from "forge-std/Test.sol";

contract PCECommunityGovTokenTest is Test {
    MockERC20 erc20CommunityToken;
    PCECommunityGovToken pceToken;
    address owner = address(this);
    address user = makeAddr("User");
    uint256 constant INITIAL_BALANCE = 5e18;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function setUp() public {
        erc20CommunityToken = new MockERC20();
        pceToken = new PCECommunityGovToken();
        pceToken.initialize(address(erc20CommunityToken));

        erc20CommunityToken.mint(user, INITIAL_BALANCE);
        vm.prank(user);
        erc20CommunityToken.approve(address(pceToken), INITIAL_BALANCE);
    }

    function test_Initialiation() public view {
        assertEq(pceToken.name(), "Community Governance Token");
        assertEq(pceToken.symbol(), "COM_GOV");
        assertEq(pceToken.owner(), owner);
        assertEq(address(pceToken.communityToken()), address(erc20CommunityToken));
    }

    function test_Deposit_RevertsWhen_AmountIsZero() public {
        vm.expectRevert("Stake: can't stake 0");
        pceToken.deposit(0);
    }

    function test_Deposit() public {
        vm.prank(user);
        vm.expectEmit(true, false, false, false);
        emit Deposited(user, INITIAL_BALANCE);
        pceToken.deposit(INITIAL_BALANCE);

        assertEq(erc20CommunityToken.balanceOf(address(pceToken)), INITIAL_BALANCE);
        assertEq(erc20CommunityToken.balanceOf(user), 0);
        assertEq(pceToken.balanceOf(user), INITIAL_BALANCE);
        assertEq(pceToken.totalSupply(), INITIAL_BALANCE);
    }

    function test_Withdraw_RevertsWhen_AmountIsZero() public {
        vm.expectRevert("Amount should be greater then 0");
        pceToken.withdraw(0);
    }

    function test_Withdraw() public {
        vm.prank(user);
        pceToken.deposit(INITIAL_BALANCE);

        vm.prank(user);
        vm.expectEmit(true, false, false, false);
        emit Withdrawn(user, INITIAL_BALANCE);
        pceToken.withdraw(INITIAL_BALANCE);

        assertEq(erc20CommunityToken.balanceOf(address(pceToken)), 0);
        assertEq(erc20CommunityToken.balanceOf(user), INITIAL_BALANCE);
        assertEq(pceToken.balanceOf(user), 0);
        assertEq(pceToken.totalSupply(), 0);
    }
}
