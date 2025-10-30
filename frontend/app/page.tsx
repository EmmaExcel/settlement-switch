
'use client';

import axios from 'axios';
import { useState, useEffect, useCallback, useMemo } from 'react';
import clsx from 'clsx';
import { useAccount } from 'wagmi';
import { ArrowUpDown, Zap, DollarSign, Clock, Gauge } from 'lucide-react';
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
}

export default function BridgePage() {
  const { address, isConnected } = useAccount();
  const [amount, setAmount] = useState('');
  const [fromChain, setFromChain] = useState<Chain>('ETH');
  const [toChain, setToChain] = useState<Chain>('MATIC');
  const [toAddress, setToAddress] = useState('');
  const [routes, setRoutes] = useState<Route[]>([]);
  const [loading, setLoading] = useState(false);
  const [speedPreference, setSpeedPreference] = useState(50); // 0 = cheapest, 100 = fastest

  // Live UI values for instant feedback
  const [estGas, setEstGas] = useState(0.25);
  const [estTime, setEstTime] = useState(20);
  const [bridgeName, setBridgeName] = useState('polygon');

  // === Auto-swap if same chain ===
  useEffect(() => {
    if (fromChain === toChain) {
      setToChain(fromChain === 'ETH' ? 'MATIC' : 'ETH');
    }
  }, [fromChain, toChain]);

  // === Fetch Routes from API ===
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
      const fetchedRoutes: Route[] = Array.isArray(data.routes) ? data.routes : [data];
      setRoutes(fetchedRoutes);
    } catch (error: any) {
      console.error('Error fetching routes:', error.response?.data || error.message);
      setRoutes([]);
    } finally {
      setLoading(false);
    }
  }, [address, isConnected, amount, fromChain, toChain]);

  // === Auto-fetch when amount or chains change ===
  useEffect(() => {
    const timer = setTimeout(() => {
      if (amount && Number(amount) > 0) {
        fetchRoutes();
      }
    }, 600);
    return () => clearTimeout(timer);
  }, [amount, fromChain, toChain, fetchRoutes]);

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
        ? 'LayerZero'
        : speedPreference < 66
        ? 'Synapse'
        : 'Polygon Bridge';

    setEstGas(gas);
    setEstTime(time);
    setBridgeName(bridge);
  }, [speedPreference]);

  // === Debug Log ===
  const handleDebugLog = () => {
    console.clear();
    console.table({
      Address: address || 'Not connected',
      Amount: amount || 'Empty',
      From: fromChain,
      To: toChain,
      Speed: speedPreference,
      Routes: routes.length,
      BestRoute: bestRoute?.bridge || 'None',
    });
  };

  // === Bridge Action ===
  const handleBridge = async () => {
    if (!bestRoute) {
      alert('No valid route found');
      return;
    }
    console.log('Bridging via:', bestRoute);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-purple-50 to-indigo-50 p-4">
      <div className="w-full max-w-md bg-white rounded-3xl shadow-lg p-6 space-y-6">
        {/* ==== FROM ==== */}
        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-700">Price</label>
          <div className="flex items-center justify-between p-4 bg-gray-50 rounded-xl">
            <input
              type="text"
              value={amount ? Number(amount).toLocaleString() : ''}
              placeholder="$0.00"
              onChange={(e) => setAmount(e.target.value.replace(/[^\d.]/g, ''))}
              className="text-2xl font-semibold bg-transparent outline-none flex-1 min-w-0"
            />
            <EthereumPolygonDropdown selected={fromChain} setSelected={setFromChain} />
          </div>
        </div>

        {/* ==== SWAP ==== */}
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
            <EthereumPolygonDropdown selected={toChain} setSelected={setToChain} />
          </div>
        </div>

        {/* ==== SPEED SLIDER ==== */}
        <div className="bg-gray-50 rounded-xl p-4 space-y-2">
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1 text-sm text-gray-600">
              <Gauge className="w-4 h-4 text-purple-600" />
              Transaction Speed
            </span>
            <span className="text-sm font-medium text-purple-700">
              {speedPreference < 33
                ? 'Cheapest'
                : speedPreference < 66
                ? 'Balanced'
                : 'Fastest'}
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
        </div>

        {/* ==== LIVE ESTIMATES ==== */}
        <div className="space-y-3 text-sm bg-gradient-to-r from-emerald-50 to-teal-50 p-4 rounded-xl border border-emerald-200 transition-all duration-300">
          <div className="flex items-center justify-between">
            <span className="text-gray-600 flex items-center gap-1">
              <Zap className="w-4 h-4 text-emerald-600" />
              Bridge
            </span>
            <span className="font-semibold text-emerald-700">{bridgeName}</span>
          </div>

          <div className="flex items-center justify-between">
            <span className="text-gray-600 flex items-center gap-1">
              <DollarSign className="w-4 h-4 text-emerald-600" />
              Est. Gas
            </span>
            <span className="font-medium">${estGas.toFixed(4)}</span>
          </div>

          <div className="flex items-center justify-between">
            <span className="text-gray-600 flex items-center gap-1">
              <Clock className="w-4 h-4 text-emerald-600" />
              Est. Time
            </span>
            <span className="font-medium">{estTime.toFixed(1)} min</span>
          </div>

          <div className="text-xs text-emerald-600 font-medium mt-2">
            Adjusted for speed preference ({speedPreference}% fast)
          </div>
        </div>

        {/* ==== ACTION ==== */}
        <div className="space-y-2">
          <button
            onClick={handleBridge}
            disabled={!isConnected || !amount || loading}
            className={clsx(
              'w-full py-4 font-semibold rounded-2xl transition-all flex items-center justify-center gap-2',
              isConnected && amount && !loading
                ? 'bg-emerald-600 hover:bg-emerald-700 text-white'
                : 'bg-gray-300 text-gray-500 cursor-not-allowed'
            )}
          >
            {loading ? 'Finding Route...' : 'Bridge Now'}
          </button>

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
