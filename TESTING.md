# StablecoinSwitch Testing Guide

## Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Run Tests
```bash
npm test
```

### 3. Run Tests with Coverage
```bash
npm run test:coverage
```

---

## Test Structure

The test suite (`test/StablecoinSwitch.test.ts`) covers:

### ✅ **Deployment Tests**
- Verifies correct chain ID initialization
- Checks mock routes are set up (Ethereum, Polygon, Optimism)
- Confirms owner is set correctly

### ✅ **getOptimalPath Tests**
- Cost-first priority routing
- Speed-first priority routing
- Inactive route handling

### ✅ **routeTransaction Tests**
- Input validation (amount, token, chain ID, priority)
- Route availability checks
- Token transfer functionality

### ✅ **Bridge Adapter Management**
- Setting LI.FI adapter
- Setting Chainlink adapter
- Setting custom bridge adapter
- Router configuration
- Owner-only access control

### ✅ **Mock Route Management**
- Updating route parameters
- Activating/deactivating routes
- Owner-only access control

### ✅ **Settlement Execution**
- Manual settlement by owner
- Input validation
- Balance checks

### ✅ **Emergency Functions**
- Token withdrawal by owner
- Access control

### ✅ **Security Tests**
- Reentrancy protection
- Access control on privileged functions

---

## Manual Testing on Testnet

### Prerequisites
1. Get Arbitrum Sepolia testnet ETH from [faucet](https://faucet.quicknode.com/arbitrum/sepolia)
2. Deploy a test USDC token or use existing testnet USDC
3. Set up your `.env` file:

```bash
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
PRIVATE_KEY=your_private_key_here
```

### Deploy Contract
```bash
npm run build
npm run deploy:arbitrumSepolia
```

### Test Flow on Testnet

1. **Deploy and Configure**
   ```solidity
   // After deployment, configure routers
   await stablecoinSwitch.setLiFiRouter(LIFI_ROUTER_ADDRESS);
   await stablecoinSwitch.setChainlinkRouter(CHAINLINK_CCIP_ROUTER);
   ```

2. **Add More Routes (Optional)**
   ```solidity
   // Add Base chain route
   await stablecoinSwitch.updateMockRoute(
     8453,  // Base chain ID
     15,    // 0.15% fee
     200,   // 200 seconds
     true   // active
   );
   ```

3. **Get Optimal Path**
   ```solidity
   const path = await stablecoinSwitch.getOptimalPath(
     USDC_ADDRESS,
     ethers.parseUnits("100", 6),
     137,  // Polygon
     0     // Cost priority
   );
   console.log("Route:", path);
   ```

4. **Execute Transaction**
   ```solidity
   // Approve tokens first
   await usdc.approve(stablecoinSwitch.address, amount);
   
   // Route transaction
   await stablecoinSwitch.routeTransaction(
     USDC_ADDRESS,
     ethers.parseUnits("100", 6),
     137,  // to Polygon
     1     // Speed priority
   );
   ```

---

## Testing with Real Bridges

### LI.FI Integration
LI.FI Router addresses per chain:
- **Arbitrum One**: `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE`
- **Arbitrum Sepolia**: Check [LI.FI docs](https://docs.li.fi)

### Chainlink CCIP Integration
Chainlink CCIP Router addresses:
- **Arbitrum Sepolia**: `0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165`
- **Arbitrum One**: `0x141fa059441E0ca23ce184B6A78bafD2A517DdE8`

### Test Sequence
1. Deploy contract
2. Set router addresses
3. Configure bridge adapters (if using custom adapters)
4. Test with small amounts first
5. Monitor events: `TransactionRouted`, `SettlementExecuted`, `LiFiBridgeFailed`

---

## Expected Test Output

When you run `npm test`, you should see:

```
StablecoinSwitch
  Deployment
    ✓ Should set the correct chain ID
    ✓ Should initialize mock routes
    ✓ Should set owner correctly
  getOptimalPath
    ✓ Should return optimal path for Cost priority
    ✓ Should return optimal path for Speed priority
    ✓ Should return empty path for inactive route
  routeTransaction
    ✓ Should revert with InvalidAmount for zero amount
    ✓ Should revert with InvalidToken for zero address
    ✓ Should revert with InvalidChainId for same chain
    ✓ Should revert with InvalidPriority for invalid priority
    ✓ Should revert with NoRouteAvailable for inactive route
  Bridge Adapter Management
    ✓ Should set LiFi bridge adapter
    ✓ Should set Chainlink bridge adapter
    ✓ Should set custom bridge adapter
    ✓ Should set LiFi router
    ✓ Should set Chainlink router
    ✓ Should only allow owner to set adapters
  updateMockRoute
    ✓ Should update mock route
    ✓ Should deactivate route
    ✓ Should only allow owner to update routes
  executeSettlement
    ✓ Should revert with InvalidAmount for zero amount
    ✓ Should revert with InvalidToken for zero address
    ✓ Should revert with InvalidRecipient for zero address
    ✓ Should only allow owner to execute settlement
  emergencyWithdraw
    ✓ Should allow owner to withdraw tokens
    ✓ Should only allow owner to withdraw

  26 passing (2s)
```

---

## Common Issues

### Issue: "Ownable: caller is not the owner"
**Solution**: Make sure you're calling privileged functions from the owner account

### Issue: "InvalidAmount" error
**Solution**: Ensure amount > 0

### Issue: "NoRouteAvailable"
**Solution**: The destination chain doesn't have an active route. Use `updateMockRoute()` to add it

### Issue: "BridgeNotConfigured"
**Solution**: Set the router addresses using `setLiFiRouter()` and `setChainlinkRouter()`

---

## Gas Usage Testing

To estimate gas costs:

```typescript
const tx = await stablecoinSwitch.routeTransaction(
  tokenAddress,
  amount,
  destinationChain,
  priority
);
const receipt = await tx.wait();
console.log("Gas used:", receipt.gasUsed.toString());
```

---

## Next Steps

1. ✅ Run unit tests locally
2. Deploy to Arbitrum Sepolia testnet
3. Configure real LI.FI and Chainlink routers
4. Test cross-chain transactions with small amounts
5. Monitor events and gas costs
6. Deploy to Arbitrum One mainnet

---

## Additional Resources

- [LI.FI Documentation](https://docs.li.fi)
- [Chainlink CCIP Docs](https://docs.chain.link/ccip)
- [Arbitrum Developer Docs](https://docs.arbitrum.io)
- [Hardhat Testing Guide](https://hardhat.org/tutorial/testing-contracts)
