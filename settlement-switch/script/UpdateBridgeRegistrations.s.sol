// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/BridgeRegistry.sol";

contract UpdateBridgeRegistrationsScript is Script {
    // Deployed contract addresses (Updated with latest fixed contracts)
    address constant BRIDGE_REGISTRY_SEPOLIA = 0x225A3471178028978081919aa3FF522c57ac7c8B;
    
    // Bridge adapter addresses (Updated with correct checksummed addresses)
    address constant LAYERZERO_ADAPTER = 0xB9B51072EB56ca874224460e65fa96f2d5BeD7f5;
    address constant ACROSS_ADAPTER = 0x8dfD68e1A08209b727149B2256140af9CE1978F0;
    address constant CONNEXT_ADAPTER = 0x2f097CD8623EB3b8Ea6d161fe87BbF154A238A3f;
    
    // Chain IDs
    uint256 constant ETHEREUM_SEPOLIA = 11155111;
    uint256 constant ARBITRUM_SEPOLIA = 421614;

    function run() external {
        vm.startBroadcast();
        
        console.log("Registering Bridge Adapters with BridgeRegistry on Ethereum Sepolia...");
        
        BridgeRegistry registry = BridgeRegistry(BRIDGE_REGISTRY_SEPOLIA);
        
        // Prepare supported chains and tokens for bidirectional bridging
        uint256[] memory supportedChains = new uint256[](2);
        supportedChains[0] = ETHEREUM_SEPOLIA; // Support bridging from Ethereum Sepolia
        supportedChains[1] = ARBITRUM_SEPOLIA; // Support bridging to Arbitrum Sepolia
        
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(0); // ETH (native token)
        
        // Register bridges with correct supported chains
        console.log("Registering LayerZero Adapter with bidirectional support...");
        registry.registerBridge(LAYERZERO_ADAPTER, supportedChains, supportedTokens);
        
        console.log("Registering Across Adapter with bidirectional support...");
        registry.registerBridge(ACROSS_ADAPTER, supportedChains, supportedTokens);
        
        console.log("Registering Connext Adapter with bidirectional support...");
        registry.registerBridge(CONNEXT_ADAPTER, supportedChains, supportedTokens);
        
        console.log("Bridge registrations updated successfully!");
        
        vm.stopBroadcast();
    }
}