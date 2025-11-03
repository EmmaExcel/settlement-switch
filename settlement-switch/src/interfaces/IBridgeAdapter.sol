// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBridgeAdapter {
    /// @notice Routing mode preferences for bridge selection
    enum RoutingMode {
        CHEAPEST,   // Minimize total cost
        FASTEST,    // Minimize transfer time
        BALANCED    // Balance between cost and speed
    }

    /// @notice Route preferences for bridge selection
    struct RoutePreferences {
        RoutingMode mode;           // Routing optimization mode
        uint256 maxSlippageBps;     // Maximum acceptable slippage in basis points
        uint256 maxFeeWei;          // Maximum acceptable fee in Wei
        uint256 maxTimeMinutes;     // Maximum acceptable time in minutes
        bool allowMultiHop;         // Allow routing through intermediate chains
    }

    /// @notice Metrics for evaluating route quality
    struct RouteMetrics {
        uint256 estimatedGasCost;   // Estimated gas cost in Wei
        uint256 bridgeFee;          // Bridge protocol fee in Wei
        uint256 totalCostWei;       // Total cost including gas and fees
        uint256 estimatedTimeMinutes; // Estimated completion time
        uint256 liquidityAvailable; // Available liquidity for the transfer
        uint256 successRate;        // Historical success rate (0-100)
        uint256 congestionLevel;    // Current network congestion (0-100)
    }

    /// @notice Complete route information
    struct Route {
        address adapter;            // Bridge adapter address
        address tokenIn;            // Input token address
        address tokenOut;           // Output token address
        uint256 amountIn;           // Input amount
        uint256 amountOut;          // Expected output amount
        uint256 srcChainId;         // Source chain ID
        uint256 dstChainId;         // Destination chain ID
        RouteMetrics metrics;       // Route quality metrics
        bytes adapterData;          // Adapter-specific data
        uint256 deadline;           // Transaction deadline
    }

    /// @notice Bridge transfer status
    enum TransferStatus {
        PENDING,    // Transfer initiated but not confirmed
        CONFIRMED,  // Transfer confirmed on source chain
        COMPLETED,  // Transfer completed on destination chain
        FAILED,     // Transfer failed
        REFUNDED    // Transfer refunded to sender
    }

    /// @notice Transfer information
    struct Transfer {
        bytes32 transferId;         // Unique transfer identifier
        address sender;             // Transfer initiator
        address recipient;          // Transfer recipient
        Route route;                // Route used for transfer
        TransferStatus status;      // Current transfer status
        uint256 initiatedAt;        // Timestamp when transfer was initiated
        uint256 completedAt;        // Timestamp when transfer was completed
    }

    // Events
    event TransferInitiated(
        bytes32 indexed transferId,
        address indexed sender,
        address indexed recipient,
        Route route
    );

    event TransferCompleted(
        bytes32 indexed transferId,
        uint256 actualAmountOut,
        uint256 actualCost,
        uint256 actualTime
    );

    event TransferFailed(
        bytes32 indexed transferId,
        string reason
    );

    // Core Functions

    function getBridgeName() external view returns (string memory);

    function supportsRoute(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view returns (bool supported);

    function getRouteMetrics(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view returns (RouteMetrics memory metrics);

    function executeBridge(
        Route memory route,
        address recipient,
        bytes calldata permitData
    ) external payable returns (bytes32 transferId);

    function getTransfer(bytes32 transferId) external view returns (Transfer memory transfer);

    function estimateGas(Route memory route) external view returns (uint256 gasEstimate);

    function getAvailableLiquidity(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view returns (uint256 liquidity);

    function getSuccessRate(
        uint256 srcChainId,
        uint256 dstChainId
    ) external view returns (uint256 successRate);

    function isHealthy() external view returns (bool healthy);

    function getTransferLimits(
        address token,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view returns (uint256 minAmount, uint256 maxAmount);
}