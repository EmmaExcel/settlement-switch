export const StablecoinSwitchAbi = [
  // Custom errors (for decoding revert reasons)
  { type: "error", name: "InvalidToken", inputs: [] },
  { type: "error", name: "InvalidChain", inputs: [] },
  { type: "error", name: "InvalidAmount", inputs: [] },
  { type: "error", name: "InvalidPriority", inputs: [] },
  { type: "error", name: "InvalidRecipient", inputs: [] },
  { type: "error", name: "UnsupportedToken", inputs: [] },
  { type: "error", name: "UnsupportedChain", inputs: [] },
  { type: "error", name: "InsufficientAmount", inputs: [] },
  { type: "error", name: "SlippageExceeded", inputs: [] },
  { type: "error", name: "BridgeAdapterNotSet", inputs: [] },
  { type: "error", name: "PriceFeedError", inputs: [] },
  { type: "error", name: "TransferFailed", inputs: [] },
  {
    type: "function",
    name: "getOptimalPath",
    inputs: [
      { name: "fromToken", type: "address", internalType: "address" },
      { name: "toToken", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
      { name: "toChainId", type: "uint256", internalType: "uint256" },
      { name: "priority", type: "uint8", internalType: "uint8" },
    ],
    outputs: [
      {
        name: "routeInfo",
        type: "tuple",
        internalType: "struct StablecoinSwitch.RouteInfo",
        components: [
          { name: "fromToken", type: "address", internalType: "address" },
          { name: "toToken", type: "address", internalType: "address" },
          { name: "fromChainId", type: "uint256", internalType: "uint256" },
          { name: "toChainId", type: "uint256", internalType: "uint256" },
          { name: "estimatedCostUsd", type: "uint256", internalType: "uint256" },
          { name: "estimatedGasUsd", type: "uint256", internalType: "uint256" },
          { name: "bridgeFeeUsd", type: "uint256", internalType: "uint256" },
          { name: "estimatedTimeMinutes", type: "uint256", internalType: "uint256" },
          { name: "bridgeAdapter", type: "address", internalType: "address" },
          { name: "bridgeName", type: "string", internalType: "string" },
          { name: "gasEstimate", type: "uint256", internalType: "uint256" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getBridgeAdapters",
    inputs: [
      { name: "chainId", type: "uint256", internalType: "uint256" },
    ],
    outputs: [
      { name: "adapters", type: "address[]", internalType: "address[]" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getBridgeAdapter",
    inputs: [
      { name: "chainId", type: "uint256", internalType: "uint256" },
    ],
    outputs: [
      { name: "adapter", type: "address", internalType: "address" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isTokenSupported",
    inputs: [
      { name: "token", type: "address", internalType: "address" },
    ],
    outputs: [
      { name: "isSupported", type: "bool", internalType: "bool" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isChainSupported",
    inputs: [
      { name: "chainId", type: "uint256", internalType: "uint256" },
    ],
    outputs: [
      { name: "isSupported", type: "bool", internalType: "bool" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "areFeedsHealthy",
    inputs: [],
    outputs: [
      { name: "ethOk", type: "bool", internalType: "bool" },
      { name: "usdcOk", type: "bool", internalType: "bool" },
      { name: "ethUpdatedAt", type: "uint256", internalType: "uint256" },
      { name: "usdcUpdatedAt", type: "uint256", internalType: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "maxPriceStalenessSeconds",
    inputs: [],
    outputs: [
      { name: "", type: "uint256", internalType: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "setMaxPriceStalenessSeconds",
    inputs: [
      { name: "seconds_", type: "uint256", internalType: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "ethUsdPriceFeed",
    inputs: [],
    outputs: [
      { name: "", type: "address", internalType: "address" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "usdcUsdPriceFeed",
    inputs: [],
    outputs: [
      { name: "", type: "address", internalType: "address" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "routeTransaction",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct StablecoinSwitch.RouteParams",
        components: [
          { name: "fromToken", type: "address", internalType: "address" },
          { name: "toToken", type: "address", internalType: "address" },
          { name: "amount", type: "uint256", internalType: "uint256" },
          { name: "toChainId", type: "uint256", internalType: "uint256" },
          { name: "priority", type: "uint8", internalType: "uint8" },
          { name: "recipient", type: "address", internalType: "address" },
          { name: "minAmountOut", type: "uint256", internalType: "uint256" },
        ],
      },
    ],
    outputs: [
      {
        name: "routeInfo",
        type: "tuple",
        internalType: "struct StablecoinSwitch.RouteInfo",
        components: [
          { name: "fromToken", type: "address", internalType: "address" },
          { name: "toToken", type: "address", internalType: "address" },
          { name: "fromChainId", type: "uint256", internalType: "uint256" },
          { name: "toChainId", type: "uint256", internalType: "uint256" },
          { name: "estimatedCostUsd", type: "uint256", internalType: "uint256" },
          { name: "estimatedGasUsd", type: "uint256", internalType: "uint256" },
          { name: "bridgeFeeUsd", type: "uint256", internalType: "uint256" },
          { name: "estimatedTimeMinutes", type: "uint256", internalType: "uint256" },
          { name: "bridgeAdapter", type: "address", internalType: "address" },
          { name: "bridgeName", type: "string", internalType: "string" },
          { name: "gasEstimate", type: "uint256", internalType: "uint256" },
        ],
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "isTokenSupported",
    inputs: [{ name: "token", type: "address", internalType: "address" }],
    outputs: [{ name: "isSupported", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isChainSupported",
    inputs: [{ name: "chainId", type: "uint256", internalType: "uint256" }],
    outputs: [{ name: "isSupported", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
];

export type StablecoinSwitchAbiType = typeof StablecoinSwitchAbi;