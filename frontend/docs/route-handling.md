# StablecoinSwitch Frontend Route Handling

This document explains the frontend changes that improve error tracing, input validation, user feedback, and gas estimation for `getOptimalPath` and `routeTransaction`.

## Overview

- Adds ABI custom errors to enable decoded revert names.
- Centralizes error mapping to friendly messages.
- Validates inputs before calls to avoid avoidable reverts.
- Wraps reads/writes and gas estimation in try/catch with clear messages.
- Adds dev-mode logs for detailed tracing.

## Error Mapping

Errors from the contract are decoded by `viem` using ABI error definitions. The helper `mapSwitchError(err, { destChainId })` converts known errors to actionable guidance:

- `UnsupportedToken` → Enable token: `setTokenSupport(USDC, true)`.
- `UnsupportedChain` → Enable chain: `setChainSupport(<chainId>, true)`.
- `BridgeAdapterNotSet` → Configure adapters: `addBridgeAdapter(<chainId>, <adapter>, "Arbitrum", <gasCost>)` or legacy `setBridgeAdapter`.
- `PriceFeedError` → Fix Chainlink feeds configuration.
- `InvalidAmount` → Enter amount > 0.
- `InvalidPriority` → Use `0` (cost) or `1` (speed).
- `InvalidRecipient` → Provide a valid `0x` address.
- `TransferFailed` → Ensure sufficient balance and allowance.

Fallback returns the raw message if no known mapping applies.

## Pre-Validation

Before calling `getOptimalPath`:
- Check token support via `isTokenSupported(USDC)`.
- Check destination chain support via `isChainSupported(chainId)`.
- Check adapter presence using `getBridgeAdapters` then fallback to `getBridgeAdapter`.

Before transaction/gas estimation:
- Validate `amount > 0`.
- Validate `recipient` is a valid `0x` address.
- Auto-switch wallet network to match the source chain.
- Ensure allowance for USDC to `StablecoinSwitch`.

## Gas Estimation & Optimization

- Avoid gas estimation when pre-validations fail.
- Use `estimateContractGas` for `routeTransaction` with safe defaults for `minAmountOut`.
- Prevent repeated reads by caching route results for the current inputs in UI state.

## Dev Tracing

In development mode (`NODE_ENV=development`), the service logs grouped diagnostics for reads, writes, and estimation:
- Call inputs (amount, chain, priority, recipient).
- Error objects and decoded friendly messages.

This aids reproducibility and debugging without leaking sensitive info in production.

## Testing Scenarios

Manual tests to validate behavior:

1. Unsupported token: Disable USDC via script, expect friendly error and no spinner hang.
2. Unsupported chain: Use a chain not enabled, expect clear guidance.
3. Missing adapter: Remove adapters for dest chain, expect adapter-specific guidance.
4. Invalid amount: Enter `0` or negative, expect inline validation and no calls.
5. Invalid recipient: Enter malformed address, expect inline validation.
6. Price feed issues: Simulate feed config issue, expect `PriceFeedError` mapping.
7. Successful route: Valid inputs, route and gas estimate populate; transaction submits and confirms.

## Files Updated

- `frontend/lib/abi/StablecoinSwitch.ts`: Added custom errors to ABI.
- `frontend/lib/services/switch.ts`: Centralized error mapping, added validation, dev logs, and wrapped calls.
- `frontend/app/bridge/page.tsx`: Displays clear route errors, stops spinners, validates inputs.

## Security Considerations

- All validation is non-invasive; contract state changes remain exclusively on-chain.
- Error messages avoid leaking sensitive data and only reference required admin actions.
- The UI blocks actions that would certainly revert (invalid inputs, missing adapters), reducing noisy reverts.