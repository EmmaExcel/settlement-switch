// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IBridgeAdapter.sol";

interface ISettlementSwitch {

    /// @notice Multi-hop route for complex transfers
    struct MultiHopRoute {
        address[] adapters;         // Bridge adapters for each hop
        uint256[] chainIds;         // Chain IDs for each hop
        address[] tokens;           // Tokens for each hop
        uint256[] amounts;          // Amounts for each hop
        uint256[] fees;             // Fees for each hop
        uint256 totalTime;          // Total estimated time
        uint256 totalCost;          // Total estimated cost
    }

    /// @notice Multi-path routing for large amounts
    struct MultiPathRoute {
        IBridgeAdapter.Route[] routes;  // Multiple routes to split amount
        uint256[] amounts;              // Amount allocation per route
        uint256 totalAmount;            // Total amount being transferred
        uint256 totalCost;              // Total cost across all routes
        uint256 maxTime;                // Maximum time among all routes
    }

    /// @notice Liquidity source information
    struct LiquiditySource {
        address adapter;            // Bridge adapter address
        uint256 chainId;            // Chain ID where liquidity exists
        uint256 availableAmount;    // Available liquidity amount
        uint256 utilizationRate;    // Current utilization percentage
    }

    /// @notice Route cache entry
    struct CachedRoute {
        IBridgeAdapter.Route route; // Cached route information
        uint256 cachedAt;           // Timestamp when route was cached
        uint256 ttl;                // Time to live in seconds
        bool isValid;               // Whether cache entry is still valid
    }

    // Events
    event RouteCalculated(
        address indexed user,
        uint256 indexed srcChain,
        uint256 indexed dstChain,
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 estimatedCost,
        uint256 estimatedTime,
        address adapter
    );

    event MultiPathRouteCalculated(
        address indexed user,
        uint256 indexed srcChain,
        uint256 indexed dstChain,
        uint256 totalAmount,
        uint256 routeCount,
        uint256 totalCost
    );

    event TransferInitiated(
        bytes32 indexed transferId,
        address indexed user,
        IBridgeAdapter.Route route,
        uint256 timestamp
    );

    event MultiPathTransferInitiated(
        bytes32[] transferIds,
        address indexed user,
        MultiPathRoute multiPath,
        uint256 timestamp
    );

    event TransferCompleted(
        bytes32 indexed transferId,
        uint256 actualCost,
        uint256 actualTime,
        bool successful
    );

    event BridgeAdapterRegistered(
        address indexed adapter,
        string name,
        bool enabled
    );

    event BridgeAdapterStatusChanged(
        address indexed adapter,
        bool enabled,
        string reason
    );

    event EmergencyPause(
        address indexed admin,
        string reason,
        uint256 timestamp
    );

    event RouteCacheUpdated(
        bytes32 indexed routeHash,
        uint256 timestamp,
        uint256 ttl
    );

    // Core Route Discovery Functions

    function findOptimalRoute(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences
    ) external view returns (IBridgeAdapter.Route memory route);

    function findMultipleRoutes(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences,
        uint256 maxRoutes
    ) external view returns (IBridgeAdapter.Route[] memory routes);

    function findMultiPathRoute(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences
    ) external view returns (MultiPathRoute memory multiPath);

    // Execution Functions

    function executeBridge(
        IBridgeAdapter.Route memory route,
        address recipient,
        bytes calldata permitData
    ) external payable returns (bytes32 transferId);

    function executeMultiPathBridge(
        MultiPathRoute memory multiPath,
        address recipient,
        bytes calldata permitData
    ) external payable returns (bytes32[] memory transferIds);

    function bridgeWithAutoRoute(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        address recipient,
        IBridgeAdapter.RoutePreferences memory preferences,
        bytes calldata permitData
    ) external payable returns (bytes32 transferId);

    // Batch Operations

    function executeBatchBridge(
        IBridgeAdapter.Route[] memory routes,
        address[] memory recipients,
        bytes[] calldata permitData
    ) external payable returns (bytes32[] memory transferIds);

    // Information Functions

    function getRegisteredAdapters() external view returns (
        address[] memory adapters,
        string[] memory names,
        bool[] memory enabled
    );

    function getAvailableLiquidity(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view returns (LiquiditySource[] memory sources);

    function getCachedRoute(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences
    ) external view returns (CachedRoute memory cached, bool isValid);

    // Admin Functions

    function registerBridgeAdapter(address adapter, bool enabled) external;

    function setBridgeAdapterStatus(address adapter, bool enabled, string memory reason) external;

    function emergencyPause(string memory reason) external;

    function emergencyUnpause() external;

    function updateRouteCacheTtl(uint256 newTtl) external;

    // View Functions

    function isPaused() external view returns (bool paused);

    function getRouteCacheTtl() external view returns (uint256 ttl);

    function getTransfer(bytes32 transferId) external view returns (IBridgeAdapter.Transfer memory transfer);

    function getUserTransfers(
        address user,
        uint256 offset,
        uint256 limit
    ) external view returns (IBridgeAdapter.Transfer[] memory transfers);
}