// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWPCE.sol";

contract Staking is OwnableUpgradeable {
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

    function initialize(uint256 _rewardPerBlock, address _pce, address _wPCE) external initializer {
        __Ownable_init(msg.sender);

        require(_pce != address(0), "Invalid PCE address");
        require(_wPCE != address(0), "Invalid WPCE address");
        require(_rewardPerBlock > 0, "Reward per block must be greater than 0");

        lastUpdateBlock = block.number;
        rewardPerBlock = _rewardPerBlock;

        pce = IERC20(_pce);
        wPCE = IWPCE(_wPCE);
    }

    function stake(uint256 _amountPEACECOIN) external updateRewardPool {
        require(_amountPEACECOIN > 0, "Staking: cant stake 0 tokens");

        // Transfer tokens first
        pce.transferFrom(_msgSender(), address(this), _amountPEACECOIN);

        // Update totalPool before conversion calculation
        totalPool = totalPool + _amountPEACECOIN;

        uint256 amountxPEACECOIN = _convertToWPEACECOIN(_amountPEACECOIN);
        wPCE.mint(_msgSender(), amountxPEACECOIN);

        emit StakedPEACECOIN(_amountPEACECOIN, amountxPEACECOIN, _msgSender());
    }

    function withdraw(uint256 _amountxPEACECOIN) external updateRewardPool {
        require(
            wPCE.balanceOf(_msgSender()) >= _amountxPEACECOIN,
            "Withdraw: not enough xPEACECOIN tokens to withdraw"
        );

        uint256 amountPEACECOIN = _convertToPEACECOIN(_amountxPEACECOIN);
        require(amountPEACECOIN > 0, "Withdraw: calculated amount is 0");

        wPCE.burn(_msgSender(), _amountxPEACECOIN);

        totalPool = totalPool - amountPEACECOIN;
        require(
            pce.balanceOf(address(this)) >= amountPEACECOIN,
            "Withdraw: failed to transfer PEACECOIN tokens"
        );
        pce.transfer(_msgSender(), amountPEACECOIN);

        emit WithdrawnPEACECOIN(amountPEACECOIN, _amountxPEACECOIN, _msgSender());
    }

    function stakingReward(uint256 _amount) public view returns (uint256) {
        return _convertToPEACECOIN(_amount);
    }

    function getStakedPEACECOIN(address _address) public view returns (uint256) {
        uint256 balance = wPCE.balanceOf(_address);
        return balance > 0 ? _convertToPEACECOIN(balance) : 0;
    }

    function setRewardPerBlock(uint256 _amount) external onlyOwner updateRewardPool {
        rewardPerBlock = _amount;
    }

    function revokeUnusedRewardPool() external onlyOwner updateRewardPool {
        uint256 contractBalance = pce.balanceOf(address(this));

        require(contractBalance > totalPool, "There are no unused tokens to revoke");

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
