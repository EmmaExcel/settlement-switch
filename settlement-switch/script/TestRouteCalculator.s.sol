// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/RouteCalculator.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract TestRouteCalculator is Script {
    // Contract addresses on Sepolia
    address constant ROUTE_CALCULATOR = 0xc3980A99003Ec243924fC8B9720D441C653C3bB1;
    
    // Chain IDs
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    
    // ETH address (native token)
    address constant ETH_ADDRESS = address(0);
    
    function run() external {
        console.log("Testing RouteCalculator for ETH routes...");
        
        RouteCalculator routeCalculator = RouteCalculator(ROUTE_CALCULATOR);
        
        // Test route preferences
        IBridgeAdapter.RoutePreferences memory preferences = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.FASTEST,
            maxSlippageBps: 500,
            maxFeeWei: 0.01 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });
        
        console.log("Querying routes for ETH from Sepolia to Arbitrum Sepolia...");
        console.log("Token In (ETH):", ETH_ADDRESS);
        console.log("Token Out (ETH):", ETH_ADDRESS);
        console.log("Amount: 0.001 ETH");
        console.log("Source Chain:", SEPOLIA_CHAIN_ID);
        console.log("Destination Chain:", ARBITRUM_SEPOLIA_CHAIN_ID);
        
        try routeCalculator.findOptimalRoute(
            ETH_ADDRESS,
            ETH_ADDRESS,
            0.001 ether,
            SEPOLIA_CHAIN_ID,
            ARBITRUM_SEPOLIA_CHAIN_ID,
            preferences
        ) returns (IBridgeAdapter.Route memory route) {
            console.log("SUCCESS: Found optimal route!");
            console.log("Adapter address:", route.adapter);
            console.log("Token In:", route.tokenIn);
            console.log("Token Out:", route.tokenOut);
            console.log("Amount In:", route.amountIn);
            console.log("Amount Out:", route.amountOut);
            console.log("Total Cost:", route.metrics.totalCostWei);
            console.log("Estimated Time (minutes):", route.metrics.estimatedTimeMinutes);
        } catch Error(string memory reason) {
            console.log("ERROR: Failed to find route -", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Low-level error occurred");
            console.logBytes(lowLevelData);
        }
        
        // Also try getting multiple routes
        console.log("\nQuerying multiple routes...");
        try routeCalculator.findMultipleRoutes(
            ETH_ADDRESS,
            ETH_ADDRESS,
            0.001 ether,
            SEPOLIA_CHAIN_ID,
            ARBITRUM_SEPOLIA_CHAIN_ID,
            preferences,
            3 // max routes
        ) returns (IBridgeAdapter.Route[] memory routes) {
            console.log("Found", routes.length, "available routes");
            for (uint256 i = 0; i < routes.length; i++) {
                console.log("Route", i, "- Adapter:", routes[i].adapter);
                console.log("  Amount Out:", routes[i].amountOut);
                console.log("  Total Cost:", routes[i].metrics.totalCostWei);
            }
        } catch Error(string memory reason) {
            console.log("ERROR: Failed to get multiple routes -", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Low-level error getting routes");
            console.logBytes(lowLevelData);
        }
    }
}