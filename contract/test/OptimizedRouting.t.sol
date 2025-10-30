// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/StablecoinSwitch.sol";
import "../src/mocks/MockPriceFeed.sol";

contract OptimizedRoutingTest is Test {
    StablecoinSwitch public stablecoinSwitch;
    MockPriceFeed public ethUsdPriceFeed;
    MockPriceFeed public usdcUsdPriceFeed;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    
    // Mock tokens
    address public constant USDC = address(0x100);
    address public constant USDT = address(0x101);
    
    // Mock bridge adapters
    address public constant ARBITRUM_ADAPTER = address(0x200);
    address public constant OPTIMISM_ADAPTER = address(0x201);
    address public constant POLYGON_ADAPTER = address(0x202);
    
    // Chain IDs
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;
    uint256 public constant OPTIMISM_CHAIN_ID = 10;
    uint256 public constant POLYGON_CHAIN_ID = 137;
    
    function setUp() public {
        // Deploy mock price feeds
        ethUsdPriceFeed = new MockPriceFeed(8);
        usdcUsdPriceFeed = new MockPriceFeed(8);
        
        // Set realistic prices
        ethUsdPriceFeed.updateAnswer(2000 * 1e8); // $2000 ETH
        usdcUsdPriceFeed.updateAnswer(1 * 1e8);   // $1 USDC
        
        // Deploy StablecoinSwitch
        vm.prank(owner);
        stablecoinSwitch = new StablecoinSwitch(
            address(ethUsdPriceFeed),
            address(usdcUsdPriceFeed),
            owner
        );
        
        // Setup tokens and chains
        vm.startPrank(owner);
        stablecoinSwitch.setTokenSupport(USDC, true);
        stablecoinSwitch.setTokenSupport(USDT, true);
        stablecoinSwitch.setChainSupport(ARBITRUM_CHAIN_ID, true);
        stablecoinSwitch.setChainSupport(OPTIMISM_CHAIN_ID, true);
        stablecoinSwitch.setChainSupport(POLYGON_CHAIN_ID, true);
        
        // Add multiple bridge adapters for Arbitrum with different costs
        stablecoinSwitch.addBridgeAdapter(
            ARBITRUM_CHAIN_ID, 
            ARBITRUM_ADAPTER, 
            "Arbitrum", 
            200000 // Lower gas cost
        );
        
        stablecoinSwitch.addBridgeAdapter(
            ARBITRUM_CHAIN_ID, 
            OPTIMISM_ADAPTER, 
            "Optimism", 
            300000 // Higher gas cost
        );
        
        stablecoinSwitch.addBridgeAdapter(
            ARBITRUM_CHAIN_ID, 
            POLYGON_ADAPTER, 
            "Polygon", 
            150000 // Lowest gas cost
        );
        
        vm.stopPrank();
    }
    
    function testMultipleAdaptersRegistered() public {
        address[] memory adapters = stablecoinSwitch.getBridgeAdapters(ARBITRUM_CHAIN_ID);
        
        assertEq(adapters.length, 3, "Should have 3 bridge adapters");
        assertEq(adapters[0], ARBITRUM_ADAPTER, "First adapter should be Arbitrum");
        assertEq(adapters[1], OPTIMISM_ADAPTER, "Second adapter should be Optimism");
        assertEq(adapters[2], POLYGON_ADAPTER, "Third adapter should be Polygon");
    }
    
    function testCostPrioritySelectsCheapestRoute() public {
        // Set gas price for consistent testing
        vm.txGasPrice(20 gwei);
        
        StablecoinSwitch.RouteInfo memory route = stablecoinSwitch.getOptimalPath(
            USDC,
            USDT,
            1000 * 1e6, // $1000 USDC
            ARBITRUM_CHAIN_ID,
            0 // Cost priority
        );
        
        // Should select Polygon adapter (lowest gas cost)
        assertEq(route.bridgeAdapter, POLYGON_ADAPTER, "Should select cheapest bridge");
        assertEq(route.bridgeName, "Polygon", "Bridge name should be Polygon");
        
        // Verify cost calculations
        assertTrue(route.estimatedGasUsd > 0, "Gas cost should be positive");
        assertTrue(route.bridgeFeeUsd > 0, "Bridge fee should be positive");
        assertTrue(route.estimatedCostUsd > 0, "Total cost should be positive");
        
        console.log("Selected bridge:", route.bridgeName);
        console.log("Gas estimate:", route.gasEstimate);
        console.log("Estimated gas USD:", route.estimatedGasUsd);
        console.log("Bridge fee USD:", route.bridgeFeeUsd);
        console.log("Total cost USD:", route.estimatedCostUsd);
    }
    
    function testSpeedPriorityBalancesCostAndTime() public {
        vm.txGasPrice(20 gwei);
        
        StablecoinSwitch.RouteInfo memory route = stablecoinSwitch.getOptimalPath(
            USDC,
            USDT,
            1000 * 1e6, // $1000 USDC
            ARBITRUM_CHAIN_ID,
            1 // Speed priority
        );
        
        // Should still prefer Polygon due to fastest time (5 minutes)
        assertEq(route.bridgeAdapter, POLYGON_ADAPTER, "Should select fastest bridge for speed priority");
        assertEq(route.bridgeName, "Polygon", "Bridge name should be Polygon");
        
        // Time should be reduced for speed priority
        assertTrue(route.estimatedTimeMinutes <= 5, "Time should be optimized for speed");
        
        console.log("Speed priority - Selected bridge:", route.bridgeName);
        console.log("Estimated time:", route.estimatedTimeMinutes, "minutes");
    }
    
    function testDifferentBridgeFeesApplied() public {
        vm.txGasPrice(20 gwei);
        
        // Test each bridge individually by removing others temporarily
        vm.startPrank(owner);
        
        // Test Arbitrum (base fee)
        stablecoinSwitch.removeBridgeAdapter(ARBITRUM_CHAIN_ID, OPTIMISM_ADAPTER);
        stablecoinSwitch.removeBridgeAdapter(ARBITRUM_CHAIN_ID, POLYGON_ADAPTER);
        
        StablecoinSwitch.RouteInfo memory arbitrumRoute = stablecoinSwitch.getOptimalPath(
            USDC, USDT, 1000 * 1e6, ARBITRUM_CHAIN_ID, 0
        );
        
        // Re-add Optimism and remove others
        stablecoinSwitch.addBridgeAdapter(ARBITRUM_CHAIN_ID, OPTIMISM_ADAPTER, "Optimism", 300000);
        stablecoinSwitch.removeBridgeAdapter(ARBITRUM_CHAIN_ID, ARBITRUM_ADAPTER);
        
        StablecoinSwitch.RouteInfo memory optimismRoute = stablecoinSwitch.getOptimalPath(
            USDC, USDT, 1000 * 1e6, ARBITRUM_CHAIN_ID, 0
        );
        
        // Re-add Polygon and remove others
        stablecoinSwitch.addBridgeAdapter(ARBITRUM_CHAIN_ID, POLYGON_ADAPTER, "Polygon", 150000);
        stablecoinSwitch.removeBridgeAdapter(ARBITRUM_CHAIN_ID, OPTIMISM_ADAPTER);
        
        StablecoinSwitch.RouteInfo memory polygonRoute = stablecoinSwitch.getOptimalPath(
            USDC, USDT, 1000 * 1e6, ARBITRUM_CHAIN_ID, 0
        );
        
        vm.stopPrank();
        
        // Verify different fee structures
        // Optimism should have 10% premium over Arbitrum
        assertTrue(optimismRoute.bridgeFeeUsd > arbitrumRoute.bridgeFeeUsd, "Optimism should have higher fees");
        
        // Polygon should have 20% discount (cheapest)
        assertTrue(polygonRoute.bridgeFeeUsd < arbitrumRoute.bridgeFeeUsd, "Polygon should have lower fees");
        
        console.log("Arbitrum bridge fee:", arbitrumRoute.bridgeFeeUsd);
        console.log("Optimism bridge fee:", optimismRoute.bridgeFeeUsd);
        console.log("Polygon bridge fee:", polygonRoute.bridgeFeeUsd);
    }
    
    function testGasCostEstimationAccuracy() public {
        vm.txGasPrice(50 gwei); // Higher gas price
        
        StablecoinSwitch.RouteInfo memory highGasRoute = stablecoinSwitch.getOptimalPath(
            USDC, USDT, 1000 * 1e6, ARBITRUM_CHAIN_ID, 0
        );
        
        vm.txGasPrice(10 gwei); // Lower gas price
        
        StablecoinSwitch.RouteInfo memory lowGasRoute = stablecoinSwitch.getOptimalPath(
            USDC, USDT, 1000 * 1e6, ARBITRUM_CHAIN_ID, 0
        );
        
        // Higher gas price should result in higher gas cost
        assertTrue(highGasRoute.estimatedGasUsd > lowGasRoute.estimatedGasUsd, 
                  "Higher gas price should increase gas cost");
        
        console.log("High gas price cost:", highGasRoute.estimatedGasUsd);
        console.log("Low gas price cost:", lowGasRoute.estimatedGasUsd);
    }
    
    function testRemoveBridgeAdapter() public {
        vm.prank(owner);
        stablecoinSwitch.removeBridgeAdapter(ARBITRUM_CHAIN_ID, OPTIMISM_ADAPTER);
        
        address[] memory adapters = stablecoinSwitch.getBridgeAdapters(ARBITRUM_CHAIN_ID);
        assertEq(adapters.length, 2, "Should have 2 adapters after removal");
        
        // Verify Optimism adapter is not in the list
        for (uint i = 0; i < adapters.length; i++) {
            assertTrue(adapters[i] != OPTIMISM_ADAPTER, "Optimism adapter should be removed");
        }
    }
    
    function testUpdateBridgeGasCost() public {
        uint256 newGasCost = 500000;
        
        vm.prank(owner);
        stablecoinSwitch.updateBridgeGasCost(ARBITRUM_ADAPTER, newGasCost);
        
        vm.txGasPrice(20 gwei);
        
        StablecoinSwitch.RouteInfo memory route = stablecoinSwitch.getOptimalPath(
            USDC, USDT, 1000 * 1e6, ARBITRUM_CHAIN_ID, 0
        );
        
        // With higher gas cost, Arbitrum should no longer be the cheapest
        assertTrue(route.bridgeAdapter != ARBITRUM_ADAPTER, 
                  "Arbitrum should not be selected with higher gas cost");
    }
    
    function testLegacySetBridgeAdapterCompatibility() public {
        address legacyAdapter = address(0x999);
        
        vm.prank(owner);
        stablecoinSwitch.setBridgeAdapter(OPTIMISM_CHAIN_ID, legacyAdapter);
        
        address[] memory adapters = stablecoinSwitch.getBridgeAdapters(OPTIMISM_CHAIN_ID);
        assertEq(adapters.length, 1, "Should have 1 adapter");
        assertEq(adapters[0], legacyAdapter, "Should be the legacy adapter");
        
        StablecoinSwitch.RouteInfo memory route = stablecoinSwitch.getOptimalPath(
            USDC, USDT, 1000 * 1e6, OPTIMISM_CHAIN_ID, 0
        );
        
        assertEq(route.bridgeAdapter, legacyAdapter, "Should use legacy adapter");
        assertEq(route.bridgeName, "Legacy", "Should have legacy name");
    }
}