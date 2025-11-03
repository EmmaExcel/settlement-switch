'use client';

import React, { useState } from 'react';
import { ChevronDown, CheckCircle } from 'lucide-react';
import { clsx } from 'clsx';

interface ChainOption {
  chainId: number;
  name: string;
  iconUrl: string;
  key: string;
}

const CHAIN_OPTIONS: ChainOption[] = [
  {
    chainId: 11155111,
    name: 'Ethereum Sepolia',
    iconUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzIiIGhlaWdodD0iMzIiIHZpZXdCb3g9IjAgMCAzMiAzMiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGNpcmNsZSBjeD0iMTYiIGN5PSIxNiIgcj0iMTYiIGZpbGw9IiM2MjdFRUEiLz4KPHBhdGggZD0iTTE2LjQ5OCAyTDE2LjM3MyAyLjQyNFYyMS4zNDRMMTYuNDk4IDIxLjQ2OUwyNS4xMjMgMTYuNzQ0TDE2LjQ5OCAyWiIgZmlsbD0id2hpdGUiIGZpbGwtb3BhY2l0eT0iMC42MDIiLz4KPHBhdGggZD0iTTE2LjQ5OCAyTDcuODc1IDE2Ljc0NEwxNi40OTggMjEuNDY5VjEyLjE4NlYyWiIgZmlsbD0id2hpdGUiLz4KPHBhdGggZD0iTTE2LjQ5OCAyMy4yMDNMMTYuNDIzIDIzLjI5NVYyOS43NjhMMTYuNDk4IDMwTDI1LjEyOCAxOC40OEwxNi40OTggMjMuMjAzWiIgZmlsbD0id2hpdGUiIGZpbGwtb3BhY2l0eT0iMC42MDIiLz4KPHBhdGggZD0iTTE2LjQ5OCAzMFYyMy4yMDNMNy44NzUgMTguNDhMMTYuNDk4IDMwWiIgZmlsbD0id2hpdGUiLz4KPHBhdGggZD0iTTE2LjQ5OCAyMS40NjlMMjUuMTIzIDE2Ljc0NEwxNi40OTggMTIuMTg2VjIxLjQ2OVoiIGZpbGw9IndoaXRlIiBmaWxsLW9wYWNpdHk9IjAuMiIvPgo8cGF0aCBkPSJNNy44NzUgMTYuNzQ0TDE2LjQ5OCAyMS40NjlWMTIuMTg2TDcuODc1IDE2Ljc0NFoiIGZpbGw9IndoaXRlIiBmaWxsLW9wYWNpdHk9IjAuNjAyIi8+Cjwvc3ZnPgo=',
    key: 'sepolia'
  },
  {
    chainId: 421614,
    name: 'Arbitrum Sepolia',
    iconUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzIiIGhlaWdodD0iMzIiIHZpZXdCb3g9IjAgMCAzMiAzMiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGNpcmNsZSBjeD0iMTYiIGN5PSIxNiIgcj0iMTYiIGZpbGw9IiMyRDM3NEIiLz4KPHBhdGggZD0iTTEwLjUgMjJIMjEuNUwxOSAyNkgxM0wxMC41IDIyWiIgZmlsbD0iIzI4QTJGRiIvPgo8cGF0aCBkPSJNMTYgNkwxMC41IDIySDIxLjVMMTYgNloiIGZpbGw9IiM5NkJFRkYiLz4KPHBhdGggZD0iTTE2IDZMMTMgMjJIMTlMMTYgNloiIGZpbGw9IiMyOEEyRkYiLz4KPC9zdmc+Cg==',
    key: 'arbitrumSepolia'
  }
];

interface ChainSelectorProps {
  selectedChain: string;
  onChainSelect: (chain: string) => void;
  disabled?: boolean;
  className?: string;
}

export default function ChainSelector({ 
  selectedChain, 
  onChainSelect, 
  disabled = false, 
  className 
}: ChainSelectorProps) {
  const [isOpen, setIsOpen] = useState(false);

  const selectedOption = CHAIN_OPTIONS.find(option => option.key === selectedChain);

  const handleChainSelect = (chainKey: string) => {
    onChainSelect(chainKey);
    setIsOpen(false);
  };

  return (
    <div className={clsx("relative inline-block", className)}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        disabled={disabled}
        className={clsx(
          "flex items-center gap-2 sm:gap-3 px-3 sm:px-4 py-2 sm:py-3 rounded-xl border-2 transition-all duration-200 w-full sm:min-w-[200px]",
          disabled
            ? "bg-gray-100 border-gray-200 cursor-not-allowed opacity-60"
            : "bg-white hover:bg-gray-50 border-gray-200 hover:border-gray-300 focus:outline-none focus:ring-1 focus:ring-purple-500 focus:border-purple-500"
        )}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
      >
        <div className="flex items-center gap-2 flex-1 min-w-0">
          {selectedOption ? (
            <>
              <img 
                src={selectedOption.iconUrl} 
                alt={selectedOption.name} 
                className="w-5 h-5 sm:w-6 sm:h-6 rounded-full flex-shrink-0" 
              />
              <div className="text-left min-w-0 flex-1">
                <div className="font-medium text-xs sm:text-sm text-gray-900 truncate">{selectedOption.name}</div>
                <div className="text-xs text-gray-500 hidden sm:block">Chain ID: {selectedOption.chainId}</div>
              </div>
            </>
          ) : (
            <div className="text-left min-w-0 flex-1">
              <div className="font-medium text-xs sm:text-sm text-gray-900">Select Chain</div>
              <div className="text-xs text-gray-500 hidden sm:block">Choose network</div>
            </div>
          )}
        </div>
        
        <ChevronDown className={clsx("w-3 h-3 sm:w-4 sm:h-4 transition-transform text-gray-400 flex-shrink-0", isOpen ? 'rotate-180' : '')} />
      </button>

      {isOpen && !disabled && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
          <div className="absolute top-full left-0 right-0 mt-2 bg-white border border-gray-200 rounded-xl shadow-lg z-50 overflow-hidden">
            <div className="py-1 sm:py-2">
              {CHAIN_OPTIONS.map((option) => {
                const isSelected = option.key === selectedChain;
                
                return (
                  <button
                    key={option.key}
                    onClick={() => handleChainSelect(option.key)}
                    className={clsx(
                      "w-full flex items-center gap-2 sm:gap-3 px-3 sm:px-4 py-2 sm:py-3 text-left transition-colors",
                      isSelected 
                        ? "bg-purple-100 text-black-700" 
                        : "hover:bg-gray-50 text-gray-900"
                    )}
                  >
                    <img 
                      src={option.iconUrl} 
                      alt={option.name} 
                      className="w-5 h-5 sm:w-6 sm:h-6 rounded-full flex-shrink-0" 
                    />
                    <div className="flex-1 min-w-0">
                      <div className="font-medium text-xs sm:text-sm truncate">{option.name}</div>
                      <div className="text-xs text-gray-500 hidden sm:block">Chain ID: {option.chainId}</div>
                    </div>
                    {isSelected && (
                      <CheckCircle className="w-3 h-3 sm:w-4 sm:h-4 text-green-500 flex-shrink-0" />
                    )}
                  </button>
                );
              })}
            </div>
          </div>
        </>
      )}
    </div>
  );
}