// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {PCEToken} from "../src/PCEToken.sol";
import {PCECommunityToken} from "../src/PCECommunityToken.sol";
import {ExchangeAllowMethod} from "../src/lib/Enum.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract PCETokenTest is Test {
    address constant ALICE = address(0xABCD);
    address constant BOB = address(0xDCBA);

    address constant COMMUNITY_TOKEN =
        0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;
    uint256 constant INITIAL_AMOUNT = 50000;

    PCEToken pceToken;
    PCECommunityToken cToken;

    function setUp() public {
        vm.label(ALICE, "alice");
        vm.label(BOB, "bob");

        cToken = new PCECommunityToken();
        pceToken = new PCEToken();
        pceToken.initialize("PEACE COIN", "PCE", address(cToken));

        assertEq(pceToken.totalSupply(), pceToken.balanceOf(address(this)));
    }

    function testVotingPower() public {
        uint256 balance = pceToken.balanceOf(address(this));
        uint256 amount = 10000;

        pceToken.delegate(address(this));
        assertEq(balance, pceToken.getVotes(address(this)));

        pceToken.transfer(ALICE, amount);
        assertEq(balance - amount, pceToken.getVotes(address(this)));
        assertEq(pceToken.numCheckpoints(address(this)), 1);

        vm.prank(ALICE);
        pceToken.delegate(ALICE);
        assertEq(pceToken.numCheckpoints(ALICE), 1);
        assertEq(amount, pceToken.getVotes(ALICE));
    }

    function testCreateToken() public {
        PCEToken.TokenInfo memory tokenInfo = PCEToken.TokenInfo({
            name: "CommunityToken",
            symbol: "CTP",
            amountToExchange: INITIAL_AMOUNT,
            dilutionFactor: 2e18,
            decreaseIntervalDays: 7,
            afterDecreaseBp: 20,
            maxIncreaseOfTotalSupplyBp: 20,
            maxIncreaseBp: 2000,
            maxUsageBp: 3000,
            changeBp: 3000,
            incomeExchangeAllowMethod: ExchangeAllowMethod.All,
            outgoExchangeAllowMethod: ExchangeAllowMethod.All,
            incomeTargetTokens: new address[](0),
            outgoTargetTokens: new address[](0)
        });

        pceToken.createToken(tokenInfo);
    }

    function testSwapToLocalToken() public {
        testCreateToken();
        uint256 amountToSwap = 10000;
        skip(1);

        uint256 balanceBefore = pceToken.balanceOf(address(this));
        pceToken.swapToLocalToken(COMMUNITY_TOKEN, amountToSwap);
        uint256 balanceAfter = pceToken.balanceOf(address(this));

        assertEq(balanceBefore - balanceAfter, amountToSwap);

        ERC20Upgradeable(COMMUNITY_TOKEN).balanceOf(address(this));

        vm.expectRevert("Target token not found");
        pceToken.swapToLocalToken(ALICE, amountToSwap);
    }

    function testSwapFromLocalToken() public {
        testCreateToken();
        uint256 amountToSwap = 20000;
        skip(1);

        ERC20Upgradeable(COMMUNITY_TOKEN).approve(
            address(pceToken),
            amountToSwap * pceToken.getCurrentFactor()
        );
        uint256 balanceBefore = pceToken.balanceOf(address(this));
        pceToken.swapFromLocalToken(COMMUNITY_TOKEN, amountToSwap);
        uint256 balanceAfter = pceToken.balanceOf(address(this));

        assertEq(balanceBefore + amountToSwap / 2, balanceAfter);

        ERC20Upgradeable(COMMUNITY_TOKEN).balanceOf(address(this));

        vm.expectRevert("Target token not found");
        pceToken.swapFromLocalToken(ALICE, amountToSwap);
    }

    function testMint(uint256 amount) public {
        vm.assume(amount < type(uint224).max);
        uint256 balanceBefore = pceToken.balanceOf(address(this));

        pceToken.mint(address(this), amount);
        uint256 balanceAfter = pceToken.balanceOf(address(this));
        assertEq(balanceBefore + amount, balanceAfter);

        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        pceToken.mint(address(this), 1);
    }

    function testSetNativeTokenToPceTokenRate(
        uint160 nativeTokenToPceTokenRate
    ) public {
        pceToken.setNativeTokenToPceTokenRate(nativeTokenToPceTokenRate);
        assertEq(
            nativeTokenToPceTokenRate,
            pceToken.nativeTokenToPceTokenRate()
        );

        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        pceToken.setNativeTokenToPceTokenRate(nativeTokenToPceTokenRate);
    }

    function testSetMetaTransactionGas(uint256 metaTransactionGas) public {
        pceToken.setMetaTransactionGas(metaTransactionGas);
        assertEq(metaTransactionGas, pceToken.metaTransactionGas());

        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        pceToken.setMetaTransactionGas(metaTransactionGas);
    }

    function testSetMetaTransactionPriorityFee(
        uint256 metaTransactionPriorityFee
    ) public {
        pceToken.setMetaTransactionPriorityFee(metaTransactionPriorityFee);
        assertEq(
            metaTransactionPriorityFee,
            pceToken.metaTransactionPriorityFee()
        );

        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        pceToken.setMetaTransactionPriorityFee(metaTransactionPriorityFee);
    }

    function testSetCommunityTokenAddress(
        address communityTokenAddress
    ) public {
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        pceToken.setCommunityTokenAddress(communityTokenAddress);
    }

    function testGetExchangeRate() public {
        testCreateToken();

        (, uint256 exchangeRate, ) = pceToken.localTokens(COMMUNITY_TOKEN);
        assertEq(exchangeRate, pceToken.getExchangeRate(COMMUNITY_TOKEN));

        vm.expectRevert("Target token not found");
        pceToken.getExchangeRate(ALICE);
    }

    function testGetSwapRate() public {
        testCreateToken();
        uint256 factor = PCECommunityToken(COMMUNITY_TOKEN).getCurrentFactor();

        (, uint256 exchangeRate, ) = pceToken.localTokens(COMMUNITY_TOKEN);

        assertEq(
            (((exchangeRate << 96) / (pceToken.INITIAL_FACTOR())) * (factor)) /
                (pceToken.lastModifiedFactor()),
            pceToken.getSwapRate(COMMUNITY_TOKEN)
        );

        vm.expectRevert("Target token not found");
        pceToken.getSwapRate(ALICE);
    }

    function testGetDepositedPCETokens() public {
        testCreateToken();

        uint256 amount = 10000;
        pceToken.swapToLocalToken(COMMUNITY_TOKEN, amount);
        assertEq(
            pceToken.getDepositedPCETokens(COMMUNITY_TOKEN),
            INITIAL_AMOUNT + amount
        );
    }
}
