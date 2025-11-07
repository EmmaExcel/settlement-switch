// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/ISettlementSwitch.sol";
import "../interfaces/IBridgeAdapter.sol";
import "./RouteCalculator.sol";
import "./BridgeRegistry.sol";
import "./FeeManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract SettlementSwitch is ISettlementSwitch, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Role for settlement operations
    bytes32 public constant SETTLEMENT_OPERATOR_ROLE = keccak256("SETTLEMENT_OPERATOR_ROLE");
    
    /// @notice Role for emergency operations
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /// @notice Supported chain configuration
    struct ChainConfig {
        uint256 chainId;            // Chain identifier
        string name;                // Chain name
        bool isSupported;           // Whether chain is supported
        uint256 maxGasPrice;        // Maximum gas price for the chain
        address wethAddress;        // WETH contract address
        address[] supportedTokens;  // List of supported token addresses
        mapping(address => bool) tokenSupported; // Quick lookup for token support
    }

    /// @notice User transfer limits and rate limiting
    struct UserLimits {
        uint256 dailyLimit;         // Daily transfer limit in USD value
        uint256 dailyTransferred;   // Amount transferred today
        uint256 lastTransferTime;   // Last transfer timestamp
        uint256 transferCount;      // Total number of transfers
        bool isWhitelisted;         // Whether user is whitelisted
    }

    /// @notice Multi-path execution state
    struct MultiPathExecution {
        bytes32[] transferIds;      // Array of transfer IDs
        uint256[] amounts;          // Amount for each path
        uint256 totalAmount;        // Total amount being transferred
        uint256 completedPaths;     // Number of completed paths
        bool isCompleted;           // Whether all paths are completed
        address recipient;          // Final recipient
    }

    // Constants
    uint256 public constant MIN_TRANSFER_INTERVAL = 10 seconds;
    uint256 public constant MAX_ROUTES_PER_QUERY = 10;
    uint256 public constant ROUTE_CACHE_TTL = 60 seconds;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_SLIPPAGE_BPS = 1000; // 10%

    // Supported chain IDs
    uint256 public constant ETHEREUM_MAINNET = 1;
    uint256 public constant ETHEREUM_SEPOLIA = 11155111;
    uint256 public constant ARBITRUM_ONE = 42161;
    uint256 public constant ARBITRUM_SEPOLIA = 421614;
    uint256 public constant POLYGON_MAINNET = 137;
    uint256 public constant POLYGON_MUMBAI = 80001;

    // Core components
    RouteCalculator public immutable routeCalculator;
    BridgeRegistry public immutable bridgeRegistry;
    FeeManager public immutable feeManager;

    // State variables
    mapping(uint256 => ChainConfig) public chainConfigs;
    mapping(address => UserLimits) public userLimits;
    mapping(bytes32 => IBridgeAdapter.Transfer) public transfers;
    mapping(bytes32 => MultiPathExecution) public multiPathExecutions;
    mapping(address => bytes32[]) public userTransferHistory;
    
    uint256[] public supportedChainIds;
    bytes32[] public allTransferIds;
    
    // Rate limiting and security
    mapping(address => bool) public blacklistedAddresses;
    mapping(address => bool) public whitelistedTokens;
    uint256 public defaultDailyLimit = 10000 ether; // $10,000 USD equivalent
    
    // Route caching
    mapping(bytes32 => CachedRoute) public routeCache;
    uint256 public routeCacheTtl = ROUTE_CACHE_TTL;

    // Events (additional to interface events)
    event ChainConfigUpdated(uint256 indexed chainId, string name, bool supported);
    event UserLimitsUpdated(address indexed user, uint256 dailyLimit);
    event BlacklistUpdated(address indexed account, bool blacklisted);
    event TokenWhitelistUpdated(address indexed token, bool whitelisted);
    event MultiPathExecutionStarted(bytes32 indexed executionId, uint256 pathCount);
    event MultiPathExecutionCompleted(bytes32 indexed executionId, bool successful);

    // Errors
    error ChainNotSupported();
    error TokenNotSupported();
    error TransferAmountTooLow();
    error TransferAmountTooHigh();
    error DailyLimitExceeded();
    error TransferTooFrequent();
    error BlacklistedAddress();
    error InvalidSlippage();
    error RouteNotFound();
    error TransferNotFound();
    error MultiPathExecutionFailed();
    error InvalidPermitData();

    constructor(
        address admin,
        address _routeCalculator,
        address _bridgeRegistry,
        address payable _feeManager
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SETTLEMENT_OPERATOR_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        routeCalculator = RouteCalculator(_routeCalculator);
        bridgeRegistry = BridgeRegistry(_bridgeRegistry);
        feeManager = FeeManager(_feeManager);

        _initializeChainConfigs();
    }

    function _initializeChainConfigs() internal {
        // Testnet configurations
        _addChainConfig(ETHEREUM_SEPOLIA, "Ethereum Sepolia", true, 50 gwei);
        _addChainConfig(ARBITRUM_SEPOLIA, "Arbitrum Sepolia", true, 1 gwei);
        _addChainConfig(POLYGON_MUMBAI, "Polygon Mumbai", true, 30 gwei);

        // Mainnet configurations (commented for testnet deployment)
        // _addChainConfig(ETHEREUM_MAINNET, "Ethereum Mainnet", false, 100 gwei);
        // _addChainConfig(ARBITRUM_ONE, "Arbitrum One", false, 1 gwei);
        // _addChainConfig(POLYGON_MAINNET, "Polygon Mainnet", false, 50 gwei);
    }

    function _addChainConfig(
        uint256 chainId,
        string memory name,
        bool supported,
        uint256 maxGasPrice
    ) internal {
        ChainConfig storage config = chainConfigs[chainId];
        config.chainId = chainId;
        config.name = name;
        config.isSupported = supported;
        config.maxGasPrice = maxGasPrice;
        
        if (supported) {
            supportedChainIds.push(chainId);
        }
        
        emit ChainConfigUpdated(chainId, name, supported);
    }

    function findOptimalRoute(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences
    ) external view override returns (IBridgeAdapter.Route memory route) {
        _validateChainSupport(srcChainId);
        _validateChainSupport(dstChainId);
        _validateTokenSupport(tokenIn, srcChainId);
        _validateTokenSupport(tokenOut, dstChainId);

        // Check cache first
        bytes32 cacheKey = _generateRouteCacheKey(
            tokenIn, tokenOut, amount, srcChainId, dstChainId, preferences
        );
        
        CachedRoute memory cached = routeCache[cacheKey];
        if (cached.isValid && (block.timestamp - cached.cachedAt) < routeCacheTtl) {
            return cached.route;
        }

        // Find route using RouteCalculator
        return routeCalculator.findOptimalRoute(
            tokenIn, tokenOut, amount, srcChainId, dstChainId, preferences
        );
    }

    function findMultipleRoutes(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences,
        uint256 maxRoutes
    ) external view override returns (IBridgeAdapter.Route[] memory routes) {
        _validateChainSupport(srcChainId);
        _validateChainSupport(dstChainId);
        _validateTokenSupport(tokenIn, srcChainId);
        _validateTokenSupport(tokenOut, dstChainId);

        if (maxRoutes > MAX_ROUTES_PER_QUERY) {
            maxRoutes = MAX_ROUTES_PER_QUERY;
        }

        return routeCalculator.findMultipleRoutes(
            tokenIn, tokenOut, amount, srcChainId, dstChainId, preferences, maxRoutes
        );
    }

    function findMultiPathRoute(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences
    ) external view override returns (MultiPathRoute memory multiPath) {
        _validateChainSupport(srcChainId);
        _validateChainSupport(dstChainId);

        // Get multiple routes
        IBridgeAdapter.Route[] memory routes = routeCalculator.findMultipleRoutes(
            tokenIn, tokenOut, amount, srcChainId, dstChainId, preferences, MAX_ROUTES_PER_QUERY
        );

        if (routes.length == 0) revert RouteNotFound();

        // Implement multi-path splitting algorithm
        return _calculateMultiPathSplit(routes, amount);
    }

    function executeBridge(
        IBridgeAdapter.Route memory route,
        address recipient,
        bytes calldata permitData
    ) external payable override nonReentrant whenNotPaused returns (bytes32 transferId) {
        _validateTransferRequest(msg.sender, route.amountIn);
        _validateRoute(route);

        // Handle permit if provided
        if (permitData.length > 0) {
            _handlePermit(route.tokenIn, permitData);
        }

        // Collect protocol fees
        uint256 protocolFee = feeManager.calculateFee(
            "protocol", route.amountIn, route.srcChainId, msg.sender
        );
        
        if (protocolFee > 0) {
            feeManager.collectFee{value: protocolFee}(
                "protocol", address(0), protocolFee, msg.sender, bytes32(0)
            );
        }

        // Transfer tokens from user
        if (route.tokenIn != address(0)) {
            IERC20(route.tokenIn).safeTransferFrom(msg.sender, address(this), route.amountIn);
            IERC20(route.tokenIn).approve(route.adapter, route.amountIn);
        }

        // Execute bridge transfer
        // Forward remaining ETH (native bridge fee and/or amount) to adapter
        uint256 remainingEth = msg.value;
        if (protocolFee <= remainingEth) {
            remainingEth -= protocolFee;
        } else {
            remainingEth = 0; // avoid underflow if misconfigured
        }

        transferId = IBridgeAdapter(route.adapter).executeBridge{ value: remainingEth }(
            route,
            recipient,
            ""
        );

        // Store transfer information
        transfers[transferId] = IBridgeAdapter.Transfer({
            transferId: transferId,
            sender: msg.sender,
            recipient: recipient,
            route: route,
            status: IBridgeAdapter.TransferStatus.PENDING,
            initiatedAt: block.timestamp,
            completedAt: 0
        });

        // Update user limits and history
        _updateUserLimits(msg.sender, route.amountIn);
        userTransferHistory[msg.sender].push(transferId);
        allTransferIds.push(transferId);

        // Cache the route
        _cacheRoute(route, transferId);

        emit TransferInitiated(transferId, msg.sender, route, block.timestamp);
        
        return transferId;
    }

    function executeMultiPathBridge(
        MultiPathRoute memory multiPath,
        address recipient,
        bytes calldata permitData
    ) external payable override nonReentrant whenNotPaused returns (bytes32[] memory transferIds) {
        _validateTransferRequest(msg.sender, multiPath.totalAmount);

        // Generate execution ID
        bytes32 executionId = keccak256(abi.encodePacked(
            msg.sender, recipient, multiPath.totalAmount, block.timestamp
        ));

        transferIds = new bytes32[](multiPath.routes.length);
        uint256 totalEthValue = 0;

        // Handle permit if provided
        if (permitData.length > 0 && multiPath.routes.length > 0) {
            _handlePermit(multiPath.routes[0].tokenIn, permitData);
        }

        // Execute each route
        for (uint256 i = 0; i < multiPath.routes.length; i++) {
            IBridgeAdapter.Route memory route = multiPath.routes[i];
            uint256 routeAmount = multiPath.amounts[i];

            // Update route amount
            route.amountIn = routeAmount;
            route.amountOut = (route.amountOut * routeAmount) / route.amountIn;

            // Transfer tokens for this route
            if (route.tokenIn != address(0)) {
                IERC20(route.tokenIn).safeTransferFrom(msg.sender, address(this), routeAmount);
                IERC20(route.tokenIn).approve(route.adapter, routeAmount);
            } else {
                totalEthValue += routeAmount;
            }

            // Execute bridge transfer
            transferIds[i] = IBridgeAdapter(route.adapter).executeBridge{
                value: route.tokenIn == address(0) ? routeAmount : 0
            }(route, recipient, "");

            // Store transfer information
            transfers[transferIds[i]] = IBridgeAdapter.Transfer({
                transferId: transferIds[i],
                sender: msg.sender,
                recipient: recipient,
                route: route,
                status: IBridgeAdapter.TransferStatus.PENDING,
                initiatedAt: block.timestamp,
                completedAt: 0
            });

            userTransferHistory[msg.sender].push(transferIds[i]);
            allTransferIds.push(transferIds[i]);
        }

        // Store multi-path execution
        multiPathExecutions[executionId] = MultiPathExecution({
            transferIds: transferIds,
            amounts: multiPath.amounts,
            totalAmount: multiPath.totalAmount,
            completedPaths: 0,
            isCompleted: false,
            recipient: recipient
        });

        // Update user limits
        _updateUserLimits(msg.sender, multiPath.totalAmount);

        emit MultiPathTransferInitiated(transferIds, msg.sender, multiPath, block.timestamp);
        emit MultiPathExecutionStarted(executionId, multiPath.routes.length);

        return transferIds;
    }

    function bridgeWithAutoRoute(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        address recipient,
        IBridgeAdapter.RoutePreferences memory preferences,
        bytes calldata permitData
    ) external payable override nonReentrant whenNotPaused returns (bytes32 transferId) {
        // Find optimal route
        IBridgeAdapter.Route memory route = this.findOptimalRoute(
            tokenIn, tokenOut, amount, srcChainId, dstChainId, preferences
        );

        // Execute the bridge transfer
        return this.executeBridge{value: msg.value}(route, recipient, permitData);
    }

    function executeBatchBridge(
        IBridgeAdapter.Route[] memory routes,
        address[] memory recipients,
        bytes[] calldata permitData
    ) external payable override nonReentrant whenNotPaused returns (bytes32[] memory transferIds) {
        if (routes.length != recipients.length || routes.length != permitData.length) {
            revert("Array length mismatch");
        }

        transferIds = new bytes32[](routes.length);
        uint256 totalAmount = 0;

        // Calculate total amount for limit checking
        for (uint256 i = 0; i < routes.length; i++) {
            totalAmount += routes[i].amountIn;
        }

        _validateTransferRequest(msg.sender, totalAmount);

        // Execute each bridge transfer
        for (uint256 i = 0; i < routes.length; i++) {
            // Handle permit if provided
            if (permitData[i].length > 0) {
                _handlePermit(routes[i].tokenIn, permitData[i]);
            }

            // Execute individual bridge
            transferIds[i] = this.executeBridge{value: 0}(routes[i], recipients[i], "");
        }

        return transferIds;
    }

    function getRegisteredAdapters() external view override returns (
        address[] memory adapters,
        string[] memory names,
        bool[] memory enabled
    ) {
        adapters = bridgeRegistry.getEnabledBridges();
        names = new string[](adapters.length);
        enabled = new bool[](adapters.length);

        for (uint256 i = 0; i < adapters.length; i++) {
            (BridgeRegistry.BridgeInfo memory info,) = bridgeRegistry.getBridgeDetails(adapters[i]);
            names[i] = info.name;
            enabled[i] = info.isEnabled && info.isHealthy;
        }

        return (adapters, names, enabled);
    }

    function getAvailableLiquidity(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (LiquiditySource[] memory sources) {
        address[] memory adapters = bridgeRegistry.getBridgesForChain(srcChainId);
        uint256 validSourceCount = 0;

        // Count valid sources
        for (uint256 i = 0; i < adapters.length; i++) {
            if (IBridgeAdapter(adapters[i]).supportsRoute(tokenIn, tokenOut, srcChainId, dstChainId)) {
                validSourceCount++;
            }
        }

        // Create sources array
        sources = new LiquiditySource[](validSourceCount);
        uint256 sourceIndex = 0;

        for (uint256 i = 0; i < adapters.length; i++) {
            address adapter = adapters[i];
            if (IBridgeAdapter(adapter).supportsRoute(tokenIn, tokenOut, srcChainId, dstChainId)) {
                uint256 liquidity = IBridgeAdapter(adapter).getAvailableLiquidity(
                    tokenIn, tokenOut, srcChainId, dstChainId
                );

                sources[sourceIndex] = LiquiditySource({
                    adapter: adapter,
                    chainId: srcChainId,
                    availableAmount: liquidity,
                    utilizationRate: 0 // Simplified - would calculate based on total capacity
                });
                sourceIndex++;
            }
        }

        return sources;
    }

    function getCachedRoute(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences
    ) external view override returns (CachedRoute memory cached, bool isValid) {
        bytes32 cacheKey = _generateRouteCacheKey(
            tokenIn, tokenOut, amount, srcChainId, dstChainId, preferences
        );
        
        cached = routeCache[cacheKey];
        isValid = cached.isValid && (block.timestamp - cached.cachedAt) < routeCacheTtl;
        
        return (cached, isValid);
    }

    // Admin Functions

    function registerBridgeAdapter(address adapter, bool enabled) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // Register with bridge registry
        uint256[] memory chainIds = supportedChainIds;
        address[] memory tokens = new address[](0); // Empty for now
        
        bridgeRegistry.registerBridge(adapter, chainIds, tokens);
        
        if (!enabled) {
            bridgeRegistry.disableBridge(adapter, "Registered as disabled");
        }

        emit BridgeAdapterRegistered(adapter, IBridgeAdapter(adapter).getBridgeName(), enabled);
    }

    function setBridgeAdapterStatus(
        address adapter,
        bool enabled,
        string memory reason
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (enabled) {
            bridgeRegistry.enableBridge(adapter);
        } else {
            bridgeRegistry.disableBridge(adapter, reason);
        }

        emit BridgeAdapterStatusChanged(adapter, enabled, reason);
    }

    function emergencyPause(string memory reason) external override onlyRole(EMERGENCY_ROLE) {
        _pause();
        emit EmergencyPause(msg.sender, reason, block.timestamp);
    }

    function emergencyUnpause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function updateRouteCacheTtl(uint256 newTtl) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        routeCacheTtl = newTtl;
    }

    // View Functions

    function isPaused() external view override returns (bool) {
        return paused();
    }

    function getRouteCacheTtl() external view override returns (uint256 ttl) {
        return routeCacheTtl;
    }

    function getTransfer(bytes32 transferId) external view override returns (IBridgeAdapter.Transfer memory transfer) {
        return transfers[transferId];
    }

    function getUserTransfers(
        address user,
        uint256 offset,
        uint256 limit
    ) external view override returns (IBridgeAdapter.Transfer[] memory userTransfers) {
        bytes32[] memory userTransferIds = userTransferHistory[user];
        
        if (offset >= userTransferIds.length) {
            return new IBridgeAdapter.Transfer[](0);
        }

        uint256 end = offset + limit;
        if (end > userTransferIds.length) {
            end = userTransferIds.length;
        }

        userTransfers = new IBridgeAdapter.Transfer[](end - offset);
        
        for (uint256 i = offset; i < end; i++) {
            userTransfers[i - offset] = transfers[userTransferIds[i]];
        }

        return userTransfers;
    }

    // Internal Functions

    function _validateChainSupport(uint256 chainId) internal view {
        if (!chainConfigs[chainId].isSupported) revert ChainNotSupported();
    }

    function _validateTokenSupport(address token, uint256 chainId) internal view {
        // For now, allow all tokens. In production, implement whitelist
        // if (!chainConfigs[chainId].tokenSupported[token]) revert TokenNotSupported();
    }

    function _validateTransferRequest(address user, uint256 amount) internal view {
        if (blacklistedAddresses[user]) revert BlacklistedAddress();
        if (amount == 0) revert TransferAmountTooLow();

        UserLimits memory limits = userLimits[user];
        
        // Check rate limiting
        if (block.timestamp - limits.lastTransferTime < MIN_TRANSFER_INTERVAL) {
            revert TransferTooFrequent();
        }

        // Check daily limits (simplified - would use USD value in production)
        uint256 dailyLimit = limits.dailyLimit > 0 ? limits.dailyLimit : defaultDailyLimit;
        if (!limits.isWhitelisted && limits.dailyTransferred + amount > dailyLimit) {
            revert DailyLimitExceeded();
        }
    }

    function _validateRoute(IBridgeAdapter.Route memory route) internal view {
        if (route.adapter == address(0)) revert RouteNotFound();
        if (route.deadline < block.timestamp) revert("Route expired");
        
        // Validate slippage
        if (route.amountOut == 0) revert InvalidSlippage();
    }

    function _handlePermit(address token, bytes calldata permitData) internal {
        if (permitData.length == 0) return;

        try this.executePermit(token, permitData) {
            // Permit executed successfully
        } catch {
            revert InvalidPermitData();
        }
    }

    function executePermit(address token, bytes calldata permitData) external {
        require(msg.sender == address(this), "Only self");
        
        (uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) = 
            abi.decode(permitData, (uint256, uint256, uint8, bytes32, bytes32));
            
        IERC20Permit(token).permit(msg.sender, address(this), value, deadline, v, r, s);
    }

    function _updateUserLimits(address user, uint256 amount) internal {
        UserLimits storage limits = userLimits[user];
        
        // Reset daily counter if new day
        if (block.timestamp >= limits.lastTransferTime + 1 days) {
            limits.dailyTransferred = 0;
        }
        
        limits.dailyTransferred += amount;
        limits.lastTransferTime = block.timestamp;
        limits.transferCount++;
    }

    function _cacheRoute(IBridgeAdapter.Route memory route, bytes32 transferId) internal {
        bytes32 cacheKey = keccak256(abi.encodePacked(
            route.tokenIn, route.tokenOut, route.amountIn,
            route.srcChainId, route.dstChainId, transferId
        ));

        routeCache[cacheKey] = CachedRoute({
            route: route,
            cachedAt: block.timestamp,
            ttl: routeCacheTtl,
            isValid: true
        });

        emit RouteCacheUpdated(cacheKey, block.timestamp, routeCacheTtl);
    }

    function _generateRouteCacheKey(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        IBridgeAdapter.RoutePreferences memory preferences
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            tokenIn, tokenOut, amount, srcChainId, dstChainId,
            preferences.mode, preferences.maxSlippageBps
        ));
    }

    function _calculateMultiPathSplit(
        IBridgeAdapter.Route[] memory routes,
        uint256 totalAmount
    ) internal pure returns (MultiPathRoute memory multiPath) {
        // Simplified multi-path algorithm
        // In production, this would use sophisticated optimization
        
        uint256 routeCount = routes.length > 3 ? 3 : routes.length; // Max 3 paths
        uint256[] memory amounts = new uint256[](routeCount);
        uint256 remainingAmount = totalAmount;
        
        // Split amount based on route quality scores
        for (uint256 i = 0; i < routeCount - 1; i++) {
            amounts[i] = remainingAmount / (routeCount - i);
            remainingAmount -= amounts[i];
        }
        amounts[routeCount - 1] = remainingAmount;

        // Create route array with adjusted amounts
        IBridgeAdapter.Route[] memory selectedRoutes = new IBridgeAdapter.Route[](routeCount);
        for (uint256 i = 0; i < routeCount; i++) {
            selectedRoutes[i] = routes[i];
        }

        return MultiPathRoute({
            routes: selectedRoutes,
            amounts: amounts,
            totalAmount: totalAmount,
            totalCost: 0, // Would calculate based on individual route costs
            maxTime: 0    // Would calculate based on slowest route
        });
    }

    function updateChainConfig(
        uint256 chainId,
        string memory name,
        bool supported,
        uint256 maxGasPrice
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ChainConfig storage config = chainConfigs[chainId];
        bool wasSupported = config.isSupported;
        
        config.name = name;
        config.isSupported = supported;
        config.maxGasPrice = maxGasPrice;

        // Update supported chains list
        if (supported && !wasSupported) {
            supportedChainIds.push(chainId);
        } else if (!supported && wasSupported) {
            for (uint256 i = 0; i < supportedChainIds.length; i++) {
                if (supportedChainIds[i] == chainId) {
                    supportedChainIds[i] = supportedChainIds[supportedChainIds.length - 1];
                    supportedChainIds.pop();
                    break;
                }
            }
        }

        emit ChainConfigUpdated(chainId, name, supported);
    }

    function setUserDailyLimit(address user, uint256 dailyLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        userLimits[user].dailyLimit = dailyLimit;
        emit UserLimitsUpdated(user, dailyLimit);
    }

    function setBlacklistStatus(address account, bool blacklisted) external onlyRole(EMERGENCY_ROLE) {
        blacklistedAddresses[account] = blacklisted;
        emit BlacklistUpdated(account, blacklisted);
    }

    function getSupportedChains() external view returns (uint256[] memory chainIds) {
        return supportedChainIds;
    }

    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyRole(EMERGENCY_ROLE) {
        if (token == address(0)) {
            payable(recipient).transfer(amount);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }

    receive() external payable {
        // Allow contract to receive ETH
    }
}
