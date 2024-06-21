// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../Bounty.sol";

contract BountyScript is Script {
    function run() external {
        address pceToken = 0x09114706E2b7338a09279D4AC984E859B964633c;
        address governance = 0x58D07b7854CD2eC0cBaf863A33E2816afd4a9719;
        uint256 _bountyAmount = 100e18;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Bounty bounty = new Bounty();
        bounty.initialize(
            ERC20Upgradeable(pceToken),
            _bountyAmount,
            governance
        );
        vm.stopBroadcast();
    }
}
