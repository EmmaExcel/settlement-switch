// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title BridgeETH
 * @dev Simple script to bridge ETH from Ethereum Sepolia to Arbitrum Sepolia
 * @notice Uses the native Arbitrum bridge for ETH deposits
 */
contract BridgeETH is Script {
    // Arbitrum Sepolia L1 Gateway Router
    address constant ARBITRUM_L1_GATEWAY_ROUTER = 0xcE18836b233C83325Cc8848CA4487e94C6288264;
    
    // Your deployer address
    address constant DEPLOYER = 0x253eF0749119119f228a362f8F74A35C0A273fA5;
    
    // Amount to bridge (0.001 ETH)
    uint256 constant BRIDGE_AMOUNT = 0.001 ether;
    
    // Gas parameters for Arbitrum
    uint256 constant MAX_GAS = 1000000;
    uint256 constant GAS_PRICE_BID = 1000000000; // 1 gwei
    uint256 constant MAX_SUBMISSION_COST = 0.01 ether;

    /**
     * @dev Helper function to get private key from environment variable
     * Handles both with and without 0x prefix
     */
    function getPrivateKey() internal view returns (uint256) {
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            return key;
        } catch {
            // If parsing as uint fails, try parsing as string and adding 0x prefix
            string memory keyStr = vm.envString("PRIVATE_KEY");
            return vm.parseUint(string.concat("0x", keyStr));
        }
    }

    function run() external {
        // Get private key from environment (handle with or without 0x prefix)
        uint256 deployerPrivateKey = getPrivateKey();
        
        console.log("=== ETH Bridge to Arbitrum Sepolia ===");
        console.log("From: Ethereum Sepolia");
        console.log("To: Arbitrum Sepolia");
        console.log("Amount:", BRIDGE_AMOUNT);
        console.log("Deployer:", DEPLOYER);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Calculate total cost (bridge amount + fees)
        uint256 totalCost = BRIDGE_AMOUNT + MAX_SUBMISSION_COST + (MAX_GAS * GAS_PRICE_BID);
        
        console.log("Total cost (including fees):", totalCost);
        console.log("Current balance:", DEPLOYER.balance);
        
        require(DEPLOYER.balance >= totalCost, "Insufficient balance for bridging");
        
        // Use the native Arbitrum bridge
        // For ETH, we can use the inbox directly
        address arbitrumInbox = 0xaAe29B0366299461418F5324a79Afc425BE5ae21; // Arbitrum Sepolia Inbox
        
        // Create retryable ticket for ETH deposit
        IInbox(arbitrumInbox).createRetryableTicket{value: totalCost}(
            DEPLOYER,           // to
            BRIDGE_AMOUNT,      // l2CallValue
            MAX_SUBMISSION_COST, // maxSubmissionCost
            DEPLOYER,           // excessFeeRefundAddress
            DEPLOYER,           // callValueRefundAddress
            MAX_GAS,            // gasLimit
            GAS_PRICE_BID,      // maxFeePerGas
            ""                  // data
        );
        
        vm.stopBroadcast();
        
        console.log("=== Bridge Transaction Submitted ===");
        console.log("ETH bridged successfully!");
        console.log("Wait ~10-15 minutes for completion");
        console.log("Check balance on Arbitrum Sepolia:");
        console.log("cast balance", DEPLOYER, "--rpc-url https://sepolia-rollup.arbitrum.io/rpc");
    }
}

// Minimal interface for Arbitrum Inbox
interface IInbox {
    function createRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256);
}