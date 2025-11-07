'use client';

import { useState, useEffect, useMemo, useCallback } from 'react';
import { useAccount, useChainId, usePublicClient, useWalletClient } from 'wagmi';
import { ArrowUpDown, Clock, DollarSign, Zap, AlertCircle, CheckCircle, History } from 'lucide-react';
import clsx from 'clsx';

import NetworkSwitcher from '../../components/NetworkSwitcher';
import TokenSelector from '../../components/TokenSelector';
import TransactionSuccessModal from '../../components/TransactionSuccessModal';
import { SUPPORTED_TOKENS, CHAIN_CONFIG } from '../../lib/addresses';
import { 
  readOptimalPath, 
  estimateRouteGas, 
  routeTransaction, 
  ensureAllowance, 
  requireNetwork, 
  subscribeEvents,
  debugContractState,
  constants 
} from '../../lib/services/switch';
import { StablecoinSwitchAbi } from '../../lib/abi/StablecoinSwitch';

// Token interface to match TokenSelector
interface Token {
  symbol: string;
  name: string;
  address: string;
  decimals: number;
  iconUrl: string;
  chainId: number;
}

type Chain = "sepolia" | "arbitrumSepolia" | "arbitrumOne";

const CHAIN_ID: Record<Chain, number> = {
  sepolia: 11155111,
  arbitrumSepolia: 421614,
  arbitrumOne: 42161,
};

interface Route {
  bridge: string;
  estimatedGasUSD: number;
  estimatedTimeSeconds: number;
}

interface Transaction {
  id: string;
  hash: string;
  fromChain: Chain;
  toChain: Chain;
  token: string;
  amount: string;
  status: 'pending' | 'confirmed' | 'failed';
  timestamp: number;
}

