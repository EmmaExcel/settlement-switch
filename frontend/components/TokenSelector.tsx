'use client';

import React, { useState, useEffect } from 'react';
import { useAccount, useBalance, useChainId } from 'wagmi';
import { ChevronDown, Search, AlertCircle, Loader2 } from 'lucide-react';
import { clsx } from 'clsx';
import { formatUnits, parseUnits, isAddress } from 'viem';
import { SUPPORTED_TOKENS } from '@/lib/addresses';

interface Token {
  symbol: string;
  name: string;
  address: string;
  decimals: number;
  iconUrl: string;
  chainId: number;
}

interface TokenSelectorProps {
  selectedToken?: Token;
  onTokenSelect: (token: Token) => void;
  className?: string;
  disabled?: boolean;
  excludeTokens?: string[]; // Array of token symbols to exclude
}

export default function TokenSelector({ 
  selectedToken, 
  onTokenSelect, 
  className, 
  disabled = false,
  excludeTokens = []
}: TokenSelectorProps) {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const [isOpen, setIsOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [availableTokens, setAvailableTokens] = useState<Token[]>([]);

  // Get balance for selected token
  const { data: balance, isLoading: balanceLoading } = useBalance({
    address,
    token: selectedToken?.address === '0x0000000000000000000000000000000000000000' 
      ? undefined 
      : selectedToken?.address as `0x${string}` | undefined,
    chainId: selectedToken?.chainId,
    query: {
      enabled: !!selectedToken && !!address && isConnected
    }
  });

  // Update available tokens based on current chain
  useEffect(() => {
    const getTokensForChain = (chainId: number): Token[] => {
      let tokenAddresses: Record<string, string> = {};
      
      if (chainId === 11155111) { // Sepolia
        tokenAddresses = SUPPORTED_TOKENS.sepolia;
      } else if (chainId === 421614) { // Arbitrum Sepolia
        tokenAddresses = SUPPORTED_TOKENS.arbitrumSepolia;
      }

      return Object.entries(tokenAddresses).map(([symbol, address]) => ({
        symbol,
        name: getTokenName(symbol),
        address,
        decimals: getTokenDecimals(symbol),
        iconUrl: getTokenIconUrl(symbol),
        chainId
      }));
    };

    const tokens = getTokensForChain(chainId)
      .filter(token => !excludeTokens.includes(token.symbol));

    setAvailableTokens(tokens);
  }, [chainId, JSON.stringify(excludeTokens)]);

  // TODO: Re-implement auto-selection logic without causing infinite loops



  const getTokenName = (symbol: string): string => {
    const nameMap: Record<string, string> = {
      'USDC': 'USD Coin',
      'USDT': 'Tether USD',
      'DAI': 'Dai Stablecoin',
      'ETH': 'Ethereum',
      'WETH': 'Wrapped Ethereum'
    };
    return nameMap[symbol] || symbol;
  };

  const getTokenDecimals = (symbol: string): number => {
    const decimalsMap: Record<string, number> = {
      'USDC': 6,
      'USDT': 6,
      'DAI': 18,
      'ETH': 18,
      'WETH': 18
    };
    return decimalsMap[symbol] || 18;
  };

  const getTokenIconUrl = (symbol: string): string => {
    const iconMap: Record<string, string> = {
      'USDC': 'https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png',
      'USDT': 'https://assets.coingecko.com/coins/images/325/small/Tether.png',
      'DAI': 'https://assets.coingecko.com/coins/images/9956/small/Badge_Dai.png',
      'ETH': 'https://assets.coingecko.com/coins/images/279/small/ethereum.png',
      'WETH': 'https://assets.coingecko.com/coins/images/2518/small/weth.png'
    };
    return iconMap[symbol] || 'https://via.placeholder.com/32x32/cccccc/666666?text=' + symbol.charAt(0);
  };

  const filteredTokens = availableTokens.filter(token =>
    token.symbol.toLowerCase().includes(searchTerm.toLowerCase()) ||
    token.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const formatBalance = (balance: bigint, decimals: number): string => {
    const formatted = formatUnits(balance, decimals);
    const num = parseFloat(formatted);
    
    if (num === 0) return '0';
    if (num < 0.0001) return '< 0.0001';
    if (num < 1) return num.toFixed(6);
    if (num < 1000) return num.toFixed(4);
    if (num < 1000000) return (num / 1000).toFixed(2) + 'K';
    return (num / 1000000).toFixed(2) + 'M';
  };

  const handleTokenSelect = (token: Token) => {
    onTokenSelect(token);
    setIsOpen(false);
    setSearchTerm('');
  };

  if (availableTokens.length === 0) {
    return (
      <div className={clsx("flex items-center gap-2 px-4 py-3 rounded-xl border-2 border-gray-200 bg-gray-50", className)}>
        <AlertCircle className="w-5 h-5 text-gray-400" />
        <span className="text-sm text-gray-500">No tokens available on this network</span>
      </div>
    );
  }

  return (
    <div className={clsx("relative", className)}>
      <button
        onClick={() => !disabled && setIsOpen(!isOpen)}
        disabled={disabled}
        className={clsx(
          "w-full flex items-center gap-3 px-4 py-3 rounded-xl border-2 transition-all duration-200",
          disabled 
            ? "bg-gray-100 border-gray-200 cursor-not-allowed opacity-60"
            : "bg-white hover:bg-gray-50 border-gray-200 hover:border-gray-300 focus:outline-none focus:ring-1 focus:ring-purple-500 focus:border-purple-500"
        )}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
      >
        {selectedToken ? (
          <>
            <img 
              src={selectedToken.iconUrl} 
              alt={selectedToken.symbol} 
              className="w-8 h-8 rounded-full" 
            />
            <div className="flex-1 text-left">
              <div className="font-semibold text-gray-900">{selectedToken.symbol}</div>
              <div className="text-sm text-gray-500">{selectedToken.name}</div>
            </div>
            <div className="text-right">
              {isConnected && address ? (
                balanceLoading ? (
                  <Loader2 className="w-4 h-4 animate-spin text-gray-400" />
                ) : balance ? (
                  <>
                    <div className="text-sm font-medium text-gray-900">
                      {formatBalance(balance.value, balance.decimals)}
                    </div>
                    <div className="text-xs text-gray-500">Balance</div>
                  </>
                ) : (
                  <div className="text-sm text-gray-500">0</div>
                )
              ) : (
                <div className="text-sm text-gray-400">--</div>
              )}
            </div>
          </>
        ) : (
          <>
            <div className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center">
              <span className="text-gray-400 text-sm">?</span>
            </div>
            <div className="flex-1 text-left">
              <div className="font-medium text-gray-500">Select Token</div>
            </div>
          </>
        )}
        
        {!disabled && (
          <ChevronDown className={clsx("w-5 h-5 transition-transform text-gray-400", isOpen ? 'rotate-180' : '')} />
        )}
      </button>

      {isOpen && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
          <div className="absolute top-full left-0 right-0 mt-2 bg-white border border-gray-200 rounded-xl shadow-lg z-50 overflow-hidden max-h-80">
            {/* Search */}
            <div className="p-3 border-b border-gray-100">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search tokens..."
                  value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-purple-500 focus:border-purple-500"
                />
              </div>
            </div>

            {/* Token List */}
            <div className="max-h-60 overflow-y-auto">
              {filteredTokens.length === 0 ? (
                <div className="p-4 text-center text-gray-500 text-sm">
                  No tokens found
                </div>
              ) : (
                filteredTokens.map((token) => {
                  const isSelected = selectedToken?.address === token.address;
                  
                  return (
                    <TokenOption
                      key={`${token.chainId}-${token.address}`}
                      token={token}
                      isSelected={isSelected}
                      onClick={() => handleTokenSelect(token)}
                      userAddress={address}
                      isConnected={isConnected}
                    />
                  );
                })
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

interface TokenOptionProps {
  token: Token;
  isSelected: boolean;
  onClick: () => void;
  userAddress?: `0x${string}`;
  isConnected: boolean;
}

function TokenOption({ token, isSelected, onClick, userAddress, isConnected }: TokenOptionProps) {
  const { data: balance, isLoading } = useBalance({
    address: userAddress,
    token: token.address === '0x0000000000000000000000000000000000000000' 
      ? undefined 
      : token.address as `0x${string}`,
    chainId: token.chainId,
    query: {
      enabled: !!userAddress && isConnected
    }
  });

  const formatBalance = (balance: bigint, decimals: number): string => {
    const formatted = formatUnits(balance, decimals);
    const num = parseFloat(formatted);
    
    if (num === 0) return '0';
    if (num < 0.0001) return '< 0.0001';
    if (num < 1) return num.toFixed(6);
    if (num < 1000) return num.toFixed(4);
    if (num < 1000000) return (num / 1000).toFixed(2) + 'K';
    return (num / 1000000).toFixed(2) + 'M';
  };

  return (
    <button
      onClick={onClick}
      className={clsx(
        "w-full flex items-center gap-3 px-4 py-3 text-left transition-colors",
        isSelected 
          ? "bg-purple-100 text-black-700" 
          : "hover:bg-gray-50 text-gray-900"
      )}
    >
      <img 
        src={token.iconUrl} 
        alt={token.symbol} 
        className="w-8 h-8 rounded-full" 
      />
      <div className="flex-1">
        <div className="font-semibold text-sm">{token.symbol}</div>
        <div className="text-xs text-gray-500">{token.name}</div>
      </div>
      <div className="text-right">
        {isConnected && userAddress ? (
          isLoading ? (
            <Loader2 className="w-4 h-4 animate-spin text-gray-400" />
          ) : balance ? (
            <div className="text-sm font-medium">
              {formatBalance(balance.value, balance.decimals)}
            </div>
          ) : (
            <div className="text-sm text-gray-500">0</div>
          )
        ) : (
          <div className="text-sm text-gray-400">--</div>
        )}
      </div>
    </button>
  );
}