import type { PublicClient, WalletClient } from "viem";
import { SettlementSwitchAbi, RoutingMode, TransferStatus } from "../abi/SettlementSwitch";
import { LayerZeroAdapterAbi } from "../abi/LayerZeroAdapter";
import { ERC20Abi } from "../abi/erc20";
import { CONTRACT_ADDRESSES, SUPPORTED_TOKENS, getContractAddress } from "../addresses";

// Re-export enums for external use
export { RoutingMode, TransferStatus };

// Types for Settlement Switch
export type RoutePreferences = {
  mode: RoutingMode;
  maxSlippageBps: number;
  maxFeeWei: bigint;
  maxTimeMinutes: number;
  allowMultiHop: boolean;
};

export type RouteMetrics = {
  estimatedGasCost: bigint;
  bridgeFee: bigint;
  totalCostWei: bigint;
  estimatedTimeMinutes: bigint;
  liquidityAvailable: bigint;
  successRate: bigint;
  congestionLevel: bigint;
};

export type BridgeRoute = {
  adapter: `0x${string}`;
  tokenIn: `0x${string}`;
  tokenOut: `0x${string}`;
  amountIn: bigint;
  amountOut: bigint;
  srcChainId: bigint;
  dstChainId: bigint;
  metrics: RouteMetrics;
  adapterData: `0x${string}`;
  deadline: bigint;
};

export type BridgeTransfer = {
  transferId: string;
  sender: string;
  recipient: string;
  route: BridgeRoute;
  status: TransferStatus;
  initiatedAt: bigint;
  completedAt: bigint;
};

export type MultipleRoutesResult = {
  routes: BridgeRoute[];
  bestRoute: BridgeRoute;
  totalOptions: number;
};

// Get Settlement Switch contract address based on current chain, with Sepolia fallback
function getSettlementSwitchAddress(chainId: number): `0x${string}` {
  const configured = getContractAddress("SettlementSwitch", chainId);
  if (configured && configured.length === 42) {
    return configured as `0x${string}`;
  }
  // Fallback to Sepolia aggregator if not configured for the chain yet
  return CONTRACT_ADDRESSES.sepolia.SettlementSwitch as `0x${string}`;
}

// Get token address for chain
function getTokenAddress(token: string, chainId: number): `0x${string}` {
  if (chainId === 11155111) { // Sepolia
    return (SUPPORTED_TOKENS.sepolia as any)[token] as `0x${string}`;
  }
  if (chainId === 421614) { // Arbitrum Sepolia
    return (SUPPORTED_TOKENS.arbitrumSepolia as any)[token] as `0x${string}`;
  }
  if (chainId === 1) { // Ethereum Mainnet
    return (SUPPORTED_TOKENS.mainnet as any)[token] as `0x${string}`;
  }
  if (chainId === 42161) { // Arbitrum One
    return (SUPPORTED_TOKENS.arbitrumOne as any)[token] as `0x${string}`;
  }
  throw new Error(`Unsupported chain ID: ${chainId}`);
}

// Create default route preferences
export function createRoutePreferences(
  mode: RoutingMode = RoutingMode.BALANCED,
  maxSlippageBps: number = 100, // 1%
  maxFeeWei: bigint = BigInt("1000000000000000000"), // 1 ETH
  maxTimeMinutes: number = 60,
  allowMultiHop: boolean = true
): RoutePreferences {
  return {
    mode,
    maxSlippageBps,
    maxFeeWei,
    maxTimeMinutes,
    allowMultiHop
  };
}

// Helper function to estimate minimum bridge amount
export function getEstimatedMinimumBridgeAmount(): bigint {
  // Conservative estimate: 0.005 ETH minimum for LayerZero bridges
  // This accounts for typical bridge fees which can range from 0.001-0.003 ETH
  return BigInt("5000000000000000"); // 0.005 ETH in wei
}

// Helper function to validate bridge amount before processing
export function validateBridgeAmount(amount: bigint, tokenSymbol: string = "ETH"): { isValid: boolean; error?: string } {
  const minimumAmount = getEstimatedMinimumBridgeAmount();
  
  if (amount < minimumAmount) {
    const amountEth = Number(amount) / 1e18;
    const minimumEth = Number(minimumAmount) / 1e18;
    
    return {
      isValid: false,
      error: `Amount too small for bridging. Minimum recommended: ${minimumEth} ${tokenSymbol} (you entered: ${amountEth.toFixed(6)} ${tokenSymbol})`
    };
  }
  
  return { isValid: true };
}

