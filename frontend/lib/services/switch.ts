import type { PublicClient, WalletClient } from "viem";
import { StablecoinSwitchAbi } from "../abi/StablecoinSwitch";
import { ERC20Abi } from "../abi/erc20";
import { CONTRACT_ADDRESSES, SUPPORTED_TOKENS } from "../addresses";

export type OptimalRoute = {
  bridge: string;
  estimatedGasUSD: number;
  estimatedTimeSeconds: number;
};

const STABLECOIN_SWITCH = CONTRACT_ADDRESSES.sepolia
  .StablecoinSwitch as `0x${string}`;
const USDC = SUPPORTED_TOKENS.sepolia.USDC as `0x${string}`;

function getUsdcForChain(chainId: number): `0x${string}` {
  if (chainId === 11155111) return SUPPORTED_TOKENS.sepolia.USDC as `0x${string}`;
  if (chainId === 421614) return SUPPORTED_TOKENS.arbitrumSepolia.USDC as `0x${string}`;
  // Default to source USDC; contract will reject unsupported chain/token
  return SUPPORTED_TOKENS.sepolia.USDC as `0x${string}`;
}

// Minimal Chainlink AggregatorV3 ABI for latestRoundData
const AggregatorAbi = [
  {
    type: "function",
    name: "latestRoundData",
    inputs: [],
    outputs: [
      { name: "roundId", type: "uint80" },
      { name: "answer", type: "int256" },
      { name: "startedAt", type: "uint256" },
      { name: "updatedAt", type: "uint256" },
      { name: "answeredInRound", type: "uint80" },
    ],
    stateMutability: "view",
  },
  { type: "function", name: "decimals", inputs: [], outputs: [{ name: "", type: "uint8" }], stateMutability: "view" },
];

// Centralized mapping for StablecoinSwitch custom errors to friendly messages
function mapSwitchError(err: any, ctx?: { destChainId?: number }) {
  const raw = err?.shortMessage || err?.message || String(err);
  const errorName = err?.data?.errorName || err?.cause?.data?.errorName || "";
  const sig = `${errorName}` || raw;
  const destChainId = ctx?.destChainId;

  // Prefer ABI-decoded error names when available
  if (sig.includes("UnsupportedToken") || raw.includes("UnsupportedToken")) {
    return "Token not supported. Ask owner to call setTokenSupport(USDC, true).";
  }
  if (sig.includes("UnsupportedChain") || raw.includes("UnsupportedChain")) {
    return `Destination chain ${destChainId ?? "<id>"} is not enabled. Ask owner to call setChainSupport(${destChainId ?? "<id>"}, true).`;
  }
  if (sig.includes("BridgeAdapterNotSet") || raw.includes("BridgeAdapterNotSet")) {
    return `No bridge adapters configured for chain ${destChainId ?? "<id>"}. Ask owner to call addBridgeAdapter(${destChainId ?? "<id>"}, <adapter>, "Arbitrum", <gasCost>) or legacy setBridgeAdapter(${destChainId ?? "<id>"}, <adapter>).`;
  }
  if (sig.includes("PriceFeedError") || raw.includes("PriceFeedError")) {
    return "Price feeds unavailable or stale. Check ETH/USD and USDC/USD Chainlink feeds configuration.";
  }
  if (sig.includes("InvalidAmount") || raw.includes("InvalidAmount")) {
    return "Enter a valid amount greater than 0.";
  }
  if (sig.includes("InvalidPriority") || raw.includes("InvalidPriority")) {
    return "Invalid priority. Use 0 for cost or 1 for speed.";
  }
  if (sig.includes("InvalidRecipient") || raw.includes("InvalidRecipient")) {
    return "Recipient address is invalid. Please double-check the destination address.";
  }
  if (sig.includes("TransferFailed") || raw.includes("TransferFailed")) {
    return "Token transfer failed. Ensure sufficient balance and allowance, then retry.";
  }
  // Common ERC20 revert surfaced by viem
  if (raw.toLowerCase().includes("transfer amount exceeds allowance")) {
    return "USDC allowance too low. Please approve USDC to StablecoinSwitch and retry.";
  }
  // Default fallback
  return raw;
}

