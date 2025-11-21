# Ordeal - Cross-Chain Bridge Aggregator

A comprehensive cross-chain bridge aggregation platform that provides optimal routing and cost-effective bridging across multiple blockchain networks.

## 🌟 Overview

Ordeal consists of two main components:
- **Settlement Switch**: Smart contract system for cross-chain bridge aggregation
- **Frontend**: Next.js web application for user interaction

The platform aggregates multiple bridge protocols (Across, Connext, LayerZero, Hop, etc.) to find the most cost-effective and efficient routes for cross-chain asset transfers.

## 🏗️ Architecture

### Smart Contracts (`settlement-switch/`)

The core smart contract system includes:

- **SettlementSwitch**: Main orchestration contract that handles bridge operations
- **RouteCalculator**: Calculates optimal routes based on cost, time, and reliability
- **BridgeRegistry**: Manages registered bridge adapters and their configurations
- **FeeManager**: Handles fee calculations and distributions
- **Bridge Adapters**: Protocol-specific implementations for various bridges

### Frontend (`frontend/`)

Next.js application providing:
- Bridge interface for users
- Chain and token selection
- Route comparison and optimization
- Transaction tracking and status

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ and npm/yarn
- Foundry (for smart contracts)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Ordeal
   ```

2. **Install dependencies**
   ```bash
   # Frontend dependencies
   cd frontend
   npm install
   cd ..

   # Smart contract dependencies
   cd settlement-switch
   forge install
   cd ..
   ```

3. **Environment Setup**
   ```bash
   # Copy environment files
   cp settlement-switch/.env.example settlement-switch/.env
   
   # Configure your environment variables
   # Add RPC URLs, private keys, and API keys
   ```

## 🔧 Development

### Smart Contracts

```bash
cd settlement-switch

# Compile contracts
forge build

# Run tests
forge test

# Deploy to testnet
forge script script/SimpleDeploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Deploy to Arbitrum (cost-effective)
forge script script/SimpleDeploy.s.sol --rpc-url $ARBITRUM_RPC_URL --broadcast --verify
```

### Frontend

```bash
cd frontend

# Start development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

## 📋 Deployment

### Smart Contract Deployment

#### Cost Estimates
- **Ethereum Mainnet**: ~0.00118 ETH (~$3.54 USD)
- **Arbitrum One**: ~0.000338 ETH (~$1.02 USD) - **Recommended**

#### Deployment Commands

**Arbitrum One (Recommended - 70% cheaper):**
```bash
cd settlement-switch
source .env
forge script script/SimpleDeploy.s.sol \
  --rpc-url $ARBITRUM_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ARBISCAN_API_KEY
```

**Ethereum Mainnet:**
```bash
cd settlement-switch
source .env

# Monitor gas prices first
./scripts/monitor-gas.sh

# Deploy when gas is optimal
forge script script/SimpleDeploy.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**Optimized Deployment (with CREATE2):**
```bash
forge script script/OptimizedDeploy.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

### Frontend Deployment

```bash
cd frontend

# Build the application
npm run build

# Deploy to Vercel (recommended)
vercel deploy

# Or deploy to other platforms
npm run export  # For static hosting
```

## 🧪 Testing

### Smart Contract Tests

```bash
cd settlement-switch

# Run all tests
forge test

# Run specific test file
forge test --match-contract SettlementSwitchTest

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

### Frontend Tests

```bash
cd frontend

# Run tests (if configured)
npm test

# Run linting
npm run lint

# Type checking
npm run type-check
```

## 📊 Supported Bridges

- **Across Protocol**: Fast and capital-efficient bridging
- **Connext**: Secure cross-chain transfers
- **LayerZero**: Omnichain interoperability
- **Hop Protocol**: Scalable rollup-to-rollup transfers
- **Arbitrum Bridge**: Native Arbitrum bridging
- **Polygon Bridge**: Native Polygon bridging

## 🌐 Supported Networks

- Ethereum Mainnet
- Arbitrum One
- Polygon
- Optimism
- Base
- And more...

## 🔐 Security

### Smart Contract Security

- Comprehensive test coverage
- Role-based access control
- Reentrancy protection
- Input validation and sanitization
- Emergency pause functionality

### Best Practices

- Never commit private keys or sensitive data
- Use environment variables for configuration
- Verify contracts on block explorers
- Test thoroughly on testnets before mainnet deployment

## 📁 Project Structure

```
ordeal/
├── README.md
├── .gitignore
├── frontend/                 # Next.js frontend application
│   ├── app/                 # App router pages
│   ├── components/          # React components
│   ├── lib/                 # Utilities and services
│   └── package.json
└── settlement-switch/       # Smart contract system
    ├── src/                 # Contract source code
    │   ├── core/           # Core contracts
    │   ├── adapters/       # Bridge adapters
    │   ├── interfaces/     # Contract interfaces
    │   └── mocks/          # Test mocks
    ├── script/             # Deployment scripts
    ├── test/               # Contract tests
    └── foundry.toml        # Foundry configuration
```

## 🛠️ Utilities

### Gas Monitoring

Monitor Ethereum gas prices for optimal deployment timing:

```bash
cd settlement-switch
./scripts/monitor-gas.sh
```

### Contract Verification

Verify deployed contracts:

```bash
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain-id 1
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- Create an issue for bug reports or feature requests
- Join our community discussions
- Check the documentation for detailed guides

## 🔗 Links

- **Frontend Demo**: [Coming Soon]
- **Smart Contracts**: [Etherscan/Arbiscan Links]
- **Documentation**: [Detailed Docs]
- **API Reference**: [API Docs]

---

**Built with ❤️ for the cross-chain future**