// Find optimal route using Settlement Switch
export async function findOptimalRoute(
  publicClient: PublicClient,
  tokenIn: string,
  tokenOut: string,
  amount: bigint,
  srcChainId: number,
  dstChainId: number,
  preferences?: RoutePreferences,
  currentChainId?: number
): Promise<BridgeRoute> {
  const chainId = currentChainId || srcChainId;
  const settlementSwitchAddress = getSettlementSwitchAddress(chainId);
  
  const tokenInAddress = tokenIn === "ETH" ? "0x0000000000000000000000000000000000000000" : getTokenAddress(tokenIn, srcChainId);
  const tokenOutAddress = tokenOut === "ETH" ? "0x0000000000000000000000000000000000000000" : getTokenAddress(tokenOut, dstChainId);
  
  const routePrefs = preferences || createRoutePreferences();

  try {
    const route = await publicClient.readContract({
      address: settlementSwitchAddress,
      abi: SettlementSwitchAbi,
      functionName: "findOptimalRoute",
      args: [
        tokenInAddress as `0x${string}`,
        tokenOutAddress as `0x${string}`,
        amount,
        BigInt(srcChainId),
        BigInt(dstChainId),
        {
          mode: routePrefs.mode,
          maxSlippageBps: BigInt(routePrefs.maxSlippageBps),
          maxFeeWei: routePrefs.maxFeeWei,
          maxTimeMinutes: BigInt(routePrefs.maxTimeMinutes),
          allowMultiHop: routePrefs.allowMultiHop
        }
      ]
    }) as BridgeRoute;

    return route;
  } catch (error: any) {
    const errorMessage = String(error?.message || error);
    
    // Provide more specific error messages
    if (errorMessage.includes('network') && errorMessage.includes('change')) {
      throw new Error("Network changed during request. Please try again.");
    } else if (errorMessage.includes('returned no data')) {
      throw new Error("No routes available for this token pair and amount.");
    } else if (errorMessage.includes('insufficient')) {
      throw new Error("Insufficient liquidity for this route.");
    } else {
      throw new Error(`Failed to find optimal route: ${errorMessage}`);
    }
  }
}

// Find multiple routes for comparison (real LayerZero integration)
export async function findMultipleRoutes(
  publicClient: PublicClient,
  tokenIn: string,
  tokenOut: string,
  amount: bigint,
  srcChainId: number,
  dstChainId: number,
  maxRoutes: number = 3,
  preferences?: RoutePreferences,
  currentChainId?: number
): Promise<MultipleRoutesResult> {
  // Validate minimum amount before processing
  const validation = validateBridgeAmount(amount, tokenIn);
  if (!validation.isValid) {
    throw new Error(validation.error);
  }

  // Resolve LayerZero adapter for the source chain; fallback to Sepolia if not configured yet
  const resolvedAdapter = getContractAddress("LayerZeroAdapter", srcChainId);
  const layerZeroAdapter = (resolvedAdapter && resolvedAdapter.length === 42
    ? resolvedAdapter
    : CONTRACT_ADDRESSES.sepolia.LayerZeroAdapter) as `0x${string}`;
  
  const tokenInAddress = tokenIn === "ETH" ? "0x0000000000000000000000000000000000000000" : getTokenAddress(tokenIn, srcChainId);
  const tokenOutAddress = tokenOut === "ETH" ? "0x0000000000000000000000000000000000000000" : getTokenAddress(tokenOut, dstChainId);

  try {
    // Get real route metrics from LayerZero adapter
    const metrics = await publicClient.readContract({
      address: layerZeroAdapter,
      abi: LayerZeroAdapterAbi,
      functionName: "getRouteMetrics",
      args: [
        tokenInAddress as `0x${string}`,
        tokenOutAddress as `0x${string}`,
        amount,
        BigInt(srcChainId),
        BigInt(dstChainId)
      ]
    });

    // Check if route is supported
    const isSupported = await publicClient.readContract({
      address: layerZeroAdapter,
      abi: LayerZeroAdapterAbi,
      functionName: "supportsRoute",
      args: [
        tokenInAddress as `0x${string}`,
        tokenOutAddress as `0x${string}`,
        BigInt(srcChainId),
        BigInt(dstChainId)
      ]
    });

    if (!isSupported) {
      throw new Error("LayerZero does not support this route");
    }

    // Validate that bridge fee doesn't exceed input amount
    if (metrics.bridgeFee >= amount) {
      const bridgeFeeEth = Number(metrics.bridgeFee) / 1e18;
      const inputAmountEth = Number(amount) / 1e18;
      const suggestedMinimum = Number(metrics.bridgeFee * BigInt(2)) / 1e18; // 2x bridge fee as minimum
      
      throw new Error(
        `Bridge amount too small. Bridge fee (${bridgeFeeEth.toFixed(6)} ETH) exceeds input amount (${inputAmountEth.toFixed(6)} ETH). ` +
        `Minimum recommended amount: ${suggestedMinimum.toFixed(6)} ETH`
      );
    }

    // Calculate output amount, ensuring it's never negative
    const calculatedAmountOut = amount - metrics.bridgeFee;
    if (calculatedAmountOut <= BigInt(0)) {
      throw new Error("Insufficient amount after bridge fees");
    }

    const route: BridgeRoute = {
      adapter: layerZeroAdapter,
      tokenIn: tokenInAddress as `0x${string}`,
      tokenOut: tokenOutAddress as `0x${string}`,
      amountIn: amount,
      amountOut: calculatedAmountOut,
      srcChainId: BigInt(srcChainId),
      dstChainId: BigInt(dstChainId),
      metrics: {
        estimatedGasCost: metrics.estimatedGasCost,
        bridgeFee: metrics.bridgeFee,
        totalCostWei: metrics.totalCostWei,
        estimatedTimeMinutes: metrics.estimatedTimeMinutes,
        liquidityAvailable: metrics.liquidityAvailable,
        successRate: metrics.successRate,
        congestionLevel: metrics.congestionLevel
      },
      adapterData: "0x" as `0x${string}`,
      deadline: BigInt(Math.floor(Date.now() / 1000) + 3600) // 1 hour from now
    };

    return {
      routes: [route],
      bestRoute: route,
      totalOptions: 1
    };
  } catch (error: any) {
    const errorMessage = String(error?.message || error);
    
    // Provide more specific error messages
    if (errorMessage.includes('network') && errorMessage.includes('change')) {
      throw new Error("Network changed during request. Please try again.");
    } else if (errorMessage.includes('returned no data')) {
      throw new Error("No routes available for this token pair and amount.");
    } else if (errorMessage.includes('insufficient')) {
      throw new Error("Insufficient liquidity available.");
    } else if (errorMessage.includes('UnsupportedRoute')) {
      throw new Error("LayerZero does not support this route.");
    } else {
      throw new Error(`Failed to find routes: ${errorMessage}`);
    }
  }
}

