// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/BridgeRegistry.sol";

contract CheckBridgeRegistryScript is Script {
    // Deployed contract addresses
    address constant BRIDGE_REGISTRY_SEPOLIA = 0x4C9d8BA4BcD7b4f7Eda75ECC0b853aF66fe6BAE7;
    
    // Chain IDs
    uint256 constant ETHEREUM_SEPOLIA = 11155111;
    uint256 constant ARBITRUM_SEPOLIA = 421614;

    function run() external view {
        console.log("Checking Bridge Registry on Ethereum Sepolia...");
        console.log("Registry address:", BRIDGE_REGISTRY_SEPOLIA);
        
        BridgeRegistry registry = BridgeRegistry(BRIDGE_REGISTRY_SEPOLIA);
        
        // Get all registered bridges
        address[] memory registeredBridges = registry.getRegisteredBridges();
        console.log("Total registered bridges:", registeredBridges.length);
        
        // Get enabled bridges
        address[] memory enabledBridges = registry.getEnabledBridges();
        console.log("Total enabled bridges:", enabledBridges.length);
        
        // Check bridges for Ethereum Sepolia
        address[] memory sepoliaBridges = registry.getBridgesForChain(ETHEREUM_SEPOLIA);
        console.log("Bridges supporting Ethereum Sepolia:", sepoliaBridges.length);
        
        // Check bridges for Arbitrum Sepolia
        address[] memory arbitrumBridges = registry.getBridgesForChain(ARBITRUM_SEPOLIA);
        console.log("Bridges supporting Arbitrum Sepolia:", arbitrumBridges.length);
        
        // List all registered bridges and their details
        for (uint256 i = 0; i < registeredBridges.length; i++) {
            address bridge = registeredBridges[i];
            console.log("Bridge", i, ":", bridge);
            
            (BridgeRegistry.BridgeInfo memory info, ) = registry.getBridgeDetails(bridge);
            console.log("  Name:", info.name);
            console.log("  Enabled:", info.isEnabled);
            console.log("  Healthy:", info.isHealthy);
            
            // Check if this bridge supports both chains
            bool supportsEthSepolia = registry.doesBridgeSupportChain(bridge, ETHEREUM_SEPOLIA);
            bool supportsArbSepolia = registry.doesBridgeSupportChain(bridge, ARBITRUM_SEPOLIA);
            
            console.log("  Supports Ethereum Sepolia:", supportsEthSepolia);
            console.log("  Supports Arbitrum Sepolia:", supportsArbSepolia);
            console.log("  Can bridge Sepolia -> Arbitrum:", supportsEthSepolia && supportsArbSepolia);
        }
    }
}