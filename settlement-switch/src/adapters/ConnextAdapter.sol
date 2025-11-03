// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ConnextAdapter is IBridgeAdapter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Router configuration
    struct Router {
        address routerAddress;      // Router address
        uint256 liquidity;          // Available liquidity
        uint256 lockedLiquidity;    // Currently locked liquidity
        uint256 feeRate;            // Router fee rate (basis points)
        uint256 reputation;         // Reputation score (0-100)
        uint256 successfulTxs;      // Number of successful transactions
        uint256 totalTxs;           // Total number of transactions
        bool isActive;              // Whether router is active
        bool isWhitelisted;         // Whether router is whitelisted
    }

    /// @notice Asset configuration for cross-chain transfers
    struct AssetConfig {
        address localAsset;         // Local asset address
        address adoptedAsset;       // Adopted asset address (canonical)
        uint256 cap;                // Maximum transfer cap
        uint256 liquidity;          // Available liquidity
        uint256 slippage;           // Maximum slippage (basis points)
        bool isStable;              // Whether asset is stable pool
        bool isActive;              // Whether asset is active
    }

    /// @notice Transfer state for Connext
    struct ConnextTransfer {
        bytes32 transferId;         // Transfer identifier
        address sender;             // Original sender
        address receiver;           // Final receiver
        address router;             // Selected router
        address asset;              // Asset being transferred
        uint256 amount;             // Transfer amount
        uint256 slippage;           // Accepted slippage
        uint256 originChain;        // Origin chain ID
        uint256 destinationChain;   // Destination chain ID
        uint256 nonce;              // Transfer nonce
        uint256 timestamp;          // Transfer timestamp
        bool isRouterLiquidity;     // Whether using router liquidity
        bool isCompleted;           // Whether transfer is completed
    }

    // State variables
    mapping(address => Router) public routers;
    mapping(uint256 => mapping(address => AssetConfig)) public assetConfigs; // chainId => asset => config
    mapping(bytes32 => Transfer) public transfers;
    mapping(bytes32 => ConnextTransfer) public connextTransfers;
    
    address[] public activeRouters;
    bytes32[] public transferHistory;
    uint256 public transferNonce;
    
    uint256 public totalTransfers;
    uint256 public successfulTransfers;
    uint256 public totalVolume;
    uint256 public lastHealthCheck;
    bool public healthyStatus = true;

    /// @notice Bridge configuration
    struct BridgeConfig {
        uint256 baseFee;            // Base fee in Wei
        uint256 feePercentage;      // Fee percentage in basis points
        uint256 minTransferAmount;  // Minimum transfer amount
        uint256 maxTransferAmount;  // Maximum transfer amount
        uint256 avgCompletionTime;  // Average completion time
        uint256 auctionPeriod;      // Router auction period
        uint256 maxSlippage;        // Maximum allowed slippage
        bool isActive;              // Whether bridge is active
    }

    BridgeConfig public bridgeConfig;

    // Events
    event RouterAdded(address indexed router, uint256 liquidity);
    event RouterLiquidityUpdated(address indexed router, uint256 newLiquidity);
    event TransferPrepared(bytes32 indexed transferId, address indexed router);
    event TransferFulfilled(bytes32 indexed transferId, address indexed router);
    event AssetConfigUpdated(uint256 indexed chainId, address indexed asset, AssetConfig config);

    // Errors
    error UnsupportedRoute();
    error InsufficientRouterLiquidity();
    error TransferAmountTooLow();
    error TransferAmountTooHigh();
    error BridgeInactive();
    error NoActiveRouters();
    error SlippageTooHigh();
    error AssetNotSupported();
    error RouterNotActive();
    error TransferExpired();

    constructor() Ownable(msg.sender) {
        _initializeConfig();
        _initializeAssetConfigs();
        _initializeRouters();
    }

    function _initializeConfig() internal {
        bridgeConfig = BridgeConfig({
            baseFee: 0.001 ether,       // Moderate base fee
            feePercentage: 5,           // 0.05% fee
            minTransferAmount: 1 ether, // 1 token minimum
            maxTransferAmount: 100000 ether, // 100k maximum
            avgCompletionTime: 600,     // 10 minutes average
            auctionPeriod: 300,         // 5 minutes auction
            maxSlippage: 300,           // 3% maximum slippage
            isActive: true
        });
    }

    function _initializeAssetConfigs() internal {
        // ETH configurations
        address eth = address(0); // Native ETH
        
        assetConfigs[11155111][eth] = AssetConfig({
            localAsset: eth,
            adoptedAsset: eth,
            cap: 100000 ether, // 100k ETH cap
            liquidity: 50000 ether, // 50k ETH liquidity
            slippage: 100, // 1% max slippage for ETH
            isStable: false,
            isActive: true
        });

        assetConfigs[421614][eth] = AssetConfig({
            localAsset: eth,
            adoptedAsset: eth,
            cap: 80000 ether, // 80k ETH cap
            liquidity: 40000 ether, // 40k ETH liquidity
            slippage: 100,
            isStable: false,
            isActive: true
        });

        assetConfigs[80001][eth] = AssetConfig({
            localAsset: eth,
            adoptedAsset: eth,
            cap: 60000 ether, // 60k ETH cap
            liquidity: 30000 ether, // 30k ETH liquidity
            slippage: 100,
            isStable: false,
            isActive: true
        });

        // USDC configurations
        address usdc = address(0x1);
        
        assetConfigs[11155111][usdc] = AssetConfig({
            localAsset: usdc,
            adoptedAsset: usdc,
            cap: 10000000 ether, // 10M USDC cap
            liquidity: 5000000 ether, // 5M USDC liquidity
            slippage: 50, // 0.5% max slippage for stable
            isStable: true,
            isActive: true
        });

        assetConfigs[421614][usdc] = AssetConfig({
            localAsset: usdc,
            adoptedAsset: usdc,
            cap: 8000000 ether, // 8M USDC cap
            liquidity: 4000000 ether, // 4M USDC liquidity
            slippage: 50,
            isStable: true,
            isActive: true
        });

        assetConfigs[80001][usdc] = AssetConfig({
            localAsset: usdc,
            adoptedAsset: usdc,
            cap: 6000000 ether, // 6M USDC cap
            liquidity: 3000000 ether, // 3M USDC liquidity
            slippage: 50,
            isStable: true,
            isActive: true
        });

        // WETH configurations
        address weth = address(0x2);
        
        assetConfigs[11155111][weth] = AssetConfig({
            localAsset: weth,
            adoptedAsset: weth,
            cap: 50000 ether, // 50k WETH cap
            liquidity: 25000 ether, // 25k WETH liquidity
            slippage: 100, // 1% max slippage for volatile
            isStable: false,
            isActive: true
        });

        assetConfigs[421614][weth] = AssetConfig({
            localAsset: weth,
            adoptedAsset: weth,
            cap: 40000 ether, // 40k WETH cap
            liquidity: 20000 ether, // 20k WETH liquidity
            slippage: 100,
            isStable: false,
            isActive: true
        });

        assetConfigs[80001][weth] = AssetConfig({
            localAsset: weth,
            adoptedAsset: weth,
            cap: 30000 ether, // 30k WETH cap
            liquidity: 15000 ether, // 15k WETH liquidity
            slippage: 100,
            isStable: false,
            isActive: true
        });
    }

    function _initializeRouters() internal {
        // Router 1 - High liquidity, premium router
        address router1 = address(0x201);
        routers[router1] = Router({
            routerAddress: router1,
            liquidity: 1000000 ether, // 1M tokens
            lockedLiquidity: 100000 ether, // 100k locked
            feeRate: 10, // 0.1%
            reputation: 98,
            successfulTxs: 9800,
            totalTxs: 10000,
            isActive: true,
            isWhitelisted: true
        });
        activeRouters.push(router1);

        // Router 2 - Medium liquidity, competitive fees
        address router2 = address(0x202);
        routers[router2] = Router({
            routerAddress: router2,
            liquidity: 500000 ether, // 500k tokens
            lockedLiquidity: 50000 ether, // 50k locked
            feeRate: 8, // 0.08%
            reputation: 95,
            successfulTxs: 9500,
            totalTxs: 10000,
            isActive: true,
            isWhitelisted: true
        });
        activeRouters.push(router2);

        // Router 3 - Lower liquidity, lowest fees
        address router3 = address(0x203);
        routers[router3] = Router({
            routerAddress: router3,
            liquidity: 250000 ether, // 250k tokens
            lockedLiquidity: 25000 ether, // 25k locked
            feeRate: 6, // 0.06%
            reputation: 92,
            successfulTxs: 9200,
            totalTxs: 10000,
            isActive: true,
            isWhitelisted: true
        });
        activeRouters.push(router3);
    }

    function getBridgeName() external pure override returns (string memory) {
        return "Connext Amarok";
    }

    function supportsRoute(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (bool supported) {
        // Connext supports same token transfers (or adopted assets)
        if (tokenIn != tokenOut) return false;
        
        // Check if both chains have active asset configs
        AssetConfig memory srcConfig = assetConfigs[srcChainId][tokenIn];
        AssetConfig memory dstConfig = assetConfigs[dstChainId][tokenOut];
        
        return srcConfig.isActive && dstConfig.isActive;
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

        AssetConfig memory dstConfig = assetConfigs[dstChainId][tokenOut];
        
        // Find best router for this transfer
        (address bestRouter, uint256 routerFee) = _findBestRouter(amount, tokenOut);
        
        // Calculate total fees
        uint256 bridgeFee = bridgeConfig.baseFee + routerFee;
        uint256 estimatedGas = _estimateGasCost(srcChainId, dstChainId);
        
        // Available liquidity from best router
        Router memory router = routers[bestRouter];
        uint256 availableLiquidity = router.liquidity - router.lockedLiquidity;
        
        // Success rate based on router reputation
        uint256 successRate = router.reputation;

        // Congestion based on router utilization
        uint256 utilizationRate = router.liquidity > 0 ? 
            (router.lockedLiquidity * 100) / router.liquidity : 100;
        uint256 congestionLevel = utilizationRate > 50 ? 
            ((utilizationRate - 50) * 100) / 50 : 0;

        return RouteMetrics({
            estimatedGasCost: estimatedGas,
            bridgeFee: bridgeFee,
            totalCostWei: estimatedGas + bridgeFee,
            estimatedTimeMinutes: bridgeConfig.avgCompletionTime / 60,
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
        if (!bridgeConfig.isActive) revert BridgeInactive();
        
        // Validate route
        if (!this.supportsRoute(route.tokenIn, route.tokenOut, route.srcChainId, route.dstChainId)) {
            revert UnsupportedRoute();
        }

        AssetConfig memory srcConfig = assetConfigs[route.srcChainId][route.tokenIn];
        AssetConfig memory dstConfig = assetConfigs[route.dstChainId][route.tokenOut];
        
        if (!srcConfig.isActive || !dstConfig.isActive) revert AssetNotSupported();
        if (route.amountIn < bridgeConfig.minTransferAmount) revert TransferAmountTooLow();
        if (route.amountIn > bridgeConfig.maxTransferAmount) revert TransferAmountTooHigh();

        // Find best router
        (address selectedRouter, uint256 routerFee) = _findBestRouter(route.amountIn, route.tokenOut);
        Router storage router = routers[selectedRouter];
        
        if (!router.isActive) revert RouterNotActive();
        
        uint256 availableLiquidity = router.liquidity - router.lockedLiquidity;
        if (availableLiquidity < route.amountIn) revert InsufficientRouterLiquidity();

        // Generate transfer ID
        transferNonce++;
        transferId = keccak256(abi.encodePacked(
            "CONNEXT", msg.sender, recipient, route.amountIn, 
            route.srcChainId, route.dstChainId, transferNonce
        ));

        // Handle token transfer
        if (route.tokenIn != address(0)) {
            IERC20(route.tokenIn).safeTransferFrom(msg.sender, address(this), route.amountIn);
        } else {
            require(msg.value >= route.amountIn + routerFee, "Insufficient ETH");
        }

        // Lock router liquidity
        router.lockedLiquidity += route.amountIn;

        // Create Connext transfer record
        connextTransfers[transferId] = ConnextTransfer({
            transferId: transferId,
            sender: msg.sender,
            receiver: recipient,
            router: selectedRouter,
            asset: route.tokenOut,
            amount: route.amountIn,
            slippage: dstConfig.slippage,
            originChain: route.srcChainId,
            destinationChain: route.dstChainId,
            nonce: transferNonce,
            timestamp: block.timestamp,
            isRouterLiquidity: true,
            isCompleted: false
        });

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

        // Simulate Connext two-phase process
        _simulateConnextTransfer(transferId, selectedRouter);

        emit TransferInitiated(transferId, msg.sender, recipient, route);
        emit TransferPrepared(transferId, selectedRouter);

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
        if (!this.supportsRoute(tokenIn, tokenOut, srcChainId, dstChainId)) {
            return 0;
        }
        
        // Return total available liquidity across all routers
        uint256 totalLiquidity = 0;
        for (uint256 i = 0; i < activeRouters.length; i++) {
            Router memory router = routers[activeRouters[i]];
            if (router.isActive) {
                totalLiquidity += (router.liquidity - router.lockedLiquidity);
            }
        }
        
        return totalLiquidity;
    }

    function getSuccessRate(
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 successRate) {
        // Connext has high success rate due to router network
        return 96;
    }

    function isHealthy() external view override returns (bool healthy) {
        return healthyStatus && bridgeConfig.isActive && activeRouters.length > 0;
    }

    function getTransferLimits(
        address token,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 minAmount, uint256 maxAmount) {
        if (!this.supportsRoute(token, token, srcChainId, dstChainId)) {
            return (0, 0);
        }
        
        AssetConfig memory dstConfig = assetConfigs[dstChainId][token];
        uint256 availableLiquidity = this.getAvailableLiquidity(token, token, srcChainId, dstChainId);
        
        uint256 dynamicMax = availableLiquidity < dstConfig.cap ? availableLiquidity : dstConfig.cap;
        dynamicMax = dynamicMax < bridgeConfig.maxTransferAmount ? dynamicMax : bridgeConfig.maxTransferAmount;
        
        return (bridgeConfig.minTransferAmount, dynamicMax);
    }

    // Internal functions

    function _estimateGasCost(uint256 srcChainId, uint256 dstChainId) internal pure returns (uint256 gasCost) {
        // Connext has moderate gas costs
        return 0.002 ether;
    }

    function _findBestRouter(uint256 amount, address token) internal view returns (address router, uint256 fee) {
        uint256 bestScore = 0;
        address bestRouter = activeRouters[0];
        uint256 bestFee = type(uint256).max;
        
        for (uint256 i = 0; i < activeRouters.length; i++) {
            Router memory r = routers[activeRouters[i]];
            if (!r.isActive || !r.isWhitelisted) continue;
            
            uint256 availableLiquidity = r.liquidity - r.lockedLiquidity;
            if (availableLiquidity < amount) continue;
            
            uint256 routerFee = (amount * r.feeRate) / 10000;
            
            // Score based on reputation, liquidity, and fees
            uint256 score = r.reputation + (availableLiquidity / 1000 ether) - (routerFee / 0.001 ether);
            
            if (score > bestScore || (score == bestScore && routerFee < bestFee)) {
                bestScore = score;
                bestRouter = activeRouters[i];
                bestFee = routerFee;
            }
        }
        
        return (bestRouter, bestFee);
    }

    function _simulateConnextTransfer(bytes32 transferId, address routerAddress) internal {
        transfers[transferId].status = TransferStatus.CONFIRMED;
        
        Router storage router = routers[routerAddress];
        
        // Success rate based on router reputation
        bool success = (uint256(keccak256(abi.encodePacked(transferId, block.timestamp))) % 100) < router.reputation;
        
        if (success) {
            connextTransfers[transferId].isCompleted = true;
            transfers[transferId].status = TransferStatus.COMPLETED;
            transfers[transferId].completedAt = block.timestamp + bridgeConfig.avgCompletionTime;
            
            // Update router stats
            router.successfulTxs++;
            router.totalTxs++;
            router.reputation = (router.successfulTxs * 100) / router.totalTxs;
            
            // Release locked liquidity
            router.lockedLiquidity -= connextTransfers[transferId].amount;
            
            successfulTransfers++;
            emit TransferCompleted(transferId, transfers[transferId].route.amountOut, 0, bridgeConfig.avgCompletionTime);
            emit TransferFulfilled(transferId, routerAddress);
        } else {
            transfers[transferId].status = TransferStatus.FAILED;
            router.totalTxs++;
            router.reputation = (router.successfulTxs * 100) / router.totalTxs;
            
            // Release locked liquidity on failure
            router.lockedLiquidity -= connextTransfers[transferId].amount;
            
            emit TransferFailed(transferId, "Router fulfillment failed");
        }
    }

    // Admin functions

    function updateConfig(BridgeConfig memory newConfig) external onlyOwner {
        bridgeConfig = newConfig;
    }

    function updateRouter(address routerAddress, Router memory router) external onlyOwner {
        bool isNewRouter = !routers[routerAddress].isActive;
        routers[routerAddress] = router;
        
        if (isNewRouter && router.isActive) {
            activeRouters.push(routerAddress);
            emit RouterAdded(routerAddress, router.liquidity);
        }
    }

    function updateAssetConfig(
        uint256 chainId,
        address asset,
        AssetConfig memory config
    ) external onlyOwner {
        assetConfigs[chainId][asset] = config;
        emit AssetConfigUpdated(chainId, asset, config);
    }

    function updateRouterLiquidity(address routerAddress, uint256 newLiquidity) external onlyOwner {
        routers[routerAddress].liquidity = newLiquidity;
        emit RouterLiquidityUpdated(routerAddress, newLiquidity);
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

    function getRouter(address routerAddress) external view returns (Router memory router) {
        return routers[routerAddress];
    }

    function getAssetConfig(uint256 chainId, address asset) external view returns (AssetConfig memory config) {
        return assetConfigs[chainId][asset];
    }

    function getConnextTransfer(bytes32 transferId) external view returns (ConnextTransfer memory transfer) {
        return connextTransfers[transferId];
    }

    function getActiveRouters() external view returns (address[] memory) {
        return activeRouters;
    }

    receive() external payable {}
}