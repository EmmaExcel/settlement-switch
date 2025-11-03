export const SettlementSwitchAbi = [
  // Core Route Discovery Functions
  {
    type: "function",
    name: "findOptimalRoute",
    inputs: [
      { name: "tokenIn", type: "address", internalType: "address" },
      { name: "tokenOut", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
      { name: "srcChainId", type: "uint256", internalType: "uint256" },
      { name: "dstChainId", type: "uint256", internalType: "uint256" },
      {
        name: "preferences",
        type: "tuple",
        internalType: "struct IBridgeAdapter.RoutePreferences",
        components: [
          { name: "mode", type: "uint8", internalType: "enum IBridgeAdapter.RoutingMode" },
          { name: "maxSlippageBps", type: "uint256", internalType: "uint256" },
          { name: "maxFeeWei", type: "uint256", internalType: "uint256" },
          { name: "maxTimeMinutes", type: "uint256", internalType: "uint256" },
          { name: "allowMultiHop", type: "bool", internalType: "bool" }
        ]
      }
    ],
    outputs: [
      {
        name: "route",
        type: "tuple",
        internalType: "struct IBridgeAdapter.Route",
        components: [
          { name: "adapter", type: "address", internalType: "address" },
          { name: "tokenIn", type: "address", internalType: "address" },
          { name: "tokenOut", type: "address", internalType: "address" },
          { name: "amountIn", type: "uint256", internalType: "uint256" },
          { name: "amountOut", type: "uint256", internalType: "uint256" },
          { name: "srcChainId", type: "uint256", internalType: "uint256" },
          { name: "dstChainId", type: "uint256", internalType: "uint256" },
          {
            name: "metrics",
            type: "tuple",
            internalType: "struct IBridgeAdapter.RouteMetrics",
            components: [
              { name: "estimatedGasCost", type: "uint256", internalType: "uint256" },
              { name: "bridgeFee", type: "uint256", internalType: "uint256" },
              { name: "totalCostWei", type: "uint256", internalType: "uint256" },
              { name: "estimatedTimeMinutes", type: "uint256", internalType: "uint256" },
              { name: "liquidityAvailable", type: "uint256", internalType: "uint256" },
              { name: "successRate", type: "uint256", internalType: "uint256" },
              { name: "congestionLevel", type: "uint256", internalType: "uint256" }
            ]
          },
          { name: "adapterData", type: "bytes", internalType: "bytes" },
          { name: "deadline", type: "uint256", internalType: "uint256" }
        ]
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "findMultipleRoutes",
    inputs: [
      { name: "tokenIn", type: "address", internalType: "address" },
      { name: "tokenOut", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
      { name: "srcChainId", type: "uint256", internalType: "uint256" },
      { name: "dstChainId", type: "uint256", internalType: "uint256" },
      {
        name: "preferences",
        type: "tuple",
        internalType: "struct IBridgeAdapter.RoutePreferences",
        components: [
          { name: "mode", type: "uint8", internalType: "enum IBridgeAdapter.RoutingMode" },
          { name: "maxSlippageBps", type: "uint256", internalType: "uint256" },
          { name: "maxFeeWei", type: "uint256", internalType: "uint256" },
          { name: "maxTimeMinutes", type: "uint256", internalType: "uint256" },
          { name: "allowMultiHop", type: "bool", internalType: "bool" }
        ]
      },
      { name: "maxRoutes", type: "uint256", internalType: "uint256" }
    ],
    outputs: [
      {
        name: "routes",
        type: "tuple[]",
        internalType: "struct IBridgeAdapter.Route[]",
        components: [
          { name: "adapter", type: "address", internalType: "address" },
          { name: "tokenIn", type: "address", internalType: "address" },
          { name: "tokenOut", type: "address", internalType: "address" },
          { name: "amountIn", type: "uint256", internalType: "uint256" },
          { name: "amountOut", type: "uint256", internalType: "uint256" },
          { name: "srcChainId", type: "uint256", internalType: "uint256" },
          { name: "dstChainId", type: "uint256", internalType: "uint256" },
          {
            name: "metrics",
            type: "tuple",
            internalType: "struct IBridgeAdapter.RouteMetrics",
            components: [
              { name: "estimatedGasCost", type: "uint256", internalType: "uint256" },
              { name: "bridgeFee", type: "uint256", internalType: "uint256" },
              { name: "totalCostWei", type: "uint256", internalType: "uint256" },
              { name: "estimatedTimeMinutes", type: "uint256", internalType: "uint256" },
              { name: "liquidityAvailable", type: "uint256", internalType: "uint256" },
              { name: "successRate", type: "uint256", internalType: "uint256" },
              { name: "congestionLevel", type: "uint256", internalType: "uint256" }
            ]
          },
          { name: "adapterData", type: "bytes", internalType: "bytes" },
          { name: "deadline", type: "uint256", internalType: "uint256" }
        ]
      }
    ],
    stateMutability: "view"
  },
  // Bridge Execution Functions
  {
    type: "function",
    name: "executeBridge",
    inputs: [
      {
        name: "route",
        type: "tuple",
        internalType: "struct IBridgeAdapter.Route",
        components: [
          { name: "adapter", type: "address", internalType: "address" },
          { name: "tokenIn", type: "address", internalType: "address" },
          { name: "tokenOut", type: "address", internalType: "address" },
          { name: "amountIn", type: "uint256", internalType: "uint256" },
          { name: "amountOut", type: "uint256", internalType: "uint256" },
          { name: "srcChainId", type: "uint256", internalType: "uint256" },
          { name: "dstChainId", type: "uint256", internalType: "uint256" },
          {
            name: "metrics",
            type: "tuple",
            internalType: "struct IBridgeAdapter.RouteMetrics",
            components: [
              { name: "estimatedGasCost", type: "uint256", internalType: "uint256" },
              { name: "bridgeFee", type: "uint256", internalType: "uint256" },
              { name: "totalCostWei", type: "uint256", internalType: "uint256" },
              { name: "estimatedTimeMinutes", type: "uint256", internalType: "uint256" },
              { name: "liquidityAvailable", type: "uint256", internalType: "uint256" },
              { name: "successRate", type: "uint256", internalType: "uint256" },
              { name: "congestionLevel", type: "uint256", internalType: "uint256" }
            ]
          },
          { name: "adapterData", type: "bytes", internalType: "bytes" },
          { name: "deadline", type: "uint256", internalType: "uint256" }
        ]
      },
      { name: "recipient", type: "address", internalType: "address" },
      { name: "permitData", type: "bytes", internalType: "bytes" }
    ],
    outputs: [
      { name: "transferId", type: "bytes32", internalType: "bytes32" }
    ],
    stateMutability: "payable"
  },
  {
    type: "function",
    name: "bridgeWithAutoRoute",
    inputs: [
      { name: "tokenIn", type: "address", internalType: "address" },
      { name: "tokenOut", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
      { name: "srcChainId", type: "uint256", internalType: "uint256" },
      { name: "dstChainId", type: "uint256", internalType: "uint256" },
      { name: "recipient", type: "address", internalType: "address" },
      {
        name: "preferences",
        type: "tuple",
        internalType: "struct IBridgeAdapter.RoutePreferences",
        components: [
          { name: "mode", type: "uint8", internalType: "enum IBridgeAdapter.RoutingMode" },
          { name: "maxSlippageBps", type: "uint256", internalType: "uint256" },
          { name: "maxFeeWei", type: "uint256", internalType: "uint256" },
          { name: "maxTimeMinutes", type: "uint256", internalType: "uint256" },
          { name: "allowMultiHop", type: "bool", internalType: "bool" }
        ]
      },
      { name: "permitData", type: "bytes", internalType: "bytes" }
    ],
    outputs: [
      { name: "transferId", type: "bytes32", internalType: "bytes32" }
    ],
    stateMutability: "payable"
  },
  // Information Functions
  {
    type: "function",
    name: "getRegisteredAdapters",
    inputs: [],
    outputs: [
      { name: "adapters", type: "address[]", internalType: "address[]" },
      { name: "names", type: "string[]", internalType: "string[]" },
      { name: "enabled", type: "bool[]", internalType: "bool[]" }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "getTransfer",
    inputs: [
      { name: "transferId", type: "bytes32", internalType: "bytes32" }
    ],
    outputs: [
      {
        name: "transfer",
        type: "tuple",
        internalType: "struct IBridgeAdapter.Transfer",
        components: [
          { name: "transferId", type: "bytes32", internalType: "bytes32" },
          { name: "sender", type: "address", internalType: "address" },
          { name: "recipient", type: "address", internalType: "address" },
          {
            name: "route",
            type: "tuple",
            internalType: "struct IBridgeAdapter.Route",
            components: [
              { name: "adapter", type: "address", internalType: "address" },
              { name: "tokenIn", type: "address", internalType: "address" },
              { name: "tokenOut", type: "address", internalType: "address" },
              { name: "amountIn", type: "uint256", internalType: "uint256" },
              { name: "amountOut", type: "uint256", internalType: "uint256" },
              { name: "srcChainId", type: "uint256", internalType: "uint256" },
              { name: "dstChainId", type: "uint256", internalType: "uint256" },
              {
                name: "metrics",
                type: "tuple",
                internalType: "struct IBridgeAdapter.RouteMetrics",
                components: [
                  { name: "estimatedGasCost", type: "uint256", internalType: "uint256" },
                  { name: "bridgeFee", type: "uint256", internalType: "uint256" },
                  { name: "totalCostWei", type: "uint256", internalType: "uint256" },
                  { name: "estimatedTimeMinutes", type: "uint256", internalType: "uint256" },
                  { name: "liquidityAvailable", type: "uint256", internalType: "uint256" },
                  { name: "successRate", type: "uint256", internalType: "uint256" },
                  { name: "congestionLevel", type: "uint256", internalType: "uint256" }
                ]
              },
              { name: "adapterData", type: "bytes", internalType: "bytes" },
              { name: "deadline", type: "uint256", internalType: "uint256" }
            ]
          },
          { name: "status", type: "uint8", internalType: "enum IBridgeAdapter.TransferStatus" },
          { name: "initiatedAt", type: "uint256", internalType: "uint256" },
          { name: "completedAt", type: "uint256", internalType: "uint256" }
        ]
      }
    ],
    stateMutability: "view"
  },
  // View Functions
  {
    type: "function",
    name: "isPaused",
    inputs: [],
    outputs: [
      { name: "paused", type: "bool", internalType: "bool" }
    ],
    stateMutability: "view"
  },
  // Events
  {
    type: "event",
    name: "TransferInitiated",
    inputs: [
      { name: "transferId", type: "bytes32", indexed: true, internalType: "bytes32" },
      { name: "user", type: "address", indexed: true, internalType: "address" },
      {
        name: "route",
        type: "tuple",
        indexed: false,
        internalType: "struct IBridgeAdapter.Route",
        components: [
          { name: "adapter", type: "address", internalType: "address" },
          { name: "tokenIn", type: "address", internalType: "address" },
          { name: "tokenOut", type: "address", internalType: "address" },
          { name: "amountIn", type: "uint256", internalType: "uint256" },
          { name: "amountOut", type: "uint256", internalType: "uint256" },
          { name: "srcChainId", type: "uint256", internalType: "uint256" },
          { name: "dstChainId", type: "uint256", internalType: "uint256" },
          {
            name: "metrics",
            type: "tuple",
            internalType: "struct IBridgeAdapter.RouteMetrics",
            components: [
              { name: "estimatedGasCost", type: "uint256", internalType: "uint256" },
              { name: "bridgeFee", type: "uint256", internalType: "uint256" },
              { name: "totalCostWei", type: "uint256", internalType: "uint256" },
              { name: "estimatedTimeMinutes", type: "uint256", internalType: "uint256" },
              { name: "liquidityAvailable", type: "uint256", internalType: "uint256" },
              { name: "successRate", type: "uint256", internalType: "uint256" },
              { name: "congestionLevel", type: "uint256", internalType: "uint256" }
            ]
          },
          { name: "adapterData", type: "bytes", internalType: "bytes" },
          { name: "deadline", type: "uint256", internalType: "uint256" }
        ]
      },
      { name: "timestamp", type: "uint256", indexed: false, internalType: "uint256" }
    ]
  },
  {
    type: "event",
    name: "TransferCompleted",
    inputs: [
      { name: "transferId", type: "bytes32", indexed: true, internalType: "bytes32" },
      { name: "actualCost", type: "uint256", indexed: false, internalType: "uint256" },
      { name: "actualTime", type: "uint256", indexed: false, internalType: "uint256" },
      { name: "successful", type: "bool", indexed: false, internalType: "bool" }
    ]
  }
] as const;

export type SettlementSwitchAbiType = typeof SettlementSwitchAbi;

// Routing Mode Enum
export enum RoutingMode {
  CHEAPEST = 0,
  FASTEST = 1,
  BALANCED = 2
}

// Transfer Status Enum
export enum TransferStatus {
  PENDING = 0,
  COMPLETED = 1,
  FAILED = 2
}