export async function requireNetwork(
  currentChainId: number,
  walletClient: WalletClient | undefined,
  expectedChainId: number
) {
  if (currentChainId !== expectedChainId && walletClient) {
    try {
      await walletClient.switchChain({ id: expectedChainId });
    } catch (err) {
      throw new Error("Please switch your wallet to the required network.");
    }
  }
}

export async function readOptimalPath(
  publicClient: PublicClient,
  amountUnits: bigint,
  destChainId: number,
  priority: 0 | 1
): Promise<OptimalRoute> {
  // Verify contract configuration before reading
  await ensureContractReady(publicClient, destChainId);

  let routeInfo: any;
  try {
    if (process.env.NODE_ENV === "development") {
      console.groupCollapsed("readOptimalPath: call");
      console.table({ amountUnits: String(amountUnits), destChainId, priority });
      console.groupEnd();
    }
    const toToken = getUsdcForChain(destChainId);
    routeInfo = await publicClient.readContract({
      address: STABLECOIN_SWITCH,
      abi: StablecoinSwitchAbi,
      functionName: "getOptimalPath",
      args: [USDC, toToken, amountUnits, BigInt(destChainId), priority],
    });
  } catch (err: any) {
    const msg = mapSwitchError(err, { destChainId });
    if (process.env.NODE_ENV === "development") {
      console.groupCollapsed("readOptimalPath: error");
      console.log(err);
      console.table({ decoded: msg });
      console.groupEnd();
    }
    throw new Error(msg);
  }

  return {
    bridge: (routeInfo as any).bridgeName as string,
    estimatedGasUSD: Number((routeInfo as any).estimatedGasUsd) / 1e18,
    estimatedTimeSeconds: Number((routeInfo as any).estimatedTimeMinutes) * 60,
  };
}

async function ensureContractReady(
  publicClient: PublicClient,
  destChainId: number
) {
  const toToken = getUsdcForChain(destChainId);
  const [tokenSupported, toTokenSupported, chainSupported] = await Promise.all([
    publicClient.readContract({
      address: STABLECOIN_SWITCH,
      abi: StablecoinSwitchAbi,
      functionName: "isTokenSupported",
      args: [USDC],
    }) as Promise<boolean>,
    publicClient.readContract({
      address: STABLECOIN_SWITCH,
      abi: StablecoinSwitchAbi,
      functionName: "isTokenSupported",
      args: [toToken],
    }) as Promise<boolean>,
    publicClient.readContract({
      address: STABLECOIN_SWITCH,
      abi: StablecoinSwitchAbi,
      functionName: "isChainSupported",
      args: [BigInt(destChainId)],
    }) as Promise<boolean>,
  ]);

  if (!tokenSupported) {
    throw new Error(
      `USDC is not enabled in StablecoinSwitch. Ask owner to call setTokenSupport(USDC, true).`
    );
  }

  if (!toTokenSupported) {
    throw new Error(
      `Destination USDC is not enabled. Ask owner to call setTokenSupport(${toToken}, true).`
    );
  }

  if (!chainSupported) {
    throw new Error(
      `Destination chain ${destChainId} is not enabled. Ask owner to call setChainSupport(${destChainId}, true).`
    );
  }

  // Adapter presence check: try modern getter first, then legacy fallback
  let adapterCount = 0;
  try {
    const adapters = (await publicClient.readContract({
      address: STABLECOIN_SWITCH,
      abi: StablecoinSwitchAbi,
      functionName: "getBridgeAdapters",
      args: [BigInt(destChainId)],
    })) as `0x${string}`[];
    adapterCount = adapters?.length ?? 0;
  } catch (_) {
    // Fallback: legacy single adapter getter
    try {
      const single = (await publicClient.readContract({
        address: STABLECOIN_SWITCH,
        abi: StablecoinSwitchAbi,
        functionName: "getBridgeAdapter",
        args: [BigInt(destChainId)],
      })) as `0x${string}`;
      if (single && single !== "0x0000000000000000000000000000000000000000") {
        adapterCount = 1;
      }
    } catch (_) {
      adapterCount = 0;
    }
  }

  if (adapterCount === 0) {
    throw new Error(
      `No bridge adapters configured for chain ${destChainId}. Ask owner to call addBridgeAdapter(${destChainId}, <adapter>, "Arbitrum", <gasCost>) or legacy setBridgeAdapter(${destChainId}, <adapter>).`
    );
  }
}

