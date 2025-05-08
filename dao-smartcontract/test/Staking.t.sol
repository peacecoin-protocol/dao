// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Staking} from "src/Staking.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {IStaking} from "src/interfaces/IStaking.sol";

contract TesteableStaking is Staking {
    function _getFutureRewardTokensPublic() external view returns (uint256) {
        return super._getFutureRewardTokens();
    }

    function _calculateBlocksLeftPublic() external view returns (uint256) {
        return super._calculateBlocksLeft();
    }
}

contract StakingTest is Test {
    Staking public staking;
    MockERC20 public stakingToken;
    MockERC20 public rewardsToken;

    address public OWNER = makeAddr("OWNER");
    address public USER_1 = makeAddr("USER_1");
    address public USER_2 = makeAddr("USER_2");
    uint256 public constant INITIAL_BALANCE = 1000e18;
    uint256 public constant STAKING_AMOUNT = INITIAL_BALANCE / 4;
    uint256 public constant REWARD_PER_BLOCK = 1e8;
    uint256 public constant STARTING_BLOCK = 10;
    uint256 public constant BLOCKS_AMOUNT = 100;
    uint256 public constant LAST_BLOCK_WITH_REWARD = STARTING_BLOCK + BLOCKS_AMOUNT - 1;
    uint256 public constant DECIMALS_PRECISION = 1e18;
    uint256 public constant REWARDS_BLOCK = STARTING_BLOCK + 3;

    event RewardsSet(uint256 rewardPerBlock, uint256 firstBlockWithReward, uint256 lastBlockWithReward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRestaked(address indexed user, uint256 reward, uint256 stakingTokens);
    event RewardTokensRecovered(uint256 amount);

    function setUp() public {
        vm.label(OWNER, "OWNER");
        vm.label(USER_1, "USER_1");
        vm.label(USER_2, "USER_2");

        stakingToken = new MockERC20();
        rewardsToken = new MockERC20();

        staking = new Staking();
        staking.initialize(address(stakingToken), address(rewardsToken), OWNER);

        rewardsToken.mint(address(staking), REWARD_PER_BLOCK * BLOCKS_AMOUNT);

        vm.prank(OWNER);
        staking.setRewards(REWARD_PER_BLOCK, STARTING_BLOCK, BLOCKS_AMOUNT);

        stakingToken.mint(USER_1, INITIAL_BALANCE);
        stakingToken.mint(USER_2, INITIAL_BALANCE);

        vm.prank(USER_1);
        stakingToken.approve(address(staking), INITIAL_BALANCE);

        vm.prank(USER_2);
        stakingToken.approve(address(staking), INITIAL_BALANCE);
    }

    // initialize
    function test_StakingInitialization() public view {
        assertEq(staking.owner(), OWNER);
        assertEq(address(staking.stakingToken()), address(stakingToken));
        assertEq(address(staking.rewardsToken()), address(rewardsToken));
    }

    // setRewards
    function test_SetRewards_UpdatesRewards() public view {
        vm.assertEq(staking.rewardPerTokenStored(), 0);
        vm.assertEq(staking.lastUpdateBlock(), block.number);
    }

    function test_SetRewards() public {
        staking = new Staking();
        staking.initialize(address(stakingToken), address(rewardsToken), OWNER);
        rewardsToken.mint(address(staking), REWARD_PER_BLOCK * BLOCKS_AMOUNT);

        vm.prank(OWNER);
        vm.expectEmit(false, false, false, true);
        emit RewardsSet(REWARD_PER_BLOCK, STARTING_BLOCK, STARTING_BLOCK + BLOCKS_AMOUNT - 1);
        staking.setRewards(REWARD_PER_BLOCK, STARTING_BLOCK, BLOCKS_AMOUNT);

        assertEq(staking.rewardPerBlock(), REWARD_PER_BLOCK);
        assertEq(staking.firstBlockWithReward(), STARTING_BLOCK);
        assertEq(staking.lastBlockWithReward(), STARTING_BLOCK + BLOCKS_AMOUNT - 1);
        assertEq(staking.rewardTokensLocked(), REWARD_PER_BLOCK * BLOCKS_AMOUNT);
    }

    function test_SetRewards_RevertsWhen_NotOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this)));
        staking.setRewards(REWARD_PER_BLOCK, STARTING_BLOCK, BLOCKS_AMOUNT);
    }

    function test_SetRewards_FailsWhenNoEnoughRewards() public {
        staking = new Staking();
        staking.initialize(address(stakingToken), address(rewardsToken), OWNER);

        vm.prank(OWNER);
        vm.expectRevert("Not enough tokens for the rewards");
        staking.setRewards(REWARD_PER_BLOCK, STARTING_BLOCK, BLOCKS_AMOUNT);
    }

    function test_SetRewards_FailsWhenNoEnoughStakedRewards() public {
        staking = new Staking();
        staking.initialize(address(stakingToken), address(stakingToken), OWNER);

        vm.prank(OWNER);
        vm.expectRevert("Not enough tokens for the rewards");
        staking.setRewards(REWARD_PER_BLOCK, STARTING_BLOCK, BLOCKS_AMOUNT);
    }

    // stake
    function test_Stake_SingleUser() public {
        vm.prank(USER_1);
        vm.expectEmit(true, false, false, true);
        emit Staked(USER_1, STAKING_AMOUNT);
        staking.stake(STAKING_AMOUNT);

        assertEq(staking.staked(USER_1), STAKING_AMOUNT);
        assertEq(staking.totalStaked(), STAKING_AMOUNT);
        assertEq(stakingToken.balanceOf(address(staking)), STAKING_AMOUNT);
        assertEq(stakingToken.balanceOf(USER_1), INITIAL_BALANCE - STAKING_AMOUNT);
    }

    function test_Stake_TwoUsers() public {
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        vm.prank(USER_2);
        staking.stake(STAKING_AMOUNT);

        assertEq(staking.staked(USER_1), STAKING_AMOUNT);
        assertEq(staking.staked(USER_2), STAKING_AMOUNT);
        assertEq(staking.totalStaked(), STAKING_AMOUNT * 2);
        assertEq(stakingToken.balanceOf(address(staking)), STAKING_AMOUNT * 2);
        assertEq(stakingToken.balanceOf(USER_1), INITIAL_BALANCE - STAKING_AMOUNT);
        assertEq(stakingToken.balanceOf(USER_2), INITIAL_BALANCE - STAKING_AMOUNT);
    }

    function test_Stake_RevertsWhen_Paused() public {
        vm.prank(OWNER);
        staking.pause();

        vm.prank(USER_1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        staking.stake(STAKING_AMOUNT);
    }

    function test_Stake_UpdateReward() public {
        vm.roll(REWARDS_BLOCK);
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        vm.roll(REWARDS_BLOCK + 1);
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        vm.assertEq(staking.lastUpdateBlock(), REWARDS_BLOCK + 1);
        vm.assertEq(staking.rewards(USER_1), staking.earned(USER_1));
        vm.assertEq(staking.userRewardPerTokenPaid(USER_1), staking.rewardPerTokenStored());
    }

    function test_Stake_RevertsWhen_ZeroAmount() public {
        vm.prank(USER_1);
        vm.expectRevert("Stake: can't stake 0");
        staking.stake(0);
    }

    function test_Stake_RevertsWhen_StakingPeriodIsOver() public {
        vm.roll(LAST_BLOCK_WITH_REWARD + 1);
        vm.prank(USER_1);
        vm.expectRevert("Stake: staking  period is over");
        staking.stake(STAKING_AMOUNT);
    }

    // blocksWithRewardsPassed
    function test_BlocksWithRewardsPassed_BeforeStakingStart() public view {
        // Current block is before the first block with rewards
        assertEq(staking.blocksWithRewardsPassed(), 0);
    }

    function test_BlocksWithRewardsPassed_StakingFinished() public {
        // Current block and lastUpdateBlock are after the last block with rewards
        vm.roll(LAST_BLOCK_WITH_REWARD + 1);
        vm.prank(USER_1);
        staking.getReward(); // This will update the lastUpdateBlock to the current block

        assertEq(staking.blocksWithRewardsPassed(), 0); // No rewards left
    }

    function test_BlocksWithRewardsPassed_DuringRewardPeriod() public {
        // Current block and lastUpdateBlock are before the last block with rewards
        uint256 passed = 3;
        vm.roll(STARTING_BLOCK + passed);
        vm.prank(USER_1);

        assertEq(staking.blocksWithRewardsPassed(), passed);
    }

    function test_BlocksWithRewardsPassed_AfterStaking_LastUpdateDuringStaking() public {
        // 3 blocks passed since last update, but current block is after the last block with rewards
        uint256 passedSinceLastUpdate = 3;
        vm.roll(STARTING_BLOCK + passedSinceLastUpdate);
        vm.prank(USER_1);
        staking.getReward();

        vm.roll(LAST_BLOCK_WITH_REWARD + 1);

        assertEq(staking.blocksWithRewardsPassed(), LAST_BLOCK_WITH_REWARD - (STARTING_BLOCK + passedSinceLastUpdate));
    }

    function test_BlocksWithRewardsPassed_DuringRewards_LastUpdateBeforeStakingStarts() public {
        // lastUpdateBlock is before the first block with rewards
        // Current block is after the first block with rewards
        uint256 passed = 3;
        vm.roll(REWARDS_BLOCK);

        assertEq(staking.blocksWithRewardsPassed(), passed);
    }

    // rewardsPerToken
    function test_RewardsPerToken() public {
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        uint256 blockedPassed = 3;
        vm.roll(STARTING_BLOCK + blockedPassed);

        uint256 expectedRewardPerToken = (blockedPassed * REWARD_PER_BLOCK * DECIMALS_PRECISION) / STAKING_AMOUNT;
        assertEq(staking.rewardPerToken(), expectedRewardPerToken);

        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        // Multiple calls to rewardPerToken in the same block returns rewardPerTokenStored
        assertEq(staking.rewardPerToken(), expectedRewardPerToken);
    }

    function test_RewardsPerToken_WhenNoStaked() public {
        vm.roll(REWARDS_BLOCK);
        assertEq(staking.rewardPerToken(), 0);
    }

    // earned
    function test_Earned() public {
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        vm.roll(REWARDS_BLOCK);

        assertEq(staking.earned(USER_1), (STAKING_AMOUNT * staking.rewardPerToken()) / DECIMALS_PRECISION);
    }

    function test_Earned_WhenNoStaked() public {
        vm.roll(REWARDS_BLOCK);
        assertEq(staking.earned(USER_1), 0);
    }

    // getReward
    function test_GetReward() public {
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        vm.roll(REWARDS_BLOCK);

        uint256 expectedReward = staking.earned(USER_1);
        uint256 stakingRewardsInitialBalance = rewardsToken.balanceOf(address(staking));

        vm.prank(USER_1);
        vm.expectEmit(true, false, false, true);
        emit RewardPaid(USER_1, expectedReward);
        staking.getReward();

        assertEq(staking.rewards(USER_1), 0);
        assertEq(rewardsToken.balanceOf(USER_1), expectedReward);
        assertEq(staking.rewardTokensLocked(), REWARD_PER_BLOCK * BLOCKS_AMOUNT - expectedReward);
        assertEq(rewardsToken.balanceOf(address(staking)), stakingRewardsInitialBalance - expectedReward);
    }

    function test_GetReward_TwoUsers() public {
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        vm.roll(REWARDS_BLOCK);

        vm.prank(USER_2);
        staking.stake(STAKING_AMOUNT);

        vm.roll(REWARDS_BLOCK + 1);

        uint256 expectedRewardUser1 = staking.earned(USER_1);
        uint256 expectedRewardUser2 = staking.earned(USER_2);
        uint256 stakingRewardsInitialBalance = rewardsToken.balanceOf(address(staking));

        vm.prank(USER_1);
        staking.getReward();

        vm.prank(USER_2);
        staking.getReward();

        assertEq(staking.rewards(USER_1), 0);
        assertEq(staking.rewards(USER_2), 0);
        assertEq(rewardsToken.balanceOf(USER_1), expectedRewardUser1);
        assertEq(rewardsToken.balanceOf(USER_2), expectedRewardUser2);
        assertEq(
            staking.rewardTokensLocked(), REWARD_PER_BLOCK * BLOCKS_AMOUNT - expectedRewardUser1 - expectedRewardUser2
        );
        assertEq(
            rewardsToken.balanceOf(address(staking)),
            stakingRewardsInitialBalance - expectedRewardUser1 - expectedRewardUser2
        );

        vm.prank(USER_1);
        staking.withdraw(STAKING_AMOUNT);
        assertEq(staking.staked(USER_1), 0);

        vm.prank(USER_2);
        staking.withdraw(STAKING_AMOUNT);
        assertEq(staking.staked(USER_2), 0);
    }

    // withdraw
    function test_Withdraw_Full() public {
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        uint256 initialBalance = stakingToken.balanceOf(USER_1);
        vm.prank(USER_1);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(USER_1, STAKING_AMOUNT);
        staking.withdraw(STAKING_AMOUNT);

        assertEq(staking.staked(USER_1), 0);
        assertEq(staking.totalStaked(), 0);
        assertEq(stakingToken.balanceOf(USER_1), initialBalance + STAKING_AMOUNT);
        assertEq(stakingToken.balanceOf(address(staking)), 0);
    }

    function test_Withdraw_TwoUsers() public {
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        vm.prank(USER_2);
        staking.stake(STAKING_AMOUNT);

        uint256 user1InitialBalance = stakingToken.balanceOf(USER_1);
        vm.prank(USER_1);
        staking.withdraw(STAKING_AMOUNT);
        assertEq(staking.staked(USER_1), 0);
        assertEq(staking.totalStaked(), STAKING_AMOUNT);
        assertEq(stakingToken.balanceOf(USER_1), user1InitialBalance + STAKING_AMOUNT);
        assertEq(stakingToken.balanceOf(address(staking)), STAKING_AMOUNT);

        uint256 user2InitialBalance = stakingToken.balanceOf(USER_2);
        vm.prank(USER_2);
        staking.withdraw(STAKING_AMOUNT);
        assertEq(staking.staked(USER_2), 0);
        assertEq(staking.totalStaked(), 0);
        assertEq(stakingToken.balanceOf(USER_2), user2InitialBalance + STAKING_AMOUNT);
        assertEq(stakingToken.balanceOf(address(staking)), 0);
    }

    function test_Withdraw_TwoUsers_Partial() public {
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        vm.prank(USER_2);
        staking.stake(STAKING_AMOUNT);

        uint256 user1InitialBalance = stakingToken.balanceOf(USER_1);
        vm.prank(USER_1);
        staking.withdraw(STAKING_AMOUNT / 2);
        assertEq(staking.staked(USER_1), STAKING_AMOUNT / 2);
        assertEq(staking.totalStaked(), STAKING_AMOUNT + STAKING_AMOUNT / 2);
        assertEq(stakingToken.balanceOf(USER_1), user1InitialBalance + STAKING_AMOUNT / 2);
        assertEq(stakingToken.balanceOf(address(staking)), STAKING_AMOUNT + STAKING_AMOUNT / 2);

        uint256 user2InitialBalance = stakingToken.balanceOf(USER_2);
        vm.prank(USER_2);
        staking.withdraw(STAKING_AMOUNT);
        assertEq(staking.staked(USER_2), 0);
        assertEq(staking.totalStaked(), STAKING_AMOUNT / 2);
        assertEq(stakingToken.balanceOf(USER_2), user2InitialBalance + STAKING_AMOUNT);
        assertEq(stakingToken.balanceOf(address(staking)), STAKING_AMOUNT / 2);
    }

    function test_Withdraw_RevertsWhen_ZeroAmount() public {
        vm.prank(USER_1);
        vm.expectRevert("Amount should be greater then 0");
        staking.withdraw(0);
    }

    function test_Withdraw_RevertsWhen_InsufficientStakedAmount() public {
        vm.prank(USER_1);
        vm.expectRevert("Insufficient staked amount");
        staking.withdraw(STAKING_AMOUNT);
    }

    // exit
    function test_Exit() public {
        vm.prank(USER_1);
        staking.stake(STAKING_AMOUNT);

        vm.roll(REWARDS_BLOCK);

        uint256 expectedReward = staking.earned(USER_1);

        uint256 initialBalance = stakingToken.balanceOf(USER_1);
        uint256 initialRewardsBalance = rewardsToken.balanceOf(address(staking));
        vm.prank(USER_1);
        staking.exit();

        assertEq(stakingToken.balanceOf(USER_1), initialBalance + STAKING_AMOUNT);
        assertEq(stakingToken.balanceOf(address(staking)), 0);
        assertEq(rewardsToken.balanceOf(USER_1), expectedReward);
        assertEq(rewardsToken.balanceOf(address(staking)), initialRewardsBalance - expectedReward);
    }

    // recoverNonLockedRewardTokens
    function test_RecoverNonLockedRewardTokens() public {
        uint256 lockedTokens = REWARD_PER_BLOCK * BLOCKS_AMOUNT;
        uint256 nonLockedTokens = rewardsToken.balanceOf(address(staking)) - lockedTokens;
        vm.prank(OWNER);
        vm.expectEmit(false, false, false, true);
        emit RewardTokensRecovered(nonLockedTokens);
        staking.recoverNonLockedRewardTokens();

        assertEq(rewardsToken.balanceOf(OWNER), nonLockedTokens);
    }

    function test_RecoverNonLockedRewardTokens_StakingMatchesRewardsToken() public {
        staking = new Staking();
        staking.initialize(address(stakingToken), address(stakingToken), OWNER);
        stakingToken.mint(address(staking), INITIAL_BALANCE);

        vm.prank(OWNER);
        staking.setRewards(REWARD_PER_BLOCK, STARTING_BLOCK, BLOCKS_AMOUNT);

        vm.startPrank(USER_1);
        stakingToken.approve(address(staking), INITIAL_BALANCE);
        staking.stake(STAKING_AMOUNT);
        vm.stopPrank();

        uint256 lockedTokens = REWARD_PER_BLOCK * BLOCKS_AMOUNT;
        uint256 nonLockedTokens = stakingToken.balanceOf(address(staking)) - lockedTokens - STAKING_AMOUNT;
        vm.prank(OWNER);
        vm.expectEmit(false, false, false, true);
        emit RewardTokensRecovered(nonLockedTokens);
        staking.recoverNonLockedRewardTokens();

        assertEq(stakingToken.balanceOf(OWNER), nonLockedTokens);
    }

    function test_RecoverNonLockedRewardTokens_RevertsWhen_NotOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this)));
        staking.recoverNonLockedRewardTokens();
    }

    // pause
    function test_Pause() public {
        vm.prank(OWNER);
        staking.pause();

        assertEq(staking.paused(), true);
    }

    function test_Pause_RevertsWhen_NotOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this)));
        staking.pause();
    }

    // unpause
    function test_Unpause() public {
        vm.prank(OWNER);
        staking.pause();

        vm.prank(OWNER);
        staking.unpause();

        assertEq(staking.paused(), false);
    }

    function test_Unpause_RevertsWhen_NotOwner() public {
        vm.prank(OWNER);
        staking.pause();

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this)));
        staking.unpause();
    }

    // _getFutureRewardTokens
    function test_getFutureRewardTokens() public {
        TesteableStaking testStaking = new TesteableStaking();
        testStaking.initialize(address(stakingToken), address(rewardsToken), OWNER);
        rewardsToken.mint(address(testStaking), REWARD_PER_BLOCK * BLOCKS_AMOUNT);

        vm.prank(OWNER);
        testStaking.setRewards(REWARD_PER_BLOCK, STARTING_BLOCK, BLOCKS_AMOUNT);

        assertEq(testStaking._getFutureRewardTokensPublic(), REWARD_PER_BLOCK * BLOCKS_AMOUNT);
    }

    // _calculateBlocksLeft
    function test_CalculateBlocksLeft_StakingNotStarted() public {
        TesteableStaking testStaking = new TesteableStaking();
        testStaking.initialize(address(stakingToken), address(rewardsToken), OWNER);
        rewardsToken.mint(address(testStaking), REWARD_PER_BLOCK * BLOCKS_AMOUNT);

        vm.prank(OWNER);
        testStaking.setRewards(REWARD_PER_BLOCK, STARTING_BLOCK, BLOCKS_AMOUNT);

        assertEq(testStaking._calculateBlocksLeftPublic(), BLOCKS_AMOUNT);
    }

    function test_CalculateBlocksLeft_RevertsWhen_StakingPeriodIsOver() public {
        TesteableStaking testStaking = new TesteableStaking();
        testStaking.initialize(address(stakingToken), address(rewardsToken), OWNER);
        rewardsToken.mint(address(testStaking), REWARD_PER_BLOCK * BLOCKS_AMOUNT);

        vm.prank(OWNER);
        testStaking.setRewards(REWARD_PER_BLOCK, STARTING_BLOCK, BLOCKS_AMOUNT);

        vm.roll(LAST_BLOCK_WITH_REWARD);
        assertEq(testStaking._calculateBlocksLeftPublic(), 0);
    }

    function test_CalculateBlocksLeft_RevertsWhen_StakingPeriodNotEnded() public {
        TesteableStaking testStaking = new TesteableStaking();
        testStaking.initialize(address(stakingToken), address(rewardsToken), OWNER);
        rewardsToken.mint(address(testStaking), REWARD_PER_BLOCK * BLOCKS_AMOUNT);

        vm.prank(OWNER);
        testStaking.setRewards(REWARD_PER_BLOCK, STARTING_BLOCK, BLOCKS_AMOUNT);

        vm.roll(REWARDS_BLOCK);
        assertEq(testStaking._calculateBlocksLeftPublic(), LAST_BLOCK_WITH_REWARD - REWARDS_BLOCK);
    }
}
