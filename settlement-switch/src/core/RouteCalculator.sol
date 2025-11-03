// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract RouteCalculator is Ownable, ReentrancyGuard {


    struct ScoringWeights {
        uint256 costWeight;         // Weight for cost optimization (0-100)
        uint256 speedWeight;        // Weight for speed optimization (0-100)
        uint256 reliabilityWeight;  // Weight for reliability optimization (0-100)
        uint256 liquidityWeight;    // Weight for liquidity optimization (0-100)
    }


    struct CachedRoute {
        IBridgeAdapter.Route route;
        uint256 cachedAt;
        uint256 score;
        bool isValid;
    }

  
    struct BridgeMetrics {
        uint256 totalTransfers;     // Total number of transfers
        uint256 successfulTransfers; // Number of successful transfers
        uint256 totalVolume;        // Total volume transferred
        uint256 avgCompletionTime;  // Average completion time
        uint256 lastUpdateTime;     // Last metrics update timestamp
        bool isHealthy;             // Current health status
    }

    // Constants
    uint256 public constant MAX_ROUTES_PER_QUERY = 10;
    uint256 public constant DEFAULT_CACHE_TTL = 60; // 60 seconds
    uint256 public constant MAX_SLIPPAGE_BPS = 1000; // 10%
    uint256 public constant BASIS_POINTS = 10000;

    // State variables
    mapping(address => bool) public registeredAdapters;
    address[] public adapterList;
    mapping(address => BridgeMetrics) public bridgeMetrics;
    
    // Route caching
    mapping(bytes32 => CachedRoute) public routeCache;
    uint256 public routeCacheTtl = DEFAULT_CACHE_TTL;
    
    // Scoring weights for different routing modes
    mapping(IBridgeAdapter.RoutingMode => ScoringWeights) public scoringWeights;

    // Events
    event AdapterRegistered(address indexed adapter, string name);
    event AdapterRemoved(address indexed adapter);
    event RouteCalculated(
        bytes32 indexed routeHash,
        address indexed adapter,
        uint256 score,
        uint256 timestamp
    );
    event RouteCached(bytes32 indexed routeHash, uint256 ttl);
    event BridgeMetricsUpdated(address indexed adapter, BridgeMetrics metrics);

    // Errors
    error InvalidAdapter();
    error AdapterAlreadyRegistered();
    error AdapterNotRegistered();
    error InvalidScoringWeights();
    error NoValidRoutes();
    error InvalidCacheEntry();

    constructor() Ownable(msg.sender) {
        _initializeScoringWeights();
    }

    function _initializeScoringWeights() internal {
        // CHEAPEST mode: prioritize cost
        scoringWeights[IBridgeAdapter.RoutingMode.CHEAPEST] = ScoringWeights({
            costWeight: 60,
            speedWeight: 15,
            reliabilityWeight: 20,
            liquidityWeight: 5
        });

        // FASTEST mode: prioritize speed
        scoringWeights[IBridgeAdapter.RoutingMode.FASTEST] = ScoringWeights({
            costWeight: 10,
            speedWeight: 60,
            reliabilityWeight: 25,
            liquidityWeight: 5
        });

        // BALANCED mode: balanced approach
        scoringWeights[IBridgeAdapter.RoutingMode.BALANCED] = ScoringWeights({
            costWeight: 25,
            speedWeight: 25,
            reliabilityWeight: 30,
            liquidityWeight: 20
        });
    }

    function registerAdapter(address adapter) external onlyOwner {
        if (adapter == address(0)) revert InvalidAdapter();
        if (registeredAdapters[adapter]) revert AdapterAlreadyRegistered();

        registeredAdapters[adapter] = true;
        adapterList.push(adapter);

        // Initialize bridge metrics
        bridgeMetrics[adapter] = BridgeMetrics({
            totalTransfers: 0,
            successfulTransfers: 0,
            totalVolume: 0,
            avgCompletionTime: 0,
            lastUpdateTime: block.timestamp,
            isHealthy: true
        });

        emit AdapterRegistered(adapter, IBridgeAdapter(adapter).getBridgeName());
    }

    function removeAdapter(address adapter) external onlyOwner {
        if (!registeredAdapters[adapter]) revert AdapterNotRegistered();

        registeredAdapters[adapter] = false;
        
        // Remove from adapter list
        for (uint256 i = 0; i < adapterList.length; i++) {
            if (adapterList[i] == adapter) {
                adapterList[i] = adapterList[adapterList.length - 1];
                adapterList.pop();
                break;
            }
        }

        emit AdapterRemoved(adapter);
    }

    function findOptimalRoute(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences
    ) external view returns (IBridgeAdapter.Route memory route) {
        // Generate cache key
        bytes32 cacheKey = _generateCacheKey(
            tokenIn, tokenOut, amount, srcChainId, dstChainId, preferences
        );

        // Check cache first
        CachedRoute memory cached = routeCache[cacheKey];
        if (cached.isValid && (block.timestamp - cached.cachedAt) < routeCacheTtl) {
            return cached.route;
        }

        // Find all valid routes
        IBridgeAdapter.Route[] memory routes = _findAllValidRoutes(
            tokenIn, tokenOut, amount, srcChainId, dstChainId, preferences
        );

        if (routes.length == 0) revert NoValidRoutes();

        // Score and select best route
        uint256 bestScore = 0;
        uint256 bestIndex = 0;

        for (uint256 i = 0; i < routes.length; i++) {
            uint256 score = _calculateRouteScore(routes[i], preferences.mode);
            if (score > bestScore) {
                bestScore = score;
                bestIndex = i;
            }
        }

        return routes[bestIndex];
    }

    function findMultipleRoutes(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences,
        uint256 maxRoutes
    ) external view returns (IBridgeAdapter.Route[] memory routes) {
        // Find all valid routes
        IBridgeAdapter.Route[] memory allRoutes = _findAllValidRoutes(
            tokenIn, tokenOut, amount, srcChainId, dstChainId, preferences
        );

        if (allRoutes.length == 0) revert NoValidRoutes();

        // Limit to maxRoutes
        uint256 routeCount = allRoutes.length > maxRoutes ? maxRoutes : allRoutes.length;
        routes = new IBridgeAdapter.Route[](routeCount);

        // Calculate scores and sort
        uint256[] memory scores = new uint256[](allRoutes.length);
        for (uint256 i = 0; i < allRoutes.length; i++) {
            scores[i] = _calculateRouteScore(allRoutes[i], preferences.mode);
        }

        // Sort routes by score (descending)
        _quickSort(allRoutes, scores, 0, int256(allRoutes.length - 1));

        // Return top routes
        for (uint256 i = 0; i < routeCount; i++) {
            routes[i] = allRoutes[i];
        }

        return routes;
    }

    function _findAllValidRoutes(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences
    ) internal view returns (IBridgeAdapter.Route[] memory) {
        IBridgeAdapter.Route[] memory tempRoutes = new IBridgeAdapter.Route[](adapterList.length);
        uint256 validRouteCount = 0;

        for (uint256 i = 0; i < adapterList.length; i++) {
            address adapter = adapterList[i];
            
            // Skip if adapter is not healthy
            if (!bridgeMetrics[adapter].isHealthy) continue;

            IBridgeAdapter bridgeAdapter = IBridgeAdapter(adapter);
            
            // Check if adapter supports this route
            if (!bridgeAdapter.supportsRoute(tokenIn, tokenOut, srcChainId, dstChainId)) {
                continue;
            }

            // Get route metrics
            IBridgeAdapter.RouteMetrics memory metrics = bridgeAdapter.getRouteMetrics(
                tokenIn, tokenOut, amount, srcChainId, dstChainId
            );

            // Apply preference filters
            if (preferences.maxFeeWei > 0 && metrics.totalCostWei > preferences.maxFeeWei) {
                continue;
            }
            if (preferences.maxTimeMinutes > 0 && metrics.estimatedTimeMinutes > preferences.maxTimeMinutes) {
                continue;
            }

            // Check liquidity availability
            uint256 availableLiquidity = bridgeAdapter.getAvailableLiquidity(
                tokenIn, tokenOut, srcChainId, dstChainId
            );
            if (availableLiquidity < amount) continue;

            // Calculate expected output amount with slippage
            uint256 expectedOutput = _calculateExpectedOutput(amount, metrics, preferences.maxSlippageBps);

            // Create route
            tempRoutes[validRouteCount] = IBridgeAdapter.Route({
                adapter: adapter,
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: amount,
                amountOut: expectedOutput,
                srcChainId: srcChainId,
                dstChainId: dstChainId,
                metrics: metrics,
                adapterData: "",
                deadline: block.timestamp + (metrics.estimatedTimeMinutes * 60) + 300 // 5 min buffer
            });

            validRouteCount++;
        }

        // Create properly sized array
        IBridgeAdapter.Route[] memory validRoutes = new IBridgeAdapter.Route[](validRouteCount);
        for (uint256 i = 0; i < validRouteCount; i++) {
            validRoutes[i] = tempRoutes[i];
        }

        return validRoutes;
    }

    function _calculateRouteScore(
        IBridgeAdapter.Route memory route,
        IBridgeAdapter.RoutingMode mode
    ) internal view returns (uint256 score) {
        ScoringWeights memory weights = scoringWeights[mode];
        
        // Ensure weights don't exceed 100 to prevent overflow
        uint256 safeWeightSum = weights.costWeight + weights.speedWeight + 
                               weights.reliabilityWeight + weights.liquidityWeight;
        if (safeWeightSum == 0) return 0; // Prevent division by zero
        
        // Normalize metrics to 0-100 scale
        uint256 costScore = _normalizeCostScore(route.metrics.totalCostWei);
        uint256 speedScore = _normalizeSpeedScore(route.metrics.estimatedTimeMinutes);
        uint256 reliabilityScore = route.metrics.successRate > 100 ? 100 : route.metrics.successRate;
        uint256 liquidityScore = _normalizeLiquidityScore(route.metrics.liquidityAvailable, route.amountIn);

        // Calculate weighted score with overflow protection
        // Use smaller intermediate calculations to prevent overflow
        uint256 weightedSum = 0;
        
        // Add each component separately with bounds checking
        if (weights.costWeight > 0 && costScore > 0) {
            weightedSum += (costScore * weights.costWeight) / 100;
        }
        if (weights.speedWeight > 0 && speedScore > 0) {
            weightedSum += (speedScore * weights.speedWeight) / 100;
        }
        if (weights.reliabilityWeight > 0 && reliabilityScore > 0) {
            weightedSum += (reliabilityScore * weights.reliabilityWeight) / 100;
        }
        if (weights.liquidityWeight > 0 && liquidityScore > 0) {
            weightedSum += (liquidityScore * weights.liquidityWeight) / 100;
        }
        
        score = weightedSum;

        // Apply congestion penalty with bounds checking
        if (route.metrics.congestionLevel > 50 && route.metrics.congestionLevel <= 100) {
            uint256 penalty = route.metrics.congestionLevel / 2;
            if (penalty < 100) {
                score = (score * (100 - penalty)) / 100;
            } else {
                score = 0; // Maximum penalty
            }
        }

        return score;
    }

    function _normalizeCostScore(uint256 cost) internal pure returns (uint256 score) {
        // Assume max reasonable cost is 0.1 ETH (100000000000000000 Wei)
        uint256 maxCost = 100000000000000000;
        
        // Handle edge cases
        if (cost == 0) return 100; // Free transactions get maximum score
        if (cost >= maxCost) return 0; // Expensive transactions get minimum score
        
        // Safe calculation to prevent overflow
        // Use (maxCost - cost) * 100 / maxCost to avoid precision loss
        return ((maxCost - cost) * 100) / maxCost;
    }

    function _normalizeSpeedScore(uint256 timeMinutes) internal pure returns (uint256 score) {
        // Assume max reasonable time is 60 minutes
        uint256 maxTime = 60;
        
        // Handle edge cases
        if (timeMinutes == 0) return 100; // Instant transactions get maximum score
        if (timeMinutes >= maxTime) return 0; // Slow transactions get minimum score
        
        // Safe calculation to prevent overflow
        // Use (maxTime - timeMinutes) * 100 / maxTime to avoid precision loss
        return ((maxTime - timeMinutes) * 100) / maxTime;
    }

    function _normalizeLiquidityScore(
        uint256 availableLiquidity,
        uint256 requiredAmount
    ) internal pure returns (uint256 score) {
        // Handle edge cases
        if (requiredAmount == 0) return 100; // No liquidity needed = perfect score
        if (availableLiquidity == 0) return 0; // No liquidity available = worst score
        if (availableLiquidity < requiredAmount) return 0; // Insufficient liquidity
        
        // Safe calculation to prevent overflow
        // Calculate utilization ratio as percentage (0-100)
        uint256 utilizationRatio = (requiredAmount * 100) / availableLiquidity;
        
        // Higher available liquidity relative to required amount = higher score
        if (utilizationRatio <= 10) return 100;  // Using ≤10% of liquidity
        if (utilizationRatio <= 25) return 80;   // Using ≤25% of liquidity
        if (utilizationRatio <= 50) return 60;   // Using ≤50% of liquidity
        if (utilizationRatio <= 75) return 40;   // Using ≤75% of liquidity
        return 20; // Using >75% of liquidity
    }

    function _calculateExpectedOutput(
        uint256 amountIn,
        IBridgeAdapter.RouteMetrics memory metrics,
        uint256 maxSlippageBps
    ) internal pure returns (uint256 expectedOutput) {
        // For simplicity, assume 1:1 token ratio minus fees and slippage
        uint256 afterFees = amountIn - metrics.bridgeFee;
        
        // Apply maximum slippage
        uint256 slippage = maxSlippageBps > 0 ? maxSlippageBps : 50; // Default 0.5%
        expectedOutput = afterFees * (BASIS_POINTS - slippage) / BASIS_POINTS;
        
        return expectedOutput;
    }

    function _quickSort(
        IBridgeAdapter.Route[] memory routes,
        uint256[] memory scores,
        int256 left,
        int256 right
    ) internal pure {
        if (left < right) {
            int256 pivotIndex = _partition(routes, scores, left, right);
            _quickSort(routes, scores, left, pivotIndex - 1);
            _quickSort(routes, scores, pivotIndex + 1, right);
        }
    }

    function _partition(
        IBridgeAdapter.Route[] memory routes,
        uint256[] memory scores,
        int256 left,
        int256 right
    ) internal pure returns (int256) {
        uint256 pivot = scores[uint256(right)];
        int256 i = left - 1;

        for (int256 j = left; j < right; j++) {
            if (scores[uint256(j)] >= pivot) { // Descending order
                i++;
                // Swap routes
                IBridgeAdapter.Route memory tempRoute = routes[uint256(i)];
                routes[uint256(i)] = routes[uint256(j)];
                routes[uint256(j)] = tempRoute;
                
                // Swap scores
                uint256 tempScore = scores[uint256(i)];
                scores[uint256(i)] = scores[uint256(j)];
                scores[uint256(j)] = tempScore;
            }
        }

        // Swap pivot
        IBridgeAdapter.Route memory tempRoute = routes[uint256(i + 1)];
        routes[uint256(i + 1)] = routes[uint256(right)];
        routes[uint256(right)] = tempRoute;
        
        uint256 tempScore = scores[uint256(i + 1)];
        scores[uint256(i + 1)] = scores[uint256(right)];
        scores[uint256(right)] = tempScore;

        return i + 1;
    }

    function _generateCacheKey(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            tokenIn, tokenOut, amount, srcChainId, dstChainId,
            preferences.mode, preferences.maxSlippageBps, preferences.maxFeeWei
        ));
    }

    function cacheRoute(
        IBridgeAdapter.Route memory route,
        IBridgeAdapter.RoutePreferences memory preferences
    ) external {
        bytes32 cacheKey = _generateCacheKey(
            route.tokenIn, route.tokenOut, route.amountIn,
            route.srcChainId, route.dstChainId, preferences
        );

        uint256 score = _calculateRouteScore(route, preferences.mode);

        routeCache[cacheKey] = CachedRoute({
            route: route,
            cachedAt: block.timestamp,
            score: score,
            isValid: true
        });

        emit RouteCached(cacheKey, routeCacheTtl);
    }

    function updateBridgeMetrics(
        address adapter,
        bool successful,
        uint256 completionTime,
        uint256 volume
    ) external {
        if (!registeredAdapters[adapter]) revert AdapterNotRegistered();

        BridgeMetrics storage metrics = bridgeMetrics[adapter];
        
        metrics.totalTransfers++;
        if (successful) {
            metrics.successfulTransfers++;
        }
        
        metrics.totalVolume += volume;
        
        // Update average completion time (exponential moving average)
        if (metrics.avgCompletionTime == 0) {
            metrics.avgCompletionTime = completionTime;
        } else {
            metrics.avgCompletionTime = (metrics.avgCompletionTime * 9 + completionTime) / 10;
        }
        
        metrics.lastUpdateTime = block.timestamp;
        
        // Update health status based on success rate
        uint256 successRate = (metrics.successfulTransfers * 100) / metrics.totalTransfers;
        metrics.isHealthy = successRate >= 90; // 90% success rate threshold

        emit BridgeMetricsUpdated(adapter, metrics);
    }

    function updateScoringWeights(
        IBridgeAdapter.RoutingMode mode,
        ScoringWeights memory weights
    ) external onlyOwner {
        // Validate individual weights are within bounds (0-100)
        if (weights.costWeight > 100 || weights.speedWeight > 100 || 
            weights.reliabilityWeight > 100 || weights.liquidityWeight > 100) {
            revert InvalidScoringWeights();
        }
        
        // Validate weights sum to 100 to prevent overflow in calculations
        uint256 totalWeight = weights.costWeight + weights.speedWeight + 
                             weights.reliabilityWeight + weights.liquidityWeight;
        if (totalWeight != 100) revert InvalidScoringWeights();

        scoringWeights[mode] = weights;
    }

    function updateRouteCacheTtl(uint256 newTtl) external onlyOwner {
        routeCacheTtl = newTtl;
    }

    function getRegisteredAdapters() external view returns (address[] memory adapters) {
        return adapterList;
    }

    function getBridgeMetrics(address adapter) external view returns (BridgeMetrics memory metrics) {
        return bridgeMetrics[adapter];
    }
}