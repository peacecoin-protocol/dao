// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWPCE} from "./interfaces/IWPCE.sol";
import {IErrors} from "./interfaces/IErrors.sol";

/**
 * @title Staking
 * @dev Contract for staking PCE tokens and earning rewards
 * @notice This contract allows users to stake PCE tokens and receive wPce tokens in return
 * @author Your Name
 */
contract Staking is OwnableUpgradeable, ReentrancyGuardUpgradeable, IErrors {
    // ============ State Variables ============
    IERC20 public pce;
    IWPCE public wPce;
    uint256 public lastUpdateBlock;
    uint256 public rewardPerBlock;
    uint256 public totalPool;

    event RewardPerBlockUpdated(uint256 previousRewardPerBlock, uint256 newRewardPerBlock);
    event UnusedRewardPoolRevoked(address indexed recipient, uint256 amount);
    event StakedPEACECOIN(uint256 amountPeacecoin, uint256 amountxPeacecoin, address indexed user);
    event WithdrawnPEACECOIN(
        uint256 amountPeacecoin,
        uint256 amountxPeacecoin,
        address indexed user
    );

    modifier updateRewardPool() {
        _updateRewardPool();
        _;
    }

    function _updateRewardPool() internal {
        if (totalPool == 0) {
            lastUpdateBlock = block.number;
        } else {
            uint256 rewardToAdd;
            (rewardToAdd, lastUpdateBlock) = _calculateReward();
            totalPool += rewardToAdd;
        }
    }

    /**
     * @notice Initialize the Staking contract
     * @dev Sets up the PCE and wPce contracts and initializes parent contracts
     * @param rewardPerBlockValue Reward amount per block
     * @param pceAddress Address of the PCE token contract
     * @param wPceAddress Address of the wPce token contract
     */
    function initialize(
        uint256 rewardPerBlockValue,
        address pceAddress,
        address wPceAddress
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        if (pceAddress == address(0)) revert InvalidAddress();
        if (wPceAddress == address(0)) revert InvalidAddress();
        if (rewardPerBlockValue == 0) revert InvalidRewardPerBlock();

        lastUpdateBlock = block.number;
        rewardPerBlock = rewardPerBlockValue;
        emit RewardPerBlockUpdated(0, rewardPerBlockValue);

        pce = IERC20(pceAddress);
        wPce = IWPCE(wPceAddress);
    }

    /**
     * @notice Stake PCE tokens
     * @dev Stakes PCE tokens and mints wPce tokens in return
     * @param amountPeacecoin Amount of PCE tokens to stake
     */
    function stake(uint256 amountPeacecoin) external updateRewardPool nonReentrant {
        if (amountPeacecoin == 0) revert ZeroAmount();

        uint256 amountXPeacecoin = convertToWpeacecoin(amountPeacecoin);

        unchecked {
            totalPool += amountPeacecoin;
        }

        uint256 balanceBefore = pce.balanceOf(address(this));
        bool success = pce.transferFrom(_msgSender(), address(this), amountPeacecoin);
        require(success, "ERC20: transferFrom failed");

        uint256 received = pce.balanceOf(address(this)) - balanceBefore;
        require(
            received >= amountPeacecoin && received <= amountPeacecoin,
            "Staking: fee-on-transfer not supported"
        );

        wPce.mint(_msgSender(), amountXPeacecoin);
        emit StakedPEACECOIN(received, amountXPeacecoin, _msgSender());
    }

    /**
     * @notice Withdraw staked PCE tokens
     * @dev Burns wPce tokens and returns PCE tokens
     * @param amountXPeacecoin Amount of wPce tokens to burn
     */
    function withdraw(uint256 amountXPeacecoin) external updateRewardPool nonReentrant {
        if (wPce.balanceOf(_msgSender()) < amountXPeacecoin) revert InsufficientBalance();

        uint256 amountPeacecoin = convertToPeacecoin(amountXPeacecoin);
        if (amountPeacecoin == 0) revert ZeroAmount();

        // Unchecked subtraction for gas optimization (safe due to previous checks)
        unchecked {
            totalPool -= amountPeacecoin;
        }

        wPce.burn(_msgSender(), amountXPeacecoin);

        if (pce.balanceOf(address(this)) < amountPeacecoin) revert InsufficientBalance();
        bool success = pce.transfer(_msgSender(), amountPeacecoin);
        require(success, "ERC20: transfer failed");

        emit WithdrawnPEACECOIN(amountPeacecoin, amountXPeacecoin, _msgSender());
    }

    /**
     * @notice Calculate staking reward for a given amount
     * @dev Returns the PCE equivalent for a given wPce amount
     * @param amount Amount of wPce tokens
     * @return PCE equivalent amount
     */
    function stakingReward(uint256 amount) public view returns (uint256) {
        return convertToPeacecoin(amount);
    }

    /**
     * @notice Get staked PCE amount for an address
     * @dev Returns the PCE equivalent of staked tokens for an address
     * @param account Address to check
     * @return Staked PCE amount
     */
    function getStakedPeacecoin(address account) public view returns (uint256) {
        uint256 balance = wPce.balanceOf(account);
        return balance > 0 ? convertToPeacecoin(balance) : 0;
    }

    /**
     * @notice Set reward per block
     * @dev Only callable by the contract owner
     * @param newRewardPerBlock New reward per block amount
     */
    function setRewardPerBlock(uint256 newRewardPerBlock) external onlyOwner updateRewardPool {
        uint256 previousRewardPerBlock = rewardPerBlock;
        rewardPerBlock = newRewardPerBlock;
        emit RewardPerBlockUpdated(previousRewardPerBlock, newRewardPerBlock);
    }

    /**
     * @notice Revoke unused reward pool tokens
     * @dev Only callable by the contract owner
     */
    function revokeUnusedRewardPool() external onlyOwner updateRewardPool {
        uint256 contractBalance = pce.balanceOf(address(this));

        if (contractBalance <= totalPool) revert NoUnusedTokens();

        uint256 unusedTokens = contractBalance - totalPool;

        emit UnusedRewardPoolRevoked(msg.sender, unusedTokens);
        bool success = pce.transfer(msg.sender, unusedTokens);
        require(success, "ERC20: transfer failed");
    }

    function convertToWpeacecoin(uint256 amount) public view returns (uint256) {
        uint256 tSxPceToken = wPce.totalSupply();
        (uint256 outstandingReward, ) = _calculateReward();
        uint256 stakingPool = totalPool + outstandingReward;

        // Prevent division by zero
        if (stakingPool == 0 || tSxPceToken == 0) {
            return amount; // First staker gets 1:1 ratio
        }

        return (tSxPceToken * amount) / stakingPool;
    }

    function convertToPeacecoin(uint256 amount) public view returns (uint256) {
        uint256 tSxPceToken = wPce.totalSupply();
        (uint256 outstandingReward, ) = _calculateReward();
        uint256 stakingPool = totalPool + outstandingReward;

        // Prevent division by zero
        if (tSxPceToken == 0) {
            return 0;
        }

        return (stakingPool * amount) / tSxPceToken;
    }

    function _calculateReward() internal view returns (uint256, uint256) {
        uint256 blocksPassed = block.number - lastUpdateBlock;
        uint256 updateBlock = block.number;

        // Prevent division by zero
        if (rewardPerBlock == 0) {
            return (0, updateBlock);
        }

        uint256 balance = pce.balanceOf(address(this));
        if (balance <= totalPool) {
            return (0, updateBlock);
        }

        uint256 available = balance - totalPool;
        uint256 blocksWithRewardFunding = available / rewardPerBlock;

        if (blocksPassed > blocksWithRewardFunding) {
            blocksPassed = blocksWithRewardFunding;
            updateBlock = lastUpdateBlock + blocksWithRewardFunding;
        }
        return (rewardPerBlock * blocksPassed, updateBlock);
    }

    function calculateApr() public view returns (uint256) {
        (uint256 outstandingReward, uint256 newestBlockWithRewards) = _calculateReward();

        if (newestBlockWithRewards != block.number) {
            return 0; // Pool is out of rewards
        }
        uint256 stakingPool = totalPool + outstandingReward;
        if (stakingPool == 0) return 0;
        uint256 secondsPerYear = 31536000;
        uint256 secondsPerBlock = 2;
        return ((rewardPerBlock * secondsPerYear * 1e18 * 100) / stakingPool / secondsPerBlock);
    }
}