/**
 * Fallback feeds health check when the contract lacks areFeedsHealthy.
 * Reads ethUsdPriceFeed and usdcUsdPriceFeed addresses and queries latestRoundData.
 */
export async function ensureFeedsHealthy(publicClient: PublicClient): Promise<{
  ethOk: boolean;
  usdcOk: boolean;
  ethUpdatedAt: bigint;
  usdcUpdatedAt: bigint;
}> {
  const [ethFeed, usdcFeed] = await Promise.all([
    publicClient.readContract({
      address: STABLECOIN_SWITCH,
      abi: StablecoinSwitchAbi,
      functionName: "ethUsdPriceFeed",
    }) as Promise<`0x${string}`>,
    publicClient.readContract({
      address: STABLECOIN_SWITCH,
      abi: StablecoinSwitchAbi,
      functionName: "usdcUsdPriceFeed",
    }) as Promise<`0x${string}`>,
  ]);

  const [ethRound, usdcRound] = await Promise.all([
    publicClient.readContract({
      address: ethFeed,
      abi: AggregatorAbi,
      functionName: "latestRoundData",
    }) as Promise<[bigint, bigint, bigint, bigint, bigint]>,
    publicClient.readContract({
      address: usdcFeed,
      abi: AggregatorAbi,
      functionName: "latestRoundData",
    }) as Promise<[bigint, bigint, bigint, bigint, bigint]>,
  ]);

  const [, ethAnswer, , ethUpdatedAt, ethAnsweredInRound] = ethRound;
  const [ethRoundId] = ethRound;
  const [, usdcAnswer, , usdcUpdatedAt, usdcAnsweredInRound] = usdcRound;
  const [usdcRoundId] = usdcRound;

  const zero = BigInt(0);
  const ethValid = ethAnswer > zero && ethUpdatedAt > zero && ethAnsweredInRound >= ethRoundId;
  const usdcValid = usdcAnswer > zero && usdcUpdatedAt > zero && usdcAnsweredInRound >= usdcRoundId;

  // Use 1 hour freshness threshold to match current deployed contracts
  const now = BigInt(Math.floor(Date.now() / 1000));
  const maxStaleness = BigInt(3600);
  const ethFresh = (now - ethUpdatedAt) <= maxStaleness;
  const usdcFresh = (now - usdcUpdatedAt) <= maxStaleness;

  return {
    ethOk: ethValid && ethFresh,
    usdcOk: usdcValid && usdcFresh,
    ethUpdatedAt,
    usdcUpdatedAt,
  };
}

export async function ensureAllowance(
  publicClient: PublicClient,
  walletClient: WalletClient,
  owner: `0x${string}`,
  spender: `0x${string}`,
  amountUnits: bigint
) {
  const allowance = await publicClient.readContract({
    address: USDC,
    abi: ERC20Abi,
    functionName: "allowance",
    args: [owner, spender],
  });

  if ((allowance as bigint) < amountUnits) {
    // Some ERC20 implementations (e.g., USDC) require resetting allowance to 0 before updating
    if ((allowance as bigint) > BigInt(0)) {
      const resetHash = await walletClient.writeContract({
        address: USDC,
        abi: ERC20Abi,
        functionName: "approve",
        args: [spender, BigInt(0)],
        chain: walletClient.chain,
        account: owner,
      });
      await publicClient.waitForTransactionReceipt({ hash: resetHash });
    }
    const hash = await walletClient.writeContract({
      address: USDC,
      abi: ERC20Abi,
      functionName: "approve",
      args: [spender, amountUnits],
      chain: walletClient.chain,
      account: owner,
    });
    await publicClient.waitForTransactionReceipt({ hash });
    return hash;
  }
  return undefined;
}

