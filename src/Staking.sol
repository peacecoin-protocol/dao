// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./interfaces/IStaking.sol";

contract Staking is IStaking, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    ERC20Upgradeable public stakingToken;
    ERC20Upgradeable public rewardsToken;

    uint256 public rewardPerBlock;
    uint256 public firstBlockWithReward;
    uint256 public lastBlockWithReward;
    uint256 public lastUpdateBlock;
    uint256 public rewardPerTokenStored;
    uint256 public rewardTokensLocked;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 public totalStaked;
    mapping(address => uint256) public staked;

    function initialize(address _stakingToken, address _rewardsToken, address _owner) external initializer {
        stakingToken = ERC20Upgradeable(_stakingToken);
        rewardsToken = ERC20Upgradeable(_rewardsToken);

        __Ownable_init(msg.sender);
        transferOwnership(_owner);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function setRewards(uint256 _rewardPerBlock, uint256 _startingBlock, uint256 _blocksAmount)
        external
        override
        onlyOwner
        updateReward(address(0))
    {
        uint256 unlockedTokens = _getFutureRewardTokens();

        rewardPerBlock = _rewardPerBlock;
        firstBlockWithReward = _startingBlock;
        lastBlockWithReward = firstBlockWithReward + _blocksAmount - 1;

        uint256 lockedTokens = _getFutureRewardTokens();
        uint256 rewardBalance = address(stakingToken) != address(rewardsToken)
            ? rewardsToken.balanceOf(address(this))
            : stakingToken.balanceOf(address(this)) + totalStaked;

        rewardTokensLocked = rewardTokensLocked - unlockedTokens + lockedTokens;
        require(rewardTokensLocked <= rewardBalance, "Not enough tokens for the rewards");

        emit RewardsSet(_rewardPerBlock, firstBlockWithReward, lastBlockWithReward);
    }

    function recoverNonLockedRewardTokens() external override onlyOwner {
        uint256 nonLockedTokens = address(stakingToken) != address(rewardsToken)
            ? rewardsToken.balanceOf(address(this)) - rewardTokensLocked
            : rewardsToken.balanceOf(address(this)) - rewardTokensLocked - totalStaked;

        rewardsToken.transfer(owner(), nonLockedTokens);
        emit RewardTokensRecovered(nonLockedTokens);
    }

    function pause() external override onlyOwner {
        super._pause();
    }

    function unpause() external override onlyOwner {
        super._unpause();
    }

    function exit() external override {
        withdraw(staked[msg.sender]);
        getReward();
    }

    function stake(uint256 _amount) external override whenNotPaused nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "Stake: can't stake 0");
        require(block.number < lastBlockWithReward, "Stake: staking  period is over");

        totalStaked = totalStaked + _amount;
        staked[msg.sender] = staked[msg.sender] + _amount;

        stakingToken.transferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public override nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "Amount should be greater then 0");
        require(staked[msg.sender] >= _amount, "Insufficient staked amount");
        totalStaked = totalStaked - _amount;
        staked[msg.sender] = staked[msg.sender] - _amount;
        stakingToken.transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function getReward() public override nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
            rewardTokensLocked = rewardTokensLocked - reward;

            emit RewardPaid(msg.sender, reward);
        }
    }

    function blocksWithRewardsPassed() public view override returns (uint256) {
        uint256 from = lastUpdateBlock > firstBlockWithReward ? lastBlockWithReward : firstBlockWithReward;
        uint256 to = block.number > lastBlockWithReward ? lastBlockWithReward : block.number;

        return from > to ? 0 : to - from;
    }

    function rewardPerToken() public view override returns (uint256) {
        if (totalStaked == 0 || lastUpdateBlock == block.number) {
            return rewardPerTokenStored;
        }

        uint256 accumulatedReward = (blocksWithRewardsPassed() * rewardPerBlock * (1e18)) / totalStaked;

        return rewardPerTokenStored + accumulatedReward;
    }

    function earned(address _account) public view override returns (uint256) {
        uint256 rewardsDifference = rewardPerToken() - userRewardPerTokenPaid[_account];
        uint256 newlyAccumulated = (staked[_account] * rewardsDifference) / (1e18);
        return rewards[_account] + newlyAccumulated;
    }

    function _getFutureRewardTokens() internal view returns (uint256) {
        return _calculateBlocksLeft() * rewardPerBlock;
    }

    function _calculateBlocksLeft() internal view returns (uint256) {
        uint256 _from = firstBlockWithReward;
        uint256 _to = lastBlockWithReward;
        if (block.number >= _to) return 0;
        if (block.number < _from) return _to - _from + 1;
        return _to - block.number;
    }
}
