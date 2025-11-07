// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/RouteCalculator.sol";

/// @notice Minimal script to deploy RouteCalculator with EOA ownership
contract DeployRouteCalculatorOnly is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        RouteCalculator calculator = new RouteCalculator();
        console.log("RouteCalculator deployed:", address(calculator));

        vm.stopBroadcast();
    }
}

