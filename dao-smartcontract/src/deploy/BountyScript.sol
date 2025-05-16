// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../Bounty.sol";

contract BountyScript is Script {
    function run() external {
        address pceToken = 0xBa9E16D096262023c50A3cCCC4f08af4b321fB21;
        address governance = 0x4a1EBA4B4895b6562B8d67510FF07c95F90049d8;
        uint256 _bountyAmount = 10e18;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Bounty bounty = new Bounty();
        bounty.initialize(ERC20Upgradeable(pceToken), _bountyAmount, governance);
        vm.stopBroadcast();

        console.log("Bounty deployed at", address(bounty));
    }
}
