# StablecoinSwitch Deployment Guide

This guide provides comprehensive instructions for deploying the StablecoinSwitch contract to various testnet environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Testnet Configurations](#testnet-configurations)
4. [Deployment Instructions](#deployment-instructions)
5. [Post-Deployment Setup](#post-deployment-setup)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Foundry**: Latest version with `forge`, `cast`, and `anvil`
- **Node.js**: v18+ for additional tooling
- **Git**: For version control

### Required Accounts

- **Wallet**: MetaMask or compatible Web3 wallet
- **API Keys**: 
  - Etherscan API key for Sepolia verification
  - Arbiscan API key for Arbitrum Sepolia verification
  - RPC provider keys (Alchemy, Infura, etc.)

### Testnet Funds

Ensure you have sufficient testnet ETH on the target networks:
- **Sepolia**: Get ETH from [Sepolia Faucet](https://sepoliafaucet.com/)
- **Arbitrum Sepolia**: Get ETH from [Chainlink Faucet](https://faucets.chain.link/arbitrum-sepolia)

## Environment Setup

### 1. Clone and Setup Repository

```bash
git clone <repository-url>
cd <repository-name>
forge install
```

### 2. Environment Variables

Create a `.env` file in the project root:

```bash
# Private Keys (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# RPC URLs
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
ARBITRUM_SEPOLIA_RPC_URL=https://arb-sepolia.g.alchemy.com/v2/your-api-key

# API Keys for Verification
ETHERSCAN_API_KEY=your_etherscan_api_key
ARBISCAN_API_KEY=your_arbiscan_api_key
```

### 3. Load Environment

```bash
source .env
```

## Testnet Configurations

### Sepolia Testnet

| Parameter | Value | Description |
|-----------|-------|-------------|
| **Chain ID** | 11155111 | Ethereum Sepolia testnet |
| **ETH/USD Price Feed** | `0x694AA1769357215DE4FAC081bf1f309aDC325306` | Chainlink ETH/USD aggregator |
| **USDC/USD Price Feed** | `0x14866185B1962B63C3Ea9E03Bc1da838bab34C19` | DAI/USD used as proxy (USDC/USD unavailable on Sepolia) |
| **USDC Token** | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | Sepolia USDC |
| **DAI Token** | `0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6` | Sepolia DAI |
| **USDT Token** | `0x7169D38820dfd117C3FA1f22a697dBA58d90BA06` | Sepolia USDT |
| **Base Fee** | 1,000,000 (1 USD) | 6 decimal places |
| **Gas Multiplier** | 120 (20% buffer) | Gas estimation buffer |

### Arbitrum Sepolia Testnet

| Parameter | Value | Description |
|-----------|-------|-------------|
| **Chain ID** | 421614 | Arbitrum Sepolia testnet |
| **ETH/USD Price Feed** | `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165` | Chainlink ETH/USD aggregator |
| **USDC/USD Price Feed** | `0x0153002d20B96532C639313c2d54c3dA09109309` | Chainlink USDC/USD aggregator |
| **USDC Token** | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` | Arbitrum Sepolia USDC |
| **DAI Token** | `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9` | Arbitrum Sepolia DAI |
| **Base Fee** | 1,000,000 (1 USD) | 6 decimal places |
| **Gas Multiplier** | 110 (10% buffer) | Lower buffer for L2 |

## Deployment Instructions

### 1. Compile Contracts

```bash
forge build
```

### 2. Run Tests (Recommended)

```bash
forge test -vv
```

### 3. Deploy to Sepolia

```bash
forge script script/DeployStablecoinSwitch.s.sol:DeployStablecoinSwitch \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 4. Deploy to Arbitrum Sepolia

```bash
forge script script/DeployStablecoinSwitch.s.sol:DeployStablecoinSwitch \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ARBISCAN_API_KEY
```

### 5. Deploy to Local Anvil (Testing)

```bash
# Start Anvil in separate terminal
anvil

# Deploy to local network
forge script script/DeployStablecoinSwitch.s.sol:DeployStablecoinSwitch \
  --rpc-url http://localhost:8545 \
  --broadcast
```

## Post-Deployment Setup

### 1. Verify Contract Deployment

Check that the contract was deployed successfully:

```bash
# Check contract code
cast code <CONTRACT_ADDRESS> --rpc-url <RPC_URL>

# Verify initialization
cast call <CONTRACT_ADDRESS> "owner()" --rpc-url <RPC_URL>
```

### 2. Configure Bridge Adapters

Add bridge adapters for cross-chain functionality:

```bash
# Example: Add a bridge adapter
cast send <CONTRACT_ADDRESS> \
  "setBridgeAdapter(uint256,address)" \
  421614 \
  <BRIDGE_ADAPTER_ADDRESS> \
  --private-key $PRIVATE_KEY \
  --rpc-url <RPC_URL>
```

### 3. Test Basic Functionality

```bash
# Check supported tokens
cast call <CONTRACT_ADDRESS> "supportedTokens(address)" <TOKEN_ADDRESS> --rpc-url <RPC_URL>

# Get route quote
cast call <CONTRACT_ADDRESS> \
  "getRouteQuote(address,address,uint256,uint256,uint8)" \
  <FROM_TOKEN> \
  <TO_TOKEN> \
  <AMOUNT> \
  <TO_CHAIN_ID> \
  <PRIORITY> \
  --rpc-url <RPC_URL>
```

## Verification

### Manual Verification (if auto-verification fails)

#### Sepolia

```bash
forge verify-contract \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" <ETH_USD_FEED> <USDC_USD_FEED> <OWNER_ADDRESS>) \
  <CONTRACT_ADDRESS> \
  src/StablecoinSwitch.sol:StablecoinSwitch
```

#### Arbitrum Sepolia

```bash
forge verify-contract \
  --chain arbitrum-sepolia \
  --etherscan-api-key $ARBISCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" <ETH_USD_FEED> <USDC_USD_FEED> <OWNER_ADDRESS>) \
  <CONTRACT_ADDRESS> \
  src/StablecoinSwitch.sol:StablecoinSwitch
```

## Contract Addresses

### Chainlink Price Feeds

#### Sepolia Testnet
- **ETH/USD**: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
- **BTC/USD**: `0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43`
- **DAI/USD**: `0x14866185B1962B63C3Ea9E03Bc1da838bab34C19`

#### Arbitrum Sepolia Testnet
- **ETH/USD**: `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165`
- **USDC/USD**: `0x0153002d20B96532C639313c2d54c3dA09109309`

### Test Tokens

#### Sepolia Testnet
- **USDC**: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- **DAI**: `0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6`
- **USDT**: `0x7169D38820dfd117C3FA1f22a697dBA58d90BA06`

#### Arbitrum Sepolia Testnet
- **USDC**: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- **DAI**: `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9`

## Troubleshooting

### Common Issues

#### Price feeds unavailable or stale

- Confirm feed addresses match Chainlink docs for your network:
  - Sepolia USDC/USD is unavailable; use DAI/USD `0x14866185B1962B63C3Ea9E03Bc1da838bab34C19` as a proxy.
  - Sepolia ETH/USD: `0x694AA1769357215DE4FAC081bf1f309aDC325306`.
- Check feed freshness with `latestRoundData`:
  ```bash
  cast call <FEED_ADDRESS> "latestRoundData()" --rpc-url $SEPOLIA_RPC_URL
  # Returns (roundId, answer, startedAt, updatedAt, answeredInRound)
  ```
- For testnets, set a larger staleness window to accommodate infrequent updates:
  ```bash
  # Using the configuration script
  SWITCH_ADDRESS=<DEPLOYED_SWITCH> \
  MAX_STALENESS_SECONDS=86400 \
  forge script contract/script/ConfigureStablecoinSwitch.s.sol:ConfigureStablecoinSwitch \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
  ```
- If your deployed contract exposes `areFeedsHealthy()`, you can call it directly:
  ```bash
  cast call <CONTRACT_ADDRESS> "areFeedsHealthy()" --rpc-url $SEPOLIA_RPC_URL
  ```

#### 1. Insufficient Gas

**Error**: `Transaction ran out of gas`

**Solution**: Increase gas limit or check gas multiplier settings

```bash
# Check current gas price
cast gas-price --rpc-url <RPC_URL>

# Estimate gas for transaction
cast estimate <CONTRACT_ADDRESS> "functionName()" --rpc-url <RPC_URL>
```

#### 2. Price Feed Issues

**Error**: `Price feed not responding`

**Solution**: Verify price feed addresses and network connectivity

```bash
# Test price feed directly
cast call <PRICE_FEED_ADDRESS> "latestRoundData()" --rpc-url <RPC_URL>
```

#### 3. Token Not Supported

**Error**: `Token not supported`

**Solution**: Add token support through owner functions

```bash
# Add token support
cast send <CONTRACT_ADDRESS> \
  "setTokenSupport(address,bool)" \
  <TOKEN_ADDRESS> \
  true \
  --private-key $PRIVATE_KEY \
  --rpc-url <RPC_URL>
```

#### 4. Verification Failures

**Error**: `Verification failed`

**Solutions**:
- Check constructor arguments encoding
- Ensure correct compiler version
- Verify API key permissions
- Use manual verification commands

### Getting Help

- **Documentation**: Check contract NatSpec comments
- **Tests**: Review test files for usage examples
- **Community**: Join project Discord/Telegram
- **Issues**: Create GitHub issues for bugs

## Security Considerations

### Pre-Deployment Checklist

- [ ] All tests passing
- [ ] Price feeds verified and active
- [ ] Constructor parameters validated
- [ ] Owner address confirmed
- [ ] Gas settings appropriate for network
- [ ] API keys secured and not exposed

### Post-Deployment Checklist

- [ ] Contract verified on block explorer
- [ ] Owner functions accessible
- [ ] Price feeds responding correctly
- [ ] Token support configured
- [ ] Bridge adapters configured (if applicable)
- [ ] Emergency procedures documented

### Monitoring

Set up monitoring for:
- Price feed health
- Contract balance changes
- Failed transactions
- Gas price fluctuations
- Bridge adapter status

## Mainnet Deployment Notes

**⚠️ Important**: This guide covers testnet deployment only. For mainnet deployment:

1. **Audit**: Ensure comprehensive security audit
2. **Insurance**: Consider smart contract insurance
3. **Gradual Rollout**: Start with limited functionality
4. **Monitoring**: Implement comprehensive monitoring
5. **Emergency Procedures**: Have pause/upgrade mechanisms ready

## License

This deployment guide is provided under the same license as the smart contract code.