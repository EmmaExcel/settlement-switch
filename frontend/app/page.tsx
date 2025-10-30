'use client';

import axios from 'axios';
import { useState, useEffect, useCallback, useMemo } from 'react';
import clsx from 'clsx';
import { useAccount } from 'wagmi';
import { ArrowUpDown, Zap, DollarSign, Clock } from 'lucide-react';
import EthereumPolygonDropdown from './components/test';

type Chain = 'ETH' | 'MATIC';

const CHAIN_ID: Record<Chain, string> = {
  ETH: '1',
  MATIC: '137',
};

interface Route {
  bridge: string;
  estimatedGasUSD: number;
  estimatedTimeSeconds: number;
  // Add other fields if needed
}

export default function BridgePage() {
  const { address, isConnected } = useAccount();
  const [amount, setAmount] = useState('');
  const [fromChain, setFromChain] = useState<Chain>('ETH');
  const [toChain, setToChain] = useState<Chain>('MATIC');
  const [toAddress, setToAddress] = useState('');
  const [activeTab, setActiveTab] = useState<'bridge' | 'swap'>('bridge');
  const [routes, setRoutes] = useState<Route[]>([]);
  const [loading, setLoading] = useState(false);

  // Auto-swap chains if same
  useEffect(() => {
    if (fromChain === toChain) {
      setToChain(fromChain === 'ETH' ? 'MATIC' : 'ETH');
    }
  }, [fromChain, toChain]);

  // === Fetch Routes ===
  const fetchRoutes = useCallback(async () => {
    if (!isConnected || !address || !amount || Number(amount) <= 0) return;

    setLoading(true);
    try {
      const response = await axios.get('/api/getRoute', {
        params: {
          fromChain: CHAIN_ID[fromChain],
          toChain: CHAIN_ID[toChain],
          token: 'USDC',
          amount,
          fromAddress: address,
        },
      });

      const data = response.data;
      // Assume API returns { routes: [...] }
      const fetchedRoutes: Route[] = Array.isArray(data.routes) ? data.routes : [data];

      setRoutes(fetchedRoutes);
    } catch (error: any) {
      console.error('Error fetching routes:', error.response?.data || error.message);
      setRoutes([]);
    } finally {
      setLoading(false);
    }
  }, [address, isConnected, amount, fromChain, toChain]);

  // === Auto-fetch on change ===
  useEffect(() => {
    const timer = setTimeout(() => {
      if (amount && Number(amount) > 0) {
        fetchRoutes();
      }
    }, 600); // Debounce

    return () => clearTimeout(timer);
  }, [amount, fromChain, toChain, fetchRoutes]);

  // === Find Best Route (Fastest + Cheapest Combined Score) ===
  const bestRoute = useMemo(() => {
    if (routes.length === 0) return null;

    return routes.reduce((best, route) => {
      const bestScore = best
        ? best.estimatedGasUSD * 0.6 + (best.estimatedTimeSeconds / 60) * 0.4
        : Infinity;
      const currentScore =
        route.estimatedGasUSD * 0.6 + (route.estimatedTimeSeconds / 60) * 0.4;

      return currentScore < bestScore ? route : best;
    }, null as Route | null);
  }, [routes]);

  // === Debug Log ===
  const handleDebugLog = () => {
    console.clear();
    console.table({
      'Wallet Connected': isConnected,
      'Address': address || 'Not connected',
      'Amount': amount || 'Empty',
      'From Chain': fromChain,
      'To Chain': toChain,
      'Routes Count': routes.length,
      'Best Route': bestRoute?.bridge || 'None',
    });
    console.log('All Routes:', routes);
  };

  // === Bridge Action ===
  const handleBridge = async () => {
    if (!bestRoute) {
      alert('No valid route found');
      return;
    }
    // Proceed with bestRoute
    console.log('Bridging via:', bestRoute);
    // Trigger actual transaction here
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-purple-50 to-indigo-50 p-4">
      <div className="w-full max-w-md bg-white rounded-3xl shadow-lg p-6 space-y-6">
        {/* ==== FROM SECTION ==== */}
        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-700">From</label>
          <div className="flex items-center justify-between p-4 bg-gray-50 rounded-xl">
            <input
              type="text"
              value={amount ? Number(amount).toLocaleString() : ''}
              placeholder="$0.00"
              onChange={(e) => {
                const value = e.target.value.replace(/[^\d.]/g, '');
                setAmount(value);
              }}
              className="text-2xl font-semibold bg-transparent outline-none flex-1 min-w-0"
            />
            <EthereumPolygonDropdown selected={fromChain} setSelected={setFromChain} />
          </div>
        </div>

        {/* ==== SWAP ARROW ==== */}
        <div className="flex justify-center -my-2 z-10">
          <button
            onClick={() => {
              setFromChain(toChain);
              setToChain(fromChain);
            }}
            className="w-10 h-10 bg-purple-100 hover:bg-purple-200 rounded-full flex items-center justify-center transition-colors"
          >
            <ArrowUpDown className="w-5 h-5 text-purple-700" />
          </button>
        </div>

        {/* ==== TO SECTION ==== */}
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
            <EthereumPolygonDropdown selected={toChain} setSelected={setToChain} />
          </div>
        </div>

        {/* ==== TABS ==== */}
        {/*
        <div className="flex bg-purple-50 rounded-xl p-1">
          {(['bridge', 'swap'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={clsx(
                'flex-1 py-2 rounded-lg text-sm font-medium capitalize transition-all',
                activeTab === tab
                  ? 'bg-white text-purple-700 shadow-sm'
                  : 'text-purple-600 hover:text-purple-700'
              )}
            >
              {tab}
            </button>
          ))}
        </div>
        */
}

        {/* ==== BEST ROUTE DISPLAY ==== */}
        {loading ? (
          <div className="text-center text-sm text-gray-500">Finding best route...</div>
        ) : bestRoute ? (
          <div className="space-y-3 text-sm bg-gradient-to-r from-emerald-50 to-teal-50 p-4 rounded-xl border border-emerald-200">
            <div className="flex items-center justify-between">
              <span className="text-gray-600 flex items-center gap-1">
                <Zap className="w-4 h-4 text-emerald-600" />
                Bridge
              </span>
              <span className="font-semibold text-emerald-700">{bestRoute.bridge}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600 flex items-center gap-1">
                <DollarSign className="w-4 h-4 text-emerald-600" />
                Est. Gas
              </span>
              <span className="font-medium">${bestRoute.estimatedGasUSD.toFixed(4)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600 flex items-center gap-1">
                <Clock className="w-4 h-4 text-emerald-600" />
                Est. Time
              </span>
              <span className="font-medium">
                {bestRoute.estimatedTimeSeconds < 60
                  ? `${bestRoute.estimatedTimeSeconds.toFixed(1)}s`
                  : `${(bestRoute.estimatedTimeSeconds / 60).toFixed(1)} min`}
              </span>
            </div>
            <div className="text-xs text-emerald-600 font-medium mt-2">
              Best route: Fastest + Cheapest
            </div>
          </div>
        ) : amount && Number(amount) > 0 ? (
          <div className="text-center text-sm text-red-500">No routes available</div>
        ) : null}

        {/* ==== ACTION BUTTONS ==== */}
        <div className="space-y-2">
          <button
            onClick={handleBridge}
            disabled={!isConnected || !amount || !bestRoute || loading}
            className={clsx(
              'w-full py-4 font-semibold rounded-2xl transition-all flex items-center justify-center gap-2',
              isConnected && amount && bestRoute && !loading
                ? 'bg-emerald-600 hover:bg-emerald-700 text-white'
                : 'bg-gray-300 text-gray-500 cursor-not-allowed'
            )}
          >
            {loading ? (
              <>Finding Route...</>
            ) : activeTab === 'bridge' ? (
              'Bridge Now'
            ) : (
              'Transfer Now'
            )}
          </button>

          {/* Debug Button */}
          {process.env.NODE_ENV === 'development' && (
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