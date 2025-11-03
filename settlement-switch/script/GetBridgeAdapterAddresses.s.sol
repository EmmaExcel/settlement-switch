// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/BridgeRegistry.sol";

contract GetBridgeAdapterAddressesScript is Script {
    // Deployed contract addresses
    address constant BRIDGE_REGISTRY_SEPOLIA = 0x4C9d8BA4BcD7b4f7Eda75ECC0b853aF66fe6BAE7;

    function run() external view {
        console.log("Getting bridge adapter addresses from BridgeRegistry...");
        
        BridgeRegistry registry = BridgeRegistry(BRIDGE_REGISTRY_SEPOLIA);
        
        // Get all registered bridges
        address[] memory registeredBridges = registry.getRegisteredBridges();
        console.log("Total registered bridges:", registeredBridges.length);
        
        for (uint256 i = 0; i < registeredBridges.length; i++) {
            address adapter = registeredBridges[i];
            console.log("Bridge", i, "address:", adapter);
            
            // Get bridge details
            (BridgeRegistry.BridgeInfo memory info, BridgeRegistry.PerformanceMetrics memory metrics) = registry.getBridgeDetails(adapter);
            console.log("  Name:", info.name);
            console.log("  Is enabled:", info.isEnabled);
            console.log("  Is healthy:", info.isHealthy);
            console.log("  Registered at:", info.registeredAt);
        }
    }
}