// Execute bridge transfer
export async function executeBridge(
  walletClient: WalletClient,
  publicClient: PublicClient,
  route: BridgeRoute,
  recipient: string,
  account: string,
  permitData: string = "0x",
  currentChainId?: number
): Promise<string> {
  const chainId = currentChainId || Number(route.srcChainId);
  const settlementSwitchAddress = getSettlementSwitchAddress(chainId);

  // Validate route parameters to prevent negative values
  if (route.amountIn <= BigInt(0)) {
    throw new Error("Invalid input amount: must be positive");
  }
  if (route.amountOut <= BigInt(0)) {
    throw new Error("Invalid output amount: must be positive");
  }

  // Handle token approval if not ETH
  if (route.tokenIn !== "0x0000000000000000000000000000000000000000") {
    await ensureAllowance(
      publicClient,
      walletClient,
      account as `0x${string}`,
      settlementSwitchAddress,
      route.amountIn,
      route.tokenIn as `0x${string}`
    );
  }

  try {
    // Set a conservative gas limit that stays within network constraints
    // Network cap is 16,777,216, so we use 15,000,000 to be safe
    const gasLimit = BigInt(15000000);
    
    const hash = await walletClient.writeContract({
      address: settlementSwitchAddress,
      abi: SettlementSwitchAbi as any, // Type assertion for ABI compatibility
      functionName: "executeBridge",
      args: [
        route as any, // Type assertion to handle complex nested types
        recipient as `0x${string}`,
        permitData as `0x${string}`
      ],
      value: route.tokenIn === "0x0000000000000000000000000000000000000000" ? route.amountIn : BigInt(0),
      account: account as `0x${string}`,
      chain: null,
      gas: gasLimit
    });

    // Wait for transaction receipt
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    
    // Extract transfer ID from logs
    const transferInitiatedLog = receipt.logs.find(log => 
      log.topics[0] === "0x..." // TransferInitiated event signature
    );
    
    return hash;
  } catch (error) {
    console.error("Error executing bridge:", error);
    throw new Error(`Failed to execute bridge: ${error}`);
  }
}