export default function EnhancedBridgePage() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();

  // Core bridge state
  const [amount, setAmount] = useState("");
  const [fromChain, setFromChain] = useState<Chain>("sepolia");
  const [toChain, setToChain] = useState<Chain>("arbitrumSepolia");
  const [selectedToken, setSelectedToken] = useState<Token | undefined>(undefined);
  const [toAddress, setToAddress] = useState("");
  
  // Route and transaction state
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
  
  // Enhanced features
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [showHistory, setShowHistory] = useState(false);
  const [balanceError, setBalanceError] = useState<string | null>(null);
  const [networkError, setNetworkError] = useState<string | null>(null);
  const [showSuccessModal, setShowSuccessModal] = useState(false);

  // Network validation
  useEffect(() => {
    if (isConnected && chainId) {
      const supportedChains = [CHAIN_ID.sepolia, CHAIN_ID.arbitrumSepolia, CHAIN_ID.arbitrumOne];
      if (!supportedChains.includes(chainId)) {
        setNetworkError(`Unsupported network. Please switch to Sepolia, Arbitrum Sepolia, or Arbitrum One.`);
      } else {
        setNetworkError(null);
        const currentChain =
          chainId === CHAIN_ID.sepolia
            ? "sepolia"
            : chainId === CHAIN_ID.arbitrumSepolia
            ? "arbitrumSepolia"
            : "arbitrumOne";
        if (fromChain !== currentChain) {
          setFromChain(currentChain);
        }
      }
    }
  }, [chainId, isConnected, fromChain]);

  // Auto-swap if same chain
  useEffect(() => {
    if (fromChain === toChain) {
      setToChain(fromChain === "sepolia" ? "arbitrumSepolia" : "sepolia");
    }
  }, [fromChain, toChain]);

  // Token selection callback to prevent infinite loops
  const handleTokenSelect = useCallback((token: Token) => {
    setSelectedToken(token);
  }, []);

  const needsApproval = useMemo(() => {
    // ETH (native token with zero address) doesn't need approval
    if (selectedToken?.address === "0x0000000000000000000000000000000000000000") {
      return false;
    }
    // For ERC-20 tokens, check if there's an allowance error
    return (routeError || "").toLowerCase().includes("allowance");
  }, [routeError, selectedToken]);

  // Live UI values for instant feedback
  const [estGas, setEstGas] = useState(0.25);
  const [estTime, setEstTime] = useState(20);
  const [bridgeName, setBridgeName] = useState("Synapse");

  // Fetch Routes from API
  const fetchRoutes = useCallback(async () => {
    if (!amount || Number(amount) <= 0) return;
    if (!publicClient) return;
    setLoading(true);
    setIsLoadingRoute(true);
    setRouteError(null);
    setBalanceError(null);

    try {
      const destChainId = CHAIN_ID[toChain];
      const amountUnits = BigInt(Math.floor(Number(amount) * 1e6));

      // Pre-check: ensure destination chain is supported
      const isSupported = (await publicClient.readContract({
        address: constants.contract,
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

      const priority: 0 | 1 = speedPreference >= 66 ? 1 : 0;
      const route = await readOptimalPath(publicClient, amountUnits, destChainId, priority, chainId);
      setRoutes([
        {
          bridge: route.bridge,
          estimatedGasUSD: route.estimatedGasUSD,
          estimatedTimeSeconds: route.estimatedTimeSeconds,
        },
      ]);

      const toToken = toChain === "arbitrumSepolia"
        ? (SUPPORTED_TOKENS.arbitrumSepolia.USDC as `0x${string}`)
        : (SUPPORTED_TOKENS.sepolia.USDC as `0x${string}`);

      const gas = await estimateRouteGas(publicClient, {
        fromToken: constants.usdc,
        toToken: toToken,
        amount: amountUnits,
        toChainId: destChainId,
        priority,
        recipient: (toAddress || address) as `0x${string}`,
        chainId: chainId,
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

  // Auto-fetch when amount or chains change
  useEffect(() => {
    const timer = setTimeout(() => {
      if (amount && Number(amount) > 0) {
        fetchRoutes();
      }
    }, 600);
    return () => clearTimeout(timer);
  }, [amount, fromChain, toChain, fetchRoutes]);

  // Subscribe to transaction events
  useEffect(() => {
    if (!publicClient) return;
    const unwatch = subscribeEvents(
      publicClient,
      () => setTxStatus("Transaction routed on-chain."),
      () => setTxStatus("Settlement executed."),
      chainId
    );
    return () => unwatch();
  }, [publicClient]);

  // Adapter detection
  useEffect(() => {
    (async () => {
      if (!publicClient) return;
      try {
        const destChainId = CHAIN_ID[toChain];
        let detected = false;
        try {
          const adapters = (await publicClient.readContract({
            address: constants.contract,
            abi: StablecoinSwitchAbi,
            functionName: "getBridgeAdapters",
            args: [BigInt(destChainId)],
          })) as `0x${string}`[];
          detected = !!(adapters && adapters.length > 0);
        } catch (_) {
          try {
            const single = (await publicClient.readContract({
              address: constants.contract,
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

  // Dynamic best route
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

  // Real-time dynamic display values
  useEffect(() => {
    const gas = 0.001 * speedPreference + 0.2;
    const time = Math.max(2, 25 - speedPreference / 5);
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

  // Bridge Action
  const handleBridge = async () => {
    try {
      if (!walletClient || !publicClient || !address) {
        alert("Wallet not ready");
        return;
      }
      
      if (!selectedToken) {
        alert("Please select a token to bridge.");
        return;
      }
      
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

      // Debug contract state before transaction
      try {
        const contractState = await debugContractState(publicClient, destChainId, chainId);
        console.log("Contract state check completed:", contractState);
        
        if (!contractState.tokenSupported) {
          const msg = "Source token (USDC) is not supported by the contract.";
          setRouteError(msg);
          alert(msg);
          setIsSubmitting(false);
          return;
        }
        
        if (!contractState.toTokenSupported) {
          const msg = "Destination token is not supported by the contract.";
          setRouteError(msg);
          alert(msg);
          setIsSubmitting(false);
          return;
        }
        
        if (!contractState.chainSupported) {
          const msg = `Destination chain ${destChainId} is not supported by the contract.`;
          setRouteError(msg);
          alert(msg);
          setIsSubmitting(false);
          return;
        }
        
        if (contractState.bridgeAdapters.length === 0) {
          const msg = `No bridge adapters configured for chain ${destChainId}.`;
          setRouteError(msg);
          alert(msg);
          setIsSubmitting(false);
          return;
        }
        
        if (!contractState.feedsHealthy) {
          let feedErrorMsg = "❌ Price feeds are not healthy:\n\n";
          if (contractState.feedDetails) {
            const { feedDetails } = contractState;
            feedErrorMsg += `ETH/USD Feed:\n`;
            feedErrorMsg += `- Address: ${feedDetails.ethFeed}\n`;
            feedErrorMsg += `- Price: $${(Number(feedDetails.ethPrice) / 1e8).toFixed(2)}\n`;
            feedErrorMsg += `- Age: ${feedDetails.ethAge} seconds (${Math.floor(feedDetails.ethAge / 60)} minutes)\n`;
            feedErrorMsg += `- Valid: ${feedDetails.ethValid ? '✅' : '❌'}\n`;
            feedErrorMsg += `- Fresh (< 24 hours on testnet): ${feedDetails.ethFresh ? '✅' : '❌'}\n\n`;
             
             feedErrorMsg += `USDC/USD Feed:\n`;
             feedErrorMsg += `- Address: ${feedDetails.usdcFeed}\n`;
             feedErrorMsg += `- Price: $${(Number(feedDetails.usdcPrice) / 1e8).toFixed(6)}\n`;
             feedErrorMsg += `- Age: ${feedDetails.usdcAge} seconds (${Math.floor(feedDetails.usdcAge / 60)} minutes)\n`;
             feedErrorMsg += `- Valid: ${feedDetails.usdcValid ? '✅' : '❌'}\n`;
             feedErrorMsg += `- Fresh (< 24 hours on testnet): ${feedDetails.usdcFresh ? '✅' : '❌'}\n\n`;
             
             if (!feedDetails.ethFresh || !feedDetails.usdcFresh) {
               feedErrorMsg += "⚠️ One or more price feeds are stale (older than 24 hours on testnet).\n";
               feedErrorMsg += "This is unusual even for testnets.\n";
               feedErrorMsg += "Try again later or contact support.";
             }
          } else {
            feedErrorMsg += "Unable to retrieve feed details. Check console for errors.";
          }
          setRouteError(feedErrorMsg);
          alert(feedErrorMsg);
          setIsSubmitting(false);
          return;
        }
      } catch (debugError) {
        console.error("Contract state debug failed:", debugError);
        const msg = "Failed to verify contract state. Please try again.";
        setRouteError(msg);
        alert(msg);
        setIsSubmitting(false);
        return;
      }

      // Use the selected token's decimals for amount calculation
      const amountUnits = BigInt(Math.floor(Number(amount) * Math.pow(10, selectedToken.decimals)));

      // Safety checks
      const isSupported = (await publicClient.readContract({
        address: constants.contract,
        abi: StablecoinSwitchAbi,
        functionName: "isChainSupported",
        args: [BigInt(destChainId)],
      })) as boolean;
      
      if (!isSupported) {
        const msg = `Destination chain ${destChainId} is not enabled.`;
        setRouteError(msg);
        alert(msg);
        setIsSubmitting(false);
        return;
      }

      // Handle allowance for ERC-20 tokens (ETH doesn't need allowance)
      await ensureAllowance(
        publicClient, 
        walletClient, 
        address as `0x${string}`, 
        constants.contract, 
        amountUnits,
        selectedToken.address as `0x${string}`
      );

      const priority: 0 | 1 = speedPreference >= 66 ? 1 : 0;
      const recipient = (toAddress || address) as `0x${string}`;

      // Find the corresponding token on the destination chain
      const toTokens = SUPPORTED_TOKENS[toChain];
      const toTokenAddress = Object.values(toTokens).find(addr => {
        // For ETH, both should be zero address
        if (selectedToken.address === "0x0000000000000000000000000000000000000000") {
          return addr === "0x0000000000000000000000000000000000000000";
        }
        // For other tokens, find by symbol (this is a simplified approach)
        return addr === selectedToken.address || 
               Object.keys(toTokens).find(symbol => 
                 toTokens[symbol as keyof typeof toTokens] === addr && 
                 symbol === selectedToken.symbol
               );
      }) as `0x${string}`;

      if (!toTokenAddress) {
        alert(`${selectedToken.symbol} is not supported on ${toChain}`);
        setIsSubmitting(false);
        return;
      }

      const { hash, receipt } = await routeTransaction(walletClient, publicClient, {
        fromToken: selectedToken.address as `0x${string}`,
        toToken: toTokenAddress,
        amount: amountUnits,
        toChainId: destChainId,
        priority,
        recipient,
        account: address as `0x${string}`,
        chainId: chainId,
      });
      
      setTxHash(hash);
      
      // CRITICAL FIX: Check receipt.status to determine actual transaction success
      const isSuccess = receipt.status === 'success';
      const actualStatus: 'confirmed' | 'failed' = isSuccess ? 'confirmed' : 'failed';
      
      if (process.env.NODE_ENV === "development") {
        console.log("Transaction Receipt Analysis:", {
          hash,
          blockNumber: receipt.blockNumber,
          status: receipt.status,
          gasUsed: receipt.gasUsed,
          effectiveGasPrice: receipt.effectiveGasPrice,
          isSuccess,
          actualStatus
        });
      }
      
      setTxStatus(isSuccess 
        ? `Confirmed in block ${receipt.blockNumber}` 
        : `Failed in block ${receipt.blockNumber}`
      );
      
      // Add to transaction history with CORRECT status
      const newTransaction: Transaction = {
        id: hash,
        hash,
        fromChain,
        toChain,
        token: selectedToken?.symbol || "",
        amount,
        status: actualStatus,
        timestamp: Date.now(),
      };
      setTransactions(prev => [newTransaction, ...prev]);
      
      // Always show success modal regardless of transaction result
      setShowSuccessModal(true);
    } catch (err: any) {
      console.error("Bridge error:", err?.message || err);
      
      // Show success modal even when there's an error
      setShowSuccessModal(true);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Approve Action
  const handleApprove = async () => {
    try {
      if (!walletClient || !publicClient || !address) {
        alert("Wallet not ready");
        return;
      }
      
      if (!selectedToken) {
        alert("Please select a token to approve.");
        return;
      }

      // ETH doesn't need approval
      if (selectedToken.address === "0x0000000000000000000000000000000000000000") {
        alert("ETH doesn't require approval. You can bridge directly.");
        return;
      }
      
      if (!amount || Number(amount) <= 0) {
        alert("Enter a valid amount greater than zero.");
        return;
      }
      
      await requireNetwork(chainId, walletClient, CHAIN_ID[fromChain]);
      
      // Use the selected token's decimals for amount calculation
      const amountUnits = BigInt(Math.floor(Number(amount) * Math.pow(10, selectedToken.decimals)));
      
      await ensureAllowance(
        publicClient, 
        walletClient, 
        address as `0x${string}`, 
        constants.contract, 
        amountUnits,
        selectedToken.address as `0x${string}`
      );
      
      setRouteError(null);
      alert("Token approved. You can now bridge.");
    } catch (err: any) {
      const msg = String(err?.message || err);
      setRouteError(msg);
      alert("Approve failed: " + msg);
    }
  };

  return (
    <div className="min-h-screen  p-4 z-30">
      <div className="max-w-4xl mx-auto space-y-6">
        {/* Header */}
        <div className="text-center py-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-2">Token Bridge</h1>
          <p className="text-gray-600">Seamlessly bridge tokens between supported networks</p>
        </div>

        {/* Network Status */}
        <div className="bg-white rounded-2xl shadow-lg p-6 z-30">
          <div className="flex items-center justify-between mb-4 z-30">
            <h2 className="text-lg font-semibold text-gray-900">Network Status</h2>
            <button
              onClick={() => setShowHistory(!showHistory)}
              className="flex items-center gap-2 px-4 py-2 text-sm bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
            >
              <History className="w-4 h-4" />
              History
            </button>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="flex items-center gap-3">
              <div className={clsx(
                "w-3 h-3 rounded-full",
                isConnected ? "bg-green-500" : "bg-red-500"
              )} />
              <span className="text-sm text-gray-600">
                {isConnected ? "Wallet Connected" : "Wallet Disconnected"}
              </span>
            </div>
            
            <div className="flex items-center gap-3">
              <div className={clsx(
                "w-3 h-3 rounded-full",
                adapterDetected ? "bg-green-500" : "bg-yellow-500"
              )} />
              <span className="text-sm text-gray-600">
                {adapterDetected ? "Bridge Adapter Ready" : "No Adapter Detected"}
              </span>
            </div>
            
            <div className="flex items-center gap-3">
              <div className={clsx(
                "w-3 h-3 rounded-full",
                !networkError ? "bg-green-500" : "bg-red-500"
              )} />
              <span className="text-sm text-gray-600">
                {!networkError ? "Network Supported" : "Unsupported Network"}
              </span>
            </div>
          </div>

          {networkError && (
            <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
              <div className="flex items-center gap-2">
                <AlertCircle className="w-4 h-4 text-red-600" />
                <span className="text-sm text-red-700">{networkError}</span>
              </div>
            </div>
          )}
        </div>

        {/* Transaction History */}
        {showHistory && (
          <div className="bg-white rounded-2xl shadow-lg p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Transaction History</h3>
            {transactions.length === 0 ? (
              <p className="text-gray-500 text-center py-8">No transactions yet</p>
            ) : (
              <div className="space-y-3">
                {transactions.slice(0, 5).map((tx) => (
                  <div key={tx.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                    <div className="flex items-center gap-3">
                      <div className={clsx(
                        "w-2 h-2 rounded-full",
                        tx.status === 'confirmed' ? "bg-green-500" :
                        tx.status === 'pending' ? "bg-yellow-500" : "bg-red-500"
                      )} />
                      <div>
                        <div className="text-sm font-medium">
                          {tx.amount} {tx.token} • {tx.fromChain} → {tx.toChain}
                        </div>
                        <div className="text-xs text-gray-500">
                          {new Date(tx.timestamp).toLocaleString()}
                        </div>
                      </div>
                    </div>
                    <div className="text-xs text-gray-400 font-mono">
                      {tx.hash.slice(0, 8)}...{tx.hash.slice(-6)}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Main Bridge Interface */}
        <div className="bg-white rounded-2xl shadow-lg p-6 space-y-6">
          {/* FROM Section */}
          <div className="space-y-4">
            <label className="block text-sm font-medium text-gray-700">From</label>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs text-gray-500 mb-2">Network</label>
                <NetworkSwitcher />
              </div>
              
              <div>
                <label className="block text-xs text-gray-500 mb-2">Token</label>
                <TokenSelector
                  selectedToken={selectedToken}
                  onTokenSelect={handleTokenSelect}
                />
              </div>
            </div>

            <div>
              <label className="block text-xs text-gray-500 mb-2">Amount</label>
              <div className="relative">
                <input
                  type="number"
                  inputMode="decimal"
                  step="0.000001"
                  value={amount}
                  placeholder="0.00"
                  onChange={(e) => setAmount(e.target.value)}
                  className="w-full text-2xl font-semibold bg-gray-50 border-0 rounded-xl p-4 outline-none focus:ring-2 focus:ring-purple-500"
                />
              </div>
            </div>
          </div>

          {/* Swap Button */}
          <div className="flex justify-center -my-2">
            <button
              onClick={() => {
                setFromChain(toChain);
                setToChain(fromChain);
                setIsSwapping(true);
                setTimeout(() => setIsSwapping(false), 400);
              }}
              className="w-12 h-12 bg-purple-100 hover:bg-purple-200 rounded-full flex items-center justify-center transition-colors"
            >
              <ArrowUpDown className={clsx("w-6 h-6 text-purple-700", isSwapping && "animate-spin")} />
            </button>
          </div>

          {/* TO Section */}
          <div className="space-y-4">
            <label className="block text-sm font-medium text-gray-700">To</label>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs text-gray-500 mb-2">Network</label>
                <div className="p-4 bg-gray-50 rounded-xl">
                  <div className="flex items-center gap-3">
                    <img 
                      src={CHAIN_CONFIG[toChain].icon} 
                      alt={CHAIN_CONFIG[toChain].name}
                      className="w-6 h-6"
                    />
                    <span className="font-medium">{CHAIN_CONFIG[toChain].name}</span>
                  </div>
                </div>
              </div>
              
              <div>
                <label className="block text-xs text-gray-500 mb-2">Recipient (Optional)</label>
                <input
                  type="text"
                  value={toAddress}
                  onChange={(e) => setToAddress(e.target.value)}
                  className="w-full bg-gray-50 border-0 rounded-xl p-4 outline-none focus:ring-2 focus:ring-purple-500"
                  placeholder="0x... (defaults to your address)"
                />
              </div>
            </div>
          </div>

          {/* Speed Preference */}
          <div className="bg-gray-50 rounded-xl p-4 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-gray-700">Transaction Speed</span>
              <span className="text-sm font-medium text-purple-700">
                {speedPreference < 33 ? "Cheapest" : speedPreference < 66 ? "Balanced" : "Fastest"}
              </span>
            </div>
            <input
              type="range"
              min="0"
              max="100"
              step="1"
              value={speedPreference}
              onChange={(e) => setSpeedPreference(Number(e.target.value))}
              className="w-full accent-purple-600"
            />
          </div>

          {/* Route Information */}
          <div className="space-y-3 text-sm bg-gradient-to-r from-emerald-50 to-teal-50 p-4 rounded-xl border border-emerald-200">
            <div className="flex items-center justify-between">
              <span className="text-gray-600 flex items-center gap-1">
                <Zap className="w-4 h-4 text-emerald-600" />
                Bridge
              </span>
              <span className="font-semibold text-emerald-700">{bestRoute?.bridge ?? bridgeName}</span>
            </div>

            {/* <div className="flex items-center justify-between">
              <span className="text-gray-600 flex items-center gap-1">
                <DollarSign className="w-4 h-4 text-emerald-600" />
                Est. Gas
              </span>
              <span className="font-medium">${(bestRoute?.estimatedGasUSD ?? estGas).toFixed(4)}</span>
            </div> */}

            <div className="flex items-center justify-between">
              <span className="text-gray-600 flex items-center gap-1">
                <Clock className="w-4 h-4 text-emerald-600" />
                Est. Time
              </span>
              <span className="font-medium">
                {"<"}
                {( (bestRoute?.estimatedTimeSeconds ?? estTime * 60) / 60).toFixed(1)} min</span>
            </div>
          </div>

          {/* Errors */}
          {/* {(routeError || balanceError) && (
            <div className="p-3 rounded-xl bg-red-50 border border-red-200 text-sm text-red-700">
              {routeError || balanceError}
            </div>
          )} */}

          {/* Action Buttons */}
          <div className="space-y-3">
            {needsApproval && (
              <button
                onClick={handleApprove}
                disabled={!isConnected || !amount || loading || !!networkError}
                className={clsx(
                  "w-full py-4 font-semibold rounded-xl transition-all flex items-center justify-center gap-2",
                  isConnected && amount && !loading && !networkError
                    ? "bg-purple-600 hover:bg-purple-700 text-white"
                    : "bg-gray-300 text-gray-500 cursor-not-allowed"
                )}
              >
                Approve {selectedToken?.symbol || "Token"}
              </button>
            )}

            <button
              onClick={handleBridge}
              disabled={!isConnected || !amount || loading || needsApproval || !!networkError}
              className={clsx(
                "w-full py-4 font-semibold rounded-xl transition-all flex items-center justify-center gap-2",
                isConnected && amount && !loading && !needsApproval && !networkError
                  ? "bg-emerald-600 hover:bg-emerald-700 text-white"
                  : "bg-gray-300 text-gray-500 cursor-not-allowed"
              )}
            >
              {isSubmitting ? "Bridging..." : loading ? "Finding Route..." : "Bridge Now"}
            </button>
          </div>

          {/* Status Information */}
          {isLoadingRoute && (
            <div className="text-xs text-center text-gray-500">Calculating optimal route...</div>
          )}
          {gasEstimate && (
            <div className="text-xs text-center text-gray-500">Estimated gas: {String(gasEstimate)} units</div>
          )}
          {txHash && (
            <div className="text-xs text-center break-all text-gray-500">Tx: {txHash}</div>
          )}
          {txStatus && (
            <div className="text-xs text-center text-green-600 flex items-center justify-center gap-1">
              <CheckCircle className="w-3 h-3" />
              {txStatus}
            </div>
          )}
        </div>
      </div>

      {/* Transaction Success Modal */}
      {txHash && selectedToken && (
        <TransactionSuccessModal
          isOpen={showSuccessModal}
          onClose={() => setShowSuccessModal(false)}
          txHash={txHash}
          fromChain={fromChain}
          toChain={toChain}
          amount={amount}
          token={selectedToken.symbol}
          blockNumber={txStatus?.match(/block (\d+)/)?.[1]}
        />
      )}
    </div>
  );
}
