// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/SettlementSwitch.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract BridgeETHScript is Script {
    // Deployed contract addresses (updated with actual deployed addresses)
    address payable constant SETTLEMENT_SWITCH_SEPOLIA = payable(0x9a87668fADc9AD2D67698708E7c827Ff1D66435B);
    address payable constant SETTLEMENT_SWITCH_ARBITRUM = payable(0x00dAAb77E5dE7aA9643b7C82C704f4E84ead6c47);
    
    // Chain IDs
    uint256 constant ETHEREUM_SEPOLIA = 11155111;
    uint256 constant ARBITRUM_SEPOLIA = 421614;
    
    // ETH address (0x0 represents native ETH)
    address constant ETH_ADDRESS = address(0);
    
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(privateKey);
        
        console.log("Bridging ETH from Ethereum Sepolia to Arbitrum Sepolia");
        console.log("Sender:", sender);
        
        vm.startBroadcast(privateKey);
        
        // Connect to Settlement Switch on Sepolia
        SettlementSwitch settlementSwitch = SettlementSwitch(SETTLEMENT_SWITCH_SEPOLIA);
        
        // Bridge parameters
        uint256 amountToBridge = 0.01 ether; // Bridge 0.01 ETH
        address recipient = sender; // Send to same address on Arbitrum
        
        // Create route preferences with all required fields
        IBridgeAdapter.RoutePreferences memory routePrefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.FASTEST,
            maxSlippageBps: 100, // 1% slippage
            maxFeeWei: 0.01 ether, // Max fee of 0.01 ETH
            maxTimeMinutes: 30, // 30 minutes max
            allowMultiHop: false
        });
        
        console.log("Bridging amount:", amountToBridge);
        console.log("To recipient:", recipient);
        
        // Execute bridge with auto-route
        bytes32 transferId = settlementSwitch.bridgeWithAutoRoute{value: amountToBridge}(
            ETH_ADDRESS,        // tokenIn (ETH)
            ETH_ADDRESS,        // tokenOut (ETH on Arbitrum)
            amountToBridge,     // amount
            ETHEREUM_SEPOLIA,   // srcChainId
            ARBITRUM_SEPOLIA,   // dstChainId
            recipient,          // recipient
            routePrefs,         // route preferences
            ""                  // no permit data needed for ETH
        );
        
        console.log("Bridge transfer initiated!");
        console.log("Transfer ID:", vm.toString(transferId));
        console.log("Monitor this transfer ID to track completion");
        
        vm.stopBroadcast();
    }
    
    // Helper function to check transfer status
    function checkTransferStatus(bytes32 transferId) external view {
        SettlementSwitch settlementSwitch = SettlementSwitch(SETTLEMENT_SWITCH_SEPOLIA);
        IBridgeAdapter.Transfer memory transfer = settlementSwitch.getTransfer(transferId);
        
        console.log("Transfer Status for ID:", vm.toString(transferId));
        console.log("Status:", uint256(transfer.status));
        console.log("Sender:", transfer.sender);
        console.log("Recipient:", transfer.recipient);
        console.log("Amount:", transfer.route.amountIn);
        console.log("Initiated at:", transfer.initiatedAt);
        console.log("Completed at:", transfer.completedAt);
    }
}