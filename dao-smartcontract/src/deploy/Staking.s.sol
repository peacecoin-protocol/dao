// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Staking} from "../Staking.sol";
import {WPCE} from "../mocks/WPCE.sol";
import {console} from "forge-std/console.sol";

contract StakingScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerAddress = vm.addr(deployerPrivateKey);
        address pceTokenAddress = 0x951E69b565924c0b846Ed0E779f190c53d29F62e;

        WPCE wpce = new WPCE();
        wpce.initialize();

        uint256 rewardPerBlock = 0.0001 ether;

        Staking staking = new Staking();
        wpce.addMinter(address(staking));

        staking.initialize({
            rewardPerBlockValue: rewardPerBlock,
            pceAddress: pceTokenAddress,
            wPceAddress: address(wpce)
        });

        console.log("Staking address:", address(staking));
        console.log("Deployer address:", deployerAddress);
        console.log("WPCE address:", address(wpce));
    }
}
