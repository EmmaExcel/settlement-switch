// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract CheckBridgeAdapterRoutesScript is Script {
    // Updated bridge adapter addresses with ETH support
    address constant LAYERZERO_ADAPTER = 0xB9B51072EB56ca874224460e65fa96f2d5BeD7f5;
    address constant ACROSS_ADAPTER = 0x8dfD68e1A08209b727149B2256140af9CE1978F0;
    address constant CONNEXT_ADAPTER = 0x2f097CD8623EB3b8Ea6d161fe87BbF154A238A3f;
    
    // Chain IDs
    uint256 constant ETHEREUM_SEPOLIA = 11155111;
    uint256 constant ARBITRUM_SEPOLIA = 421614;
    
    function run() external {
        console.log("Checking bridge adapter route support...");
        
        // Check LayerZero adapter
        console.log("\n=== LayerZero Adapter ===");
        console.log("Address:", LAYERZERO_ADAPTER);
        checkAdapterRoute(LAYERZERO_ADAPTER, "LayerZero");
        
        // Check Across adapter
        console.log("\n=== Across Adapter ===");
        console.log("Address:", ACROSS_ADAPTER);
        checkAdapterRoute(ACROSS_ADAPTER, "Across");
        
        // Check Connext adapter
        console.log("\n=== Connext Adapter ===");
        console.log("Address:", CONNEXT_ADAPTER);
        checkAdapterRoute(CONNEXT_ADAPTER, "Connext");
    }
    
    function checkAdapterRoute(address adapter, string memory name) internal {
        IBridgeAdapter bridgeAdapter = IBridgeAdapter(adapter);
        
        // Test ETH bridging from Sepolia to Arbitrum Sepolia
        bool supportsSepoliaToArbitrum = bridgeAdapter.supportsRoute(
            address(0), // ETH
            address(0), // ETH
            ETHEREUM_SEPOLIA,
            ARBITRUM_SEPOLIA
        );
        
        console.log(string.concat(name, " supports Sepolia -> Arbitrum Sepolia (ETH):"), supportsSepoliaToArbitrum);
        
        // Test reverse direction
        bool supportsArbitrumToSepolia = bridgeAdapter.supportsRoute(
            address(0), // ETH
            address(0), // ETH
            ARBITRUM_SEPOLIA,
            ETHEREUM_SEPOLIA
        );
        
        console.log(string.concat(name, " supports Arbitrum Sepolia -> Sepolia (ETH):"), supportsArbitrumToSepolia);
    }
}