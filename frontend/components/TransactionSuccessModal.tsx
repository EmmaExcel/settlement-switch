'use client';

import { useState, useEffect } from 'react';
import { CheckCircle, ExternalLink, X, Copy, Check } from 'lucide-react';
import clsx from 'clsx';

interface TransactionSuccessModalProps {
  isOpen: boolean;
  onClose: () => void;
  txHash: string;
  fromChain: string;
  toChain: string;
  amount: string;
  token: string;
  bridge?: string;
  blockNumber?: string;
}

export default function TransactionSuccessModal({
  isOpen,
  onClose,
  txHash,
  fromChain,
  toChain,
  amount,
  token,
  bridge,
  blockNumber
}: TransactionSuccessModalProps) {
  const [copied, setCopied] = useState(false);

  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(txHash);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  const getExplorerUrl = (hash: string, chain: string) => {
    const baseUrls: Record<string, string> = {
      sepolia: 'https://sepolia.etherscan.io/tx/',
      arbitrumSepolia: 'https://sepolia.arbiscan.io/tx/'
    };
    return `${baseUrls[chain] || baseUrls.sepolia}${hash}`;
  };

  const formatChainName = (chain: string) => {
    const names: Record<string, string> = {
      sepolia: 'Ethereum Sepolia',
      arbitrumSepolia: 'Arbitrum Sepolia'
    };
    return names[chain] || chain;
  };

  // Close modal on escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    
    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      document.body.style.overflow = 'hidden';
    }
    
    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = 'unset';
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={onClose}
      />
      
      {/* Modal */}
      <div className="relative bg-white dark:bg-gray-900 rounded-2xl shadow-2xl max-w-md w-full mx-4 p-6 animate-in fade-in-0 zoom-in-95 duration-200">
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-2 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
        >
          <X className="w-5 h-5 text-gray-500" />
        </button>

        {/* Success icon */}
        <div className="flex justify-center mb-6">
          <div className="w-16 h-16 bg-green-100 dark:bg-green-900/30 rounded-full flex items-center justify-center">
            <CheckCircle className="w-8 h-8 text-green-600 dark:text-green-400" />
          </div>
        </div>

        {/* Title */}
        <h2 className="text-2xl font-bold text-center text-gray-900 dark:text-white mb-2">
          Transaction Successful!
        </h2>
        
        <p className="text-gray-600 dark:text-gray-400 text-center mb-6">
          Your bridge transaction has been confirmed on the blockchain.
        </p>

        {/* Transaction details */}
        <div className="space-y-4 mb-6">
          <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm text-gray-600 dark:text-gray-400">Amount</span>
              <span className="font-semibold text-gray-900 dark:text-white">
                {amount} {token}
              </span>
            </div>
            
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm text-gray-600 dark:text-gray-400">From</span>
              <span className="font-medium text-gray-900 dark:text-white">
                {formatChainName(fromChain)}
              </span>
            </div>
            
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm text-gray-600 dark:text-gray-400">To</span>
              <span className="font-medium text-gray-900 dark:text-white">
                {formatChainName(toChain)}
              </span>
            </div>

            {bridge && (
              <div className="flex justify-between items-center mb-2">
                <span className="text-sm text-gray-600 dark:text-gray-400">Bridge</span>
                <span className="font-medium text-gray-900 dark:text-white">
                  {bridge}
                </span>
              </div>
            )}

            {blockNumber && (
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600 dark:text-gray-400">Block</span>
                <span className="font-medium text-gray-900 dark:text-white">
                  #{blockNumber}
                </span>
              </div>
            )}
          </div>

          {/* Transaction hash */}
          <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm text-gray-600 dark:text-gray-400">Transaction Hash</span>
              <button
                onClick={copyToClipboard}
                className="flex items-center gap-1 text-sm text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300 transition-colors"
              >
                {copied ? (
                  <>
                    <Check className="w-4 h-4" />
                    Copied
                  </>
                ) : (
                  <>
                    <Copy className="w-4 h-4" />
                    Copy
                  </>
                )}
              </button>
            </div>
            <div className="font-mono text-sm text-gray-900 dark:text-white break-all">
              {txHash}
            </div>
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex gap-3">
          <a
            href={getExplorerUrl(txHash, fromChain)}
            target="_blank"
            rel="noopener noreferrer"
            className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors"
          >
            <ExternalLink className="w-4 h-4" />
            View on Explorer
          </a>
          
          <button
            onClick={onClose}
            className="flex-1 px-4 py-3 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-900 dark:text-white rounded-lg font-medium transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}