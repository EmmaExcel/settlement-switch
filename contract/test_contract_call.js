const { ethers } = require('ethers');

// Configuration
const RPC_URL = 'https://ethereum-sepolia-rpc.publicnode.com';
const CONTRACT_ADDRESS = '0xc16a01431b1d980b0df125df4d8df4633c4d5ba0';
const TOKEN_ADDRESS = '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238';

// Simple ABI for isTokenSupported function
const ABI = [
    "function isTokenSupported(address token) view returns (bool)"
];

async function testContractCall() {
    try {
        console.log('Testing contract call...');
        console.log('RPC URL:', RPC_URL);
        console.log('Contract Address:', CONTRACT_ADDRESS);
        console.log('Token Address:', TOKEN_ADDRESS);
        
        // Create provider
        const provider = new ethers.JsonRpcProvider(RPC_URL);
        
        // Test basic connectivity
        console.log('\n1. Testing RPC connectivity...');
        const blockNumber = await provider.getBlockNumber();
        console.log('Current block number:', blockNumber);
        
        // Create contract instance
        console.log('\n2. Creating contract instance...');
        const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, provider);
        
        // Test contract call
        console.log('\n3. Calling isTokenSupported...');
        const startTime = Date.now();
        const isSupported = await contract.isTokenSupported(TOKEN_ADDRESS);
        const endTime = Date.now();
        
        console.log('Result:', isSupported);
        console.log('Call duration:', endTime - startTime, 'ms');
        
        console.log('\n✅ Contract call successful!');
        
    } catch (error) {
        console.error('\n❌ Contract call failed:');
        console.error('Error:', error.message);
        if (error.code) {
            console.error('Error code:', error.code);
        }
        if (error.reason) {
            console.error('Reason:', error.reason);
        }
    }
}

testContractCall();