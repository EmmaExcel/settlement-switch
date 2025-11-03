// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/RouteCalculator.sol";

contract RegisterAdaptersWithRouteCalculatorScript is Script {
    // Deployed contract addresses (Updated with latest fixed contracts)
    address constant ROUTE_CALCULATOR_SEPOLIA = 0x4cB5d76dc96f183E3c0DC0DCF8A8d71f6a10824D;
    
    // Updated adapter addresses with ETH support
    address constant LAYERZERO_ADAPTER = 0xB9B51072EB56ca874224460e65fa96f2d5BeD7f5;
    address constant ACROSS_ADAPTER = 0x8dfD68e1A08209b727149B2256140af9CE1978F0;
    address constant CONNEXT_ADAPTER = 0x2f097CD8623EB3b8Ea6d161fe87BbF154A238A3f;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Registering bridge adapters with RouteCalculator...");
        
        RouteCalculator calculator = RouteCalculator(ROUTE_CALCULATOR_SEPOLIA);
        
        // Register LayerZero adapter
        console.log("Registering LayerZero adapter:", LAYERZERO_ADAPTER);
        calculator.registerAdapter(LAYERZERO_ADAPTER);
        
        // Register Across adapter
        console.log("Registering Across adapter:", ACROSS_ADAPTER);
        calculator.registerAdapter(ACROSS_ADAPTER);
        
        // Register Connext adapter
        console.log("Registering Connext adapter:", CONNEXT_ADAPTER);
        calculator.registerAdapter(CONNEXT_ADAPTER);
        
        console.log("All adapters registered with RouteCalculator!");
        
        // Verify registration
        address[] memory registeredAdapters = calculator.getRegisteredAdapters();
        console.log("Total registered adapters:", registeredAdapters.length);
        
        for (uint256 i = 0; i < registeredAdapters.length; i++) {
            console.log("Adapter", i, ":", registeredAdapters[i]);
        }

        vm.stopBroadcast();
    }
}