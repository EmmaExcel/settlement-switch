'use client';

import React, { useState } from 'react';
import { ChevronDown } from 'lucide-react';
import { clsx } from 'clsx';

export default function ChainDropdown({
  selected,
  setSelected,
}: {
  selected: "SEPOLIA" | "ARBITRUM_SEPOLIA";
  setSelected: (selected: "SEPOLIA" | "ARBITRUM_SEPOLIA") => void;
}) {
  const [isOpen, setIsOpen] = useState(false);

  const options = [
    {
      value: 'SEPOLIA',
      label: 'Sepolia',
      iconUrl: 'https://assets.coingecko.com/coins/images/279/small/ethereum.png',
    },
    {
      value: 'ARBITRUM_SEPOLIA',
      label: 'Arbitrum Sepolia',
      iconUrl: 'https://assets.coingecko.com/coins/images/16547/small/arb.png',
    },
  ] as const;

  const selectedOption = options.find(o => o.value === selected) ?? options[0];

  return (
    <div className="relative inline-block">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-2 px-3 py-2 rounded-lg bg-gray-100 hover:bg-gray-200 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 min-w-[100px] justify-center"
        aria-haspopup="listbox"
        aria-expanded={isOpen}
      >
        <img src={selectedOption.iconUrl} alt={selectedOption.label} className="w-5 h-5" />
        <span className="font-medium text-sm">{selectedOption.label}</span>
        <ChevronDown className={`w-4 h-4 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
      </button>

      {isOpen && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
          <div className="absolute top-full left-0 mt-2 w-full min-w-[120px] bg-white rounded-lg shadow-lg border border-gray-200 z-50 overflow-hidden">
            {options.map(option => (
              <button
                key={option.value}
                onClick={() => {
                  setSelected(option.value);
                  setIsOpen(false);
                }}
                className={`flex items-center gap-2 w-full px-3 py-2 text-left hover:bg-gray-50 transition-colors ${selected === option.value ? 'bg-blue-50' : ''}`}
                role="option"
                aria-selected={selected === option.value}
              >
                <img src={option.iconUrl} alt={option.label} className="w-5 h-5" />
                <span className="font-medium text-sm">{option.label}</span>
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
