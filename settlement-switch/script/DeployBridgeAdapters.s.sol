// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/adapters/LayerZeroAdapter.sol";
import "../src/adapters/AcrossAdapter.sol";
import "../src/adapters/ConnextAdapter.sol";
import "../src/core/BridgeRegistry.sol";
import "../src/core/SettlementSwitch.sol";

contract DeployBridgeAdaptersScript is Script {
    // Deployed core contract addresses (updated with new deployment)
    address constant BRIDGE_REGISTRY_SEPOLIA = 0x4C9d8BA4BcD7b4f7Eda75ECC0b853aF66fe6BAE7;
    address constant SETTLEMENT_SWITCH_SEPOLIA = 0x9a87668fADc9AD2D67698708E7c827Ff1D66435B;
    
    address constant BRIDGE_REGISTRY_ARBITRUM = 0x0876123851b855A570C70aE9fe72C51d1EAc0b5f;
    address constant SETTLEMENT_SWITCH_ARBITRUM = 0x00dAAb77E5dE7aA9643b7C82C704f4E84ead6c47;
    
    // Chain IDs
    uint256 constant ETHEREUM_SEPOLIA = 11155111;
    uint256 constant ARBITRUM_SEPOLIA = 421614;
    
    // LayerZero endpoints (testnet)
    address constant LZ_ENDPOINT_SEPOLIA = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address constant LZ_ENDPOINT_ARBITRUM = 0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3;
    
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(privateKey);
        
        // Deploy on Sepolia by default - the RPC URL determines the actual chain
        deployAdaptersOnSepolia();
        
        vm.stopBroadcast();
    }
    
    function runArbitrum() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(privateKey);
        
        deployAdaptersOnArbitrum();
        
        vm.stopBroadcast();
    }
    
    function deployAdaptersOnSepolia() internal {
        console.log("Deploying adapters on Ethereum Sepolia...");
        
        // Get the BridgeRegistry contract
        BridgeRegistry registry = BridgeRegistry(BRIDGE_REGISTRY_SEPOLIA);
        
        // Deploy LayerZero Adapter
        LayerZeroAdapter lzAdapter = new LayerZeroAdapter();
        console.log("LayerZero Adapter deployed at:", address(lzAdapter));
        
        // Deploy Across Adapter
        AcrossAdapter acrossAdapter = new AcrossAdapter();
        console.log("Across Adapter deployed at:", address(acrossAdapter));
        
        // Deploy Connext Adapter
        ConnextAdapter connextAdapter = new ConnextAdapter();
        console.log("Connext Adapter deployed at:", address(connextAdapter));
        
        // Prepare supported chains and tokens
        uint256[] memory supportedChains = new uint256[](2);
        supportedChains[0] = ETHEREUM_SEPOLIA; // Support bridging from Ethereum Sepolia
        supportedChains[1] = ARBITRUM_SEPOLIA; // Support bridging to Arbitrum Sepolia
        
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(0); // ETH (native token)
        
        // Register adapters with the registry
        console.log("Registering LayerZero Adapter...");
        registry.registerBridge(address(lzAdapter), supportedChains, supportedTokens);
        
        console.log("Registering Across Adapter...");
        registry.registerBridge(address(acrossAdapter), supportedChains, supportedTokens);
        
        console.log("Registering Connext Adapter...");
        registry.registerBridge(address(connextAdapter), supportedChains, supportedTokens);
        
        console.log("All adapters deployed and registered on Ethereum Sepolia!");
    }
    
    function deployAdaptersOnArbitrum() internal {
        console.log("Deploying adapters on Arbitrum Sepolia...");
        
        // Get the BridgeRegistry contract
        BridgeRegistry registry = BridgeRegistry(BRIDGE_REGISTRY_ARBITRUM);
        
        // Deploy LayerZero Adapter
        LayerZeroAdapter lzAdapter = new LayerZeroAdapter();
        console.log("LayerZero Adapter deployed at:", address(lzAdapter));
        
        // Deploy Across Adapter
        AcrossAdapter acrossAdapter = new AcrossAdapter();
        console.log("Across Adapter deployed at:", address(acrossAdapter));
        
        // Deploy Connext Adapter
        ConnextAdapter connextAdapter = new ConnextAdapter();
        console.log("Connext Adapter deployed at:", address(connextAdapter));
        
        // Prepare supported chains and tokens
        uint256[] memory supportedChains = new uint256[](2);
        supportedChains[0] = ARBITRUM_SEPOLIA; // Support bridging from Arbitrum Sepolia
        supportedChains[1] = ETHEREUM_SEPOLIA; // Support bridging to Ethereum Sepolia
        
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(0); // ETH (native token)
        
        // Register adapters with the registry
        console.log("Registering LayerZero Adapter...");
        registry.registerBridge(address(lzAdapter), supportedChains, supportedTokens);
        
        console.log("Registering Across Adapter...");
        registry.registerBridge(address(acrossAdapter), supportedChains, supportedTokens);
        
        console.log("Registering Connext Adapter...");
        registry.registerBridge(address(connextAdapter), supportedChains, supportedTokens);
        
        console.log("All adapters deployed and registered on Arbitrum Sepolia!");
    }
}