# Arbitrum Foundry Template

A comprehensive Foundry template optimized for Arbitrum development, featuring gas-efficient smart contracts, deployment scripts, and testing patterns specifically designed for Layer 2 development.

## 🚀 Features

- **Arbitrum-Optimized Contracts**: Pre-built ERC20, ERC721, and DeFi staking contracts optimized for Arbitrum's low gas costs
- **Multi-Network Deployment**: Support for Arbitrum One, Arbitrum Sepolia, and Ethereum networks
- **Comprehensive Testing**: Full test suite with Arbitrum-specific testing patterns and gas optimization tests
- **Professional Deployment Scripts**: Automated deployment with verification and logging
- **Development Tools**: Makefile with common commands and environment configuration

## 📋 Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/downloads)
- [Node.js](https://nodejs.org/) (optional, for additional tooling)

## 🛠 Installation

1. **Clone this template:**
   ```bash
   git clone <your-repo-url>
   cd arbitrum-foundry-template
   ```

2. **Install Foundry dependencies:**
   ```bash
   forge install
   ```

3. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

4. **Build the project:**
   ```bash
   forge build
   ```

## 🔧 Configuration

### Environment Setup

Copy `.env.example` to `.env` and configure the following:

#### Required Variables
```bash
# RPC URLs
ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc

# Private Key (NEVER commit real keys!)
PRIVATE_KEY=0x...

# API Keys for verification
ARBITRUM_API_KEY=your_arbitrum_api_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

#### Optional Variables
- `ALCHEMY_API_KEY`: For enhanced RPC endpoints
- `INFURA_PROJECT_ID`: Alternative RPC provider
- `TENDERLY_*`: For advanced debugging and monitoring

### Network Configuration

The template supports multiple networks configured in `foundry.toml`:

- **Arbitrum One** (mainnet): Chain ID 42161
- **Arbitrum Sepolia** (testnet): Chain ID 421614
- **Ethereum Mainnet**: Chain ID 1
- **Sepolia**: Chain ID 11155111
- **Anvil** (local): Chain ID 31337

## 📦 Smart Contracts

### ArbitrumToken (ERC20)

A gas-optimized ERC20 token with advanced features:

```solidity
// Key Features:
- EIP-2612 Permit support
- Burnable tokens
- Owner-controlled minting with daily limits
- Batch operations for gas efficiency
- Emergency token recovery
```

**Deployment:**
```bash
forge script script/DeployArbitrum.s.sol:DeployArbitrum --rpc-url arbitrum --broadcast --verify
```

### ArbitrumNFT (ERC721)

A feature-rich NFT contract optimized for Arbitrum:

```solidity
// Key Features:
- Enumerable and URI storage
- Batch minting capabilities
- Whitelist functionality
- Royalty support (EIP-2981)
- Reveal mechanism for mystery drops
```

### ArbitrumStaking (DeFi)

A sophisticated staking contract with multiple reward mechanisms:

```solidity
// Key Features:
- Multiple reward tokens
- Flexible staking periods
- Compound staking
- Emergency withdrawal
- Gas-optimized calculations
```

## 🧪 Testing

### Run All Tests
```bash
forge test
```

### Run Tests with Gas Reports
```bash
forge test --gas-report
```

### Run Fork Tests
```bash
forge test --fork-url $ARBITRUM_RPC_URL
```

### Run Specific Test File
```bash
forge test --match-path test/ArbitrumToken.t.sol
```

### Coverage Report
```bash
forge coverage
```

## 🚀 Deployment

### Quick Deployment

Deploy to Arbitrum Sepolia (testnet):
```bash
make deploy-sepolia
```

Deploy to Arbitrum One (mainnet):
```bash
make deploy-mainnet
```

### Manual Deployment

1. **Deploy to testnet first:**
   ```bash
   forge script script/DeployArbitrum.s.sol:DeployArbitrum \
     --rpc-url arbitrum-sepolia \
     --broadcast \
     --verify \
     --etherscan-api-key $ARBITRUM_API_KEY
   ```

2. **Deploy to mainnet:**
   ```bash
   forge script script/DeployArbitrum.s.sol:DeployArbitrum \
     --rpc-url arbitrum \
     --broadcast \
     --verify \
     --etherscan-api-key $ARBITRUM_API_KEY
   ```

### Deployment Verification

After deployment, verify your contracts:
```bash
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> \
  --chain-id 42161 \
  --etherscan-api-key $ARBITRUM_API_KEY
```

## 🔍 Contract Verification

### Automatic Verification
Contracts are automatically verified during deployment when using the `--verify` flag.

### Manual Verification
```bash
# Verify on Arbitrum One
forge verify-contract 0x... ArbitrumToken \
  --chain-id 42161 \
  --etherscan-api-key $ARBITRUM_API_KEY \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "Token Name" "SYMBOL" 1000000000000000000000000)

# Verify on Arbitrum Sepolia
forge verify-contract 0x... ArbitrumToken \
  --chain-id 421614 \
  --etherscan-api-key $ARBITRUM_API_KEY \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "Token Name" "SYMBOL" 1000000000000000000000000)
