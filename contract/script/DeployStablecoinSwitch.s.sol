// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/StablecoinSwitch.sol";
import "./BaseDeployment.s.sol";

/**
 * @title DeployStablecoinSwitch
 * @notice Deployment script for StablecoinSwitch contract
 * @dev Deploys StablecoinSwitch with proper initialization parameters for testnet environments
 */
contract DeployStablecoinSwitch is BaseDeployment {
    // Deployed contract instance
    StablecoinSwitch public stablecoinSwitch;
    
    // Deployment parameters
    struct DeploymentParams {
        address ethUsdPriceFeed;
        address usdcUsdPriceFeed;
        address usdcToken;
        address daiToken;
        address usdtToken;
        uint256 baseFeeUsd;
        uint256 gasMultiplier;
    }
    
    /**
     * @notice Main deployment function
     */
    function run() public override {
        // Set up the deployment configuration
        setUp();
        
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        DeploymentParams memory params = getDeploymentParams();
        
        // Deploy StablecoinSwitch
        stablecoinSwitch = new StablecoinSwitch(
            params.ethUsdPriceFeed,
            params.usdcUsdPriceFeed,
            config.deployer // Use the deployer from network config
        );
        
        // Initialize supported tokens
        initializeSupportedTokens(params);
        
        // Log deployment
        _logDeployment("StablecoinSwitch", address(stablecoinSwitch));
        
        vm.stopBroadcast();
        
        // Provide verification commands
        provideVerificationCommands();
    }
    
    /**
     * @notice Get deployment parameters based on chain ID
     */
    function getDeploymentParams() internal view returns (DeploymentParams memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 11155111) {
            // Sepolia Testnet
            return DeploymentParams({
                ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                usdcUsdPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E, // Using DAI/USD as proxy for USDC/USD
                usdcToken: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // Sepolia USDC
                daiToken: 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6, // Sepolia DAI
                usdtToken: 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06, // Sepolia USDT
                baseFeeUsd: 1e6, // $1 USD (6 decimals)
                gasMultiplier: 120 // 20% buffer
            });
        } else if (chainId == 421614) {
            // Arbitrum Sepolia Testnet
            return DeploymentParams({
                ethUsdPriceFeed: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165, // Arbitrum Sepolia ETH/USD
                usdcUsdPriceFeed: 0x0153002d20B96532C639313c2d54c3dA09109309, // Arbitrum Sepolia USDC/USD
                usdcToken: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d, // Arbitrum Sepolia USDC
                daiToken: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9, // Arbitrum Sepolia DAI
                usdtToken: address(0), // Placeholder - update with actual
                baseFeeUsd: 1e6, // $1 USD (6 decimals)
                gasMultiplier: 110 // 10% buffer (lower due to L2)
            });
        } else if (chainId == 31337) {
            // Anvil Local
            return DeploymentParams({
                ethUsdPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // Mainnet ETH/USD for testing
                usdcUsdPriceFeed: 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6, // Mainnet USDC/USD for testing
                usdcToken: address(0), // Mock USDC - update with actual address
                daiToken: 0x6B175474E89094C44Da98b954EedeAC495271d0F, // Mock DAI
                usdtToken: address(0), // Mock USDT - update with actual address
                baseFeeUsd: 1e6, // $1 USD (6 decimals)
                gasMultiplier: 120 // 20% buffer
            });
        } else {
            revert("Unsupported chain ID");
        }
    }
    
    /**
     * @notice Initialize supported tokens
     */
    function initializeSupportedTokens(DeploymentParams memory params) internal {
        // Add USDC support (if available)
        if (params.usdcToken != address(0)) {
            stablecoinSwitch.setTokenSupport(params.usdcToken, true);
        }
        
        // Add DAI support (if available)
        if (params.daiToken != address(0)) {
            stablecoinSwitch.setTokenSupport(params.daiToken, true);
        }
        
        // Add USDT support (if available)
        if (params.usdtToken != address(0)) {
            stablecoinSwitch.setTokenSupport(params.usdtToken, true);
        }
        
        console.log("Initialized supported tokens:");
        console.log("  USDC:", params.usdcToken);
        console.log("  DAI:", params.daiToken);
        if (params.usdtToken != address(0)) {
            console.log("  USDT:", params.usdtToken);
        }
    }
    
    /**
     * @notice Provide verification commands for different chains
     */
    function provideVerificationCommands() internal view {
        uint256 chainId = block.chainid;
        DeploymentParams memory params = getDeploymentParams();
        
        console.log("\n=== Contract Verification Commands ===");
        
        if (chainId == 11155111) {
            // Sepolia
            console.log("Sepolia Etherscan verification:");
            console.log("forge verify-contract \\");
            console.log("  --chain sepolia \\");
            console.log("  --etherscan-api-key $ETHERSCAN_API_KEY \\");
            console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,address)\"");
            console.log("    ", params.ethUsdPriceFeed);
            console.log("    ", params.usdcUsdPriceFeed); 
            console.log("    ", msg.sender, ") \\");
            console.log("  %s \\", address(stablecoinSwitch));
            console.log("  src/StablecoinSwitch.sol:StablecoinSwitch");
        } else if (chainId == 421614) {
            // Arbitrum Sepolia
            console.log("Arbitrum Sepolia verification:");
            console.log("forge verify-contract \\");
            console.log("  --chain arbitrum-sepolia \\");
            console.log("  --etherscan-api-key $ARBISCAN_API_KEY \\");
            console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,address)\"");
            console.log("    ", params.ethUsdPriceFeed);
            console.log("    ", params.usdcUsdPriceFeed); 
            console.log("    ", msg.sender, ") \\");
            console.log("  %s \\", address(stablecoinSwitch));
            console.log("  src/StablecoinSwitch.sol:StablecoinSwitch");
        }
        
        console.log("\n=== Deployment Summary ===");
        console.log("StablecoinSwitch deployed at:", address(stablecoinSwitch));
        console.log("Chain ID:", chainId);
        console.log("ETH/USD Price Feed:", params.ethUsdPriceFeed);
        console.log("USDC/USD Price Feed:", params.usdcUsdPriceFeed);
        console.log("Base Fee (USD):", params.baseFeeUsd);
        console.log("Gas Multiplier:", params.gasMultiplier);
    }
}