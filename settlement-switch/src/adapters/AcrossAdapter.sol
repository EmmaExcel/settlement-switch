// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AcrossAdapter is IBridgeAdapter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Across pool configuration
    struct LiquidityPool {
        address token;              // Pool token address
        uint256 totalLiquidity;     // Total pool liquidity
        uint256 utilizedLiquidity;  // Currently utilized liquidity
        uint256 utilizationRate;    // Current utilization rate (basis points)
        uint256 lpFeeRate;          // LP fee rate (basis points)
        uint256 relayerFeeRate;     // Relayer fee rate (basis points)
        bool isActive;              // Whether pool is active
    }

    /// @notice Relayer information
    struct Relayer {
        address relayerAddress;     // Relayer address
        uint256 stake;              // Staked amount
        uint256 reputation;         // Reputation score (0-100)
        uint256 successfulRelays;   // Number of successful relays
        uint256 totalRelays;        // Total number of relays
        bool isActive;              // Whether relayer is active
    }

    /// @notice Relay request
    struct RelayRequest {
        bytes32 transferId;         // Transfer identifier
        address sender;             // Original sender
        address recipient;          // Final recipient
        address token;              // Token being transferred
        uint256 amount;             // Transfer amount
        uint256 originChainId;      // Origin chain ID
        uint256 destinationChainId; // Destination chain ID
        uint256 relayerFee;         // Fee for relayer
        uint256 lpFee;              // Fee for liquidity providers
        uint256 timestamp;          // Request timestamp
        address assignedRelayer;    // Assigned relayer
        bool isRelayed;             // Whether request is relayed
        bool isDisputed;            // Whether relay is disputed
    }

    // State variables
    mapping(uint256 => mapping(address => LiquidityPool)) public liquidityPools; // chainId => token => pool
    mapping(address => Relayer) public relayers;
    mapping(bytes32 => Transfer) public transfers;
    mapping(bytes32 => RelayRequest) public relayRequests;
    
    address[] public activeRelayers;
    bytes32[] public transferHistory;
    
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
        uint256 disputePeriod;      // Dispute period for challenges
        uint256 minRelayerStake;    // Minimum relayer stake
        bool isActive;              // Whether bridge is active
    }

    BridgeConfig public config;

    // Events
    event RelayRequested(bytes32 indexed transferId, address indexed relayer, uint256 fee);
    event RelayCompleted(bytes32 indexed transferId, address indexed relayer);
    event RelayDisputed(bytes32 indexed transferId, address indexed challenger);
    event LiquidityAdded(uint256 indexed chainId, address indexed token, uint256 amount);
    event RelayerRegistered(address indexed relayer, uint256 stake);

    // Errors
    error UnsupportedRoute();
    error InsufficientLiquidity();
    error TransferAmountTooLow();
    error TransferAmountTooHigh();
    error BridgeInactive();
    error NoActiveRelayers();
    error InsufficientRelayerStake();
    error RelayAlreadyCompleted();
    error DisputePeriodExpired();

    constructor() Ownable(msg.sender) {
        _initializeConfig();
        _initializeLiquidityPools();
        _initializeRelayers();
    }

    function _initializeConfig() internal {
        config = BridgeConfig({
            baseFee: 0.0005 ether,      // Very low base fee
            feePercentage: 2,           // 0.02% - very competitive
            minTransferAmount: 0.1 ether, // Low minimum
            maxTransferAmount: 10000 ether, // High maximum
            avgCompletionTime: 180,     // 3 minutes - very fast
            disputePeriod: 7200,        // 2 hours dispute period
            minRelayerStake: 10 ether,  // Minimum stake for relayers
            isActive: true
        });
    }

    function _initializeLiquidityPools() internal {
        // ETH pools
        address eth = address(0); // Native ETH
        liquidityPools[11155111][eth] = LiquidityPool({
            token: eth,
            totalLiquidity: 10000 ether, // 10k ETH
            utilizedLiquidity: 1000 ether, // 1k utilized
            utilizationRate: 1000, // 10%
            lpFeeRate: 4, // 0.04%
            relayerFeeRate: 2, // 0.02%
            isActive: true
        });

        liquidityPools[421614][eth] = LiquidityPool({
            token: eth,
            totalLiquidity: 8000 ether, // 8k ETH
            utilizedLiquidity: 800 ether, // 800 utilized
            utilizationRate: 1000, // 10%
            lpFeeRate: 4,
            relayerFeeRate: 2,
            isActive: true
        });

        liquidityPools[80001][eth] = LiquidityPool({
            token: eth,
            totalLiquidity: 6000 ether, // 6k ETH
            utilizedLiquidity: 600 ether, // 600 utilized
            utilizationRate: 1000, // 10%
            lpFeeRate: 4,
            relayerFeeRate: 2,
            isActive: true
        });

        // USDC pools
        address usdc = address(0x1);
        liquidityPools[11155111][usdc] = LiquidityPool({
            token: usdc,
            totalLiquidity: 2000000 ether, // 2M USDC
            utilizedLiquidity: 200000 ether, // 200k utilized
            utilizationRate: 1000, // 10%
            lpFeeRate: 4, // 0.04%
            relayerFeeRate: 2, // 0.02%
            isActive: true
        });

        liquidityPools[421614][usdc] = LiquidityPool({
            token: usdc,
            totalLiquidity: 1500000 ether, // 1.5M USDC
            utilizedLiquidity: 150000 ether, // 150k utilized
            utilizationRate: 1000, // 10%
            lpFeeRate: 4,
            relayerFeeRate: 2,
            isActive: true
        });

        liquidityPools[80001][usdc] = LiquidityPool({
            token: usdc,
            totalLiquidity: 1000000 ether, // 1M USDC
            utilizedLiquidity: 100000 ether, // 100k utilized
            utilizationRate: 1000, // 10%
            lpFeeRate: 4,
            relayerFeeRate: 2,
            isActive: true
        });

        // WETH pools
        address weth = address(0x2);
        liquidityPools[11155111][weth] = LiquidityPool({
            token: weth,
            totalLiquidity: 5000 ether, // 5k WETH
            utilizedLiquidity: 500 ether, // 500 utilized
            utilizationRate: 1000, // 10%
            lpFeeRate: 4,
            relayerFeeRate: 2,
            isActive: true
        });

        liquidityPools[421614][weth] = LiquidityPool({
            token: weth,
            totalLiquidity: 4000 ether, // 4k WETH
            utilizedLiquidity: 400 ether, // 400 utilized
            utilizationRate: 1000, // 10%
            lpFeeRate: 4,
            relayerFeeRate: 2,
            isActive: true
        });

        liquidityPools[80001][weth] = LiquidityPool({
            token: weth,
            totalLiquidity: 3000 ether, // 3k WETH
            utilizedLiquidity: 300 ether, // 300 utilized
            utilizationRate: 1000, // 10%
            lpFeeRate: 4,
            relayerFeeRate: 2,
            isActive: true
        });
    }

    function _initializeRelayers() internal {
        // Relayer 1
        address relayer1 = address(0x101);
        relayers[relayer1] = Relayer({
            relayerAddress: relayer1,
            stake: 100 ether,
            reputation: 95,
            successfulRelays: 950,
            totalRelays: 1000,
            isActive: true
        });
        activeRelayers.push(relayer1);

        // Relayer 2
        address relayer2 = address(0x102);
        relayers[relayer2] = Relayer({
            relayerAddress: relayer2,
            stake: 150 ether,
            reputation: 98,
            successfulRelays: 980,
            totalRelays: 1000,
            isActive: true
        });
        activeRelayers.push(relayer2);

        // Relayer 3
        address relayer3 = address(0x103);
        relayers[relayer3] = Relayer({
            relayerAddress: relayer3,
            stake: 80 ether,
            reputation: 92,
            successfulRelays: 920,
            totalRelays: 1000,
            isActive: true
        });
        activeRelayers.push(relayer3);
    }

    function getBridgeName() external pure override returns (string memory) {
        return "Across Protocol";
    }

    function supportsRoute(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (bool supported) {
        // Across supports same token transfers
        if (tokenIn != tokenOut) return false;
        
        // Check if both chains have active pools for this token
        LiquidityPool memory srcPool = liquidityPools[srcChainId][tokenIn];
        LiquidityPool memory dstPool = liquidityPools[dstChainId][tokenOut];
        
        return srcPool.isActive && dstPool.isActive;
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

        LiquidityPool memory dstPool = liquidityPools[dstChainId][tokenOut];
        
        // Calculate dynamic fees based on utilization
        uint256 lpFee = (amount * dstPool.lpFeeRate) / 10000;
        uint256 relayerFee = (amount * dstPool.relayerFeeRate) / 10000;
        uint256 bridgeFee = config.baseFee + lpFee + relayerFee;

        // Estimate gas cost (very low for Across)
        uint256 estimatedGas = _estimateGasCost(srcChainId, dstChainId);
        
        // Available liquidity
        uint256 availableLiquidity = dstPool.totalLiquidity - dstPool.utilizedLiquidity;
        
        // Very high success rate due to optimistic model
        uint256 successRate = totalTransfers > 0 ? 
            (successfulTransfers * 100) / totalTransfers : 99;

        // Calculate congestion based on utilization
        uint256 congestionLevel = dstPool.utilizationRate / 100; // Convert from basis points

        return RouteMetrics({
            estimatedGasCost: estimatedGas,
            bridgeFee: bridgeFee,
            totalCostWei: estimatedGas + bridgeFee,
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
        LiquidityPool storage dstPool = liquidityPools[route.dstChainId][route.tokenOut];
        uint256 availableLiquidity = dstPool.totalLiquidity - dstPool.utilizedLiquidity;
        
        if (availableLiquidity < route.amountIn) revert InsufficientLiquidity();

        // Check active relayers
        if (activeRelayers.length == 0) revert NoActiveRelayers();

        // Generate transfer ID
        transferId = keccak256(abi.encodePacked(
            "ACROSS", msg.sender, recipient, route.amountIn, 
            route.srcChainId, route.dstChainId, block.timestamp
        ));

        // Handle token transfer
        if (route.tokenIn != address(0)) {
            IERC20(route.tokenIn).safeTransferFrom(msg.sender, address(this), route.amountIn);
        } else {
            require(msg.value >= route.amountIn, "Insufficient ETH");
        }

        // Update pool utilization
        dstPool.utilizedLiquidity += route.amountIn;
        dstPool.utilizationRate = (dstPool.utilizedLiquidity * 10000) / dstPool.totalLiquidity;

        // Select best relayer
        address selectedRelayer = _selectBestRelayer();
        
        // Calculate fees
        uint256 lpFee = (route.amountIn * dstPool.lpFeeRate) / 10000;
        uint256 relayerFee = (route.amountIn * dstPool.relayerFeeRate) / 10000;

        // Create relay request
        relayRequests[transferId] = RelayRequest({
            transferId: transferId,
            sender: msg.sender,
            recipient: recipient,
            token: route.tokenOut,
            amount: route.amountIn,
            originChainId: route.srcChainId,
            destinationChainId: route.dstChainId,
            relayerFee: relayerFee,
            lpFee: lpFee,
            timestamp: block.timestamp,
            assignedRelayer: selectedRelayer,
            isRelayed: false,
            isDisputed: false
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

        // Simulate fast relay
        _simulateRelay(transferId, selectedRelayer);

        emit TransferInitiated(transferId, msg.sender, recipient, route);
        emit RelayRequested(transferId, selectedRelayer, relayerFee);

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
        
        LiquidityPool memory dstPool = liquidityPools[dstChainId][tokenOut];
        return dstPool.totalLiquidity - dstPool.utilizedLiquidity;
    }

    function getSuccessRate(
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 successRate) {
        // Across has very high success rate due to optimistic model
        return 99;
    }

    function isHealthy() external view override returns (bool healthy) {
        return healthyStatus && config.isActive && activeRelayers.length > 0;
    }

    function getTransferLimits(
        address token,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 minAmount, uint256 maxAmount) {
        if (!this.supportsRoute(token, token, srcChainId, dstChainId)) {
            return (0, 0);
        }
        
        LiquidityPool memory dstPool = liquidityPools[dstChainId][token];
        uint256 availableLiquidity = dstPool.totalLiquidity - dstPool.utilizedLiquidity;
        uint256 dynamicMax = availableLiquidity < config.maxTransferAmount ? 
            availableLiquidity : config.maxTransferAmount;
        
        return (config.minTransferAmount, dynamicMax);
    }

    // Internal functions

    function _estimateGasCost(uint256 srcChainId, uint256 dstChainId) internal pure returns (uint256 gasCost) {
        // Across has very low gas costs due to optimistic relaying
        return 0.0005 ether; // Flat low cost
    }

    function _selectBestRelayer() internal view returns (address relayer) {
        uint256 bestScore = 0;
        address bestRelayer = activeRelayers[0];
        
        for (uint256 i = 0; i < activeRelayers.length; i++) {
            Relayer memory rel = relayers[activeRelayers[i]];
            if (!rel.isActive) continue;
            
            // Score based on reputation and stake
            uint256 score = rel.reputation + (rel.stake / 1 ether);
            if (score > bestScore) {
                bestScore = score;
                bestRelayer = activeRelayers[i];
            }
        }
        
        return bestRelayer;
    }

    function _simulateRelay(bytes32 transferId, address relayerAddress) internal {
        transfers[transferId].status = TransferStatus.CONFIRMED;
        
        Relayer storage relayer = relayers[relayerAddress];
        
        // Success rate based on relayer reputation
        bool success = (uint256(keccak256(abi.encodePacked(transferId, block.timestamp))) % 100) < relayer.reputation;
        
        if (success) {
            relayRequests[transferId].isRelayed = true;
            transfers[transferId].status = TransferStatus.COMPLETED;
            transfers[transferId].completedAt = block.timestamp + config.avgCompletionTime;
            
            // Update relayer stats
            relayer.successfulRelays++;
            relayer.totalRelays++;
            relayer.reputation = (relayer.successfulRelays * 100) / relayer.totalRelays;
            
            successfulTransfers++;
            emit TransferCompleted(transferId, transfers[transferId].route.amountOut, 0, config.avgCompletionTime);
            emit RelayCompleted(transferId, relayerAddress);
        } else {
            transfers[transferId].status = TransferStatus.FAILED;
            relayer.totalRelays++;
            relayer.reputation = (relayer.successfulRelays * 100) / relayer.totalRelays;
            
            emit TransferFailed(transferId, "Relay failed");
        }
    }

    // Admin functions

    function updateConfig(BridgeConfig memory newConfig) external onlyOwner {
        config = newConfig;
    }

    function addLiquidity(
        uint256 chainId,
        address token,
        uint256 amount
    ) external onlyOwner {
        LiquidityPool storage pool = liquidityPools[chainId][token];
        pool.totalLiquidity += amount;
        pool.utilizationRate = (pool.utilizedLiquidity * 10000) / pool.totalLiquidity;
        
        emit LiquidityAdded(chainId, token, amount);
    }

    function registerRelayer(address relayerAddress, uint256 stake) external onlyOwner {
        if (stake < config.minRelayerStake) revert InsufficientRelayerStake();
        
        relayers[relayerAddress] = Relayer({
            relayerAddress: relayerAddress,
            stake: stake,
            reputation: 100, // Start with perfect reputation
            successfulRelays: 0,
            totalRelays: 0,
            isActive: true
        });
        
        activeRelayers.push(relayerAddress);
        emit RelayerRegistered(relayerAddress, stake);
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

    function getLiquidityPool(uint256 chainId, address token) external view returns (LiquidityPool memory pool) {
        return liquidityPools[chainId][token];
    }

    function getRelayer(address relayerAddress) external view returns (Relayer memory relayer) {
        return relayers[relayerAddress];
    }

    function getRelayRequest(bytes32 transferId) external view returns (RelayRequest memory request) {
        return relayRequests[transferId];
    }

    receive() external payable {}
}