// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/adapters/LayerZeroAdapter.sol";

contract TestFixedLayerZeroAdapter is Script {
    LayerZeroAdapter public adapter;
    
    // New deployed adapter address with corrected endpoint IDs
    address constant FIXED_ADAPTER = 0x78bf06da0b3149944bca88a77e019fdd61ba50cf;
    
    // Test addresses
    address constant ETH_ADDRESS = address(0);
    address constant WETH_SEPOLIA = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    
    // Chain IDs
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    
    function run() external {
        adapter = LayerZeroAdapter(FIXED_ADAPTER);
        
        console.log("Testing Fixed LayerZero Adapter at:", FIXED_ADAPTER);
        console.log("=".repeat(50));
        
        // Test 1: Check if adapter supports the route
        testSupportsRoute();
        
        // Test 2: Check endpoint ID mappings
        testEndpointMappings();
        
        // Test 3: Check adapter configuration
        testAdapterConfig();
        
        console.log("=".repeat(50));
        console.log("All tests completed!");
    }
    
    function testSupportsRoute() external view {
        console.log("Test 1: Checking route support...");
        
        // Test ETH route from Sepolia to Arbitrum Sepolia
        bool supportsETH = adapter.supportsRoute(
            ETH_ADDRESS,
            ETH_ADDRESS,
            SEPOLIA_CHAIN_ID,
            ARBITRUM_SEPOLIA_CHAIN_ID
        );
        
        console.log("ETH Sepolia -> Arbitrum Sepolia supported:", supportsETH);
        
        // Test WETH route
        bool supportsWETH = adapter.supportsRoute(
            WETH_SEPOLIA,
            WETH_SEPOLIA,
            SEPOLIA_CHAIN_ID,
            ARBITRUM_SEPOLIA_CHAIN_ID
        );
        
        console.log("WETH Sepolia -> Arbitrum Sepolia supported:", supportsWETH);
        
        if (supportsETH && supportsWETH) {
            console.log("✅ Route support test PASSED");
        } else {
            console.log("❌ Route support test FAILED");
        }
    }
    
    function testEndpointMappings() external view {
        console.log("\nTest 2: Checking endpoint ID mappings...");
        
        // Check Sepolia mapping (should be 40161)
        uint16 sepoliaEndpoint = adapter.chainIdToLzChainId(SEPOLIA_CHAIN_ID);
        console.log("Sepolia Chain ID", SEPOLIA_CHAIN_ID, "-> LayerZero Endpoint:", sepoliaEndpoint);
        
        // Check Arbitrum Sepolia mapping (should be 40231)
        uint16 arbSepoliaEndpoint = adapter.chainIdToLzChainId(ARBITRUM_SEPOLIA_CHAIN_ID);
        console.log("Arbitrum Sepolia Chain ID", ARBITRUM_SEPOLIA_CHAIN_ID, "-> LayerZero Endpoint:", arbSepoliaEndpoint);
        
        if (sepoliaEndpoint == 40161 && arbSepoliaEndpoint == 40231) {
            console.log("✅ Endpoint mapping test PASSED");
        } else {
            console.log("❌ Endpoint mapping test FAILED");
            console.log("Expected: Sepolia=40161, Arbitrum Sepolia=40231");
        }
    }
    
    function testAdapterConfig() external view {
        console.log("\nTest 3: Checking adapter configuration...");
        
        // Check if adapter is active
        bool isActive = adapter.isActive();
        console.log("Adapter is active:", isActive);
        
        // Check adapter name
        string memory name = adapter.getAdapterName();
        console.log("Adapter name:", name);
        
        // Get route metrics for a sample route
        try adapter.getRouteMetrics(
            ETH_ADDRESS,
            ETH_ADDRESS,
            1 ether,
            SEPOLIA_CHAIN_ID,
            ARBITRUM_SEPOLIA_CHAIN_ID
        ) returns (uint256 estimatedGas, uint256 bridgeFee) {
            console.log("Sample route metrics:");
            console.log("  Estimated gas:", estimatedGas);
            console.log("  Bridge fee:", bridgeFee);
            console.log("✅ Route metrics test PASSED");
        } catch {
            console.log("❌ Route metrics test FAILED");
        }
    }
}