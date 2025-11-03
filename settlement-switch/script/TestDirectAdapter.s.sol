// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract TestDirectAdapter is Script {
    // Updated adapter addresses
    address constant LAYERZERO_ADAPTER = 0xB9B51072EB56ca874224460e65fa96f2d5BeD7f5;
    address constant ACROSS_ADAPTER = 0x8dfD68e1A08209b727149B2256140af9CE1978F0;
    address constant CONNEXT_ADAPTER = 0x2f097CD8623EB3b8Ea6d161fe87BbF154A238A3f;
    
    // Chain IDs
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    
    // ETH address (native token)
    address constant ETH_ADDRESS = address(0);
    
    function run() external {
        console.log("Testing bridge adapters directly...");
        
        // Test LayerZero adapter
        console.log("\n=== Testing LayerZero Adapter ===");
        testAdapter(LAYERZERO_ADAPTER, "LayerZero");
        
        // Test Across adapter
        console.log("\n=== Testing Across Adapter ===");
        testAdapter(ACROSS_ADAPTER, "Across");
        
        // Test Connext adapter
        console.log("\n=== Testing Connext Adapter ===");
        testAdapter(CONNEXT_ADAPTER, "Connext");
    }
    
    function testAdapter(address adapterAddress, string memory name) internal {
        IBridgeAdapter adapter = IBridgeAdapter(adapterAddress);
        
        console.log("Testing", name, "adapter at:", adapterAddress);
        
        // Check if it supports the route
        try adapter.supportsRoute(
            ETH_ADDRESS,
            ETH_ADDRESS,
            SEPOLIA_CHAIN_ID,
            ARBITRUM_SEPOLIA_CHAIN_ID
        ) returns (bool supported) {
            console.log("Supports ETH route:", supported);
            
            if (supported) {
                // Get route metrics
                try adapter.getRouteMetrics(
                    ETH_ADDRESS,
                    ETH_ADDRESS,
                    0.001 ether,
                    SEPOLIA_CHAIN_ID,
                    ARBITRUM_SEPOLIA_CHAIN_ID
                ) returns (IBridgeAdapter.RouteMetrics memory metrics) {
                    console.log("Route metrics retrieved successfully");
                    console.log("  Bridge Fee:", metrics.bridgeFee);
                    console.log("  Total Cost:", metrics.totalCostWei);
                    console.log("  Estimated Time:", metrics.estimatedTimeMinutes, "minutes");
                    console.log("  Success Rate:", metrics.successRate, "%");
                } catch Error(string memory reason) {
                    console.log("ERROR getting metrics:", reason);
                } catch (bytes memory lowLevelData) {
                    console.log("ERROR: Low-level error getting metrics");
                    console.logBytes(lowLevelData);
                }
            }
        } catch Error(string memory reason) {
            console.log("ERROR checking route support:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Low-level error checking support");
            console.logBytes(lowLevelData);
        }
    }
}