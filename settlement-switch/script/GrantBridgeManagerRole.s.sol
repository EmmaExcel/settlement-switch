// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/BridgeRegistry.sol";

/**
 * @title GrantBridgeManagerRole
 * @notice Script to grant BRIDGE_MANAGER_ROLE to deployer address
 */
contract GrantBridgeManagerRole is Script {
    
    // Deployed contract addresses
    address constant BRIDGE_REGISTRY_SEPOLIA = 0x36dFA1deBCa6b5e9D6069fE38Ba45e55806985b8;
    address constant BRIDGE_REGISTRY_ARBITRUM = 0x95B3cE0b0d5e42b2b88cAD686F235C27726125D4;
    
    function run() external {
        uint256 chainId = block.chainid;
        console.log("Chain ID:", chainId);
        
        vm.startBroadcast();
        
        if (chainId == 11155111) { // Sepolia
            grantRoleOnSepolia();
        } else if (chainId == 421614) { // Arbitrum Sepolia
            grantRoleOnArbitrum();
        } else {
            console.log("Unsupported chain ID:", chainId);
            revert("Unsupported chain");
        }
        
        vm.stopBroadcast();
    }
    
    function grantRoleOnSepolia() internal {
        console.log("Granting BRIDGE_MANAGER_ROLE on Sepolia...");
        
        BridgeRegistry registry = BridgeRegistry(BRIDGE_REGISTRY_SEPOLIA);
        address deployer = msg.sender;
        
        console.log("Deployer address:", deployer);
        console.log("BridgeRegistry address:", address(registry));
        
        // Grant BRIDGE_MANAGER_ROLE to deployer
        registry.grantRole(registry.BRIDGE_MANAGER_ROLE(), deployer);
        
        console.log("BRIDGE_MANAGER_ROLE granted to deployer on Sepolia");
    }
    
    function grantRoleOnArbitrum() internal {
        console.log("Granting BRIDGE_MANAGER_ROLE on Arbitrum Sepolia...");
        
        BridgeRegistry registry = BridgeRegistry(BRIDGE_REGISTRY_ARBITRUM);
        address deployer = msg.sender;
        
        console.log("Deployer address:", deployer);
        console.log("BridgeRegistry address:", address(registry));
        
        // Grant BRIDGE_MANAGER_ROLE to deployer
        registry.grantRole(registry.BRIDGE_MANAGER_ROLE(), deployer);
        
        console.log("BRIDGE_MANAGER_ROLE granted to deployer on Arbitrum Sepolia");
    }
}