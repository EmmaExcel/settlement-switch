'use client';

import { useState, useEffect, useMemo, useCallback } from 'react';
import { useAccount, useChainId, usePublicClient, useWalletClient } from 'wagmi';
import { ArrowUpDown, Clock, DollarSign, Zap, AlertCircle, CheckCircle, History, Route as RouteIcon, TrendingUp } from 'lucide-react';
import clsx from 'clsx';

import ChainSelector from '../../components/ChainSelector';
import NetworkSwitcher from '../../components/NetworkSwitcher';
import TokenSelector from '../../components/TokenSelector';
import TransactionSuccessModal from '../../components/TransactionSuccessModal';
import { SUPPORTED_TOKENS, CHAIN_CONFIG } from '../../lib/addresses';
import { 
  findOptimalRoute,
  findMultipleRoutes,
  bridgeWithAutoRoute,
  executeBridge,
  getTransferStatus,
  getRegisteredAdapters,
  getBridgeAdapterName,
  formatRouteMetrics,
  createRoutePreferences,
  RoutingMode,
  TransferStatus,
  constants,
  type BridgeRoute,
  type MultipleRoutesResult,
  type RoutePreferences
} from '../../lib/services/settlementSwitch';

// Token interface to match TokenSelector
interface Token {
  symbol: string;
  name: string;
  address: string;
  decimals: number;
  iconUrl: string;
  chainId: number;
}

type Chain = "sepolia" | "arbitrumSepolia" | "arbitrumOne" | "mainnet";

const CHAIN_ID: Record<Chain, number> = {
  sepolia: 11155111,
  arbitrumSepolia: 421614,
  arbitrumOne: 42161,
  mainnet: 1,
};

interface RouteOption {
  route: BridgeRoute;
  bridgeName: string;
  metrics: {
    gasCostETH: number;
    bridgeFeeETH: number;
    totalCostETH: number;
    estimatedTimeMinutes: number;
    successRatePercent: number;
    liquidityAvailableETH: number;
    congestionLevel: number;
  };
  isRecommended: boolean;
}

interface Transaction {
  id: string;
  hash: string;
  transferId?: string;
  fromChain: Chain;
  toChain: Chain;
  token: string;
  amount: string;
  bridge: string;
  status: 'pending' | 'confirmed' | 'failed';
  timestamp: number;
}

