// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../Campagins.sol";
import "../PCEGovTokenTest.sol";

contract CampaginsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Campagins campagins = new Campagins();
        campagins.initialize(ERC20Upgradeable(address(0x8d4d8C9192C7df57840129D71c18ED49dda7Fe33)));


        Campagins.Campagin memory champ = Campagins.Campagin({
            title: "Test Campagin",
            description: "Test Description",
            amount: 10e18,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: true
        });
        campagins.createCampagin(champ);
        campagins.createCampagin(champ);
        campagins.createCampagin(champ);
        campagins.createCampagin(champ);

        vm.roll(block.number + 1);

        campagins.createCampagin(Campagins.Campagin({
            title: "Test Campagin",
            description: "Test Description",
            amount: 10e18,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: true
        }));
        campagins.createCampagin(Campagins.Campagin({
            title: "Test Campagin",
            description: "Test Description",
            amount: 10e18,
            startDate: block.timestamp + 100,
            endDate: block.timestamp + 1000,
            validateSignatures: true
        }));

        address[] memory winners = new address[](2);
        winners[0] = 0x6fD12d4d7E8e1D3E5EE6B3A6e8c7DD426Bb24BF5;
        winners[1] = 0x59178bAc7A9BBfa287F39887EAA2826666f14A2a;

        vm.roll(block.number + 1);
        campagins.addCampWinners(0, winners);
        campagins.addCampWinners(1, winners);
        
        vm.roll(block.number + 1);
        campagins.addCampWinners(3, winners);
        campagins.addCampWinners(4, winners);
        console.log("Campagins deployed at", address(campagins));

        vm.stopBroadcast();
    }
}
