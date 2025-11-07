export const LayerZeroAdapterAbi = [
  // Custom errors for better revert decoding
  { "type": "error", "name": "UnsupportedRoute", "inputs": [] },
  { "type": "error", "name": "InsufficientLiquidity", "inputs": [] },
  { "type": "error", "name": "TransferAmountTooLow", "inputs": [] },
  { "type": "error", "name": "TransferAmountTooHigh", "inputs": [] },
  { "type": "error", "name": "BridgeInactive", "inputs": [] },
  { "type": "error", "name": "InvalidChainId", "inputs": [] },
  {
    "type": "function",
    "name": "executeBridge",
    "inputs": [
      {
        "name": "route",
        "type": "tuple",
        "internalType": "struct IBridgeAdapter.Route",
        "components": [
          {"name": "adapter", "type": "address", "internalType": "address"},
          {"name": "tokenIn", "type": "address", "internalType": "address"},
          {"name": "tokenOut", "type": "address", "internalType": "address"},
          {"name": "amountIn", "type": "uint256", "internalType": "uint256"},
          {"name": "amountOut", "type": "uint256", "internalType": "uint256"},
          {"name": "srcChainId", "type": "uint256", "internalType": "uint256"},
          {"name": "dstChainId", "type": "uint256", "internalType": "uint256"},
          {
            "name": "metrics",
            "type": "tuple",
            "internalType": "struct IBridgeAdapter.RouteMetrics",
            "components": [
              {"name": "estimatedGasCost", "type": "uint256", "internalType": "uint256"},
              {"name": "bridgeFee", "type": "uint256", "internalType": "uint256"},
              {"name": "totalCostWei", "type": "uint256", "internalType": "uint256"},
              {"name": "estimatedTimeMinutes", "type": "uint256", "internalType": "uint256"},
              {"name": "liquidityAvailable", "type": "uint256", "internalType": "uint256"},
              {"name": "successRate", "type": "uint256", "internalType": "uint256"},
              {"name": "congestionLevel", "type": "uint256", "internalType": "uint256"}
            ]
          },
          {"name": "adapterData", "type": "bytes", "internalType": "bytes"},
          {"name": "deadline", "type": "uint256", "internalType": "uint256"}
        ]
      },
      {"name": "recipient", "type": "address", "internalType": "address"},
      {"name": "permitData", "type": "bytes", "internalType": "bytes"}
    ],
    "outputs": [{"name": "transferId", "type": "bytes32", "internalType": "bytes32"}],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "getRouteMetrics",
    "inputs": [
      {"name": "tokenIn", "type": "address", "internalType": "address"},
      {"name": "tokenOut", "type": "address", "internalType": "address"},
      {"name": "amount", "type": "uint256", "internalType": "uint256"},
      {"name": "srcChainId", "type": "uint256", "internalType": "uint256"},
      {"name": "dstChainId", "type": "uint256", "internalType": "uint256"}
    ],
    "outputs": [
      {
        "name": "metrics",
        "type": "tuple",
        "internalType": "struct IBridgeAdapter.RouteMetrics",
        "components": [
          {"name": "estimatedGasCost", "type": "uint256", "internalType": "uint256"},
          {"name": "bridgeFee", "type": "uint256", "internalType": "uint256"},
          {"name": "totalCostWei", "type": "uint256", "internalType": "uint256"},
          {"name": "estimatedTimeMinutes", "type": "uint256", "internalType": "uint256"},
          {"name": "liquidityAvailable", "type": "uint256", "internalType": "uint256"},
          {"name": "successRate", "type": "uint256", "internalType": "uint256"},
          {"name": "congestionLevel", "type": "uint256", "internalType": "uint256"}
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "supportsRoute",
    "inputs": [
      {"name": "tokenIn", "type": "address", "internalType": "address"},
      {"name": "tokenOut", "type": "address", "internalType": "address"},
      {"name": "srcChainId", "type": "uint256", "internalType": "uint256"},
      {"name": "dstChainId", "type": "uint256", "internalType": "uint256"}
    ],
    "outputs": [{"name": "supported", "type": "bool", "internalType": "bool"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getBridgeName",
    "inputs": [],
    "outputs": [{"name": "", "type": "string", "internalType": "string"}],
    "stateMutability": "pure"
  }
] as const;
