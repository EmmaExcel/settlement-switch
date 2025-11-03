// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/RouteCalculator.sol";

contract CheckRouteCalculatorScript is Script {
    // Deployed contract addresses
    address constant ROUTE_CALCULATOR_SEPOLIA = 0xc3980A99003Ec243924fC8B9720D441C653C3bB1;

    function run() external view {
        console.log("Checking RouteCalculator on Ethereum Sepolia...");
        console.log("RouteCalculator address:", ROUTE_CALCULATOR_SEPOLIA);
        
        RouteCalculator calculator = RouteCalculator(ROUTE_CALCULATOR_SEPOLIA);
        
        // Get all registered adapters
        address[] memory registeredAdapters = calculator.getRegisteredAdapters();
        console.log("Total registered adapters in RouteCalculator:", registeredAdapters.length);
        
        // List all registered adapters
        for (uint256 i = 0; i < registeredAdapters.length; i++) {
            address adapter = registeredAdapters[i];
            console.log("Adapter", i, ":", adapter);
            
            // Check if adapter is registered
            bool isRegistered = calculator.registeredAdapters(adapter);
            console.log("  Is registered:", isRegistered);
            
            // Get bridge metrics
            RouteCalculator.BridgeMetrics memory metrics = calculator.getBridgeMetrics(adapter);
            console.log("  Is healthy:", metrics.isHealthy);
            console.log("  Total transfers:", metrics.totalTransfers);
        }
    }
}