export default function SettlementSwitchBridgePage() {
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
  const [routeOptions, setRouteOptions] = useState<RouteOption[]>([]);
  const [selectedRouteIndex, setSelectedRouteIndex] = useState(0);
  const [routingMode, setRoutingMode] = useState<RoutingMode>(RoutingMode.BALANCED);
  const [loading, setLoading] = useState(false);
  const [isLoadingRoute, setIsLoadingRoute] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [txHash, setTxHash] = useState<string | null>(null);
  const [transferId, setTransferId] = useState<string | null>(null);
  const [routeError, setRouteError] = useState<string | null>(null);
  
  // Enhanced features
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [showHistory, setShowHistory] = useState(false);
  const [showRouteComparison, setShowRouteComparison] = useState(false);
  const [balanceError, setBalanceError] = useState<string | null>(null);
  const [networkError, setNetworkError] = useState<string | null>(null);
  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [isNetworkChanging, setIsNetworkChanging] = useState(false);
  const [registeredAdapters, setRegisteredAdapters] = useState<{adapters: string[], names: string[], enabled: boolean[]}>({
    adapters: [], names: [], enabled: []
  });

  // Network validation with change detection
  useEffect(() => {
    if (isConnected && chainId) {
      const supportedChains = [CHAIN_ID.sepolia, CHAIN_ID.arbitrumSepolia, CHAIN_ID.arbitrumOne];
      
      setIsNetworkChanging(false);
      
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
    } else if (isConnected && !chainId) {
      setIsNetworkChanging(true);
      setNetworkError("Network is changing, please wait...");
    }
  }, [chainId, isConnected]);

  // Load registered adapters
  useEffect(() => {
    if (publicClient && chainId) {
      getRegisteredAdapters(publicClient, chainId)
        .then(setRegisteredAdapters)
        .catch(console.error);
    }
  }, [publicClient, chainId]);

  // Token selection callback
  const handleTokenSelect = useCallback((token: Token) => {
    setSelectedToken(token);
  }, []);

  // Fetch multiple routes for comparison
  const fetchRoutes = useCallback(async () => {
    if (!amount || Number(amount) <= 0) return;
    if (!publicClient || !selectedToken) return;
    if (isNetworkChanging) return; // Don't fetch during network changes
    
    setLoading(true);
    setIsLoadingRoute(true);
    setRouteError(null);
    setBalanceError(null);

    try {
      const amountUnits = BigInt(Math.floor(Number(amount) * Math.pow(10, selectedToken.decimals)));
      const preferences = createRoutePreferences(routingMode);
      
      // Get multiple routes for comparison
      const result: MultipleRoutesResult = await findMultipleRoutes(
        publicClient,
        selectedToken.symbol,
        selectedToken.symbol, // Same token on destination
        amountUnits,
        CHAIN_ID[fromChain],
        CHAIN_ID[toChain],
        3, // Max 3 routes
        preferences,
        chainId
      );

      // Format routes for display
      const formattedRoutes: RouteOption[] = result.routes.map((route, index) => ({
        route,
        bridgeName: getBridgeAdapterName(route.adapter),
        metrics: formatRouteMetrics(route.metrics),
        isRecommended: route.adapter === result.bestRoute.adapter
      }));

      setRouteOptions(formattedRoutes);
      
      // Auto-select the best route
      const bestRouteIndex = formattedRoutes.findIndex(r => r.isRecommended);
      setSelectedRouteIndex(bestRouteIndex >= 0 ? bestRouteIndex : 0);
      
    } catch (error: any) {
      const message = String(error?.message || error);
      
      // Handle specific network change errors
      if (message.includes('network') && message.includes('change')) {
        setRouteError("Network changed during request. Please try again.");
        setIsNetworkChanging(true);
        // Retry after a short delay
        setTimeout(() => {
          setIsNetworkChanging(false);
          if (amount && Number(amount) > 0 && selectedToken) {
            fetchRoutes();
          }
        }, 2000);
      } else {
        setRouteError(message);
      }
      setRouteOptions([]);
    } finally {
      setLoading(false);
      setIsLoadingRoute(false);
    }
  }, [amount, fromChain, toChain, selectedToken, publicClient, routingMode, chainId, isNetworkChanging]);

  // Auto-fetch when parameters change
  useEffect(() => {
    const timer = setTimeout(() => {
      if (amount && Number(amount) > 0 && selectedToken) {
        fetchRoutes();
      }
    }, 500);
    return () => clearTimeout(timer);
  }, [fetchRoutes]);

  // Execute bridge transaction
  const handleBridge = async () => {
    if (!walletClient || !publicClient || !address || !selectedToken || routeOptions.length === 0) return;
    if (isNetworkChanging) {
      setRouteError("Network is changing, please wait and try again.");
      return;
    }
    
    setIsSubmitting(true);
    setRouteError(null);

    try {
      const selectedRoute = routeOptions[selectedRouteIndex];
      const recipient = toAddress || address;
      const amountUnits = BigInt(Math.floor(Number(amount) * Math.pow(10, selectedToken.decimals)));
      
      // Use bridgeWithAutoRoute for simplicity, or executeBridge for more control
      const hash = await bridgeWithAutoRoute(
        walletClient,
        publicClient,
        selectedToken.symbol,
        selectedToken.symbol,
        amountUnits,
        CHAIN_ID[fromChain],
        CHAIN_ID[toChain],
        recipient,
        address,
        createRoutePreferences(routingMode),
        "0x", // No permit data
        chainId
      );

      setTxHash(hash);
      
      // Add to transaction history
      const newTransaction: Transaction = {
        id: Date.now().toString(),
        hash,
        fromChain,
        toChain,
        token: selectedToken.symbol,
        amount,
        bridge: selectedRoute.bridgeName,
        status: 'pending',
        timestamp: Date.now()
      };
      
      setTransactions(prev => [newTransaction, ...prev]);
      setShowSuccessModal(true);
      
      // Reset form
      setAmount("");
      setRouteOptions([]);
      
    } catch (error: any) {
      console.error("Bridge transaction failed:", error);
      const message = String(error?.message || error);
      
      // Handle specific network change errors
      if (message.includes('network') && message.includes('change')) {
        setRouteError("Network changed during transaction. Please verify your network and try again.");
        setIsNetworkChanging(true);
        setTimeout(() => setIsNetworkChanging(false), 3000);
      } else if (error?.code === -32603) {
        setRouteError("Network request rejected. Please check your network connection and try again.");
      } else {
        setRouteError(`Transaction failed: ${message}`);
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  // Swap chains
  const handleSwapChains = () => {
    setFromChain(toChain);
    setToChain(fromChain);
  };

  const selectedRoute = routeOptions[selectedRouteIndex];
  const canBridge = amount && Number(amount) > 0 && selectedToken && routeOptions.length > 0 && !isSubmitting && !isNetworkChanging;

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8 py-4 sm:py-6 lg:py-8">
        {/* Header */}
        <div className="text-center mb-6 sm:mb-8">
          <h1 className="text-2xl sm:text-3xl lg:text-4xl font-bold text-gray-900 mb-2 px-2">
            Settlement Switch Bridge
          </h1>
          <p className="text-sm sm:text-base text-gray-600 max-w-xs sm:max-w-md lg:max-w-2xl mx-auto px-4">
            Multi-bridge aggregator powered by LayerZero, Connext, and Across. 
            Find the best routes across all bridges automatically.
          </p>
        </div>

        {/* Network Error/Status */}
        {networkError && (
          <div className={clsx(
            "mb-4 sm:mb-6 p-3 sm:p-4 border rounded-lg mx-2 sm:mx-0",
            isNetworkChanging 
              ? "bg-yellow-50 border-yellow-200" 
              : "bg-red-50 border-red-200"
          )}>
            <div className="flex items-center">
              {isNetworkChanging ? (
                <div className="animate-spin rounded-full h-4 w-4 sm:h-5 sm:w-5 border-b-2 border-yellow-500 mr-2 flex-shrink-0"></div>
              ) : (
                <AlertCircle className="h-4 w-4 sm:h-5 sm:w-5 text-red-500 mr-2 flex-shrink-0" />
              )}
              <span className={clsx(
                "text-sm sm:text-base",
                isNetworkChanging ? "text-yellow-700" : "text-red-700"
              )}>
                {networkError}
              </span>
            </div>
          </div>
        )}

        {/* Bridge Adapters Status */}
        <div className="mb-4 sm:mb-6 bg-white max-w-2xl mx-auto rounded-xl sm:rounded-2xl shadow-lg sm:shadow-xl border border-gray-100 overflow-hidden mx-2 sm:mx-auto">
          <div className="p-4 sm:p-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-4 gap-2">
              <h3 className="font-semibold text-gray-900 text-base sm:text-lg">Available Bridge Adapters</h3>
              <div className="flex items-center text-xs sm:text-sm text-gray-500">
                <CheckCircle className="h-3 w-3 sm:h-4 sm:w-4 mr-1 text-green-500" />
                1 Active
              </div>
            </div>
            
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2 sm:gap-3">
              {/* LayerZero - Active */}
              <div className="flex items-center justify-between p-2 sm:p-3 bg-purple-200 border border-purple-300 rounded-lg">
                <div className="flex items-center">
                  <div className="w-2 h-2 bg-purple-500 rounded-full mr-2 sm:mr-3 flex-shrink-0"></div>
                  <span className="font-medium text-black-900 text-sm sm:text-base">LayerZero</span>
                </div>
                <CheckCircle className="h-3 w-3 sm:h-4 sm:w-4 text-purple-500 flex-shrink-0" />
              </div>
              
              {/* Coming Soon bridges */}
              <div className="flex items-center justify-between p-2 sm:p-3 bg-gray-50 border border-gray-200 rounded-lg">
                <div className="flex items-center">
                  <div className="w-2 h-2 bg-gray-400 rounded-full mr-2 sm:mr-3 flex-shrink-0"></div>
                  <span className="font-medium text-gray-600 text-sm sm:text-base">Connext</span>
                </div>
                <Clock className="h-3 w-3 sm:h-4 sm:w-4 text-gray-400 flex-shrink-0" />
              </div>
              
              <div className="flex items-center justify-between p-2 sm:p-3 bg-gray-50 border border-gray-200 rounded-lg sm:col-span-2 lg:col-span-1">
                <div className="flex items-center">
                  <div className="w-2 h-2 bg-gray-400 rounded-full mr-2 sm:mr-3 flex-shrink-0"></div>
                  <span className="font-medium text-gray-600 text-sm sm:text-base">Across</span>
                </div>
                <Clock className="h-3 w-3 sm:h-4 sm:w-4 text-gray-400 flex-shrink-0" />
              </div>
            </div>
            
            <p className="text-xs sm:text-sm text-gray-600 mt-3 sm:mt-4 text-center px-2">
              LayerZero provides fast, secure cross-chain transfers. Additional bridges launching soon.
            </p>
          </div>
        </div>

        <div className="max-w-2xl mx-auto px-2 sm:px-0">
          {/* Main Bridge Card */}
          <div className="bg-white rounded-xl sm:rounded-2xl shadow-lg sm:shadow-xl border border-gray-100 overflow-hidden">
           
            <div className="p-4 sm:p-6 border-b border-gray-100">
              <h3 className="font-semibold text-gray-900 mb-3 text-base sm:text-lg">Routing Preference</h3>
              <div className="flex flex-col sm:flex-row space-y-2 sm:space-y-0 sm:space-x-2">
                {[
                  { mode: RoutingMode.CHEAPEST, label: "Cheapest", icon: DollarSign },
                  { mode: RoutingMode.FASTEST, label: "Fastest", icon: Zap },
                  { mode: RoutingMode.BALANCED, label: "Balanced", icon: TrendingUp }
                ].map(({ mode, label, icon: Icon }) => (
                  <button
                    key={mode}
                    onClick={() => setRoutingMode(mode)}
                    className={clsx(
                      "flex items-center justify-center px-3 sm:px-4 py-2 sm:py-2 rounded-lg font-medium transition-colors text-sm sm:text-base",
                      routingMode === mode
                        ? "bg-purple-200 text-purple-700 border-2 border-purple-300"
                        : "bg-gray-50 text-gray-600 border-2 border-transparent hover:bg-gray-100"
                    )}
                  >
                    <Icon className="h-3 w-3 sm:h-4 sm:w-4 mr-1 sm:mr-2" />
                    {label}
                  </button>
                ))}
              </div>
            </div>

            {/* Bridge Form */}
            <div className="p-4 sm:p-6">
              {/* From Section */}
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">From</label>
                  <div className="flex flex-col sm:flex-row space-y-3 sm:space-y-0 sm:space-x-3">

                    <div className="flex-1">
                      <ChainSelector
                        selectedChain={fromChain}
                        onChainSelect={(chain: string) => setFromChain(chain as Chain)}
                        disabled={isSubmitting}
                      />
                    </div>

                    <div className="flex-1">
                      <TokenSelector
                        selectedToken={selectedToken}
                        onTokenSelect={handleTokenSelect}
                        disabled={isSubmitting}
                      />
                    </div>

                    
                  </div>
                </div>

                {/* Amount Input */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Amount</label>
                  <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="0.0"
                    disabled={isSubmitting}
                    className="w-full px-3 sm:px-4 py-2 sm:py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent text-lg sm:text-2xl font-bold"
                  />
                </div>

                {/* Swap Button */}
                <div className="flex justify-center">
                  <button
                    onClick={handleSwapChains}
                    disabled={isSubmitting}
                    className="p-2 bg-gray-100 hover:bg-gray-200 rounded-full transition-colors"
                  >
                    <ArrowUpDown className="h-4 w-4 sm:h-5 sm:w-5 text-gray-600" />
                  </button>
                </div>

                {/* To Section */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">To</label>
                  <div className="flex flex-col sm:flex-row space-y-3 sm:space-y-0 sm:space-x-3">
                    <div className="flex-1">
                      <ChainSelector
                        selectedChain={toChain}
                        onChainSelect={(chain: string) => setToChain(chain as Chain)}
                        disabled={isSubmitting}
                      />
                    </div>
                    <div className="flex-1 bg-gray-50 rounded-lg p-3 flex items-center">
                      <span className="text-gray-600 text-sm sm:text-base">
                        {selectedToken?.symbol || "Select token"}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Recipient Address */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Recipient Address (optional)
                  </label>
                  <input
                    type="text"
                    value={toAddress}
                    onChange={(e) => setToAddress(e.target.value)}
                    placeholder={address || "Enter recipient address"}
                    disabled={isSubmitting}
                    className="w-full px-3 sm:px-4 py-2 sm:py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm sm:text-base"
                  />
                </div>
              </div>
            </div>

            {/* Route Options */}
            {routeOptions.length > 0 && (
              <div className="border-t border-gray-100">
                <div className="p-4 sm:p-6">
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-4 gap-2">
                    <h3 className="font-semibold text-gray-900 text-base sm:text-lg">Available Routes</h3>
                    <button
                      onClick={() => setShowRouteComparison(!showRouteComparison)}
                      className="text-purple-600 hover:text-purple-700 text-sm font-medium self-start sm:self-auto"
                    >
                      {showRouteComparison ? "Hide Details" : "Compare Routes"}
                    </button>
                  </div>

                  {showRouteComparison ? (
                    // Detailed route comparison
                    <div className="space-y-3">
                      {routeOptions.map((option, index) => (
                        <div
                          key={index}
                          onClick={() => setSelectedRouteIndex(index)}
                          className={clsx(
                            "p-3 sm:p-4 border rounded-lg cursor-pointer transition-colors",
                            selectedRouteIndex === index
                              ? "border-purple-500 bg-purple-100"
                              : "border-gray-200 hover:border-gray-300"
                          )}
                        >
                          <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-2 gap-1 sm:gap-0">
                            <div className="flex items-center">
                              <span className="font-medium text-gray-900 text-sm sm:text-base">{option.bridgeName}</span>
                              {option.isRecommended && (
                                <span className="ml-2 px-2 py-1 bg-green-100 text-green-800 text-xs rounded-full">
                                  Recommended
                                </span>
                              )}
                            </div>
                            <span className="text-xs sm:text-sm text-gray-600">
                              {option.metrics.successRatePercent.toFixed(0)}% success rate
                            </span>
                          </div>
                          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 sm:gap-4 text-xs sm:text-sm">
                            <div>
                              <span className="text-gray-500">Cost:</span>
                              <div className="font-medium">{option.metrics.totalCostETH.toFixed(6)} ETH</div>
                            </div>
                            <div>
                              <span className="text-gray-500">Time:</span>
                              <div className="font-medium">{option.metrics.estimatedTimeMinutes} min</div>
                            </div>
                            <div>
                              <span className="text-gray-500">Liquidity:</span>
                              <div className="font-medium">{option.metrics.liquidityAvailableETH.toFixed(2)} ETH</div>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    // Simple route selector
                    <div className="flex flex-col sm:flex-row space-y-2 sm:space-y-0 sm:space-x-2">
                      {routeOptions.map((option, index) => (
                        <button
                          key={index}
                          onClick={() => setSelectedRouteIndex(index)}
                          className={clsx(
                            "flex-1 p-3 border rounded-lg text-center transition-colors",
                            selectedRouteIndex === index
                              ? "border-purple-500 bg-purple-100 text-purple-700"
                              : "border-gray-200 hover:border-gray-300"
                          )}
                        >
                          <div className="font-medium text-sm sm:text-base">{option.bridgeName}</div>
                          <div className="text-xs sm:text-sm text-gray-600">
                            {option.metrics.totalCostETH.toFixed(6)} ETH
                          </div>
                        </button>
                      ))}
                    </div>
                  )}

                  {/* Selected Route Summary */}
                  {selectedRoute && (
                    <div className="mt-4 p-3 sm:p-4 bg-gray-50 rounded-lg">
                      <div className="flex items-center justify-between mb-2">
                        <span className="font-medium text-gray-900 text-sm sm:text-base">
                          Selected: {selectedRoute.bridgeName}
                        </span>
                        {selectedRoute.isRecommended && (
                          <CheckCircle className="h-4 w-4 sm:h-5 sm:w-5 text-green-500" />
                        )}
                      </div>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-4 text-xs sm:text-sm">
                        <div className="flex items-center">
                          <DollarSign className="h-3 w-3 sm:h-4 sm:w-4 text-gray-400 mr-1" />
                          <span>Total Cost: {selectedRoute.metrics.totalCostETH.toFixed(6)} ETH</span>
                        </div>
                        <div className="flex items-center">
                          <Clock className="h-3 w-3 sm:h-4 sm:w-4 text-gray-400 mr-1" />
                          <span>Est. Time: {selectedRoute.metrics.estimatedTimeMinutes} min</span>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Error Display */}
            {routeError && (
              <div className="border-t border-gray-100 p-4 sm:p-6">
                <div className="flex items-center p-3 sm:p-4 bg-red-50 border border-red-200 rounded-lg mx-2 sm:mx-0">
                  <AlertCircle className="h-4 w-4 sm:h-5 sm:w-5 text-red-500 mr-2 flex-shrink-0" />
                  <span className="text-red-700 text-xs sm:text-sm">{routeError}</span>
                </div>
              </div>
            )}

            {/* Bridge Button */}
            <div className="border-t border-gray-100 p-4 sm:p-6">
              <button
                onClick={handleBridge}
                disabled={!canBridge || isLoadingRoute}
                className={clsx(
                  "w-full py-3 sm:py-4 px-4 sm:px-6 rounded-lg font-semibold text-white transition-colors text-sm sm:text-base",
                  canBridge && !isLoadingRoute
                    ? "bg-purple-600 hover:bg-purple-700"
                    : "bg-gray-300 cursor-not-allowed"
                )}
              >
                {isSubmitting ? (
                  "Processing..."
                ) : isLoadingRoute ? (
                  "Finding Routes..."
                ) : (
                  `Bridge ${amount || "0"} ${selectedToken?.symbol || ""}`
                )}
              </button>
            </div>
          </div>

          {/* Transaction History */}
          {transactions.length > 0 && (
            <div className="mt-4 sm:mt-6 bg-white rounded-2xl shadow-xl border border-gray-100 overflow-hidden mx-2 sm:mx-0">
              <div className="p-4 sm:p-6 border-b border-gray-100">
                <div className="flex items-center justify-between">
                  <h3 className="font-semibold text-gray-900 text-base sm:text-lg">Recent Transactions</h3>
                  <button
                    onClick={() => setShowHistory(!showHistory)}
                    className="text-blue-600 hover:text-blue-700"
                  >
                    <History className="h-4 w-4 sm:h-5 sm:w-5" />
                  </button>
                </div>
              </div>
              {showHistory && (
                <div className="p-4 sm:p-6">
                  <div className="space-y-3">
                    {transactions.slice(0, 5).map((tx) => (
                      <div key={tx.id} className="flex flex-col sm:flex-row sm:items-center justify-between p-3 bg-gray-50 rounded-lg gap-2 sm:gap-0">
                        <div>
                          <div className="font-medium text-gray-900 text-sm sm:text-base">
                            {tx.amount} {tx.token}
                          </div>
                          <div className="text-xs sm:text-sm text-gray-600">
                            {tx.fromChain} → {tx.toChain} via {tx.bridge}
                          </div>
                        </div>
                        <div className="text-left sm:text-right">
                          <div className={clsx(
                            "text-xs sm:text-sm font-medium",
                            tx.status === 'confirmed' ? "text-green-600" :
                            tx.status === 'failed' ? "text-red-600" : "text-yellow-600"
                          )}>
                            {tx.status}
                          </div>
                          <div className="text-xs text-gray-500">
                            {new Date(tx.timestamp).toLocaleTimeString()}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Success Modal */}
        {showSuccessModal && txHash && (
          <TransactionSuccessModal
            isOpen={showSuccessModal}
            onClose={() => setShowSuccessModal(false)}
            txHash={txHash}
            amount={amount}
            token={selectedToken?.symbol || ""}
            fromChain={fromChain}
            toChain={toChain}
            bridge={selectedRoute?.bridgeName || ""}
          />
        )}
      </div>
    </div>
  );
}