```

## 🛡 Security Best Practices

### 1. Private Key Management
- **NEVER** commit private keys to version control
- Use hardware wallets for mainnet deployments
- Consider using multi-signature wallets for production

### 2. Contract Security
- All contracts include standard security patterns:
  - ReentrancyGuard for state-changing functions
  - Access control with OpenZeppelin's Ownable
  - Input validation and bounds checking
  - Emergency pause mechanisms where appropriate

### 3. Testing
- Comprehensive test coverage (>95%)
- Fuzz testing for edge cases
- Fork testing against live networks
- Gas optimization verification

### 4. Deployment Security
- Always deploy to testnet first
- Verify contracts on block explorers
- Use timelock contracts for critical functions
- Implement proper access controls

## ⚡ Gas Optimization

### Arbitrum-Specific Optimizations

1. **Batch Operations**: Use batch functions to reduce transaction overhead
2. **Storage Optimization**: Packed structs and efficient storage layouts
3. **Function Modifiers**: Gas-efficient access control patterns
4. **Event Optimization**: Indexed parameters for efficient filtering

### Gas Usage Examples

| Operation | Ethereum L1 | Arbitrum L2 | Savings |
|-----------|-------------|-------------|---------|
| ERC20 Transfer | ~21,000 gas | ~2,100 gas | 90% |
| NFT Mint | ~80,000 gas | ~8,000 gas | 90% |
| Staking Deposit | ~120,000 gas | ~12,000 gas | 90% |

## 📊 Monitoring and Analytics

### Tenderly Integration
```bash
# Set up Tenderly monitoring
export TENDERLY_USER=your_username
export TENDERLY_PROJECT=your_project
tenderly export init
```

### OpenZeppelin Defender
Configure Defender for automated monitoring:
- Transaction monitoring
- Security alerts
- Automated responses
- Gas price optimization

## 🔧 Development Commands

### Using Make (Recommended)
```bash
# Build project
make build

# Run tests
make test

# Deploy to testnet
make deploy-sepolia

# Deploy to mainnet
make deploy-mainnet

# Generate gas report
make gas-report

# Run coverage
make coverage

# Clean build artifacts
make clean
```

### Using Forge Directly
```bash
# Build
forge build

# Test
forge test -vvv

# Deploy
forge script script/DeployArbitrum.s.sol --broadcast

# Format code
forge fmt

# Update dependencies
forge update
```

## 📁 Project Structure

```
├── src/
│   ├── ArbitrumToken.sol      # ERC20 token contract
│   ├── ArbitrumNFT.sol        # ERC721 NFT contract
│   ├── ArbitrumStaking.sol    # DeFi staking contract
│   └── Counter.sol            # Example counter contract
├── script/
│   ├── BaseDeployment.s.sol   # Base deployment utilities
│   ├── DeployArbitrum.s.sol   # Main deployment script
│   └── Counter.s.sol          # Example deployment script
├── test/
│   ├── ArbitrumToken.t.sol    # Token contract tests
│   ├── ArbitrumNFT.t.sol      # NFT contract tests
│   ├── ArbitrumStaking.t.sol  # Staking contract tests
│   └── Counter.t.sol          # Example tests
├── lib/                       # Foundry dependencies
├── .env.example              # Environment template
├── foundry.toml              # Foundry configuration
├── Makefile                  # Development commands
└── README.md                 # This file
```

## 🌐 Network Information

### Arbitrum One (Mainnet)
- **Chain ID**: 42161
- **RPC URL**: https://arb1.arbitrum.io/rpc
- **Explorer**: https://arbiscan.io/
- **Bridge**: https://bridge.arbitrum.io/

### Arbitrum Sepolia (Testnet)
- **Chain ID**: 421614
- **RPC URL**: https://sepolia-rollup.arbitrum.io/rpc
- **Explorer**: https://sepolia.arbiscan.io/
- **Faucet**: https://faucet.quicknode.com/arbitrum/sepolia

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Development Guidelines

- Follow Solidity style guide
- Maintain test coverage above 95%
- Add comprehensive documentation
- Optimize for gas efficiency
- Include security considerations

## 📚 Resources

### Arbitrum Documentation
- [Arbitrum Docs](https://docs.arbitrum.io/)
- [Arbitrum Bridge](https://bridge.arbitrum.io/)
- [Arbitrum Portal](https://portal.arbitrum.io/)

### Foundry Resources
- [Foundry Book](https://book.getfoundry.sh/)
- [Foundry GitHub](https://github.com/foundry-rs/foundry)
- [Forge Standard Library](https://github.com/foundry-rs/forge-std)

### Security Resources
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Consensys Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Slither Static Analyzer](https://github.com/crytic/slither)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This template is provided as-is for educational and development purposes. Always conduct thorough testing and security audits before deploying to mainnet. The authors are not responsible for any losses or damages resulting from the use of this template.

---

**Happy Building on Arbitrum! 🚀**
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
