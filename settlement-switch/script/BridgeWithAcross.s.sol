// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/interfaces/IBridgeAdapter.sol";
import "../src/interfaces/ISettlementSwitch.sol";
import "../src/core/FeeManager.sol";

contract BridgeWithAcross is Script {
    // Contract addresses
    address constant SETTLEMENT_SWITCH = 0x9a87668fADc9AD2D67698708E7c827Ff1D66435B;
    address constant ACROSS_ADAPTER = 0x8dfD68e1A08209b727149B2256140af9CE1978F0;
    address payable constant FEE_MANAGER = payable(0x4D4f731416Ad43523441887ee49Ccd8bea78ac5f);
    
    // Chain IDs
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    
    // ETH address (native token)
    address constant ETH_ADDRESS = address(0);
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Bridging ETH using Across adapter directly...");
        console.log("Deployer:", deployer);
        console.log("Settlement Switch:", SETTLEMENT_SWITCH);
        console.log("Across Adapter:", ACROSS_ADAPTER);
        
        // Amount to bridge (0.001 ETH)
        uint256 amount = 0.001 ether;
        console.log("Amount to bridge:", amount);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get route metrics from Across adapter
        IBridgeAdapter acrossAdapter = IBridgeAdapter(ACROSS_ADAPTER);
        IBridgeAdapter.RouteMetrics memory metrics = acrossAdapter.getRouteMetrics(
            ETH_ADDRESS,
            ETH_ADDRESS,
            amount,
            SEPOLIA_CHAIN_ID,
            ARBITRUM_SEPOLIA_CHAIN_ID
        );
        
        console.log("Route metrics:");
        console.log("  Bridge Fee:", metrics.bridgeFee);
        console.log("  Total Cost:", metrics.totalCostWei);
        console.log("  Estimated Time:", metrics.estimatedTimeMinutes, "minutes");
        
        // Calculate protocol fee
        FeeManager feeManager = FeeManager(FEE_MANAGER);
        uint256 protocolFee = feeManager.calculateFee("protocol", amount, SEPOLIA_CHAIN_ID, deployer);
        console.log("Protocol fee:", protocolFee);
        
        // Total amount needed = bridge amount + protocol fee
        uint256 totalRequired = amount + protocolFee;
        console.log("Total ETH required:", totalRequired);
        
        // Calculate expected output amount
        uint256 expectedOutput = amount - metrics.bridgeFee;
        console.log("Expected output amount:", expectedOutput);
        
        // Construct the route manually
        IBridgeAdapter.Route memory route = IBridgeAdapter.Route({
            adapter: ACROSS_ADAPTER,
            tokenIn: ETH_ADDRESS,
            tokenOut: ETH_ADDRESS,
            amountIn: amount,
            amountOut: expectedOutput,
            srcChainId: SEPOLIA_CHAIN_ID,
            dstChainId: ARBITRUM_SEPOLIA_CHAIN_ID,
            metrics: metrics,
            adapterData: "",  // Across doesn't need special adapter data for ETH
            deadline: block.timestamp + 3600  // 1 hour deadline
        });
        
        // Execute the bridge
        ISettlementSwitch settlementSwitch = ISettlementSwitch(SETTLEMENT_SWITCH);
        console.log("Executing bridge transaction...");
        bytes32 transferId = settlementSwitch.executeBridge{value: totalRequired}(
            route,
            deployer,  // recipient (same as sender for this test)
            ""  // no permit data needed for ETH
        );
        
        console.log("Bridge transaction successful!");
        console.log("Transfer ID:", vm.toString(transferId));
        
        vm.stopBroadcast();
    }
}