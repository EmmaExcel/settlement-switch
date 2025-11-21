// Contract addresses for different networks
export const CONTRACT_ADDRESSES = {
  // Sepolia Testnet (Chain ID: 11155111)
  sepolia: {
    // Legacy StablecoinSwitch (keeping for backward compatibility)
    StablecoinSwitch: "0x1fca7be27d3981ab8783f862672f2be6346383d5",

    // Settlement Switch System (New Multi-Bridge Aggregator - Latest deployment with fixed arithmetic)
    SettlementSwitch: "0xC094dD48B8E9017BB5962a1Da8FE9f7B76fb47DA",
    RouteCalculator: "0x4cB5d76dc96f183E3c0DC0DCF8A8d71f6a10824D",
    BridgeRegistry: "0x225A3471178028978081919aa3FF522c57ac7c8B",
    FeeManager: "0x57eDf3dA78760586E4f2BfF50B2613Dc566b424A",

    // Bridge Adapters
    LayerZeroAdapter: "0xe5753ba7b2d8ad8a4c6c4d221ea73cfddbb8c313", // Updated with corrected minimum transfer amount
    ConnextAdapter: "0x2f097cd8623eb3b8ea6d161fe87bbf154a238a3f",
    AcrossAdapter: "0x8dfd68e1a08209b727149b2256140af9ce1978f0",

    // Legacy addresses
    ArbitrumInbox: "0xaae29b0366299461418f5324a79afc425be5ae21",
    ETHBridge: "", // Add when deployed
    ArbitrumBridgeAdapter: "0x61D490b46a579588448F770aabb7B02582ed9AD9", // Deployed on Sepolia
  },

  // Arbitrum Sepolia (Chain ID: 421614) - Updated with new deployed contracts
  arbitrumSepolia: {
    StablecoinSwitch: "0x771bc486143f8a12ebdfc3ca23472fee0a1f6f85", // Same contract deployed on Sepolia
    ArbitrumL2Bridge: "0x3072D9408bBAFdB7C0E0FE53bca8Bed665088444", // Bridge adapter

    // Added from broadcast logs
    SettlementSwitch: "0x00daab77e5de7aa9643b7c82c704f4e84ead6c47",
    RouteCalculator: "0x3b7732741bec717450ba8e41957ff13da75ed7b3",
    BridgeRegistry: "0x0876123851b855a570c70ae9fe72c51d1eac0b5f",
    FeeManager: "0x902daa2e17dbe89ae26ea4e32cbe295815021322",
    LayerZeroAdapter: "0xb439f6ebc57cad53788f155a0325b8a670dc5f76"
  },

  // Mainnet (Chain ID: 1) - for production
  mainnet: {
    // Fill these after mainnet deploy
    SettlementSwitch: "",
    RouteCalculator: "",
    BridgeRegistry: "",
    FeeManager: "",
    LayerZeroAdapter: ""
  },

  // Arbitrum One (Chain ID: 42161) - for production
  arbitrumOne: {
    SettlementSwitch: "0x64aD503BC93faFd92249450A4B6B7eb777e0baF9",
    RouteCalculator: "0xB739Ba9b1002d6E6795A49804F98b802b08B759f",
    BridgeRegistry: "0x7bEe309F8d64A086510315A12538A82887bC6c04",
    FeeManager: "0x036D268B1892ED99f32a1a7249A12fD6f334214E",
    LayerZeroAdapter: "0x49F7E8962d6236797d9c7554aE98B3CA2A273C28"
  }
} as const;

// Supported tokens on Sepolia
export const SUPPORTED_TOKENS = {
  sepolia: {
    ETH: "0x0000000000000000000000000000000000000000", // Native ETH
    WETH: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9", // Wrapped ETH (Settlement Switch)
    USDC: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
    USDT: "0x7169D38820dfd117C3FA1f22a697dBA58d90BA06",
    DAI: "0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6",
    // Add more tokens as needed
  },
  arbitrumSepolia: {
    ETH: "0x0000000000000000000000000000000000000000", // Native ETH
    WETH: "0x980B62Da83eFf3D4576C647993b0c1D7faf17c73", // Wrapped ETH on Arbitrum Sepolia
    USDC: "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d",
  },
  mainnet: {
    ETH: "0x0000000000000000000000000000000000000000",
    WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    USDC: "0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    DAI: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    USDT: "0xdAC17F958D2ee523a2206206994597C13D831ec7"
  },
  arbitrumOne: {
    ETH: "0x0000000000000000000000000000000000000000",
    WETH: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    USDC: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    USDT: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9"
  }
} as const;

// Chain configurations
export const CHAIN_CONFIG = {
  sepolia: {
    id: 11155111,
    name: "Sepolia",
    network: "sepolia",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    icon: "/icons/ethereum.svg",
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
    icon: "/icons/arbitrum.svg",
    rpcUrls: {
      default: { http: ["https://sepolia-rollup.arbitrum.io/rpc"] },
      public: { http: ["https://sepolia-rollup.arbitrum.io/rpc"] },
    },
    blockExplorers: {
      default: { name: "Arbiscan", url: "https://sepolia.arbiscan.io" },
    },
  },
  mainnet: {
    id: 1,
    name: "Ethereum Mainnet",
    network: "mainnet",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    icon: "/icons/ethereum.svg",
    rpcUrls: {
      default: { http: ["https://ethereum-rpc.publicnode.com"] },
      public: { http: ["https://ethereum-rpc.publicnode.com"] },
    },
    blockExplorers: {
      default: { name: "Etherscan", url: "https://etherscan.io" },
    },
  },
  arbitrumOne: {
    id: 42161,
    name: "Arbitrum One",
    network: "arbitrum",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    icon: "/icons/arbitrum.svg",
    rpcUrls: {
      default: { http: ["https://arbitrum-one.publicnode.com"] },
      public: { http: ["https://arbitrum-one.publicnode.com"] },
    },
    blockExplorers: {
      default: { name: "Arbiscan", url: "https://arbiscan.io" },
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
