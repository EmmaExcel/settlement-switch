// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract HopProtocolAdapter is IBridgeAdapter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Hop bridge configuration for each token
    struct HopBridge {
        address l1Token;            // L1 token address
        address l2Token;            // L2 token address
        address hopToken;           // Hop token (hToken) address
        uint256 liquidityPool;      // Available liquidity in pool
        uint256 bondingCurveRate;   // Bonding curve rate for pricing
        bool isActive;              // Whether bridge is active
    }

    /// @notice AMM pool for Hop tokens
    struct AmmPool {
        uint256 hopTokenReserve;    // Hop token reserve
        uint256 canonicalReserve;   // Canonical token reserve
        uint256 totalLiquidity;     // Total liquidity tokens
        uint256 feeRate;            // Fee rate in basis points
    }

    /// @notice Supported routes and their configurations
    mapping(uint256 => mapping(address => HopBridge)) public hopBridges; // chainId => token => bridge
    mapping(uint256 => mapping(address => AmmPool)) public ammPools;     // chainId => token => pool
    mapping(bytes32 => Transfer) public transfers;
    bytes32[] public transferHistory;

    /// @notice Bridge performance metrics
    uint256 public totalTransfers;
    uint256 public successfulTransfers;
    uint256 public totalVolume;
    uint256 public lastHealthCheck;
    bool public healthyStatus = true;

    /// @notice Bridge configuration
    struct BridgeConfig {
        uint256 baseFee;            // Base fee in Wei
        uint256 feePercentage;      // Fee percentage in basis points (lower than LayerZero)
        uint256 minTransferAmount;  // Minimum transfer amount
        uint256 maxTransferAmount;  // Maximum transfer amount
        uint256 avgCompletionTime;  // Average completion time (faster than LayerZero)
        uint256 bondingPeriod;      // Bonding period for L1 exits
        bool isActive;              // Whether bridge is active
    }

    BridgeConfig public config;

    // Events
    event HopBridgeAdded(uint256 indexed chainId, address indexed token, HopBridge bridge);
    event LiquidityUpdated(uint256 indexed chainId, address indexed token, uint256 newLiquidity);
    event AmmSwap(address indexed token, uint256 amountIn, uint256 amountOut, bool hopToCanonical);

    // Errors
    error UnsupportedRoute();
    error InsufficientLiquidity();
    error TransferAmountTooLow();
    error TransferAmountTooHigh();
    error BridgeInactive();
    error SlippageTooHigh();

    constructor() Ownable(msg.sender) {
        _initializeConfig();
        _initializeHopBridges();
    }

    function _initializeConfig() internal {
        config = BridgeConfig({
            baseFee: 0.001 ether,       // Lower base fee than LayerZero
            feePercentage: 4,           // 0.04% - competitive fee
            minTransferAmount: 1 ether, // Lower minimum
            maxTransferAmount: 50000 ether, // Lower maximum due to liquidity constraints
            avgCompletionTime: 300,     // 5 minutes - much faster
            bondingPeriod: 86400,       // 24 hours for L1 exits
            isActive: true
        });
    }

    function _initializeHopBridges() internal {
        // USDC bridges
        address usdc = address(0x1); // Mock USDC address
        
        // Ethereum Sepolia USDC bridge
        hopBridges[11155111][usdc] = HopBridge({
            l1Token: usdc,
            l2Token: usdc,
            hopToken: address(0x11), // hUSDC
            liquidityPool: 500000 ether, // 500k USDC
            bondingCurveRate: 9950, // 99.5% rate (0.5% spread)
            isActive: true
        });

        // Arbitrum Sepolia USDC bridge
        hopBridges[421614][usdc] = HopBridge({
            l1Token: usdc,
            l2Token: usdc,
            hopToken: address(0x11),
            liquidityPool: 300000 ether, // 300k USDC
            bondingCurveRate: 9960, // 99.6% rate
            isActive: true
        });

        // Polygon Mumbai USDC bridge
        hopBridges[80001][usdc] = HopBridge({
            l1Token: usdc,
            l2Token: usdc,
            hopToken: address(0x11),
            liquidityPool: 200000 ether, // 200k USDC
            bondingCurveRate: 9940, // 99.4% rate
            isActive: true
        });

        // Initialize AMM pools
        _initializeAmmPools(usdc);

        // ETH bridges
        address weth = address(0x2); // Mock WETH address
        
        hopBridges[11155111][weth] = HopBridge({
            l1Token: weth,
            l2Token: weth,
            hopToken: address(0x22), // hETH
            liquidityPool: 1000 ether, // 1k ETH
            bondingCurveRate: 9970, // 99.7% rate
            isActive: true
        });

        hopBridges[421614][weth] = HopBridge({
            l1Token: weth,
            l2Token: weth,
            hopToken: address(0x22),
            liquidityPool: 800 ether, // 800 ETH
            bondingCurveRate: 9975, // 99.75% rate
            isActive: true
        });

        hopBridges[80001][weth] = HopBridge({
            l1Token: weth,
            l2Token: weth,
            hopToken: address(0x22),
            liquidityPool: 600 ether, // 600 ETH
            bondingCurveRate: 9965, // 99.65% rate
            isActive: true
        });

        _initializeAmmPools(weth);
    }

    function _initializeAmmPools(address token) internal {
        // Ethereum Sepolia pool
        ammPools[11155111][token] = AmmPool({
            hopTokenReserve: 100000 ether,
            canonicalReserve: 100000 ether,
            totalLiquidity: 100000 ether,
            feeRate: 4 // 0.04%
        });

        // Arbitrum Sepolia pool
        ammPools[421614][token] = AmmPool({
            hopTokenReserve: 60000 ether,
            canonicalReserve: 60000 ether,
            totalLiquidity: 60000 ether,
            feeRate: 4
        });

        // Polygon Mumbai pool
        ammPools[80001][token] = AmmPool({
            hopTokenReserve: 40000 ether,
            canonicalReserve: 40000 ether,
            totalLiquidity: 40000 ether,
            feeRate: 4
        });
    }

    function getBridgeName() external pure override returns (string memory) {
        return "Hop Protocol";
    }

    function supportsRoute(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (bool supported) {
        // Hop supports same token transfers across supported chains
        if (tokenIn != tokenOut) return false;
        
        // Check if both chains have active bridges for this token
        HopBridge memory srcBridge = hopBridges[srcChainId][tokenIn];
        HopBridge memory dstBridge = hopBridges[dstChainId][tokenOut];
        
        return srcBridge.isActive && dstBridge.isActive;
    }

    function getRouteMetrics(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (RouteMetrics memory metrics) {
        if (!this.supportsRoute(tokenIn, tokenOut, srcChainId, dstChainId)) {
            revert UnsupportedRoute();
        }

        HopBridge memory dstBridge = hopBridges[dstChainId][tokenOut];
        AmmPool memory dstPool = ammPools[dstChainId][tokenOut];

        // Calculate Hop-specific fees (AMM swap + bridge fee)
        uint256 ammFee = _calculateAmmFee(amount, dstPool);
        uint256 bridgeFee = config.baseFee + (amount * config.feePercentage / 10000);
        uint256 totalBridgeFee = ammFee + bridgeFee;

        // Estimate gas cost (lower than LayerZero due to optimizations)
        uint256 estimatedGas = _estimateGasCost(srcChainId, dstChainId);
        
        // Available liquidity is the minimum of bridge liquidity and AMM liquidity
        uint256 availableLiquidity = dstBridge.liquidityPool < dstPool.canonicalReserve ? 
            dstBridge.liquidityPool : dstPool.canonicalReserve;
        
        // Higher success rate due to faster finality
        uint256 successRate = totalTransfers > 0 ? 
            (successfulTransfers * 100) / totalTransfers : 98;

        // Lower congestion due to dedicated liquidity pools
        uint256 utilizationRate = availableLiquidity > 0 ? (amount * 100) / availableLiquidity : 100;
        uint256 congestionLevel = utilizationRate > 70 ? 
            ((utilizationRate - 70) * 100) / 30 : 0;

        return RouteMetrics({
            estimatedGasCost: estimatedGas,
            bridgeFee: totalBridgeFee,
            totalCostWei: estimatedGas + totalBridgeFee,
            estimatedTimeMinutes: config.avgCompletionTime / 60,
            liquidityAvailable: availableLiquidity,
            successRate: successRate,
            congestionLevel: congestionLevel
        });
    }

    function executeBridge(
        Route memory route,
        address recipient,
        bytes calldata permitData
    ) external payable override nonReentrant returns (bytes32 transferId) {
        if (!config.isActive) revert BridgeInactive();
        
        // Validate route
        if (!this.supportsRoute(route.tokenIn, route.tokenOut, route.srcChainId, route.dstChainId)) {
            revert UnsupportedRoute();
        }

        if (route.amountIn < config.minTransferAmount) revert TransferAmountTooLow();
        if (route.amountIn > config.maxTransferAmount) revert TransferAmountTooHigh();

        // Check liquidity
        HopBridge memory dstBridge = hopBridges[route.dstChainId][route.tokenOut];
        AmmPool memory dstPool = ammPools[route.dstChainId][route.tokenOut];
        
        uint256 availableLiquidity = dstBridge.liquidityPool < dstPool.canonicalReserve ? 
            dstBridge.liquidityPool : dstPool.canonicalReserve;
            
        if (availableLiquidity < route.amountIn) revert InsufficientLiquidity();

        // Generate transfer ID
        transferId = keccak256(abi.encodePacked(
            "HOP", msg.sender, recipient, route.amountIn, 
            route.srcChainId, route.dstChainId, block.timestamp
        ));

        // Handle token transfer
        if (route.tokenIn != address(0)) {
            IERC20(route.tokenIn).safeTransferFrom(msg.sender, address(this), route.amountIn);
        } else {
            require(msg.value >= route.amountIn, "Insufficient ETH");
        }

        // Simulate Hop's two-step process:
        // 1. Swap canonical token for hToken on source chain
        // 2. Send hToken to destination and swap back to canonical

        // Update liquidity pools
        _updateLiquidityAfterTransfer(route.tokenIn, route.tokenOut, route.amountIn, route.srcChainId, route.dstChainId);

        // Create transfer record
        transfers[transferId] = Transfer({
            transferId: transferId,
            sender: msg.sender,
            recipient: recipient,
            route: route,
            status: TransferStatus.PENDING,
            initiatedAt: block.timestamp,
            completedAt: 0
        });

        transferHistory.push(transferId);
        totalTransfers++;
        totalVolume += route.amountIn;

        // Simulate faster completion than LayerZero
        _simulateHopCompletion(transferId);

        emit TransferInitiated(transferId, msg.sender, recipient, route);

        return transferId;
    }

    function getTransfer(bytes32 transferId) external view override returns (Transfer memory transfer) {
        return transfers[transferId];
    }

    function estimateGas(Route memory route) external view override returns (uint256 gasEstimate) {
        return _estimateGasCost(route.srcChainId, route.dstChainId);
    }

    function getAvailableLiquidity(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 liquidity) {
        if (tokenIn != tokenOut) return 0;
        
        HopBridge memory dstBridge = hopBridges[dstChainId][tokenOut];
        AmmPool memory dstPool = ammPools[dstChainId][tokenOut];
        
        return dstBridge.liquidityPool < dstPool.canonicalReserve ? 
            dstBridge.liquidityPool : dstPool.canonicalReserve;
    }

    function getSuccessRate(
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 successRate) {
        // Hop has high success rates due to optimistic transfers
        if (srcChainId == 11155111 && dstChainId == 421614) return 99; // ETH -> ARB
        if (srcChainId == 11155111 && dstChainId == 80001) return 98;  // ETH -> MATIC
        if (srcChainId == 421614 && dstChainId == 80001) return 99;    // ARB -> MATIC
        return 98; // Default high success rate
    }

    function isHealthy() external view override returns (bool healthy) {
        return healthyStatus && config.isActive && (block.timestamp - lastHealthCheck < 1800); // 30 min
    }

    function getTransferLimits(
        address token,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 minAmount, uint256 maxAmount) {
        HopBridge memory srcBridge = hopBridges[srcChainId][token];
        HopBridge memory dstBridge = hopBridges[dstChainId][token];
        
        if (!srcBridge.isActive || !dstBridge.isActive) {
            return (0, 0);
        }
        
        // Max amount is limited by available liquidity
        uint256 maxLiquidity = dstBridge.liquidityPool;
        uint256 dynamicMax = maxLiquidity < config.maxTransferAmount ? maxLiquidity : config.maxTransferAmount;
        
        return (config.minTransferAmount, dynamicMax);
    }

    // Internal functions

    function _calculateAmmFee(uint256 amount, AmmPool memory pool) internal pure returns (uint256 fee) {
        // Simplified constant product AMM fee calculation
        return (amount * pool.feeRate) / 10000;
    }

    function _estimateGasCost(uint256 srcChainId, uint256 dstChainId) internal pure returns (uint256 gasCost) {
        // Hop has lower gas costs due to optimizations
        if (srcChainId == 11155111) { // From Ethereum
            if (dstChainId == 421614) return 0.002 ether; // To Arbitrum
            if (dstChainId == 80001) return 0.0025 ether; // To Polygon
        } else if (srcChainId == 421614) { // From Arbitrum
            if (dstChainId == 11155111) return 0.0008 ether; // To Ethereum
            if (dstChainId == 80001) return 0.0015 ether;    // To Polygon
        } else if (srcChainId == 80001) { // From Polygon
            if (dstChainId == 11155111) return 0.003 ether; // To Ethereum
            if (dstChainId == 421614) return 0.002 ether;   // To Arbitrum
        }
        return 0.002 ether; // Default
    }

    function _updateLiquidityAfterTransfer(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId
    ) internal {
        // Update source chain liquidity (increase)
        hopBridges[srcChainId][tokenIn].liquidityPool += amount;
        
        // Update destination chain liquidity (decrease)
        hopBridges[dstChainId][tokenOut].liquidityPool -= amount;
        
        // Update AMM pools
        AmmPool storage srcPool = ammPools[srcChainId][tokenIn];
        AmmPool storage dstPool = ammPools[dstChainId][tokenOut];
        
        // Simulate AMM swaps
        srcPool.canonicalReserve -= amount;
        srcPool.hopTokenReserve += amount;
        
        dstPool.hopTokenReserve -= amount;
        dstPool.canonicalReserve += amount;
    }

    function _simulateHopCompletion(bytes32 transferId) internal {
        transfers[transferId].status = TransferStatus.CONFIRMED;
        
        // Hop has higher success rate (98%)
        bool success = (uint256(keccak256(abi.encodePacked(transferId, block.timestamp))) % 100) < 98;
        
        if (success) {
            transfers[transferId].status = TransferStatus.COMPLETED;
            transfers[transferId].completedAt = block.timestamp + config.avgCompletionTime;
            successfulTransfers++;
            emit TransferCompleted(transferId, transfers[transferId].route.amountOut, 0, config.avgCompletionTime);
        } else {
            transfers[transferId].status = TransferStatus.FAILED;
            emit TransferFailed(transferId, "AMM slippage exceeded");
        }
    }

    // Admin functions

    function updateConfig(BridgeConfig memory newConfig) external onlyOwner {
        config = newConfig;
    }

    function updateHopBridge(
        uint256 chainId,
        address token,
        HopBridge memory bridge
    ) external onlyOwner {
        hopBridges[chainId][token] = bridge;
        emit HopBridgeAdded(chainId, token, bridge);
    }

    function updateAmmPool(
        uint256 chainId,
        address token,
        AmmPool memory pool
    ) external onlyOwner {
        ammPools[chainId][token] = pool;
    }

    function updateHealthStatus(bool healthy) external onlyOwner {
        healthyStatus = healthy;
        lastHealthCheck = block.timestamp;
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }

    function getBridgeStats() external view returns (
        uint256 _totalTransfers,
        uint256 _successfulTransfers,
        uint256 _totalVolume,
        uint256 _successRate
    ) {
        _totalTransfers = totalTransfers;
        _successfulTransfers = successfulTransfers;
        _totalVolume = totalVolume;
        _successRate = totalTransfers > 0 ? (successfulTransfers * 100) / totalTransfers : 0;
    }

    function getHopBridgeInfo(uint256 chainId, address token) external view returns (
        HopBridge memory bridge,
        AmmPool memory pool
    ) {
        return (hopBridges[chainId][token], ammPools[chainId][token]);
    }

    receive() external payable {}
}