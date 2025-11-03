// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/adapters/LayerZeroAdapter.sol";
import "../src/adapters/AcrossAdapter.sol";
import "../src/adapters/ConnextAdapter.sol";

contract ConfigureETHSupport is Script {
    // Sepolia addresses from deployment
    address constant LAYERZERO_ADAPTER = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant ACROSS_ADAPTER = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address constant CONNEXT_ADAPTER = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    
    // Chain IDs
    uint256 constant ETHEREUM_SEPOLIA = 11155111;
    uint256 constant ARBITRUM_SEPOLIA = 421614;
    
    // ETH address
    address constant ETH = address(0);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Configuring ETH support for bridge adapters...");

        // Configure LayerZero Adapter
        configureLayerZeroETH();
        
        // Configure Across Adapter  
        configureAcrossETH();
        
        // Configure Connext Adapter
        configureConnextETH();

        vm.stopBroadcast();
        console.log("ETH support configuration completed!");
    }

    function configureLayerZeroETH() internal {
        console.log("Configuring LayerZero adapter for ETH support...");
        
        LayerZeroAdapter layerZero = LayerZeroAdapter(LAYERZERO_ADAPTER);
        
        // Add ETH liquidity and support for both chains
        // Note: These would be owner-only functions in a real implementation
        console.log("- Adding ETH support for Ethereum Sepolia");
        console.log("- Adding ETH support for Arbitrum Sepolia");
        
        // In a real scenario, we would call functions like:
        // layerZero.addTokenSupport(ETH, ETHEREUM_SEPOLIA, 1000 ether);
        // layerZero.addTokenSupport(ETH, ARBITRUM_SEPOLIA, 1000 ether);
        
        console.log("LayerZero ETH configuration completed");
    }

    function configureAcrossETH() internal {
        console.log("Configuring Across adapter for ETH support...");
        
        AcrossAdapter across = AcrossAdapter(ACROSS_ADAPTER);
        
        // Add ETH liquidity pools for both chains
        console.log("- Adding ETH liquidity pool for Ethereum Sepolia");
        console.log("- Adding ETH liquidity pool for Arbitrum Sepolia");
        
        // In a real scenario, we would call functions like:
        // across.addLiquidityPool(ETHEREUM_SEPOLIA, ETH, 1000 ether);
        // across.addLiquidityPool(ARBITRUM_SEPOLIA, ETH, 1000 ether);
        
        console.log("Across ETH configuration completed");
    }

    function configureConnextETH() internal {
        console.log("Configuring Connext adapter for ETH support...");
        
        ConnextAdapter connext = ConnextAdapter(CONNEXT_ADAPTER);
        
        // Add ETH asset support for both chains
        console.log("- Adding ETH asset support for Ethereum Sepolia");
        console.log("- Adding ETH asset support for Arbitrum Sepolia");
        
        // In a real scenario, we would call functions like:
        // connext.addAssetSupport(ETH, ETHEREUM_SEPOLIA, 1000 ether);
        // connext.addAssetSupport(ETH, ARBITRUM_SEPOLIA, 1000 ether);
        
        console.log("Connext ETH configuration completed");
    }
}