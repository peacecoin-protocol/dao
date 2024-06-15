// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {PCEToken} from "../src/PCEToken.sol";
import {PCECommunityToken} from "../src/PCECommunityToken.sol";
import {ExchangeAllowMethod} from "../src/lib/Enum.sol";
import {console} from "forge-std/console.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {Utils} from "../src/lib/Utils.sol";

contract PCETokenTest is Test {
    address alice = address(0xABCD);
    address bob = address(0xDCBA);

    address communityToken = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;
    PCEToken pceToken;
    PCECommunityToken cToken;

    uint256 initialAmount = 50000;

    function setUp() public {
        vm.label(alice, "alice");
        vm.label(bob, "bob");

        cToken = new PCECommunityToken();
        pceToken = new PCEToken();
        pceToken.initialize("PEACE COIN", "PCE", address(cToken));

        assertEq(pceToken.totalSupply(), pceToken.balanceOf(address(this)));
    }

    function test__votingPower() public {
        uint256 _balance = pceToken.balanceOf(address(this));
        uint256 _amount = 10000;
        pceToken.delegate(address(this));
        assertEq(_balance, pceToken.getVotes(address(this)));

        pceToken.transfer(alice, _amount);
        assertEq(_balance - _amount, pceToken.getVotes(address(this)));

        assertEq(pceToken.numCheckpoints(address(this)), 1);

        vm.prank(alice);
        pceToken.delegate(alice);
        assertEq(pceToken.numCheckpoints(alice), 1);
        assertEq(_amount, pceToken.getVotes(alice));
    }

    function test__createToken() public {
        PCEToken.TokenInfo memory tokenInfo;

        tokenInfo = PCEToken.TokenInfo({
            name: "CommunityToken", // Name
            symbol: "CTP", // Symbol
            amountToExchange: initialAmount, // amountToExchange
            dilutionFactor: 2e18, // dilutionFactor
            decreaseIntervalDays: 7, // decreaseIntervalDays
            afterDecreaseBp: 20, // decreaseBp
            maxIncreaseOfTotalSupplyBp: 20, // maxIncreaseOfTotalSupplyBp
            maxIncreaseBp: 2000, // maxIncreaseBp
            maxUsageBp: 3000, // maxUsageBp
            changeBp: 3000, // changeBp
            incomeExchangeAllowMethod: ExchangeAllowMethod.All, // incomeAllowMethod
            outgoExchangeAllowMethod: ExchangeAllowMethod.All, // outgoAllowMethod
            incomeTargetTokens: new address[](0), // incomeTargetTokens
            outgoTargetTokens: new address[](0) // outgoTargetTokens
        });

        pceToken.createToken(tokenInfo);
    }

    function test__moveVotingPower() public {
        test__createToken();

        pceToken.delegate(address(this));
        vm.expectRevert("NOT_COMMUNITY_TOKEN");
        pceToken.moveVotingPower(address(this), bob, 10000);

        vm.prank(communityToken);
        pceToken.moveVotingPower(address(this), bob, 10000);
        assertEq(pceToken.getVotes(bob), 10000);
    }

    function test__swapToLocalToken() public {
        test__createToken();
        uint256 _amountToSwap = 10000;
        skip(1);

        uint256 _balanceBefore = pceToken.balanceOf(address(this));
        pceToken.swapToLocalToken(communityToken, _amountToSwap);
        uint256 _balanceAfter = pceToken.balanceOf(address(this));

        assertEq(_balanceBefore - _balanceAfter, _amountToSwap);

        ERC20Upgradeable(communityToken).balanceOf(address(this));

        vm.expectRevert("Target token not found");
        pceToken.swapToLocalToken(alice, _amountToSwap);
    }

    function test__swapFromLocalToken() public {
        test__createToken();
        uint256 _amountToSwap = 20000;
        skip(1);

        ERC20Upgradeable(communityToken).approve(
            address(pceToken),
            _amountToSwap * pceToken.getCurrentFactor()
        );
        uint256 _balanceBefore = pceToken.balanceOf(address(this));
        pceToken.swapFromLocalToken(communityToken, _amountToSwap);
        uint256 _balanceAfter = pceToken.balanceOf(address(this));

        assertEq(_balanceBefore + _amountToSwap / 2, _balanceAfter);

        ERC20Upgradeable(communityToken).balanceOf(address(this));

        vm.expectRevert("Target token not found");
        pceToken.swapFromLocalToken(alice, _amountToSwap);
    }

    function test__mint(uint256 _amount) public {
        vm.assume(_amount < type(uint224).max);
        uint256 _balanceBefore = pceToken.balanceOf(address(this));

        pceToken.mint(address(this), _amount);
        uint256 _balanceAfter = pceToken.balanceOf(address(this));
        assertEq(_balanceBefore + _amount, _balanceAfter);

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        pceToken.mint(address(this), 1);
    }

    function test__setNativeTokenToPceTokenRate(
        uint160 _nativeTokenToPceTokenRate
    ) public {
        pceToken.setNativeTokenToPceTokenRate(_nativeTokenToPceTokenRate);
        assertEq(
            _nativeTokenToPceTokenRate,
            pceToken.nativeTokenToPceTokenRate()
        );

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        pceToken.setNativeTokenToPceTokenRate(_nativeTokenToPceTokenRate);
    }

    function test__setMetaTransactionGas(uint256 _metaTransactionGas) public {
        pceToken.setMetaTransactionGas(_metaTransactionGas);
        assertEq(_metaTransactionGas, pceToken.metaTransactionGas());

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        pceToken.setMetaTransactionGas(_metaTransactionGas);
    }

    function test__setMetaTransactionPriorityFee(
        uint256 _metaTransactionPriorityFee
    ) public {
        pceToken.setMetaTransactionPriorityFee(_metaTransactionPriorityFee);
        assertEq(
            _metaTransactionPriorityFee,
            pceToken.metaTransactionPriorityFee()
        );

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        pceToken.setMetaTransactionPriorityFee(_metaTransactionPriorityFee);
    }

    function test__setCommunityTokenAddress(
        address communityTokenAddress
    ) public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        pceToken.setCommunityTokenAddress(communityTokenAddress);
    }

    function test__getExchangeRate() public {
        test__createToken();

        (, uint256 exchangeRate, ) = pceToken.localTokens(communityToken);
        assertEq(exchangeRate, pceToken.getExchangeRate(communityToken));

        vm.expectRevert("Target token not found");
        pceToken.getExchangeRate(alice);
    }

    function test__getSwapRate() public {
        test__createToken();
        uint256 factor = PCECommunityToken(communityToken).getCurrentFactor();

        (, uint256 exchangeRate, ) = pceToken.localTokens(communityToken);

        assertEq(
            (((exchangeRate << 96) / (pceToken.INITIAL_FACTOR())) * (factor)) /
                (pceToken.lastModifiedFactor()),
            pceToken.getSwapRate(communityToken)
        );

        vm.expectRevert("Target token not found");
        pceToken.getExchangeRate(alice);
    }

    function test__getDepositedPCETokens() public {
        test__createToken();

        uint256 _amount = 10000;
        pceToken.swapToLocalToken(communityToken, _amount);
        assertEq(
            pceToken.getDepositedPCETokens(communityToken),
            initialAmount + _amount
        );
    }
}
