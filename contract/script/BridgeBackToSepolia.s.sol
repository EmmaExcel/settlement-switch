// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface IL2ArbitrumGateway {
    function outboundTransfer(
        address _l1Token,
        address _to,
        uint256 _amount,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        bytes calldata _data
    ) external payable returns (bytes memory);
}

contract BridgeBackToSepolia is Script {
    // Arbitrum Sepolia ETH Gateway
    address constant ETH_GATEWAY = 0x6e244cD02BBB8a6dbd7F626f05B2ef82151Ab502;
    
    // Bridge amount (leaving some for gas)
    uint256 constant BRIDGE_AMOUNT = 0.0005 ether; // Bridge 0.0005 ETH back
    uint256 constant MAX_GAS = 100000; // Gas limit for L1 execution
    uint256 constant GAS_PRICE_BID = 1000000000; // 1 gwei
    
    function run() external {
        uint256 deployerPrivateKey = getPrivateKey();
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Bridging ETH from Arbitrum Sepolia back to Ethereum Sepolia");
        console.log("Deployer address:", deployer);
        console.log("Bridge amount:", BRIDGE_AMOUNT);
        
        // Check balance
        uint256 balance = deployer.balance;
        console.log("Current balance:", balance);
        
        require(balance >= BRIDGE_AMOUNT + 0.001 ether, "Insufficient balance for bridging + gas");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Use ETH Gateway for withdrawal
        IL2ArbitrumGateway gateway = IL2ArbitrumGateway(ETH_GATEWAY);
        
        // Prepare data for withdrawal
        bytes memory data = abi.encode(MAX_GAS, "");
        
        // Execute ETH withdrawal
        gateway.outboundTransfer{value: BRIDGE_AMOUNT}(
            address(0), // ETH token address
            deployer,   // Destination address on L1
            BRIDGE_AMOUNT,
            MAX_GAS,
            GAS_PRICE_BID,
            data
        );
        
        vm.stopBroadcast();
        
        console.log("Bridge transaction completed!");
        console.log("Note: Withdrawal will take ~7 days to finalize on Ethereum Sepolia");
        console.log("You can track the withdrawal status on the Arbitrum bridge interface:");
        console.log("https://bridge.arbitrum.io/");
    }
    
    function getPrivateKey() internal view returns (uint256) {
        string memory privateKeyStr = vm.envString("PRIVATE_KEY");
        
        // Handle both with and without 0x prefix
        if (bytes(privateKeyStr).length == 66 && 
            bytes(privateKeyStr)[0] == '0' && 
            bytes(privateKeyStr)[1] == 'x') {
            // Has 0x prefix, parse directly
            return vm.parseUint(privateKeyStr);
        } else {
            // No 0x prefix, add it
            string memory prefixedKey = string(abi.encodePacked("0x", privateKeyStr));
            return vm.parseUint(prefixedKey);
        }
    }
}