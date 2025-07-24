// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../mocks/MockERC20.sol";
import "../Staking.sol";
import "forge-std/console.sol";

contract StakingScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);

        uint256 rewardPerBlock = 1e18;
        uint256 rewardBlocks = 1_000_000;

        MockERC20 mockERC20 = new MockERC20();
        mockERC20.initialize();

        mockERC20.mint(deployerAddress, 1e18 * 1000_000_000);

        vm.roll(block.number + 10);

        Staking staking = new Staking();
        staking.initialize(rewardPerBlock, address(mockERC20), address(mockERC20));

        mockERC20.transfer(address(staking), rewardPerBlock * rewardBlocks);

        mockERC20.approve(address(staking), 5_000_000 * 1e18);
        staking.stake(5_000_000 * 1e18);

        console.log("Staked 5_000_000 * 1e18");

        vm.roll(block.number + 10);

        mockERC20.approve(address(staking), 15_000_000 * 1e18);
        staking.stake(15_000_000 * 1e18);

        console.log("Staked 15_000_000 * 1e18");

        console.log("Staking address:", address(staking));
        console.log("MockERC20 address:", address(mockERC20));
        console.log("Deployer address:", deployerAddress);
    }
}
