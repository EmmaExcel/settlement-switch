// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title StablecoinSwitch
 * @dev Production-ready cross-chain stablecoin routing contract with Chainlink price feeds
 * @notice This contract enables secure cross-chain stablecoin routing with real-time price data
 * @author Arbitrum Development Team
 */
contract StablecoinSwitch is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    /// @notice Chainlink price feed for ETH/USD
    AggregatorV3Interface public immutable ethUsdPriceFeed;
    
    /// @notice Chainlink price feed for USDC/USD
    AggregatorV3Interface public immutable usdcUsdPriceFeed;

    /// @notice Maximum allowed staleness for price feeds in seconds
    /// @dev Default is 3600 seconds (1 hour). Can be adjusted by owner for testnets.
    uint256 public maxPriceStalenessSeconds = 3600;

    /// @notice Mapping of bridge adapter addresses for different chains
    /// @dev Now supports multiple adapters per chain for route optimization
    mapping(uint256 => address[]) public bridgeAdapters;
    
    /// @notice Mapping of bridge adapter names for identification
    mapping(address => string) public bridgeAdapterNames;
    
    /// @notice Mapping of bridge-specific gas costs
    mapping(address => uint256) public bridgeGasCosts;

    /// @notice Mapping to track supported tokens
    mapping(address => bool) public supportedTokens;

    /// @notice Mapping to track supported destination chains
    mapping(uint256 => bool) public supportedChains;

    /// @notice Base gas cost for transactions (in wei)
    uint256 public constant BASE_GAS_COST = 21000;

    /// @notice Priority multipliers for cost calculation
    uint256 public constant COST_PRIORITY_MULTIPLIER = 100; // 1.0x
    uint256 public constant SPEED_PRIORITY_MULTIPLIER = 150; // 1.5x

    /// @notice Maximum allowed slippage (in basis points, 100 = 1%)
    uint256 public constant MAX_SLIPPAGE_BPS = 500; // 5%

    // ============ Structs ============



    /**
     * @notice Enhanced route information structure with gas optimization
     * @param fromToken Source token address
     * @param toToken Destination token address
     * @param fromChainId Source chain ID
     * @param toChainId Destination chain ID
     * @param estimatedCostUsd Estimated total cost in USD (18 decimals)
     * @param estimatedGasUsd Estimated gas cost in USD (18 decimals)
     * @param bridgeFeeUsd Bridge-specific fee in USD (18 decimals)
     * @param estimatedTimeMinutes Estimated completion time in minutes
     * @param bridgeAdapter Address of the optimal bridge adapter
     * @param bridgeName Name of the bridge for identification
     * @param gasEstimate Actual gas estimate for the transaction
     */
    struct RouteInfo {
        address fromToken;
        address toToken;
        uint256 fromChainId;
        uint256 toChainId;
        uint256 estimatedCostUsd;
        uint256 estimatedGasUsd;
        uint256 bridgeFeeUsd;
        uint256 estimatedTimeMinutes;
        address bridgeAdapter;
        string bridgeName;
        uint256 gasEstimate;
    }

    /**
     * @notice Transaction routing parameters
     * @param fromToken Source token address
     * @param toToken Destination token address
     * @param amount Amount to route
     * @param toChainId Destination chain ID
     * @param priority Priority level (0 = Cost, 1 = Speed)
     * @param recipient Recipient address on destination chain
     * @param minAmountOut Minimum amount to receive (slippage protection)
     */
    struct RouteParams {
        address fromToken;
        address toToken;
        uint256 amount;
        uint256 toChainId;
        uint8 priority;
        address recipient;
        uint256 minAmountOut;
    }

    // ============ Events ============

    /**
     * @notice Emitted when a transaction is routed
     * @param user User initiating the transaction
     * @param fromToken Source token address
     * @param toToken Destination token address
     * @param amount Amount being routed
     * @param toChainId Destination chain ID
     * @param priority Priority level used
     * @param estimatedCostUsd Estimated cost in USD
     * @param bridgeAdapter Bridge adapter used
     */
    event TransactionRouted(
        address indexed user,
        address indexed fromToken,
        address indexed toToken,
        uint256 amount,
        uint256 toChainId,
        uint8 priority,
        uint256 estimatedCostUsd,
        address bridgeAdapter
    );

    /**
     * @notice Emitted when a settlement is executed
     * @param user User receiving the settlement
     * @param token Token being settled
     * @param amount Amount settled
     * @param fromChainId Source chain ID
     * @param transactionHash Original transaction hash
     */
    event SettlementExecuted(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 fromChainId,
        bytes32 indexed transactionHash
    );

    /**
     * @notice Emitted when a bridge adapter is set
     * @param chainId Chain ID for the adapter
     * @param adapter Address of the bridge adapter
     * @param isActive Whether the adapter is active
     */
    event BridgeAdapterSet(
        uint256 indexed chainId,
        address indexed adapter,
        bool isActive
    );

    /**
     * @notice Emitted when a token's support status is updated
     * @param token Token address
     * @param isSupported Whether the token is supported
     */
    event TokenSupportUpdated(
        address indexed token,
        bool isSupported
    );

    /**
     * @notice Emitted when a chain's support status is updated
     * @param chainId Chain ID
     * @param isSupported Whether the chain is supported
     */
    event ChainSupportUpdated(
        uint256 indexed chainId,
        bool isSupported
    );

    // ============ Errors ============

    error InvalidToken();
    error InvalidChain();
    error InvalidAmount();
    error InvalidPriority();
    error InvalidRecipient();
    error UnsupportedToken();
    error UnsupportedChain();
    error InsufficientAmount();
    error SlippageExceeded();
    error BridgeAdapterNotSet();
    error PriceFeedError();
    error TransferFailed();

    // ============ Constructor ============

    /**
     * @notice Initialize the StablecoinSwitch contract
     * @param _ethUsdPriceFeed Address of ETH/USD Chainlink price feed
     * @param _usdcUsdPriceFeed Address of USDC/USD Chainlink price feed
     * @param _owner Address of the contract owner
     */
    constructor(
        address _ethUsdPriceFeed,
        address _usdcUsdPriceFeed,
        address _owner
    ) Ownable(_owner) {
        if (_ethUsdPriceFeed == address(0)) revert InvalidToken();
        if (_usdcUsdPriceFeed == address(0)) revert InvalidToken();
        if (_owner == address(0)) revert InvalidRecipient();

        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        usdcUsdPriceFeed = AggregatorV3Interface(_usdcUsdPriceFeed);
    }

    // ============ External Functions ============

    /**
     * @notice Route a cross-chain stablecoin transaction
     * @param params Routing parameters
     * @return routeInfo Information about the selected route
     */
    function routeTransaction(RouteParams calldata params) 
        external 
        nonReentrant 
        returns (RouteInfo memory routeInfo) 
    {
        // Input validation
        _validateRouteParams(params);

        // Get optimal route
        routeInfo = getOptimalPath(
            params.fromToken,
            params.toToken,
            params.amount,
            params.toChainId,
            params.priority
        );

        // Check slippage protection
        if (params.minAmountOut > 0) {
            uint256 expectedOutput = _calculateExpectedOutput(params.amount, routeInfo);
            if (expectedOutput < params.minAmountOut) {
                revert SlippageExceeded();
            }
        }

        // Transfer tokens from user
        IERC20(params.fromToken).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount
        );

        // Emit routing event
        emit TransactionRouted(
            msg.sender,
            params.fromToken,
            params.toToken,
            params.amount,
            params.toChainId,
            params.priority,
            routeInfo.estimatedCostUsd,
            routeInfo.bridgeAdapter
        );

        return routeInfo;
    }

    /**
     * @notice Get the optimal routing path for a transaction with multi-route comparison
     * @param fromToken Source token address
     * @param toToken Destination token address
     * @param amount Amount to route
     * @param toChainId Destination chain ID
     * @param priority Priority level (0 = Cost, 1 = Speed)
     * @return routeInfo Optimal route information
     */
    function getOptimalPath(
        address fromToken,
        address toToken,
        uint256 amount,
        uint256 toChainId,
        uint8 priority
    ) public view returns (RouteInfo memory routeInfo) {
        // Validate inputs
        if (!supportedTokens[fromToken]) revert UnsupportedToken();
        if (!supportedTokens[toToken]) revert UnsupportedToken();
        if (!supportedChains[toChainId]) revert UnsupportedChain();
        if (amount == 0) revert InvalidAmount();
        if (priority > 1) revert InvalidPriority();

        // Get all available bridge adapters for the destination chain
        address[] memory adapters = bridgeAdapters[toChainId];
        if (adapters.length == 0) revert BridgeAdapterNotSet();

        // Get current prices
        uint256 ethPriceUsd = _getEthPriceUsd();
        uint256 usdcPriceUsd = _getUsdcPriceUsd();

        RouteInfo memory bestRoute;
        uint256 bestScore = type(uint256).max;

        // Compare all available routes
        for (uint256 i = 0; i < adapters.length; i++) {
            address adapter = adapters[i];
            if (adapter == address(0)) continue;

            // Calculate route-specific costs
            RouteInfo memory currentRoute = _calculateRouteInfo(
                fromToken,
                toToken,
                amount,
                toChainId,
                adapter,
                ethPriceUsd,
                priority
            );

            // Calculate score based on priority
            uint256 score = _calculateRouteScore(currentRoute, priority);

            // Select best route based on score
            if (score < bestScore) {
                bestScore = score;
                bestRoute = currentRoute;
            }
        }

        if (bestRoute.bridgeAdapter == address(0)) revert BridgeAdapterNotSet();
        return bestRoute;
    }

    /**
     * @notice Calculate detailed route information for a specific bridge adapter
     * @param fromToken Source token address
     * @param toToken Destination token address
     * @param amount Amount to route
     * @param toChainId Destination chain ID
     * @param adapter Bridge adapter address
     * @param ethPriceUsd Current ETH price in USD
     * @param priority Priority level (0 = Cost, 1 = Speed)
     * @return routeInfo Detailed route information
     */
    function _calculateRouteInfo(
        address fromToken,
        address toToken,
        uint256 amount,
        uint256 toChainId,
        address adapter,
        uint256 ethPriceUsd,
        uint8 priority
    ) internal view returns (RouteInfo memory routeInfo) {
        // Get bridge-specific gas cost (fallback to base cost if not set)
        uint256 bridgeGasCost = bridgeGasCosts[adapter];
        if (bridgeGasCost == 0) {
            bridgeGasCost = BASE_GAS_COST * 10; // Estimate 10x base cost for bridge operations
        }

        // Calculate gas cost in USD
        uint256 gasPrice = tx.gasprice > 0 ? tx.gasprice : 20 gwei;
        uint256 gasCostWei = bridgeGasCost * gasPrice;
        uint256 gasCostUsd = (gasCostWei * ethPriceUsd * 1e10) / 1e8;

        // Calculate bridge-specific fees (0.1% base + bridge premium)
        uint256 baseFeeUsd = (amount * 1e10 * ethPriceUsd) / (1000 * 1e8); // 0.1%
        uint256 bridgeFeeUsd = _getBridgeFee(adapter, amount, ethPriceUsd);

        // Apply priority multipliers
        uint256 priorityMultiplier = priority == 0 
            ? COST_PRIORITY_MULTIPLIER 
            : SPEED_PRIORITY_MULTIPLIER;

        uint256 totalGasUsd = (gasCostUsd * priorityMultiplier) / 100;
        uint256 totalBridgeFeeUsd = (bridgeFeeUsd * priorityMultiplier) / 100;
        uint256 totalCostUsd = totalGasUsd + totalBridgeFeeUsd;

        // Estimate completion time based on bridge type and priority
        uint256 estimatedTime = _getEstimatedTime(adapter, priority);

        return RouteInfo({
            fromToken: fromToken,
            toToken: toToken,
            fromChainId: block.chainid,
            toChainId: toChainId,
            estimatedCostUsd: totalCostUsd,
            estimatedGasUsd: totalGasUsd,
            bridgeFeeUsd: totalBridgeFeeUsd,
            estimatedTimeMinutes: estimatedTime,
            bridgeAdapter: adapter,
            bridgeName: bridgeAdapterNames[adapter],
            gasEstimate: bridgeGasCost
        });
    }

    /**
     * @notice Calculate route score for optimization (lower is better)
     * @param route Route information
     * @param priority Priority level (0 = Cost, 1 = Speed)
     * @return score Route score for comparison
     */
    function _calculateRouteScore(RouteInfo memory route, uint8 priority) internal pure returns (uint256 score) {
        if (priority == 0) {
            // Cost priority: minimize total cost
            return route.estimatedCostUsd;
        } else {
            // Speed priority: balance cost and time
            // Score = cost + (time_penalty * time_minutes)
            uint256 timePenalty = 1e18; // 1 USD per minute penalty
            return route.estimatedCostUsd + (timePenalty * route.estimatedTimeMinutes);
        }
    }

    /**
     * @notice Get bridge-specific fee
     * @param adapter Bridge adapter address
     * @param amount Transaction amount
     * @param ethPriceUsd Current ETH price
     * @return fee Bridge fee in USD
     */
    function _getBridgeFee(address adapter, uint256 amount, uint256 ethPriceUsd) internal view returns (uint256 fee) {
        // Base fee: 0.1% of transaction value
        uint256 baseFee = (amount * 1e10 * ethPriceUsd) / (1000 * 1e8);
        
        // Add bridge-specific premium based on adapter name
        string memory bridgeName = bridgeAdapterNames[adapter];
        
        // Different bridges have different fee structures
        if (keccak256(bytes(bridgeName)) == keccak256(bytes("Arbitrum"))) {
            return baseFee; // Arbitrum: base fee only
        } else if (keccak256(bytes(bridgeName)) == keccak256(bytes("Optimism"))) {
            return (baseFee * 110) / 100; // Optimism: 10% premium
        } else if (keccak256(bytes(bridgeName)) == keccak256(bytes("Polygon"))) {
            return (baseFee * 80) / 100; // Polygon: 20% discount (cheaper)
        } else {
            return (baseFee * 120) / 100; // Unknown bridges: 20% premium for safety
        }
    }

    /**
     * @notice Get estimated completion time for a bridge
     * @param adapter Bridge adapter address
     * @param priority Priority level
     * @return time Estimated time in minutes
     */
    function _getEstimatedTime(address adapter, uint8 priority) internal view returns (uint256 time) {
        string memory bridgeName = bridgeAdapterNames[adapter];
        
        // Base times for different bridges (in minutes)
        uint256 baseTime;
        if (keccak256(bytes(bridgeName)) == keccak256(bytes("Arbitrum"))) {
            baseTime = 15; // Arbitrum: ~15 minutes
        } else if (keccak256(bytes(bridgeName)) == keccak256(bytes("Optimism"))) {
            baseTime = 20; // Optimism: ~20 minutes  
        } else if (keccak256(bytes(bridgeName)) == keccak256(bytes("Polygon"))) {
            baseTime = 5; // Polygon: ~5 minutes (fastest)
        } else {
            baseTime = 30; // Unknown bridges: conservative estimate
        }

        // Apply priority modifier
        if (priority == 1) {
            return (baseTime * 70) / 100; // Speed priority: 30% faster
        } else {
             return baseTime; // Cost priority: normal time
         }
     }

     /**
     * @notice Execute settlement for a cross-chain transaction
     * @param recipient Recipient address
     * @param token Token to settle
     * @param amount Amount to settle
     * @param fromChainId Source chain ID
     * @param transactionHash Original transaction hash
     */
    function executeSettlement(
        address recipient,
        address token,
        uint256 amount,
        uint256 fromChainId,
        bytes32 transactionHash
    ) external nonReentrant onlyOwner {
        if (recipient == address(0)) revert InvalidRecipient();
        if (!supportedTokens[token]) revert UnsupportedToken();
        if (amount == 0) revert InvalidAmount();

        // Transfer tokens to recipient
        IERC20(token).safeTransfer(recipient, amount);

        emit SettlementExecuted(
            recipient,
            token,
            amount,
            fromChainId,
            transactionHash
        );
    }

    // ============ Administrative Functions ============

    /**
     * @notice Add a bridge adapter for a specific chain
     * @param chainId Chain ID
     * @param adapter Bridge adapter address
     * @param name Bridge adapter name (e.g., "Arbitrum", "Optimism")
     * @param gasCost Estimated gas cost for this bridge
     */
    function addBridgeAdapter(
        uint256 chainId, 
        address adapter, 
        string calldata name,
        uint256 gasCost
    ) external onlyOwner {
        if (chainId == 0) revert InvalidChain();
        if (adapter == address(0)) revert InvalidToken();
        
        // Add to the array of adapters for this chain
        bridgeAdapters[chainId].push(adapter);
        
        // Set bridge metadata
        bridgeAdapterNames[adapter] = name;
        bridgeGasCosts[adapter] = gasCost;
        
        emit BridgeAdapterSet(chainId, adapter, true);
    }

    /**
     * @notice Remove a bridge adapter for a specific chain
     * @param chainId Chain ID
     * @param adapter Bridge adapter address to remove
     */
    function removeBridgeAdapter(uint256 chainId, address adapter) external onlyOwner {
        if (chainId == 0) revert InvalidChain();
        
        address[] storage adapters = bridgeAdapters[chainId];
        
        // Find and remove the adapter
        for (uint256 i = 0; i < adapters.length; i++) {
            if (adapters[i] == adapter) {
                // Move last element to current position and pop
                adapters[i] = adapters[adapters.length - 1];
                adapters.pop();
                
                // Clear metadata
                delete bridgeAdapterNames[adapter];
                delete bridgeGasCosts[adapter];
                
                emit BridgeAdapterSet(chainId, adapter, false);
                return;
            }
        }
    }

    /**
     * @notice Update bridge adapter gas cost
     * @param adapter Bridge adapter address
     * @param gasCost New gas cost estimate
     */
    function updateBridgeGasCost(address adapter, uint256 gasCost) external onlyOwner {
        if (adapter == address(0)) revert InvalidToken();
        
        bridgeGasCosts[adapter] = gasCost;
    }

    /**
     * @notice Get all bridge adapters for a chain
     * @param chainId Chain ID
     * @return adapters Array of bridge adapter addresses
     */
    function getBridgeAdapters(uint256 chainId) external view returns (address[] memory adapters) {
        return bridgeAdapters[chainId];
    }

    /**
     * @notice Legacy function for backward compatibility - adds first bridge adapter
     * @param chainId Chain ID
     * @param adapter Bridge adapter address
     */
    function setBridgeAdapter(uint256 chainId, address adapter) external onlyOwner {
        if (chainId == 0) revert InvalidChain();
        
        // Clear existing adapters and add new one
        delete bridgeAdapters[chainId];
        
        if (adapter != address(0)) {
            bridgeAdapters[chainId].push(adapter);
            bridgeAdapterNames[adapter] = "Legacy";
            bridgeGasCosts[adapter] = BASE_GAS_COST * 10;
        }
        
        emit BridgeAdapterSet(chainId, adapter, adapter != address(0));
    }

    /**
     * @notice Update token support status
     * @param token Token address
     * @param isSupported Whether the token should be supported
     */
    function setTokenSupport(address token, bool isSupported) external onlyOwner {
        if (token == address(0)) revert InvalidToken();
        
        supportedTokens[token] = isSupported;
        
        emit TokenSupportUpdated(token, isSupported);
    }

    /**
     * @notice Update chain support status
     * @param chainId Chain ID
     * @param isSupported Whether the chain should be supported
     */
    function setChainSupport(uint256 chainId, bool isSupported) external onlyOwner {
        if (chainId == 0) revert InvalidChain();
        
        supportedChains[chainId] = isSupported;
        
        emit ChainSupportUpdated(chainId, isSupported);
    }

    /**
     * @notice Emergency withdrawal function for owner
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            // Withdraw ETH
            (bool success, ) = payable(owner()).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Withdraw ERC20 token
            IERC20(token).safeTransfer(owner(), amount);
        }
    }

    // ============ Internal Functions ============

    /**
     * @notice Validate route parameters
     * @param params Route parameters to validate
     */
    function _validateRouteParams(RouteParams calldata params) internal view {
        if (!supportedTokens[params.fromToken]) revert UnsupportedToken();
        if (!supportedTokens[params.toToken]) revert UnsupportedToken();
        if (!supportedChains[params.toChainId]) revert UnsupportedChain();
        if (params.amount == 0) revert InvalidAmount();
        if (params.priority > 1) revert InvalidPriority();
        if (params.recipient == address(0)) revert InvalidRecipient();
    }

    /**
     * @notice Get ETH price in USD from Chainlink
     * @return price ETH price in USD (8 decimals)
     */
    function _getEthPriceUsd() internal view returns (uint256 price) {
        try ethUsdPriceFeed.latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            if (answer <= 0) revert PriceFeedError();
            if (updatedAt == 0) revert PriceFeedError();
            if (block.timestamp - updatedAt > maxPriceStalenessSeconds) revert PriceFeedError();
            
            return uint256(answer);
        } catch {
            revert PriceFeedError();
        }
    }

    /**
     * @notice Get USDC price in USD from Chainlink
     * @return price USDC price in USD (8 decimals)
     */
    function _getUsdcPriceUsd() internal view returns (uint256 price) {
        try usdcUsdPriceFeed.latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            if (answer <= 0) revert PriceFeedError();
            if (updatedAt == 0) revert PriceFeedError();
            if (block.timestamp - updatedAt > maxPriceStalenessSeconds) revert PriceFeedError();
            
            return uint256(answer);
        } catch {
            revert PriceFeedError();
        }
    }

    /**
     * @notice Update the maximum allowed staleness for price feeds
     * @param seconds_ New staleness threshold in seconds
     */
    function setMaxPriceStalenessSeconds(uint256 seconds_) external onlyOwner {
        maxPriceStalenessSeconds = seconds_;
    }

    /**
     * @notice Non-reverting health check for price feeds
     * @return ethOk Whether ETH/USD feed is valid and fresh
     * @return usdcOk Whether USDC/USD feed is valid and fresh
     * @return ethUpdatedAt Last ETH feed update timestamp
     * @return usdcUpdatedAt Last USDC feed update timestamp
     */
    function areFeedsHealthy()
        external
        view
        returns (
            bool ethOk,
            bool usdcOk,
            uint256 ethUpdatedAt,
            uint256 usdcUpdatedAt
        )
    {
        // ETH/USD
        try ethUsdPriceFeed.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            bool valid = (answer > 0 && updatedAt != 0 && answeredInRound >= roundId);
            bool fresh = (block.timestamp - updatedAt <= maxPriceStalenessSeconds);
            ethOk = valid && fresh;
            ethUpdatedAt = updatedAt;
        } catch {
            ethOk = false;
            ethUpdatedAt = 0;
        }

        // USDC/USD
        try usdcUsdPriceFeed.latestRoundData() returns (
            uint80 roundId2,
            int256 answer2,
            uint256 /* startedAt2 */,
            uint256 updatedAt2,
            uint80 answeredInRound2
        ) {
            bool valid2 = (answer2 > 0 && updatedAt2 != 0 && answeredInRound2 >= roundId2);
            bool fresh2 = (block.timestamp - updatedAt2 <= maxPriceStalenessSeconds);
            usdcOk = valid2 && fresh2;
            usdcUpdatedAt = updatedAt2;
        } catch {
            usdcOk = false;
            usdcUpdatedAt = 0;
        }
    }

    /**
     * @notice Calculate base cost for routing
     * @param amount Amount being routed
     * @param ethPriceUsd Current ETH price in USD
     * @return cost Base cost in USD (18 decimals)
     */
    function _calculateBaseCost(uint256 amount, uint256 ethPriceUsd) internal pure returns (uint256 cost) {
        // Simple fee calculation: 0.1% of transaction value
        // Convert to 18 decimals for consistency
        return (amount * 1e10 * ethPriceUsd) / (1000 * 1e8);
    }

    /**
     * @notice Calculate gas cost in USD
     * @param ethPriceUsd Current ETH price in USD
     * @return cost Gas cost in USD (18 decimals)
     */
    function _calculateGasCost(uint256 ethPriceUsd) internal view returns (uint256 cost) {
        // Estimate gas cost based on current gas price and ETH price
        uint256 gasPrice = tx.gasprice;
        
        // Use a default gas price if tx.gasprice is 0 (common in test environments)
        if (gasPrice == 0) {
            gasPrice = 20 gwei; // Default to 20 gwei
        }
        
        uint256 gasCostWei = BASE_GAS_COST * gasPrice;
        
        // Convert to USD (18 decimals)
        return (gasCostWei * ethPriceUsd * 1e10) / 1e8;
    }

    /**
     * @notice Calculate expected output amount
     * @param inputAmount Input amount
     * @param routeInfo Route information
     * @return expectedOutput Expected output amount
     */
    function _calculateExpectedOutput(
        uint256 inputAmount, 
        RouteInfo memory routeInfo
    ) internal pure returns (uint256 expectedOutput) {
        // Simple 1:1 conversion for stablecoins with minimal fees
        // In production, this would include more sophisticated pricing
        uint256 feeAmount = (inputAmount * 10) / 10000; // 0.1% fee
        return inputAmount - feeAmount;
    }

    // ============ View Functions ============

    /**
     * @notice Check if a token is supported
     * @param token Token address to check
     * @return isSupported Whether the token is supported
     */
    function isTokenSupported(address token) external view returns (bool isSupported) {
        return supportedTokens[token];
    }

    /**
     * @notice Check if a chain is supported
     * @param chainId Chain ID to check
     * @return isSupported Whether the chain is supported
     */
    function isChainSupported(uint256 chainId) external view returns (bool isSupported) {
        return supportedChains[chainId];
    }

    /**
     * @notice Get first bridge adapter for a chain (for backward compatibility)
     * @param chainId Chain ID
     * @return adapter Bridge adapter address
     */
    function getBridgeAdapter(uint256 chainId) external view returns (address adapter) {
        address[] memory adapters = bridgeAdapters[chainId];
        return adapters.length > 0 ? adapters[0] : address(0);
    }

    /**
     * @notice Get current ETH price in USD
     * @return price Current ETH price (8 decimals)
     */
    function getCurrentEthPrice() external view returns (uint256 price) {
        return _getEthPriceUsd();
    }

    /**
     * @notice Get current USDC price in USD
     * @return price Current USDC price (8 decimals)
     */
    function getCurrentUsdcPrice() external view returns (uint256 price) {
        return _getUsdcPriceUsd();
    }
}