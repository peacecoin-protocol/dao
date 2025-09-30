// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWPCE.sol";
import "./interfaces/IErrors.sol";

/**
 * @title Staking
 * @dev Contract for staking PCE tokens and earning rewards
 * @notice This contract allows users to stake PCE tokens and receive wPCE tokens in return
 * @author Your Name
 */
contract Staking is OwnableUpgradeable, ReentrancyGuardUpgradeable, IErrors {
    // ============ State Variables ============
    IERC20 public pce;
    IWPCE public wPCE;
    uint256 public lastUpdateBlock;
    uint256 public rewardPerBlock;
    uint256 public totalPool;

    event UnusedRewardPoolRevoked(address recipient, uint256 amount);
    event StakedPEACECOIN(uint256 amountPEACECOIN, uint256 amountxPEACECOIN, address indexed user);
    event WithdrawnPEACECOIN(
        uint256 amountPEACECOIN,
        uint256 amountxPEACECOIN,
        address indexed user
    );

    modifier updateRewardPool() {
        if (totalPool == 0) {
            lastUpdateBlock = block.number;
        } else {
            uint256 rewardToAdd;
            (rewardToAdd, lastUpdateBlock) = _calculateReward();
            totalPool += rewardToAdd;
        }
        _;
    }

    /**
     * @notice Initialize the Staking contract
     * @dev Sets up the PCE and wPCE contracts and initializes parent contracts
     * @param _rewardPerBlock Reward amount per block
     * @param _pce Address of the PCE token contract
     * @param _wPCE Address of the wPCE token contract
     */
    function initialize(uint256 _rewardPerBlock, address _pce, address _wPCE) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        if (_pce == address(0)) revert InvalidAddress();
        if (_wPCE == address(0)) revert InvalidAddress();
        if (_rewardPerBlock == 0) revert InvalidRewardPerBlock();

        lastUpdateBlock = block.number;
        rewardPerBlock = _rewardPerBlock;

        pce = IERC20(_pce);
        wPCE = IWPCE(_wPCE);
    }

    /**
     * @notice Stake PCE tokens
     * @dev Stakes PCE tokens and mints wPCE tokens in return
     * @param _amountPEACECOIN Amount of PCE tokens to stake
     */
    function stake(uint256 _amountPEACECOIN) external updateRewardPool nonReentrant {
        if (_amountPEACECOIN == 0) revert ZeroAmount();

        // Transfer tokens first
        pce.transferFrom(_msgSender(), address(this), _amountPEACECOIN);

        uint256 amountxPEACECOIN = _convertToWPEACECOIN(_amountPEACECOIN);

        // Unchecked addition for gas optimization (safe due to previous checks)
        unchecked {
            totalPool += _amountPEACECOIN;
        }

        wPCE.mint(_msgSender(), amountxPEACECOIN);

        emit StakedPEACECOIN(_amountPEACECOIN, amountxPEACECOIN, _msgSender());
    }

    /**
     * @notice Withdraw staked PCE tokens
     * @dev Burns wPCE tokens and returns PCE tokens
     * @param _amountxPEACECOIN Amount of wPCE tokens to burn
     */
    function withdraw(uint256 _amountxPEACECOIN) external updateRewardPool nonReentrant {
        if (wPCE.balanceOf(_msgSender()) < _amountxPEACECOIN) revert InsufficientBalance();

        uint256 amountPEACECOIN = _convertToPEACECOIN(_amountxPEACECOIN);
        if (amountPEACECOIN == 0) revert ZeroAmount();

        wPCE.burn(_msgSender(), _amountxPEACECOIN);

        // Unchecked subtraction for gas optimization (safe due to previous checks)
        unchecked {
            totalPool -= amountPEACECOIN;
        }

        if (pce.balanceOf(address(this)) < amountPEACECOIN) revert InsufficientBalance();
        pce.transfer(_msgSender(), amountPEACECOIN);

        emit WithdrawnPEACECOIN(amountPEACECOIN, _amountxPEACECOIN, _msgSender());
    }

    /**
     * @notice Calculate staking reward for a given amount
     * @dev Returns the PCE equivalent for a given wPCE amount
     * @param _amount Amount of wPCE tokens
     * @return PCE equivalent amount
     */
    function stakingReward(uint256 _amount) public view returns (uint256) {
        return _convertToPEACECOIN(_amount);
    }

    /**
     * @notice Get staked PCE amount for an address
     * @dev Returns the PCE equivalent of staked tokens for an address
     * @param _address Address to check
     * @return Staked PCE amount
     */
    function getStakedPEACECOIN(address _address) public view returns (uint256) {
        uint256 balance = wPCE.balanceOf(_address);
        return balance > 0 ? _convertToPEACECOIN(balance) : 0;
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

        pce.transfer(msg.sender, unusedTokens);
        emit UnusedRewardPoolRevoked(msg.sender, unusedTokens);
    }

    function _convertToWPEACECOIN(uint256 _amount) public view returns (uint256) {
        uint256 TSxPCEToken = wPCE.totalSupply();
        (uint256 outstandingReward, ) = _calculateReward();
        uint256 stakingPool = totalPool + outstandingReward;

        // Prevent division by zero
        if (stakingPool == 0 || TSxPCEToken == 0) {
            return _amount; // First staker gets 1:1 ratio
        }

        return (TSxPCEToken * _amount) / stakingPool;
    }

    function _convertToPEACECOIN(uint256 _amount) public view returns (uint256) {
        uint256 TSxPCEToken = wPCE.totalSupply();
        (uint256 outstandingReward, ) = _calculateReward();
        uint256 stakingPool = totalPool + outstandingReward;

        // Prevent division by zero
        if (TSxPCEToken == 0) {
            return 0;
        }

        return (stakingPool * _amount) / TSxPCEToken;
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

    function _calculateAPR() public view returns (uint256) {
        (uint256 outstandingReward, uint256 newestBlockWithRewards) = _calculateReward();

        if (newestBlockWithRewards != block.number) {
            return 0; // Pool is out of rewards
        }
        uint256 stakingPool = totalPool + outstandingReward;
        if (stakingPool == 0) return 0;
        uint256 SECONDS_PER_YEAR = 31536000;
        uint256 SECONDS_PER_BLOCK = 2;
        return
            ((((rewardPerBlock * 1e18) / stakingPool) * SECONDS_PER_YEAR) / SECONDS_PER_BLOCK) *
            100;
    }
}
