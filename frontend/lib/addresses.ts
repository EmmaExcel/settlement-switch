// Contract addresses for different networks
export const CONTRACT_ADDRESSES = {
  // Sepolia Testnet (Chain ID: 11155111)
  sepolia: {
    StablecoinSwitch: "0xc16a01431b1d980b0df125df4d8df4633c4d5ba0",
    ArbitrumInbox: "0xaae29b0366299461418f5324a79afc425be5ae21",
    // Add other contract addresses as they get deployed
    ETHBridge: "", // Add when deployed
    ArbitrumBridgeAdapter: "0x61D490b46a579588448F770aabb7B02582ed9AD9", // Deployed on Sepolia
  },
  
  // Arbitrum Sepolia (Chain ID: 421614)
  arbitrumSepolia: {
    // Add Arbitrum contract addresses here
  },
  
  // Mainnet (Chain ID: 1) - for production
  mainnet: {
    // Add mainnet addresses when ready for production
  },
  
  // Arbitrum One (Chain ID: 42161) - for production
  arbitrumOne: {
    // Add Arbitrum One addresses when ready for production
  }
} as const;

// Supported tokens on Sepolia
export const SUPPORTED_TOKENS = {
  sepolia: {
    USDC: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
    USDT: "0x7169D38820dfd117C3FA1f22a697dBA58d90BA06", 
    DAI: "0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6",
    // Add more tokens as needed
  }
} as const;

// Chain configurations
export const CHAIN_CONFIG = {
  sepolia: {
    id: 11155111,
    name: "Sepolia",
    network: "sepolia",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: {
      default: { http: ["https://ethereum-sepolia-rpc.publicnode.com"] },
      public: { http: ["https://ethereum-sepolia-rpc.publicnode.com"] },
    },
    blockExplorers: {
      default: { name: "Etherscan", url: "https://sepolia.etherscan.io" },
    },
  },
  arbitrumSepolia: {
    id: 421614,
    name: "Arbitrum Sepolia",
    network: "arbitrum-sepolia",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: {
      default: { http: ["https://sepolia-rollup.arbitrum.io/rpc"] },
      public: { http: ["https://sepolia-rollup.arbitrum.io/rpc"] },
    },
    blockExplorers: {
      default: { name: "Arbiscan", url: "https://sepolia.arbiscan.io" },
    },
  }
} as const;

// Helper function to get contract address for current chain
export function getContractAddress(
  contractName: keyof typeof CONTRACT_ADDRESSES.sepolia,
  chainId: number
): string {
  switch (chainId) {
    case 11155111:
      return CONTRACT_ADDRESSES.sepolia[contractName];
    case 421614:
      return (CONTRACT_ADDRESSES.arbitrumSepolia as any)[contractName] || "";
    case 1:
      return (CONTRACT_ADDRESSES.mainnet as any)[contractName] || "";
    case 42161:
      return (CONTRACT_ADDRESSES.arbitrumOne as any)[contractName] || "";
    default:
      throw new Error(`Unsupported chain ID: ${chainId}`);
  }
}