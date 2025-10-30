"use client";
import { useState, useEffect, useCallback, useMemo } from "react";
import clsx from "clsx";
import { useAccount, usePublicClient, useWalletClient, useChainId } from "wagmi";
import { ArrowUpDown, Zap, DollarSign, Clock, Gauge } from "lucide-react";
import ChainDropdown from "../components/test";
import { StablecoinSwitchAbi } from "@/lib/abi/StablecoinSwitch";
// Removed unused imports to avoid confusion and keep contract-only flow
import {
  constants as SwitchConstants,
  ensureAllowance,
  estimateRouteGas,
  readOptimalPath,
  routeTransaction,
  subscribeEvents,
  requireNetwork,
} from "@/lib/services/switch";

type Chain = "SEPOLIA" | "ARBITRUM_SEPOLIA";

const CHAIN_ID: Record<Chain, number> = {
  SEPOLIA: 11155111,
  ARBITRUM_SEPOLIA: 421614,
};

interface Route {
  bridge: string;
  estimatedGasUSD: number;
  estimatedTimeSeconds: number;
}

export default function BridgePage() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();
  const [amount, setAmount] = useState("");
  const [fromChain, setFromChain] = useState<Chain>("SEPOLIA");
  const [toChain, setToChain] = useState<Chain>("ARBITRUM_SEPOLIA");
  const [toAddress, setToAddress] = useState("");
  const [routes, setRoutes] = useState<Route[]>([]);
  const [loading, setLoading] = useState(false);
  const [speedPreference, setSpeedPreference] = useState(50);
  const [isSwapping, setIsSwapping] = useState(false);
  const [isLoadingRoute, setIsLoadingRoute] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [gasEstimate, setGasEstimate] = useState<bigint | null>(null);
  const [txHash, setTxHash] = useState<string | null>(null);
  const [txStatus, setTxStatus] = useState<string | null>(null);
  const [routeError, setRouteError] = useState<string | null>(null);
  const [adapterDetected, setAdapterDetected] = useState<boolean>(false);

  // Live UI values for instant feedback
  const [estGas, setEstGas] = useState(0.25);
  const [estTime, setEstTime] = useState(20);
  const [bridgeName, setBridgeName] = useState("polygon");

  // === Auto-swap if same chain ===
  useEffect(() => {
    if (fromChain === toChain) {
      setToChain(fromChain === "SEPOLIA" ? "ARBITRUM_SEPOLIA" : "SEPOLIA");
    }
  }, [fromChain, toChain]);

  // === Fetch Routes from API ===
  const fetchRoutes = useCallback(async () => {
    if (!amount || Number(amount) <= 0) return;
    if (!publicClient) return;
    setLoading(true);
    setIsLoadingRoute(true);
    setRouteError(null);

    try {
      const destChainId = CHAIN_ID[toChain];
      const amountUnits = BigInt(Math.floor(Number(amount) * 1e6));

      // Pre-check: ensure destination chain is supported to avoid noisy errors
      const isSupported = (await publicClient.readContract({
        address: SwitchConstants.contract,
        abi: StablecoinSwitchAbi,
        functionName: "isChainSupported",
        args: [BigInt(destChainId)],
      })) as boolean;
      if (!isSupported) {
        setRoutes([]);
        setRouteError(
          `Destination chain ${destChainId} is not enabled. Ask owner to call setChainSupport(${destChainId}, true).`
        );
        return;
      }

      // Pre-check: price feeds health to avoid revert-heavy route calls
      try {
        const [ethOk, usdcOk, ethUpdatedAt, usdcUpdatedAt] = (await publicClient.readContract({
          address: SwitchConstants.contract,
          abi: StablecoinSwitchAbi,
          functionName: "areFeedsHealthy",
        })) as [boolean, boolean, bigint, bigint];

        if (!ethOk || !usdcOk) {
          const ethTs = Number(ethUpdatedAt || 0) * 1000;
          const usdcTs = Number(usdcUpdatedAt || 0) * 1000;
          const ethStr = ethTs ? new Date(ethTs).toLocaleString() : "unknown";
          const usdcStr = usdcTs ? new Date(usdcTs).toLocaleString() : "unknown";
          setRoutes([]);
          setRouteError(
            `Price feeds unavailable or stale. ETH feed: ${ethOk ? "OK" : "STALE"} (updated ${ethStr}); USDC feed: ${usdcOk ? "OK" : "STALE"} (updated ${usdcStr}). Ask owner to adjust maxPriceStalenessSeconds or verify feed addresses in deployment.`
          );
          return;
        }
        } catch (_) {
          // Fallback: if areFeedsHealthy() is not present on chain, directly check aggregator freshness
          try {
            const { ensureFeedsHealthy } = await import("@/lib/services/switch");
            const { ethOk, usdcOk, ethUpdatedAt, usdcUpdatedAt } = await ensureFeedsHealthy(publicClient);
            if (!ethOk || !usdcOk) {
            const ethTs = Number(ethUpdatedAt ?? BigInt(0)) * 1000;
            const usdcTs = Number(usdcUpdatedAt ?? BigInt(0)) * 1000;
            const ethStr = ethTs ? new Date(ethTs).toLocaleString() : "unknown";
            const usdcStr = usdcTs ? new Date(usdcTs).toLocaleString() : "unknown";
            setRoutes([]);
            setRouteError(
              `Price feeds unavailable or stale. ETH feed: ${ethOk ? "OK" : "STALE"} (updated ${ethStr}); USDC feed: ${usdcOk ? "OK" : "STALE"} (updated ${usdcStr}).`
            );
            return;
            }
          } catch {
            // Continue; downstream error mapping will handle
          }
        }

      const priority: 0 | 1 = speedPreference >= 66 ? 1 : 0;
      const route = await readOptimalPath(publicClient, amountUnits, destChainId, priority);
      setRoutes([
        {
          bridge: route.bridge,
          estimatedGasUSD: route.estimatedGasUSD,
          estimatedTimeSeconds: route.estimatedTimeSeconds,
        },
      ]);

      const gas = await estimateRouteGas(publicClient, {
        fromToken: SwitchConstants.usdc,
        toToken: SwitchConstants.usdc,
        amount: amountUnits,
        toChainId: destChainId,
        priority,
        recipient: (toAddress || address) as `0x${string}`,
      });
      setGasEstimate(gas);
    } catch (error: any) {
      const message = String(error?.response?.data || error?.message || error);
      setRouteError(message);
      setRoutes([]);
    } finally {
      setLoading(false);
      setIsLoadingRoute(false);
    }
  }, [address, amount, fromChain, toChain, publicClient, toAddress, speedPreference]);

  // === Auto-fetch when amount or chains change ===
  useEffect(() => {
    const timer = setTimeout(() => {
      if (amount && Number(amount) > 0) {
        fetchRoutes();
      }
    }, 600);
    return () => clearTimeout(timer);
  }, [amount, fromChain, toChain, fetchRoutes]);

  useEffect(() => {
    if (!publicClient) return;
    const unwatch = subscribeEvents(
      publicClient,
      () => setTxStatus("Transaction routed on-chain."),
      () => setTxStatus("Settlement executed.")
    );
    return () => unwatch();
  }, [publicClient]);

  // === Adapter detection badge ===
  useEffect(() => {
    (async () => {
      if (!publicClient) return;
      try {
        const destChainId = CHAIN_ID[toChain];
        let detected = false;
        try {
          const adapters = (await publicClient.readContract({
            address: SwitchConstants.contract,
            abi: StablecoinSwitchAbi,
            functionName: "getBridgeAdapters",
            args: [BigInt(destChainId)],
          })) as `0x${string}`[];
          detected = !!(adapters && adapters.length > 0);
        } catch (_) {
          try {
            const single = (await publicClient.readContract({
              address: SwitchConstants.contract,
              abi: StablecoinSwitchAbi,
              functionName: "getBridgeAdapter",
              args: [BigInt(destChainId)],
            })) as `0x${string}`;
            detected = !!(single && single !== "0x0000000000000000000000000000000000000000");
          } catch (_) {
            detected = false;
          }
        }
        setAdapterDetected(detected);
      } catch {
        setAdapterDetected(false);
      }
    })();
  }, [publicClient, toChain]);

  // === Dynamic best route (computed instantly) ===
  const bestRoute = useMemo(() => {
    if (routes.length === 0) return null;

    const speedWeight = speedPreference / 100;
    const gasWeight = 1 - speedWeight;

    return routes.reduce((best, route) => {
      const bestScore = best
        ? best.estimatedGasUSD * gasWeight +
          (best.estimatedTimeSeconds / 60) * speedWeight
        : Infinity;

      const currentScore =
        route.estimatedGasUSD * gasWeight +
        (route.estimatedTimeSeconds / 60) * speedWeight;

      return currentScore < bestScore ? route : best;
    }, null as Route | null);
  }, [routes, speedPreference]);

  // === Real-time dynamic display values (even before API) ===
  useEffect(() => {
    // Simulate local instant feedback
    const gas = 0.001 * speedPreference + 0.2; // Example: faster → slightly higher gas
    const time = Math.max(2, 25 - speedPreference / 5); // faster → lower time
    const bridge =
      speedPreference < 33
        ? "LayerZero"
        : speedPreference < 66
        ? "Synapse"
        : "Polygon Bridge";

    setEstGas(gas);
    setEstTime(time);
    setBridgeName(bridge);
  }, [speedPreference]);

  // === Debug Log ===
  const handleDebugLog = () => {
    console.clear();
    console.table({
      Address: address || "Not connected",
      Amount: amount || "Empty",
      From: fromChain,
      To: toChain,
      Speed: speedPreference,
      Routes: routes.length,
      BestRoute: bestRoute?.bridge || "None",
    });
  };

  // === Bridge Action ===
  const handleBridge = async () => {
    try {
      if (!walletClient || !publicClient || !address) {
        alert("Wallet not ready");
        return;
      }
      // Basic input validation
      if (!amount || Number(amount) <= 0) {
        alert("Enter a valid amount greater than zero.");
        return;
      }
      if (toAddress && !/^0x[a-fA-F0-9]{40}$/.test(toAddress)) {
        alert("Recipient address is invalid.");
        return;
      }

      setIsSubmitting(true);
      const destChainId = CHAIN_ID[toChain];
      await requireNetwork(chainId, walletClient, CHAIN_ID[fromChain]);

      const amountUnits = BigInt(Math.floor(Number(amount) * 1e6));

      // Safety check before attempting to write: ensure destination chain is enabled and adapters exist
      const isSupported = (await publicClient.readContract({
        address: SwitchConstants.contract,
        abi: StablecoinSwitchAbi,
        functionName: "isChainSupported",
        args: [BigInt(destChainId)],
      })) as boolean;
      if (!isSupported) {
        const msg = `Destination chain ${destChainId} is not enabled. Ask owner to call setChainSupport(${destChainId}, true).`;
        setRouteError(msg);
        alert(msg);
        setIsSubmitting(false);
        return;
      }
      // Adapter presence check with legacy fallback
      let adapterCount = 0;
      try {
        const adapters = (await publicClient.readContract({
          address: SwitchConstants.contract,
          abi: StablecoinSwitchAbi,
          functionName: "getBridgeAdapters",
          args: [BigInt(destChainId)],
        })) as `0x${string}`[];
        adapterCount = adapters?.length ?? 0;
      } catch (_) {
        try {
          const single = (await publicClient.readContract({
            address: SwitchConstants.contract,
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
        const msg = `No bridge adapters configured for chain ${destChainId}. Ask owner to call addBridgeAdapter(${destChainId}, <adapter>, "Arbitrum", <gasCost>) or legacy setBridgeAdapter(${destChainId}, <adapter>).`;
        setRouteError(msg);
        alert(msg);
        setIsSubmitting(false);
        return;
      }

      // Compute a route on-demand if none is available
      if (!bestRoute) {
        const priorityOnDemand: 0 | 1 = speedPreference >= 66 ? 1 : 0;
        const onDemand = await readOptimalPath(publicClient, amountUnits, destChainId, priorityOnDemand);
        if (onDemand) {
          setRoutes([
            {
              bridge: onDemand.bridge,
              estimatedGasUSD: onDemand.estimatedGasUSD,
              estimatedTimeSeconds: onDemand.estimatedTimeSeconds,
            },
          ]);
        } else {
          alert("No valid route found");
          setIsSubmitting(false);
          return;
        }
      }
      await ensureAllowance(publicClient, walletClient, address as `0x${string}`, SwitchConstants.contract, amountUnits);

      const priority: 0 | 1 = speedPreference >= 66 ? 1 : 0;
      const recipient = (toAddress || address) as `0x${string}`;

      const { hash, receipt } = await routeTransaction(walletClient, publicClient, {
        fromToken: SwitchConstants.usdc,
        toToken: SwitchConstants.usdc,
        amount: amountUnits,
        toChainId: destChainId,
        priority,
        recipient,
        account: address as `0x${string}`,
      });
      setTxHash(hash);
      setTxStatus(`Confirmed in block ${receipt.blockNumber}`);
      alert("Transaction submitted and confirmed. Check Explorer.");
    } catch (err: any) {
      console.error("Bridge error:", err?.message || err);
      alert("Bridge failed: " + (err?.message || "unknown error"));
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center  p-4 ">
      <div className="w-full max-w-2xl bg-white rounded-3xl shadow-lg p-6 space-y-6 z-20">
        {/* Adapter status badge */}
        <div className="flex justify-end">
          <span
            className={clsx(
              "inline-flex items-center px-3 py-1 rounded-full text-xs font-medium",
              adapterDetected ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700"
            )}
          >
            {adapterDetected ? "Arbitrum adapter detected" : "No adapter detected"}
          </span>
        </div>
        {/* ==== FROM ==== */}
        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-700">
            Price
          </label>
          <div className="flex items-center justify-between p-4 bg-gray-50 rounded-xl">
            <input
              type="number"
              inputMode="decimal"
              step="0.000001"
              value={amount}
              placeholder="0.00"
              onChange={(e) => setAmount(e.target.value)}
              className="text-2xl font-semibold bg-transparent outline-none flex-1 min-w-0"
            />
            <ChainDropdown
              selected={fromChain}
              setSelected={setFromChain}
            />
          </div>
        </div>

        {/* ==== SWAP ==== */}
        <div className="flex justify-center -my-2 z-10">
          <button
            onClick={() => {
              setFromChain(toChain);
              setToChain(fromChain);
              setIsSwapping(true);
              setTimeout(() => setIsSwapping(false), 400);
            }}
            className="w-15 h-15 bg-purple-100 hover:bg-purple-200 rounded-full flex items-center justify-center transition-colors cursor-pointer"
          >
            <ArrowUpDown className={clsx("w-8 h-8 text-purple-700", isSwapping && "animate-rotate-once")} />
          </button>
        </div>

        {/* ==== TO ==== */}
        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-700">To</label>
          <div className="flex items-center justify-between p-4 bg-gray-50 rounded-xl">
            <input
              type="text"
              value={toAddress}
              onChange={(e) => setToAddress(e.target.value)}
              className="text-2xl font-semibold bg-transparent outline-none w-32"
              placeholder="0x..."
            />
            <ChainDropdown
              selected={toChain}
              setSelected={setToChain}
            />
          </div>
        </div>

        {/* ==== SPEED SLIDER ==== */}
        {/* <div className="bg-gray-50 rounded-xl p-4 space-y-2">
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1 text-sm text-gray-600">
              <Gauge className="w-4 h-4 text-purple-600" />
              Transaction Speed
            </span>
            <span className="text-sm font-medium text-purple-700">
              {speedPreference < 33
                ? "Cheapest"
                : speedPreference < 66
                ? "Balanced"
                : "Fastest"}
            </span>
          </div>
          <input
            type="range"
            min="0"
            max="100"
            step="1"
            value={speedPreference}
            onChange={(e) => setSpeedPreference(Number(e.target.value))}
            className="w-full accent-purple-600 cursor-pointer"
          />
        </div> */}

        <div className="space-y-3 text-sm bg-gradient-to-r from-emerald-50 to-teal-50 p-4 rounded-xl border border-emerald-200 transition-all duration-300">
          <div className="flex items-center justify-between">
            <span className="text-gray-600 flex items-center gap-1">
              <Zap className="w-4 h-4 text-emerald-600" />
              Bridge
            </span>
            <span className="font-semibold text-emerald-700">{bestRoute?.bridge ?? bridgeName}</span>
          </div>

          <div className="flex items-center justify-between">
            <span className="text-gray-600 flex items-center gap-1">
              <DollarSign className="w-4 h-4 text-emerald-600" />
              Est. Gas
            </span>
            <span className="font-medium">${(bestRoute?.estimatedGasUSD ?? estGas).toFixed(4)}</span>
          </div>

          <div className="flex items-center justify-between">
            <span className="text-gray-600 flex items-center gap-1">
              <Clock className="w-4 h-4 text-emerald-600" />
              Est. Time
            </span>
            <span className="font-medium">{((bestRoute?.estimatedTimeSeconds ?? estTime * 60) / 60).toFixed(1)} min</span>
          </div>

          <div className="text-xs text-emerald-600 font-medium mt-2">
            Adjusted for speed preference ({speedPreference}% fast)
          </div>
        </div>

        {routeError && (
          <div className="p-3 rounded-xl bg-red-50 border border-red-200 text-sm text-red-700">
            {routeError}
          </div>
        )}

        {/* ==== ACTION ==== */}
        <div className="space-y-2">
          <button
            onClick={handleBridge}
            disabled={!isConnected || !amount || loading || !!routeError || routes.length === 0}
            className={clsx(
              "w-full py-4 font-semibold rounded-2xl transition-all flex items-center justify-center gap-2",
              isConnected && amount && !loading && !routeError && routes.length > 0
                ? "bg-emerald-600 hover:bg-emerald-700 text-white"
                : "bg-gray-300 text-gray-500 cursor-not-allowed"
            )}
          >
            {isSubmitting ? "Routing..." : loading ? "Finding Route..." : "Bridge Now"}
          </button>

          {isLoadingRoute && (
            <div className="text-xs mt-2">Calculating optimal route...</div>
          )}
          {gasEstimate && (
            <div className="text-xs mt-1">Estimated gas: {String(gasEstimate)} units</div>
          )}
          {txHash && (
            <div className="text-xs mt-2 break-all">Tx: {txHash}</div>
          )}
          {txStatus && <div className="text-xs mt-1">Status: {txStatus}</div>}

          {process.env.NODE_ENV === "development" && (
            <button
              onClick={handleDebugLog}
              className="w-full py-2 text-xs text-gray-500 hover:text-gray-700 underline"
            >
              Log State (Dev)
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
