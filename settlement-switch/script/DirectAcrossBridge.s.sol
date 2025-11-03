// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract DirectAcrossBridge is Script {
    // Contract addresses
    address constant ACROSS_ADAPTER = 0x8dfD68e1A08209b727149B2256140af9CE1978F0;
    
    // Chain IDs
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    
    // Bridge parameters
    uint256 constant BRIDGE_AMOUNT = 0.1 ether;  // Increased to meet minimum requirement
    address constant ETH_ADDRESS = address(0);
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Bridging ETH using Across adapter directly (bypassing Settlement Switch)...");
        console.log("Deployer:", deployer);
        console.log("Across Adapter:", ACROSS_ADAPTER);
        console.log("Amount to bridge:", BRIDGE_AMOUNT);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the adapter instance
        IBridgeAdapter acrossAdapter = IBridgeAdapter(ACROSS_ADAPTER);
        
        // Check if the route is supported
        bool routeSupported = acrossAdapter.supportsRoute(
            ETH_ADDRESS,
            ETH_ADDRESS,
            SEPOLIA_CHAIN_ID,
            ARBITRUM_SEPOLIA_CHAIN_ID
        );
        
        require(routeSupported, "Route not supported by Across adapter");
        console.log("Route is supported by Across adapter");
        
        // Get route metrics
        IBridgeAdapter.RouteMetrics memory metrics = acrossAdapter.getRouteMetrics(
            ETH_ADDRESS,
            ETH_ADDRESS,
            BRIDGE_AMOUNT,
            SEPOLIA_CHAIN_ID,
            ARBITRUM_SEPOLIA_CHAIN_ID
        );
        
        console.log("Route metrics:");
        console.log("  Bridge Fee:", metrics.bridgeFee);
        console.log("  Total Cost:", metrics.totalCostWei);
        console.log("  Estimated Time:", metrics.estimatedTimeMinutes, "minutes");
        console.log("  Available Liquidity:", metrics.liquidityAvailable);
        console.log("  Success Rate:", metrics.successRate, "%");
        
        // Calculate expected output amount (amount - bridge fee)
        uint256 expectedOutput = BRIDGE_AMOUNT - metrics.bridgeFee;
        console.log("Expected output amount:", expectedOutput);
        
        // Create the route
        IBridgeAdapter.Route memory route = IBridgeAdapter.Route({
            adapter: ACROSS_ADAPTER,
            tokenIn: ETH_ADDRESS,
            tokenOut: ETH_ADDRESS,
            amountIn: BRIDGE_AMOUNT,
            amountOut: expectedOutput,
            srcChainId: SEPOLIA_CHAIN_ID,
            dstChainId: ARBITRUM_SEPOLIA_CHAIN_ID,
            metrics: metrics,
            adapterData: "",  // Across doesn't need special adapter data for ETH
            deadline: block.timestamp + 3600  // 1 hour deadline
        });
        
        // Execute the bridge directly on the adapter
        console.log("Executing bridge transaction directly on Across adapter...");
        bytes32 transferId = acrossAdapter.executeBridge{value: BRIDGE_AMOUNT}(
            route,
            deployer,  // recipient (same as sender for this test)
            ""  // no permit data needed for ETH
        );
        
        console.log("Bridge transaction successful!");
        console.log("Transfer ID:", vm.toString(transferId));
        
        vm.stopBroadcast();
    }
}