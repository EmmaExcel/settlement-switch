# Direct Contract Interaction Guide

This guide shows you how to interact with your deployed contracts directly, bypassing tests and deployment scripts.

## 🚀 Quick Start

### 1. Set Up Your Environment

```bash
# Copy the environment template
cp .env.local .env

# Edit .env and add your RPC URL and private key
# NEVER commit your private key to version control!
export PRIVATE_KEY="your_private_key_here"
```

### 2. Choose Your Interaction Method

You have three ways to interact with contracts directly:

#### Method 1: Shell Script (Easiest)
```bash
# Make the script executable (already done)
chmod +x interact.sh

# Show available commands
./interact.sh help

# Example interactions
./interact.sh owner
./interact.sh check_token 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
./interact.sh balance 0x253eF0749119119f228a362f8F74A35C0A273fA5
```

#### Method 2: Direct Cast Commands
```bash
# Get contract owner
cast call 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 "owner()" --rpc-url https://sepolia.infura.io/v3/YOUR_KEY

# Check token support
cast call 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 "isTokenSupported(address)" 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 --rpc-url https://sepolia.infura.io/v3/YOUR_KEY

# Add token support (requires private key)
cast send 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 "setTokenSupport(address,bool)" 0xNEW_TOKEN_ADDRESS true --private-key $PRIVATE_KEY --rpc-url https://sepolia.infura.io/v3/YOUR_KEY
```

#### Method 3: Forge Console (Most Interactive)
```bash
# Start interactive console
forge script console_interact.sol --fork-url https://sepolia.infura.io/v3/YOUR_KEY --interactive

# In the console, you can call functions directly:
# checkOwner()
# checkTokenSupport(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)
# getAllSupportedTokens()
```

## 📋 Deployed Contracts

### Sepolia Testnet (Chain ID: 11155111)

| Contract | Address | Description |
|----------|---------|-------------|
| StablecoinSwitch | `0xc16a01431b1d980b0df125df4d8df4633c4d5ba0` | Main stablecoin switching contract |

### Supported Tokens (from deployment)
- Token 1: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- Token 2: `0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6`
- Token 3: `0x7169D38820dfd117C3FA1f22a697dBA58d90BA06`

## 🔧 Available Interactions

### Read Operations (No Gas Required)

#### Check Contract Owner
```bash
./interact.sh owner
# or
cast call 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 "owner()" --rpc-url $SEPOLIA_RPC
```

#### Check Token Support
```bash
./interact.sh check_token 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
# or
cast call 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 "isTokenSupported(address)" 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 --rpc-url $SEPOLIA_RPC
```

#### Check ETH Balance
```bash
./interact.sh balance 0x253eF0749119119f228a362f8F74A35C0A273fA5
# or
cast balance 0x253eF0749119119f228a362f8F74A35C0A273fA5 --rpc-url $SEPOLIA_RPC --ether
```

### Write Operations (Require Gas & Private Key)

#### Add Token Support (Owner Only)
```bash
export PRIVATE_KEY="your_private_key"
./interact.sh add_token 0xNEW_TOKEN_ADDRESS
# or
cast send 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 "setTokenSupport(address,bool)" 0xNEW_TOKEN_ADDRESS true --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC
```

#### Remove Token Support (Owner Only)
```bash
./interact.sh remove_token 0xTOKEN_TO_REMOVE
# or
cast send 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 "setTokenSupport(address,bool)" 0xTOKEN_TO_REMOVE false --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC
```

#### Perform Token Swap
```bash
./interact.sh swap 0xFROM_TOKEN 0xTO_TOKEN 1000000000000000000  # 1 token (18 decimals)
```

## 🛠 Advanced Usage

### Using Forge Console for Complex Interactions

1. Start the interactive console:
```bash
forge script console_interact.sol --fork-url https://sepolia.infura.io/v3/YOUR_KEY --interactive
```

2. Available functions in console:
```solidity
// Read functions
checkOwner()
checkTokenSupport(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)
getAllSupportedTokens()
getBalance(0x253eF0749119119f228a362f8F74A35C0A273fA5)
checkContractState()

// Simulation functions
simulateSwap(0xFROM_TOKEN, 0xTO_TOKEN, 1000000000000000000)

// Write functions (require --broadcast flag)
addTokenSupport(0xNEW_TOKEN)
removeTokenSupport(0xOLD_TOKEN)
```

### Custom Cast Commands

You can create your own cast commands for specific interactions:

```bash
# Get contract bytecode
cast code 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 --rpc-url $SEPOLIA_RPC

# Get storage slot
cast storage 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 0 --rpc-url $SEPOLIA_RPC

# Call any function with custom ABI
cast call 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 "functionName(uint256)" 123 --rpc-url $SEPOLIA_RPC
```

## 🔐 Security Best Practices

1. **Never commit private keys** to version control
2. **Use environment variables** for sensitive data
3. **Test on testnets first** before mainnet interactions
4. **Verify contract addresses** before sending transactions
5. **Use hardware wallets** for mainnet interactions

## 🐛 Troubleshooting

### Common Issues

1. **"Insufficient funds"**: Make sure your wallet has enough ETH for gas
2. **"Nonce too low"**: Your transaction nonce is behind, wait or reset
3. **"Contract not found"**: Verify the contract address and network
4. **"Function not found"**: Check the function signature and ABI

### Getting Help

```bash
# Check if contract exists
cast code 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 --rpc-url $SEPOLIA_RPC

# Get transaction receipt
cast receipt 0xTRANSACTION_HASH --rpc-url $SEPOLIA_RPC

# Estimate gas for a transaction
cast estimate 0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 "setTokenSupport(address,bool)" 0xTOKEN true --rpc-url $SEPOLIA_RPC
```

## 📚 Additional Resources

- [Foundry Cast Documentation](https://book.getfoundry.sh/reference/cast/)
- [Ethereum JSON-RPC API](https://ethereum.org/en/developers/docs/apis/json-rpc/)
- [Sepolia Testnet Faucet](https://sepoliafaucet.com/)

## 🎯 Next Steps

1. Set up your environment variables
2. Try the read operations first
3. Test write operations on testnet
4. Build your own interaction scripts
5. Integrate with your frontend application

Happy interacting! 🚀