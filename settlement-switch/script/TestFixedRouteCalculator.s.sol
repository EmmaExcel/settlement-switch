// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/RouteCalculator.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract TestFixedRouteCalculator is Script {
    RouteCalculator public routeCalculator;
    address constant ROUTE_CALCULATOR = 0xc3980A99003Ec243924fC8B9720D441C653C3bB1;
    address constant ACROSS_ADAPTER = 0x38f815795d2c38C8691B0DD4422ba26A910a9c9C;
    address constant WETH_ADDRESS = address(0x2);
    uint256 constant BRIDGE_AMOUNT = 0.01 ether;

    function run() external {
        vm.startBroadcast();

        routeCalculator = RouteCalculator(ROUTE_CALCULATOR);

        console.log("Testing Fixed RouteCalculator...");
        console.log("RouteCalculator address:", address(routeCalculator));

        // Test 1: Check if adapters are registered
        address[] memory adapters = routeCalculator.getRegisteredAdapters();
        console.log("Number of registered adapters:", adapters.length);
        
        bool acrossFound = false;
        for (uint256 i = 0; i < adapters.length; i++) {
            console.log("Adapter", i, ":", adapters[i]);
            if (adapters[i] == ACROSS_ADAPTER) {
                acrossFound = true;
            }
        }
        
        if (acrossFound) {
            console.log("[SUCCESS] Across adapter found in registered adapters");
        } else {
            console.log("[ERROR] Across adapter NOT found in registered adapters");
        }

        // Test 2: Try to find optimal route (this should work without overflow now)
        try routeCalculator.findOptimalRoute(
            WETH_ADDRESS,           // tokenIn
            WETH_ADDRESS,           // tokenOut  
            BRIDGE_AMOUNT,          // amount
            11155111,               // srcChainId (Ethereum Sepolia)
            421614,                 // dstChainId (Arbitrum Sepolia)
            IBridgeAdapter.RoutePreferences({
                mode: IBridgeAdapter.RoutingMode.BALANCED,
                maxSlippageBps: 100,
                maxFeeWei: 0.005 ether,
                maxTimeMinutes: 30,
                allowMultiHop: false
            })
        ) returns (IBridgeAdapter.Route memory route) {
            console.log("[SUCCESS] findOptimalRoute succeeded without overflow!");
            console.log("Selected adapter:", route.adapter);
            console.log("Amount in:", route.amountIn);
            console.log("Amount out:", route.amountOut);
            console.log("Bridge fee:", route.metrics.bridgeFee);
            console.log("Total cost:", route.metrics.totalCostWei);
            console.log("Estimated time:", route.metrics.estimatedTimeMinutes, "minutes");
        } catch Error(string memory reason) {
            console.log("[ERROR] findOptimalRoute failed:", reason);
        } catch {
            console.log("[ERROR] findOptimalRoute failed with unknown error");
        }

        // Test 3: Try to find multiple routes
        try routeCalculator.findMultipleRoutes(
            WETH_ADDRESS,           // tokenIn
            WETH_ADDRESS,           // tokenOut  
            BRIDGE_AMOUNT,          // amount
            11155111,               // srcChainId (Ethereum Sepolia)
            421614,                 // dstChainId (Arbitrum Sepolia)
            IBridgeAdapter.RoutePreferences({
                mode: IBridgeAdapter.RoutingMode.BALANCED,
                maxSlippageBps: 100,
                maxFeeWei: 0.005 ether,
                maxTimeMinutes: 30,
                allowMultiHop: false
            }),
            3                       // maxRoutes
        ) returns (IBridgeAdapter.Route[] memory routes) {
            console.log("[SUCCESS] findMultipleRoutes succeeded!");
            console.log("Found", routes.length, "routes");
            
            for (uint256 i = 0; i < routes.length; i++) {
                console.log("Route", i, "adapter:", routes[i].adapter);
                console.log("Route", i, "cost:", routes[i].metrics.totalCostWei);
            }
        } catch Error(string memory reason) {
            console.log("[ERROR] findMultipleRoutes failed:", reason);
        } catch {
            console.log("[ERROR] findMultipleRoutes failed with unknown error");
        }

        console.log("RouteCalculator testing completed!");

        vm.stopBroadcast();
    }
}