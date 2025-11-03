// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/core/SettlementSwitch.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract TestETHBridgingScript is Script {
    // Settlement Switch address on Sepolia (with correct checksum)
    address payable constant SETTLEMENT_SWITCH = payable(0x4C9d8BA4BcD7b4f7Eda75ECC0b853aF66fe6BAE7);
    
    // Chain IDs
    uint256 constant ETHEREUM_SEPOLIA = 11155111;
    uint256 constant ARBITRUM_SEPOLIA = 421614;
    
    // Test parameters
    uint256 constant BRIDGE_AMOUNT = 0.001 ether; // Small test amount
    address constant ETH_ADDRESS = address(0);
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Testing ETH bridging with Settlement Switch...");
        console.log("Deployer address:", deployer);
        console.log("Settlement Switch address:", SETTLEMENT_SWITCH);
        console.log("Bridge amount:", BRIDGE_AMOUNT);
        
        // Check deployer balance
        uint256 balance = deployer.balance;
        console.log("Deployer ETH balance:", balance);
        
        if (balance < BRIDGE_AMOUNT + 0.01 ether) { // Need extra for gas
            console.log("ERROR: Insufficient ETH balance for bridging test");
            return;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        SettlementSwitch settlementSwitch = SettlementSwitch(SETTLEMENT_SWITCH);
        
        // Use bridgeWithAutoRoute for automatic route selection
        try settlementSwitch.bridgeWithAutoRoute{value: BRIDGE_AMOUNT}(
            ETH_ADDRESS,                                    // tokenIn (ETH)
            ETH_ADDRESS,                                    // tokenOut (ETH)
            BRIDGE_AMOUNT,                                  // amount
            ETHEREUM_SEPOLIA,                               // srcChainId
            ARBITRUM_SEPOLIA,                               // dstChainId
            deployer,                                       // recipient
            IBridgeAdapter.RoutePreferences({               // preferences
                mode: IBridgeAdapter.RoutingMode.BALANCED,      // balanced routing
                maxSlippageBps: 500,                            // 5% max slippage
                maxFeeWei: 0.01 ether,                          // max fee
                maxTimeMinutes: 60,                             // 1 hour max time
                allowMultiHop: false                            // no multi-hop
            }),
            ""                                              // empty permit data
        ) returns (bytes32 transferId) {
            console.log("SUCCESS: ETH bridging transaction submitted!");
            console.log("Transfer ID:", vm.toString(transferId));
            console.log("Bridging", BRIDGE_AMOUNT, "ETH from Sepolia to Arbitrum Sepolia");
            console.log("Recipient:", deployer);
        } catch Error(string memory reason) {
            console.log("ERROR: Bridge transaction failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("ERROR: Bridge transaction failed with low-level error");
            console.logBytes(lowLevelData);
        }
        
        vm.stopBroadcast();
    }
}