export async function estimateRouteGas(
  publicClient: PublicClient,
  params: {
    fromToken: `0x${string}`;
    toToken: `0x${string}`;
    amount: bigint;
    toChainId: number;
    priority: 0 | 1;
    recipient: `0x${string}`;
    minAmountOut?: bigint;
  }
) {
  // Basic parameter validation to avoid unnecessary RPC calls
  if (!params.amount || params.amount <= BigInt(0)) {
    throw new Error("Enter a valid amount greater than 0.");
  }
  if (!/^0x[a-fA-F0-9]{40}$/.test(params.recipient)) {
    throw new Error("Recipient address is invalid.");
  }
  try {
    if (process.env.NODE_ENV === "development") {
      console.groupCollapsed("estimateRouteGas: call");
      console.table({
        amount: String(params.amount),
        toChainId: params.toChainId,
        priority: params.priority,
        recipient: params.recipient,
      });
      console.groupEnd();
    }
    const gas = await publicClient.estimateContractGas({
      address: STABLECOIN_SWITCH,
      abi: StablecoinSwitchAbi,
      functionName: "routeTransaction",
      args: [
        {
          fromToken: params.fromToken,
          toToken: params.toToken,
          amount: params.amount,
          toChainId: BigInt(params.toChainId),
          priority: params.priority,
          recipient: params.recipient,
          minAmountOut: params.minAmountOut ?? BigInt(0),
        },
      ],
    });
    return gas;
  } catch (err: any) {
    const msg = mapSwitchError(err, { destChainId: params.toChainId });
    if (process.env.NODE_ENV === "development") {
      console.groupCollapsed("estimateRouteGas: error");
      console.log(err);
      console.table({ decoded: msg });
      console.groupEnd();
    }
    throw new Error(msg);
  }
}

export async function routeTransaction(
  walletClient: WalletClient,
  publicClient: PublicClient,
  params: {
    fromToken: `0x${string}`;
    toToken: `0x${string}`;
    amount: bigint;
    toChainId: number;
    priority: 0 | 1;
    recipient: `0x${string}`;
    minAmountOut?: bigint;
    account: `0x${string}`;
  }
) {
  // Basic parameter validation
  if (!params.amount || params.amount <= BigInt(0)) {
    throw new Error("Enter a valid amount greater than 0.");
  }
  if (!/^0x[a-fA-F0-9]{40}$/.test(params.recipient)) {
    throw new Error("Recipient address is invalid.");
  }
  try {
    if (process.env.NODE_ENV === "development") {
      console.groupCollapsed("routeTransaction: write");
      console.table({
        amount: String(params.amount),
        toChainId: params.toChainId,
        priority: params.priority,
        recipient: params.recipient,
      });
      console.groupEnd();
    }
    const hash = await walletClient.writeContract({
      address: STABLECOIN_SWITCH,
      abi: StablecoinSwitchAbi,
      functionName: "routeTransaction",
      args: [
        {
          fromToken: params.fromToken,
          toToken: params.toToken,
          amount: params.amount,
          toChainId: BigInt(params.toChainId),
          priority: params.priority,
          recipient: params.recipient,
          minAmountOut: params.minAmountOut ?? BigInt(0),
        },
      ],
      chain: walletClient.chain,
      account: params.account,
    });
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    return { hash, receipt };
  } catch (err: any) {
    const msg = mapSwitchError(err, { destChainId: params.toChainId });
    if (process.env.NODE_ENV === "development") {
      console.groupCollapsed("routeTransaction: error");
      console.log(err);
      console.table({ decoded: msg });
      console.groupEnd();
    }
    throw new Error(msg);
  }
}

export function subscribeEvents(
  publicClient: PublicClient,
  onRouted?: (log: any) => void,
  onSettlement?: (log: any) => void
) {
  const unwatchRouted = publicClient.watchContractEvent({
    address: STABLECOIN_SWITCH,
    abi: StablecoinSwitchAbi,
    eventName: "TransactionRouted",
    onLogs: (logs) => {
      logs.forEach((l) => onRouted?.(l));
    },
  });

  const unwatchSettlement = publicClient.watchContractEvent({
    address: STABLECOIN_SWITCH,
    abi: StablecoinSwitchAbi,
    eventName: "SettlementExecuted",
    onLogs: (logs) => {
      logs.forEach((l) => onSettlement?.(l));
    },
  });

  return () => {
    unwatchRouted?.();
    unwatchSettlement?.();
  };
}

export const constants = {
  contract: STABLECOIN_SWITCH,
  usdc: USDC,
};