// Bridge with auto route (real LayerZero integration)
export async function bridgeWithAutoRoute(
  walletClient: WalletClient,
  publicClient: PublicClient,
  tokenIn: string,
  tokenOut: string,
  amount: bigint,
  srcChainId: number,
  dstChainId: number,
  recipient: string,
  account: string,
  preferences?: RoutePreferences,
  permitData: string = "0x",
  currentChainId?: number
): Promise<string> {
  // Resolve LayerZero adapter for the source chain; fallback to Sepolia if not configured yet
  const resolvedAdapter = getContractAddress("LayerZeroAdapter", srcChainId);
  const layerZeroAdapter = (resolvedAdapter && resolvedAdapter.length === 42
    ? resolvedAdapter
    : CONTRACT_ADDRESSES.sepolia.LayerZeroAdapter) as `0x${string}`;
  
  const tokenInAddress = tokenIn === "ETH" ? "0x0000000000000000000000000000000000000000" : getTokenAddress(tokenIn, srcChainId);
  const tokenOutAddress = tokenOut === "ETH" ? "0x0000000000000000000000000000000000000000" : getTokenAddress(tokenOut, dstChainId);

  try {
    // First get the route metrics to build the route object
    const metrics = await publicClient.readContract({
      address: layerZeroAdapter,
      abi: LayerZeroAdapterAbi,
      functionName: "getRouteMetrics",
      args: [
        tokenInAddress as `0x${string}`,
        tokenOutAddress as `0x${string}`,
        amount,
        BigInt(srcChainId),
        BigInt(dstChainId)
      ]
    });

    // Build the route object for the bridge call
    const route = {
      adapter: layerZeroAdapter,
      tokenIn: tokenInAddress as `0x${string}`,
      tokenOut: tokenOutAddress as `0x${string}`,
      amountIn: amount,
      amountOut: amount - metrics.bridgeFee,
      srcChainId: BigInt(srcChainId),
      dstChainId: BigInt(dstChainId),
      metrics: {
        estimatedGasCost: metrics.estimatedGasCost,
        bridgeFee: metrics.bridgeFee,
        totalCostWei: metrics.totalCostWei,
        estimatedTimeMinutes: metrics.estimatedTimeMinutes,
        liquidityAvailable: metrics.liquidityAvailable,
        successRate: metrics.successRate,
        congestionLevel: metrics.congestionLevel
      },
      adapterData: "0x" as `0x${string}`,
      deadline: BigInt(Math.floor(Date.now() / 1000) + 3600)
    };

    // Handle token approval if not ETH
    if (tokenInAddress !== "0x0000000000000000000000000000000000000000") {
      await ensureAllowance(
        publicClient,
        walletClient,
        account as `0x${string}`,
        layerZeroAdapter as `0x${string}`,
        amount,
        tokenInAddress as `0x${string}`
      );
    }

    // Execute the bridge transaction directly with LayerZero adapter
    // Set a conservative gas limit that stays within network constraints
    // Network cap is 16,777,216, so we use 15,000,000 to be safe
    const gasLimit = BigInt(15000000);
    
    const hash = await walletClient.writeContract({
      address: layerZeroAdapter as `0x${string}`,
      abi: LayerZeroAdapterAbi as any, // Type assertion for ABI compatibility
      functionName: "executeBridge",
      args: [
        route as any, // Type assertion for complex nested types
        recipient as `0x${string}`,
        permitData as `0x${string}`
      ],
      value: tokenInAddress === "0x0000000000000000000000000000000000000000" ? amount : BigInt(0),
      account: account as `0x${string}`,
      chain: null,
      gas: gasLimit
    });

    // Wait for transaction receipt to verify success
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    
    // Check if transaction actually succeeded
    if (receipt.status !== 'success') {
      throw new Error(`Transaction failed on-chain. Hash: ${hash}`);
    }

    return hash;
  } catch (error: any) {
    const errorMessage = String(error?.message || error);
    
    // Handle specific errors
    if (errorMessage.includes('network') && errorMessage.includes('change')) {
      throw new Error("Network changed during transaction. Please verify your network and try again.");
    } else if (errorMessage.includes('User rejected')) {
      throw new Error("Transaction was rejected by user.");
    } else if (errorMessage.includes('insufficient funds')) {
      throw new Error("Insufficient funds for transaction.");
    } else if (errorMessage.includes('UnsupportedRoute')) {
      throw new Error("LayerZero does not support this route.");
    } else {
      throw new Error(`Bridge transaction failed: ${errorMessage}`);
    }
  }
}

