// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "./src/StablecoinSwitch.sol";

/**
 * @title ConsoleInteract
 * @dev Interactive console script for direct contract interaction
 * @notice Use with: forge script console_interact.sol --fork-url $SEPOLIA_RPC --interactive
 */
contract ConsoleInteract is Script {
    
    // ============ Deployed Contract Addresses ============
    
    address constant STABLECOIN_SWITCH = 0xC16A01431b1d980b0df125df4d8Df4633c4d5ba0;
    address constant DEPLOYER = 0x253eF0749119119f228a362f8F74A35C0A273fA5;
    
    // Known supported tokens
    address constant TOKEN_1 = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant TOKEN_2 = 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6;
    address constant TOKEN_3 = 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06;
    
    // ============ Contract Instances ============
    
    StablecoinSwitch public stablecoinSwitch;
    
    function setUp() public {
        stablecoinSwitch = StablecoinSwitch(STABLECOIN_SWITCH);
    }
    
    function run() public {
        console.log("============ Contract Interaction Console ============");
        console.log("StablecoinSwitch deployed at:", STABLECOIN_SWITCH);
        console.log("Deployer address:", DEPLOYER);
        console.log("");
        
        // Display basic contract info
        displayContractInfo();
        
        console.log("");
        console.log("============ Available Functions ============");
        console.log("Call these functions directly in the console:");
        console.log("- checkOwner()");
        console.log("- checkTokenSupport(address token)");
        console.log("- getAllSupportedTokens()");
        console.log("- getBalance(address account)");
        console.log("- getTokenBalance(address token, address account)");
        console.log("");
        console.log("Owner-only functions (requires private key):");
        console.log("- addTokenSupport(address token)");
        console.log("- removeTokenSupport(address token)");
        console.log("- performSwap(address from, address to, uint256 amount)");
    }
    
    // ============ Read Functions ============
    
    function displayContractInfo() public view {
        console.log("============ Contract Information ============");
        
        try stablecoinSwitch.owner() returns (address owner) {
            console.log("Contract Owner:", owner);
        } catch {
            console.log("Could not fetch owner");
        }
        
        console.log("");
        console.log("Known Supported Tokens:");
        console.log("Token 1:", TOKEN_1, "- Supported:", checkTokenSupport(TOKEN_1));
        console.log("Token 2:", TOKEN_2, "- Supported:", checkTokenSupport(TOKEN_2));
        console.log("Token 3:", TOKEN_3, "- Supported:", checkTokenSupport(TOKEN_3));
    }
    
    function checkOwner() public view returns (address) {
        return stablecoinSwitch.owner();
    }
    
    function getOwner() public view {
        address owner = StablecoinSwitch(STABLECOIN_SWITCH).owner();
        console2.log("Contract owner:", owner);
    }
    
    function checkTokenSupport(address token) public view returns (bool) {
        return stablecoinSwitch.isTokenSupported(token);
    }
    
    function getAllSupportedTokens() public view {
        console.log("============ Supported Tokens ============");
        console.log("Token 1:", TOKEN_1, "- Supported:", checkTokenSupport(TOKEN_1));
        console.log("Token 2:", TOKEN_2, "- Supported:", checkTokenSupport(TOKEN_2));
        console.log("Token 3:", TOKEN_3, "- Supported:", checkTokenSupport(TOKEN_3));
    }
    
    function getBalance(address account) public view returns (uint256) {
        return account.balance;
    }
    
    function getTokenBalance(address token, address account) public view returns (uint256) {
        // This would require the token contract to have a balanceOf function
        // For now, we'll just return a placeholder
        console.log("Checking token balance for:", account, "on token:", token);
        return 0; // Placeholder
    }
    
    // ============ Write Functions (Require Private Key) ============
    
    function addTokenSupport(address token) public {
        vm.startBroadcast();
        stablecoinSwitch.setTokenSupport(token, true);
        vm.stopBroadcast();
        console.log("Added support for token:", token);
    }
    
    function removeTokenSupport(address token) public {
        vm.startBroadcast();
        stablecoinSwitch.setTokenSupport(token, false);
        vm.stopBroadcast();
        console.log("Removed support for token:", token);
    }
    
    function performSwap(address fromToken, address toToken, uint256 amount) public {
        console2.log("Attempting to swap tokens");
        console2.log("Amount:", amount);
        console2.log("From token:", fromToken);
        console2.log("To token:", toToken);
        
        // Check if both tokens are supported
        require(checkTokenSupport(fromToken), "From token not supported");
        require(checkTokenSupport(toToken), "To token not supported");
        
        vm.startBroadcast();
        // Note: This assumes the swap function exists and is properly implemented
        // You may need to adjust based on the actual StablecoinSwitch implementation
        console.log("Swap would be executed here");
        vm.stopBroadcast();
    }
    
    // ============ Utility Functions ============
    
    function simulateSwap(address fromToken, address toToken, uint256 amount) public view {
        console.log("============ Swap Simulation ============");
        console.log("From Token:", fromToken);
        console.log("To Token:", toToken);
        console.log("Amount:", amount);
        console.log("From Token Supported:", checkTokenSupport(fromToken));
        console.log("To Token Supported:", checkTokenSupport(toToken));
        
        if (!checkTokenSupport(fromToken)) {
            console.log("ERROR: From token is not supported");
        }
        if (!checkTokenSupport(toToken)) {
            console.log("ERROR: To token is not supported");
        }
        if (checkTokenSupport(fromToken) && checkTokenSupport(toToken)) {
            console.log("SUCCESS: Swap would be possible");
        }
    }
    
    function checkContractState() public view {
        console.log("============ Contract State Check ============");
        console.log("Contract Address:", STABLECOIN_SWITCH);
        console.log("Contract Owner:", checkOwner());
        console.log("Contract Balance:", getBalance(STABLECOIN_SWITCH));
        
        // Check if contract is paused (if pause functionality exists)
        console.log("Checking contract functionality...");
        getAllSupportedTokens();
    }
}