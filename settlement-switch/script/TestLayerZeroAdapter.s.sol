// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract TestLayerZeroAdapter is Script {
    address constant LAYERZERO_ADAPTER = 0xB9B51072EB56ca874224460e65fa96f2d5BeD7f5;
    address constant WETH_ADDRESS = address(0x2);
    uint256 constant BRIDGE_AMOUNT = 0.01 ether;
    uint256 constant SRC_CHAIN_ID = 11155111; // Ethereum Sepolia
    uint256 constant DST_CHAIN_ID = 421614;   // Arbitrum Sepolia

    function run() external {
        vm.startBroadcast();

        console.log("Testing LayerZero Adapter...");
        console.log("LayerZero Adapter address:", LAYERZERO_ADAPTER);

        IBridgeAdapter layerZeroAdapter = IBridgeAdapter(LAYERZERO_ADAPTER);

        // Test 1: Check if adapter supports the route
        console.log("\n=== Testing Route Support ===");
        try layerZeroAdapter.supportsRoute(
            WETH_ADDRESS,
            WETH_ADDRESS,
            SRC_CHAIN_ID,
            DST_CHAIN_ID
        ) returns (bool supported) {
            if (supported) {
                console.log("[SUCCESS] LayerZero adapter supports WETH Sepolia -> Arbitrum Sepolia route");
            } else {
                console.log("[INFO] LayerZero adapter does NOT support WETH Sepolia -> Arbitrum Sepolia route");
                
                // Try ETH instead
                try layerZeroAdapter.supportsRoute(
                    address(0),
                    address(0),
                    SRC_CHAIN_ID,
                    DST_CHAIN_ID
                ) returns (bool ethSupported) {
                    if (ethSupported) {
                        console.log("[SUCCESS] LayerZero adapter supports ETH Sepolia -> Arbitrum Sepolia route");
                    } else {
                        console.log("[INFO] LayerZero adapter does NOT support ETH route either");
                    }
                } catch {
                    console.log("[ERROR] Failed to check ETH route support");
                }
            }
        } catch Error(string memory reason) {
            console.log("[ERROR] supportsRoute failed:", reason);
        } catch {
            console.log("[ERROR] supportsRoute failed with unknown error");
        }

        // Test 2: Check available liquidity
        console.log("\n=== Testing Liquidity ===");
        try layerZeroAdapter.getAvailableLiquidity(
            WETH_ADDRESS,
            WETH_ADDRESS,
            SRC_CHAIN_ID,
            DST_CHAIN_ID
        ) returns (uint256 liquidity) {
            console.log("[SUCCESS] Available WETH liquidity:", liquidity);
        } catch Error(string memory reason) {
            console.log("[ERROR] getAvailableLiquidity failed:", reason);
        } catch {
            console.log("[ERROR] getAvailableLiquidity failed with unknown error");
        }

        // Test 3: Get route metrics
        console.log("\n=== Testing Route Metrics ===");
        try layerZeroAdapter.getRouteMetrics(
            WETH_ADDRESS,
            WETH_ADDRESS,
            BRIDGE_AMOUNT,
            SRC_CHAIN_ID,
            DST_CHAIN_ID
        ) returns (IBridgeAdapter.RouteMetrics memory metrics) {
            console.log("[SUCCESS] LayerZero route metrics retrieved:");
            console.log("  Estimated gas cost:", metrics.estimatedGasCost);
            console.log("  Bridge fee:", metrics.bridgeFee);
            console.log("  Total cost:", metrics.totalCostWei);
            console.log("  Estimated time:", metrics.estimatedTimeMinutes, "minutes");
            console.log("  Success rate:", metrics.successRate, "%");
            console.log("  Liquidity available:", metrics.liquidityAvailable);
            console.log("  Congestion level:", metrics.congestionLevel);
        } catch Error(string memory reason) {
            console.log("[ERROR] getRouteMetrics failed:", reason);
        } catch {
            console.log("[ERROR] getRouteMetrics failed with unknown error");
        }

        // Test 4: Check adapter health
        console.log("\n=== Testing Adapter Health ===");
        try layerZeroAdapter.isHealthy() returns (bool healthy) {
            if (healthy) {
                console.log("[SUCCESS] LayerZero adapter is healthy");
            } else {
                console.log("[WARNING] LayerZero adapter is not healthy");
            }
        } catch Error(string memory reason) {
            console.log("[ERROR] isHealthy failed:", reason);
        } catch {
            console.log("[ERROR] isHealthy failed with unknown error");
        }

        // Test 5: Check transfer limits
        console.log("\n=== Testing Transfer Limits ===");
        try layerZeroAdapter.getTransferLimits(
            WETH_ADDRESS,
            SRC_CHAIN_ID,
            DST_CHAIN_ID
        ) returns (uint256 minAmount, uint256 maxAmount) {
            console.log("[SUCCESS] LayerZero transfer limits:");
            console.log("  Min amount:", minAmount);
            console.log("  Max amount:", maxAmount);
        } catch Error(string memory reason) {
            console.log("[ERROR] getTransferLimits failed:", reason);
        } catch {
            console.log("[ERROR] getTransferLimits failed with unknown error");
        }

        console.log("\nLayerZero Adapter testing completed!");

        vm.stopBroadcast();
    }
}