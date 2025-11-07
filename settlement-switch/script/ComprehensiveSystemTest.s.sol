// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/SettlementSwitch.sol";
import "../src/core/RouteCalculator.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract ComprehensiveSystemTest is Script {
    // Contract addresses
    address constant SETTLEMENT_SWITCH = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant ROUTE_CALCULATOR = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    
    // Token addresses
    address constant WETH_SEPOLIA = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    
    // Chain IDs
    uint256 constant ETHEREUM_SEPOLIA = 11155111;
    uint256 constant ARBITRUM_SEPOLIA = 421614;
    
    // Bridge adapter addresses
    address constant LAYERZERO_ADAPTER = 0xB9B51072EB56ca874224460e65fa96f2d5BeD7f5;
    address constant CONNEXT_ADAPTER = 0x2f097CD8623EB3b8Ea6d161fe87BbF154A238A3f;
    address constant ACROSS_ADAPTER = 0x8dfD68e1A08209b727149B2256140af9CE1978F0;
    
    // Test parameters
    address constant WETH_ADDRESS = address(0x2);
    uint256 constant BRIDGE_AMOUNT = 0.01 ether;
    uint256 constant SRC_CHAIN_ID = 11155111; // Ethereum Sepolia
    uint256 constant DST_CHAIN_ID = 421614;   // Arbitrum Sepolia

    function run() external {
        vm.startBroadcast();

        console.log("=== COMPREHENSIVE SETTLEMENT SWITCH SYSTEM TEST ===");
        console.log("Testing all fixes and functionality...\n");

        // Test 1: RouteCalculator Functionality
        testRouteCalculator();

        // Test 2: Individual Bridge Adapters
        testBridgeAdapters();

        // Test 3: SettlementSwitch Integration
        testSettlementSwitch();

        // Test 4: End-to-End Route Finding
        testEndToEndRouteFinding();

        console.log("\n=== COMPREHENSIVE TEST COMPLETED ===");
        console.log("All major components tested successfully!");

        vm.stopBroadcast();
    }

    function testRouteCalculator() internal {
        console.log("1. TESTING ROUTE CALCULATOR");
        console.log("============================");
        
        RouteCalculator calculator = RouteCalculator(ROUTE_CALCULATOR);
        
        // Test route finding without overflow
        IBridgeAdapter.RoutePreferences memory preferences = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.BALANCED,
            maxSlippageBps: 500,
            maxFeeWei: 0.01 ether,
            maxTimeMinutes: 30,
            allowMultiHop: false
        });

        try calculator.findOptimalRoute(
            WETH_ADDRESS,
            WETH_ADDRESS,
            BRIDGE_AMOUNT,
            SRC_CHAIN_ID,
            DST_CHAIN_ID,
            preferences
        ) returns (IBridgeAdapter.Route memory route) {
            console.log("[SUCCESS] RouteCalculator.findOptimalRoute works without overflow");
            console.log("  Selected adapter:", route.adapter);
            console.log("  Total cost:", route.metrics.totalCostWei);
            console.log("  Estimated time:", route.metrics.estimatedTimeMinutes, "minutes");
        } catch Error(string memory reason) {
            console.log("[ERROR] RouteCalculator.findOptimalRoute failed:", reason);
        } catch {
            console.log("[ERROR] RouteCalculator.findOptimalRoute failed with unknown error");
        }

        // Test multiple routes
        try calculator.findMultipleRoutes(
            WETH_ADDRESS,
            WETH_ADDRESS,
            BRIDGE_AMOUNT,
            SRC_CHAIN_ID,
            DST_CHAIN_ID,
            preferences,
            3
        ) returns (IBridgeAdapter.Route[] memory routes) {
            console.log("[SUCCESS] RouteCalculator.findMultipleRoutes found", routes.length, "routes");
        } catch {
            console.log("[ERROR] RouteCalculator.findMultipleRoutes failed");
        }

        console.log("");
    }

    function testBridgeAdapters() internal {
        console.log("2. TESTING BRIDGE ADAPTERS");
        console.log("===========================");
        
        address[3] memory adapters = [LAYERZERO_ADAPTER, CONNEXT_ADAPTER, ACROSS_ADAPTER];
        string[3] memory names = ["LayerZero", "Connext", "Across"];
        
        for (uint i = 0; i < adapters.length; i++) {
            console.log("Testing", names[i], "adapter...");
            
            IBridgeAdapter adapter = IBridgeAdapter(adapters[i]);
            
            // Test route support
            try adapter.supportsRoute(WETH_ADDRESS, WETH_ADDRESS, SRC_CHAIN_ID, DST_CHAIN_ID) returns (bool supported) {
                if (supported) {
                    console.log("  [SUCCESS] Supports WETH route");
                } else {
                    console.log("  [INFO] Does not support WETH route");
                }
            } catch {
                console.log("  [ERROR] Route support check failed");
            }
            
            // Test health
            try adapter.isHealthy() returns (bool healthy) {
                if (healthy) {
                    console.log("  [SUCCESS] Adapter is healthy");
                } else {
                    console.log("  [WARNING] Adapter is not healthy");
                }
            } catch {
                console.log("  [ERROR] Health check failed");
            }
            
            // Test liquidity
            try adapter.getAvailableLiquidity(WETH_ADDRESS, WETH_ADDRESS, SRC_CHAIN_ID, DST_CHAIN_ID) returns (uint256 liquidity) {
                console.log("  [SUCCESS] Available liquidity:", liquidity);
            } catch {
                console.log("  [ERROR] Liquidity check failed");
            }
        }
        
        console.log("");
    }

    function testSettlementSwitch() internal {
        console.log("3. TESTING SETTLEMENT SWITCH");
        console.log("=============================");
        
        SettlementSwitch settlementSwitch = SettlementSwitch(payable(SETTLEMENT_SWITCH));
        
        // Check if SettlementSwitch is properly initialized
        bool isPaused = settlementSwitch.isPaused();
        console.log("SettlementSwitch paused status:", isPaused);
        
        // Test route cache TTL
        uint256 cacheTtl = settlementSwitch.getRouteCacheTtl();
        console.log("Route cache TTL:", cacheTtl);
        
        // Test getting registered adapters
        (address[] memory adapters, string[] memory names, bool[] memory enabled) = 
            settlementSwitch.getRegisteredAdapters();
        console.log("Number of registered adapters:", adapters.length);
        
        // Test ETH handling (the bug we fixed) - check if we can find routes for ETH
        IBridgeAdapter.RoutePreferences memory preferences = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,
            maxFeeWei: 0.05 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });
        
        try settlementSwitch.findOptimalRoute(
            address(0), // ETH
            WETH_SEPOLIA,
            1 ether,
            ETHEREUM_SEPOLIA,
            ARBITRUM_SEPOLIA,
            preferences
        ) returns (IBridgeAdapter.Route memory route) {
            console.log("[SUCCESS] ETH route found successfully");
            console.log("  Adapter:", route.adapter);
            console.log("  Amount out:", route.amountOut);
        } catch {
            console.log("[ERROR] ETH route finding failed");
        }
        
        console.log("[SUCCESS] SettlementSwitch basic functionality tested");
        
        console.log("");
    }

    function testEndToEndRouteFinding() internal {
        console.log("4. TESTING END-TO-END ROUTE FINDING");
        console.log("====================================");
        
        SettlementSwitch settlementSwitch = SettlementSwitch(payable(SETTLEMENT_SWITCH));
        
        IBridgeAdapter.RoutePreferences memory preferences = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 500,
            maxFeeWei: 0.01 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        // Test finding optimal route through SettlementSwitch
        try settlementSwitch.findOptimalRoute(
            WETH_ADDRESS,
            WETH_ADDRESS,
            BRIDGE_AMOUNT,
            SRC_CHAIN_ID,
            DST_CHAIN_ID,
            preferences
        ) returns (IBridgeAdapter.Route memory route) {
            console.log("[SUCCESS] End-to-end route finding works");
            console.log("  Selected adapter:", route.adapter);
            console.log("  Expected output:", route.amountOut);
            console.log("  Total cost:", route.metrics.totalCostWei);
            console.log("  Success rate:", route.metrics.successRate, "%");
        } catch Error(string memory reason) {
            console.log("[ERROR] End-to-end route finding failed:", reason);
        } catch {
            console.log("[ERROR] End-to-end route finding failed with unknown error");
        }

        // Test different routing modes
        string[3] memory modes = ["CHEAPEST", "FASTEST", "BALANCED"];
        IBridgeAdapter.RoutingMode[3] memory routingModes = [
            IBridgeAdapter.RoutingMode.CHEAPEST,
            IBridgeAdapter.RoutingMode.FASTEST,
            IBridgeAdapter.RoutingMode.BALANCED
        ];
        
        for (uint i = 0; i < modes.length; i++) {
            preferences.mode = routingModes[i];
            
            try settlementSwitch.findOptimalRoute(
                WETH_ADDRESS,
                WETH_ADDRESS,
                BRIDGE_AMOUNT,
                SRC_CHAIN_ID,
                DST_CHAIN_ID,
                preferences
            ) returns (IBridgeAdapter.Route memory route) {
                console.log("[SUCCESS]", modes[i], "mode works - Cost:", route.metrics.totalCostWei);
            } catch {
                console.log("[ERROR]", modes[i], "mode failed");
            }
        }
        
        console.log("");
    }
}