// Get transfer status
export async function getTransferStatus(
  publicClient: PublicClient,
  transferId: string,
  currentChainId?: number
): Promise<BridgeTransfer> {
  const chainId = currentChainId || 11155111; // Default to Sepolia
  const settlementSwitchAddress = getSettlementSwitchAddress(chainId);

  try {
    const transfer = await publicClient.readContract({
      address: settlementSwitchAddress,
      abi: SettlementSwitchAbi,
      functionName: "getTransfer",
      args: [transferId as `0x${string}`]
    }) as BridgeTransfer;

    return transfer;
  } catch (error) {
    console.error("Error getting transfer status:", error);
    throw new Error(`Failed to get transfer status: ${error}`);
  }
}

// Get registered bridge adapters (simplified to focus on LayerZero first)
export async function getRegisteredAdapters(
  publicClient: PublicClient,
  currentChainId?: number
): Promise<{ adapters: string[]; names: string[]; enabled: boolean[] }> {
  // For now, let's focus on LayerZero only to get something working
  const layerZeroAdapter = CONTRACT_ADDRESSES.sepolia.LayerZeroAdapter;
  
  return {
    adapters: [layerZeroAdapter],
    names: ["LayerZero"],
    enabled: [true]
  };
}

// Ensure token allowance (reused from existing service)
async function ensureAllowance(
  publicClient: PublicClient,
  walletClient: WalletClient,
  owner: `0x${string}`,
  spender: `0x${string}`,
  amountUnits: bigint,
  tokenAddress: `0x${string}`
) {
  const currentAllowance = await publicClient.readContract({
    address: tokenAddress,
    abi: ERC20Abi,
    functionName: "allowance",
    args: [owner, spender],
  }) as bigint;

  if (currentAllowance < amountUnits) {
    const hash = await walletClient.writeContract({
      address: tokenAddress,
      abi: ERC20Abi as any, // Type assertion for ABI compatibility
      functionName: "approve",
      args: [spender, amountUnits],
      account: owner,
      chain: null
    });

    await publicClient.waitForTransactionReceipt({ hash });
  }
}

// Format route metrics for display
export function formatRouteMetrics(metrics: RouteMetrics) {
  return {
    gasCostETH: Number(metrics.estimatedGasCost) / 1e18,
    bridgeFeeETH: Number(metrics.bridgeFee) / 1e18,
    totalCostETH: Number(metrics.totalCostWei) / 1e18,
    estimatedTimeMinutes: Number(metrics.estimatedTimeMinutes),
    successRatePercent: Number(metrics.successRate) / 100,
    liquidityAvailableETH: Number(metrics.liquidityAvailable) / 1e18,
    congestionLevel: Number(metrics.congestionLevel)
  };
}

// Get bridge adapter name from address
export function getBridgeAdapterName(adapterAddress: string): string {
  const adapters = CONTRACT_ADDRESSES.sepolia;
  
  if (adapterAddress.toLowerCase() === adapters.LayerZeroAdapter.toLowerCase()) {
    return "LayerZero";
  }
  if (adapterAddress.toLowerCase() === adapters.ConnextAdapter.toLowerCase()) {
    return "Connext";
  }
  if (adapterAddress.toLowerCase() === adapters.AcrossAdapter.toLowerCase()) {
    return "Across";
  }
  
  return "Unknown Bridge";
}

// Subscribe to transfer events
export function subscribeToTransferEvents(
  publicClient: PublicClient,
  onTransferInitiated?: (log: any) => void,
  onTransferCompleted?: (log: any) => void,
  currentChainId?: number
) {
  const chainId = currentChainId || 11155111;
  const settlementSwitchAddress = getSettlementSwitchAddress(chainId);

  // Subscribe to TransferInitiated events
  if (onTransferInitiated) {
    publicClient.watchContractEvent({
      address: settlementSwitchAddress,
      abi: SettlementSwitchAbi,
      eventName: "TransferInitiated",
      onLogs: onTransferInitiated
    });
  }

  // Subscribe to TransferCompleted events
  if (onTransferCompleted) {
    publicClient.watchContractEvent({
      address: settlementSwitchAddress,
      abi: SettlementSwitchAbi,
      eventName: "TransferCompleted",
      onLogs: onTransferCompleted
    });
  }
}

// Export constants
export const constants = {
  RoutingMode,
  TransferStatus,
  DEFAULT_MAX_SLIPPAGE_BPS: 100, // 1%
  DEFAULT_MAX_TIME_MINUTES: 60,
  DEFAULT_MAX_FEE_ETH: "1000000000000000000", // 1 ETH
  MINIMUM_BRIDGE_AMOUNT_WEI: "5000000000000000", // 0.005 ETH
  MINIMUM_BRIDGE_AMOUNT_ETH: 0.005
};
