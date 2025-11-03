'use client';

import React, { useState, useEffect } from 'react';
import { useChainId, useAccount, useSwitchChain } from 'wagmi';
import { ChevronDown, AlertTriangle, CheckCircle, Loader2 } from 'lucide-react';
import { clsx } from 'clsx';
import { CHAIN_CONFIG } from '@/lib/addresses';

interface NetworkOption {
  chainId: number;
  name: string;
  iconUrl: string;
  rpcUrl: string;
  blockExplorer: string;
}

const NETWORK_OPTIONS: NetworkOption[] = [
  {
    chainId: 11155111,
    name: 'Ethereum Sepolia',
    iconUrl: 'https://assets.coingecko.com/coins/images/279/small/ethereum.png',
    rpcUrl: 'https://ethereum-sepolia-rpc.publicnode.com',
    blockExplorer: 'https://sepolia.etherscan.io'
  },
  {
    chainId: 421614,
    name: 'Arbitrum Sepolia',
    iconUrl: 'https://assets.coingecko.com/coins/images/16547/small/arb.png',
    rpcUrl: 'https://sepolia-rollup.arbitrum.io/rpc',
    blockExplorer: 'https://sepolia.arbiscan.io'
  }
];

interface NetworkSwitcherProps {
  onNetworkChange?: (chainId: number) => void;
  className?: string;
}

export default function NetworkSwitcher({ onNetworkChange, className }: NetworkSwitcherProps) {
  const { isConnected } = useAccount();
  const currentChainId = useChainId();
  const { switchChain, isPending, error } = useSwitchChain();
  const [isOpen, setIsOpen] = useState(false);
  const [switchingTo, setSwitchingTo] = useState<number | null>(null);

  const currentNetwork = NETWORK_OPTIONS.find(n => n.chainId === currentChainId);
  const isUnsupportedNetwork = !currentNetwork && isConnected;

  useEffect(() => {
    if (onNetworkChange && currentChainId) {
      onNetworkChange(currentChainId);
    }
  }, [currentChainId, onNetworkChange]);

  const handleNetworkSwitch = async (targetChainId: number) => {
    if (!isConnected) {
      alert('Please connect your wallet first');
      return;
    }

    if (targetChainId === currentChainId) {
      setIsOpen(false);
      return;
    }

    setSwitchingTo(targetChainId);
    setIsOpen(false);

    try {
      await switchChain({ chainId: targetChainId });
    } catch (err: any) {
      console.error('Network switch failed:', err);
      // Handle specific error cases
      if (err.code === 4902) {
        // Network not added to wallet
        const targetNetwork = NETWORK_OPTIONS.find(n => n.chainId === targetChainId);
        if (targetNetwork) {
          alert(`Please add ${targetNetwork.name} to your wallet first`);
        }
      } else {
        alert(`Failed to switch network: ${err.message || 'Unknown error'}`);
      }
    } finally {
      setSwitchingTo(null);
    }
  };

  const getNetworkStatus = () => {
    if (!isConnected) {
      return { icon: AlertTriangle, color: 'text-gray-500', message: 'Not connected' };
    }
    if (isUnsupportedNetwork) {
      return { icon: AlertTriangle, color: 'text-red-500', message: 'Unsupported network' };
    }
    if (currentNetwork) {
      return { icon: CheckCircle, color: 'text-green-500', message: 'Connected' };
    }
    return { icon: Loader2, color: 'text-blue-500', message: 'Detecting...' };
  };

  const status = getNetworkStatus();
  const StatusIcon = status.icon;

  return (
    <div className={clsx("relative inline-block", className)}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        disabled={!isConnected}
        className={clsx(
          "flex items-center gap-3 px-4 py-3 rounded-xl border-2 transition-all duration-200 min-w-[200px]",
          isConnected 
            ? "bg-white hover:bg-gray-50 border-gray-200 hover:border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500" 
            : "bg-gray-100 border-gray-200 cursor-not-allowed opacity-60"
        )}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
      >
        <div className="flex items-center gap-2 flex-1">
          {currentNetwork ? (
            <>
              <img 
                src={currentNetwork.iconUrl} 
                alt={currentNetwork.name} 
                className="w-6 h-6 rounded-full" 
              />
              <div className="text-left">
                <div className="font-medium text-sm text-gray-900">{currentNetwork.name}</div>
                <div className="text-xs text-gray-500">Chain ID: {currentNetwork.chainId}</div>
              </div>
            </>
          ) : (
            <>
              <div className="w-6 h-6 rounded-full bg-gray-300 flex items-center justify-center">
                <StatusIcon className={clsx("w-4 h-4", status.color)} />
              </div>
              <div className="text-left">
                <div className="font-medium text-sm text-gray-900">
                  {isUnsupportedNetwork ? 'Unsupported Network' : status.message}
                </div>
                {currentChainId && (
                  <div className="text-xs text-gray-500">Chain ID: {currentChainId}</div>
                )}
              </div>
            </>
          )}
        </div>
        
        {isPending && switchingTo ? (
          <Loader2 className="w-4 h-4 animate-spin text-blue-500" />
        ) : (
          <ChevronDown className={clsx("w-4 h-4 transition-transform text-gray-400", isOpen ? 'rotate-180' : '')} />
        )}
      </button>

      {isOpen && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
          <div className="absolute top-full left-0 right-0 mt-2 bg-white border border-gray-200 rounded-xl shadow-lg z-50 overflow-hidden">
            <div className="py-2">
              {NETWORK_OPTIONS.map((network) => {
                const isActive = network.chainId === currentChainId;
                const isSwitching = switchingTo === network.chainId;
                
                return (
                  <button
                    key={network.chainId}
                    onClick={() => handleNetworkSwitch(network.chainId)}
                    disabled={isSwitching}
                    className={clsx(
                      "w-full flex items-center gap-3 px-4 py-3 text-left transition-colors",
                      isActive 
                        ? "bg-blue-50 text-blue-700" 
                        : "hover:bg-gray-50 text-gray-900",
                      isSwitching && "opacity-60 cursor-not-allowed"
                    )}
                  >
                    <img 
                      src={network.iconUrl} 
                      alt={network.name} 
                      className="w-6 h-6 rounded-full" 
                    />
                    <div className="flex-1">
                      <div className="font-medium text-sm">{network.name}</div>
                      <div className="text-xs text-gray-500">Chain ID: {network.chainId}</div>
                    </div>
                    {isSwitching ? (
                      <Loader2 className="w-4 h-4 animate-spin text-blue-500" />
                    ) : isActive ? (
                      <CheckCircle className="w-4 h-4 text-green-500" />
                    ) : null}
                  </button>
                );
              })}
            </div>
            
            {isUnsupportedNetwork && (
              <div className="border-t border-gray-200 p-3 bg-red-50">
                <div className="flex items-center gap-2 text-red-700 text-sm">
                  <AlertTriangle className="w-4 h-4" />
                  <span>Please switch to a supported network</span>
                </div>
              </div>
            )}
          </div>
        </>
      )}

      {error && (
        <div className="absolute top-full left-0 right-0 mt-1 p-2 bg-red-50 border border-red-200 rounded-lg text-red-700 text-xs">
          Network switch failed: {error.message}
        </div>
      )}
    </div>
  );
}