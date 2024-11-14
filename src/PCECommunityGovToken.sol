// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PCECommunityGovToken is
    OwnableUpgradeable,
    ERC20VotesUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for ERC20Upgradeable;

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

    event RewardsSet(
        uint256 _rewardPerBlock,
        uint256 _firstBlockWithReward,
        uint256 _lastBlockWithReward
    );
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    event RewardTokensRecovered(uint256 amount);

    function initialize(
        address _stakingToken,
        address _rewardsToken
    ) external initializer {
        stakingToken = ERC20Upgradeable(_stakingToken);
        rewardsToken = ERC20Upgradeable(_rewardsToken);

        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    modifier updateReward(address account) {
        uint256 _rewardPerToken = rewardPerToken();
        rewardPerTokenStored = _rewardPerToken;
        lastUpdateBlock = block.number;
        if (account != address(0)) {
            rewards[account] = earned(account, _rewardPerToken);
            userRewardPerTokenPaid[account] = _rewardPerToken;
        }
        _;
    }

    function setRewards(
        uint256 _rewardPerBlock,
        uint256 _startingBlock,
        uint256 _blocksAmount
    ) external onlyOwner updateReward(address(0)) {
        uint256 unlockedTokens = _getFutureRewardTokens();

        rewardPerBlock = _rewardPerBlock;
        firstBlockWithReward = _startingBlock;
        lastBlockWithReward = _startingBlock + _blocksAmount - 1;

        uint256 lockedTokens = _getFutureRewardTokens();
        uint256 rewardBalance;
        if (address(rewardsToken) != address(0)) {
            rewardBalance = address(stakingToken) != address(rewardsToken)
                ? rewardsToken.balanceOf(address(this))
                : stakingToken.balanceOf(address(this)) - totalStaked;
        } else {
            rewardBalance = address(this).balance;
        }

        rewardTokensLocked = rewardTokensLocked + lockedTokens - unlockedTokens;
        require(
            rewardTokensLocked <= rewardBalance,
            "Not enough tokens for the rewards"
        );

        emit RewardsSet(
            _rewardPerBlock,
            _startingBlock,
            _startingBlock + _blocksAmount - 1
        );
    }

    function recoverNonLockedRewardTokens() external onlyOwner {
        uint256 nonLockedTokens;
        if (address(rewardsToken) != address(0)) {
            nonLockedTokens = address(stakingToken) != address(rewardsToken)
                ? rewardsToken.balanceOf(address(this)) - rewardTokensLocked
                : rewardsToken.balanceOf(address(this)) -
                    rewardTokensLocked -
                    totalStaked;

            rewardsToken.safeTransfer(owner(), nonLockedTokens);
        } else {
            nonLockedTokens = address(this).balance - rewardTokensLocked;

            (bool sent, ) = payable(owner()).call{value: nonLockedTokens}("");
            require(sent, "Failed to send Ether");
        }
        emit RewardTokensRecovered(nonLockedTokens);
    }

    function pause() external onlyOwner {
        super._pause();
    }

    function unpause() external onlyOwner {
        super._unpause();
    }

    function exit() external {
        withdraw(staked[msg.sender]);
        getReward();
    }

    function stake(
        uint256 _amount
    ) external whenNotPaused nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "Stake: can't stake 0");
        require(
            block.number < lastBlockWithReward,
            "Stake: staking  period is over"
        );

        totalStaked = totalStaked + _amount;
        staked[msg.sender] = staked[msg.sender] + _amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(
        uint256 _amount
    ) public nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "Amount should be greater then 0");
        require(staked[msg.sender] >= _amount, "Insufficient staked amount");
        totalStaked = totalStaked - _amount;
        staked[msg.sender] = staked[msg.sender] - _amount;

        stakingToken.safeTransfer(msg.sender, _amount);
        _burn(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardTokensLocked = rewardTokensLocked - reward;

            if (address(rewardsToken) != address(0)) {
                rewardsToken.safeTransfer(msg.sender, reward);
            } else {
                (bool sent, ) = payable(msg.sender).call{value: reward}("");
                require(sent, "Failed to send Ether");
            }

            emit RewardPaid(msg.sender, reward);
        }
    }

    function blocksWithRewardsPassed() public view returns (uint256) {
        uint256 from = lastUpdateBlock > firstBlockWithReward
            ? lastUpdateBlock
            : firstBlockWithReward;
        uint256 to = block.number > lastBlockWithReward
            ? lastBlockWithReward
            : block.number;

        return from > to ? 0 : to - from;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0 || lastUpdateBlock == block.number) {
            return rewardPerTokenStored;
        }

        uint256 accumulatedReward = (blocksWithRewardsPassed() *
            rewardPerBlock *
            1e18) / totalStaked;
        return rewardPerTokenStored + accumulatedReward;
    }

    function earned(
        address _account,
        uint256 _rewardPerToken
    ) public view returns (uint256) {
        uint256 rewardsDifference = _rewardPerToken -
            userRewardPerTokenPaid[_account];
        uint256 newlyAccumulated = (staked[_account] * (rewardsDifference)) /
            1e18;
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

    function _calculateAnnualReward() public view returns (uint256) {
        uint256 SECONDS_PER_YAER = 31536000;
        if (
            totalStaked == 0 ||
            block.number < firstBlockWithReward ||
            block.number >= lastBlockWithReward
        ) return 0;
        return (rewardPerBlock * 1e18 * SECONDS_PER_YAER) / totalStaked / 12;
    }

    receive() external payable {}
}
