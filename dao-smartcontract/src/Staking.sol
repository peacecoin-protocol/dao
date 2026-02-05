// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
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

    event UnusedRewardPoolRevoked(address recipient, uint256 amount);
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
     * @param _rewardPerBlock Reward amount per block
     * @param _pce Address of the PCE token contract
     * @param _wPce Address of the wPce token contract
     */
    function initialize(uint256 _rewardPerBlock, address _pce, address _wPce) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        if (_pce == address(0)) revert InvalidAddress();
        if (_wPce == address(0)) revert InvalidAddress();
        if (_rewardPerBlock == 0) revert InvalidRewardPerBlock();

        lastUpdateBlock = block.number;
        rewardPerBlock = _rewardPerBlock;

        pce = IERC20(_pce);
        wPce = IWPCE(_wPce);
    }

    /**
     * @notice Stake PCE tokens
     * @dev Stakes PCE tokens and mints wPce tokens in return
     * @param _amountPeacecoin Amount of PCE tokens to stake
     */
    function stake(uint256 _amountPeacecoin) external updateRewardPool nonReentrant {
        if (_amountPeacecoin == 0) revert ZeroAmount();

        // Transfer tokens first
        bool success = pce.transferFrom(_msgSender(), address(this), _amountPeacecoin);
        require(success, "ERC20: transferFrom failed");

        uint256 amountxPeacecoin = _convertToWpeacecoin(_amountPeacecoin);

        // Unchecked addition for gas optimization (safe due to previous checks)
        unchecked {
            totalPool += _amountPeacecoin;
        }

        wPce.mint(_msgSender(), amountxPeacecoin);

        emit StakedPEACECOIN(_amountPeacecoin, amountxPeacecoin, _msgSender());
    }

    /**
     * @notice Withdraw staked PCE tokens
     * @dev Burns wPce tokens and returns PCE tokens
     * @param _amountxPeacecoin Amount of wPce tokens to burn
     */
    function withdraw(uint256 _amountxPeacecoin) external updateRewardPool nonReentrant {
        if (wPce.balanceOf(_msgSender()) < _amountxPeacecoin) revert InsufficientBalance();

        uint256 amountPeacecoin = _convertToPeacecoin(_amountxPeacecoin);
        if (amountPeacecoin == 0) revert ZeroAmount();

        wPce.burn(_msgSender(), _amountxPeacecoin);

        // Unchecked subtraction for gas optimization (safe due to previous checks)
        unchecked {
            totalPool -= amountPeacecoin;
        }

        if (pce.balanceOf(address(this)) < amountPeacecoin) revert InsufficientBalance();
        bool success = pce.transfer(_msgSender(), amountPeacecoin);
        require(success, "ERC20: transfer failed");

        emit WithdrawnPEACECOIN(amountPeacecoin, _amountxPeacecoin, _msgSender());
    }

    /**
     * @notice Calculate staking reward for a given amount
     * @dev Returns the PCE equivalent for a given wPce amount
     * @param _amount Amount of wPce tokens
     * @return PCE equivalent amount
     */
    function stakingReward(uint256 _amount) public view returns (uint256) {
        return _convertToPeacecoin(_amount);
    }

    /**
     * @notice Get staked PCE amount for an address
     * @dev Returns the PCE equivalent of staked tokens for an address
     * @param _address Address to check
     * @return Staked PCE amount
     */
    function getStakedPeacecoin(address _address) public view returns (uint256) {
        uint256 balance = wPce.balanceOf(_address);
        return balance > 0 ? _convertToPeacecoin(balance) : 0;
    }

    /**
     * @notice Set reward per block
     * @dev Only callable by the contract owner
     * @param _amount New reward per block amount
     */
    function setRewardPerBlock(uint256 _amount) external onlyOwner updateRewardPool {
        rewardPerBlock = _amount;
    }

    /**
     * @notice Revoke unused reward pool tokens
     * @dev Only callable by the contract owner
     */
    function revokeUnusedRewardPool() external onlyOwner updateRewardPool {
        uint256 contractBalance = pce.balanceOf(address(this));

        if (contractBalance <= totalPool) revert NoUnusedTokens();

        uint256 unusedTokens = contractBalance - totalPool;

        bool success = pce.transfer(msg.sender, unusedTokens);
        require(success, "ERC20: transfer failed");
        emit UnusedRewardPoolRevoked(msg.sender, unusedTokens);
    }

    function _convertToWpeacecoin(uint256 _amount) public view returns (uint256) {
        uint256 tSxPceToken = wPce.totalSupply();
        (uint256 outstandingReward, ) = _calculateReward();
        uint256 stakingPool = totalPool + outstandingReward;

        // Prevent division by zero
        if (stakingPool == 0 || tSxPceToken == 0) {
            return _amount; // First staker gets 1:1 ratio
        }

        return (tSxPceToken * _amount) / stakingPool;
    }

    function _convertToPeacecoin(uint256 _amount) public view returns (uint256) {
        uint256 tSxPceToken = wPce.totalSupply();
        (uint256 outstandingReward, ) = _calculateReward();
        uint256 stakingPool = totalPool + outstandingReward;

        // Prevent division by zero
        if (tSxPceToken == 0) {
            return 0;
        }

        return (stakingPool * _amount) / tSxPceToken;
    }

    function _calculateReward() internal view returns (uint256, uint256) {
        uint256 blocksPassed = block.number - lastUpdateBlock;
        uint256 updateBlock = block.number;

        // Prevent division by zero
        if (rewardPerBlock == 0) {
            return (0, updateBlock);
        }

        uint256 blocksWithRewardFunding = (pce.balanceOf(address(this)) - totalPool) /
            rewardPerBlock;
        if (blocksPassed > blocksWithRewardFunding) {
            blocksPassed = blocksWithRewardFunding;
            updateBlock = lastUpdateBlock + blocksWithRewardFunding;
        }
        return (rewardPerBlock * blocksPassed, updateBlock);
    }

    function _calculateApr() public view returns (uint256) {
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
