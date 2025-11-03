// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LayerZeroAdapter is IBridgeAdapter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice LayerZero chain ID mappings
    mapping(uint256 => uint16) public chainIdToLzChainId;
    mapping(uint16 => uint256) public lzChainIdToChainId;

    /// @notice Supported token pools
    mapping(address => mapping(uint256 => bool)) public supportedTokens;
    mapping(address => mapping(uint256 => uint256)) public tokenLiquidity;

    /// @notice Transfer tracking
    mapping(bytes32 => Transfer) public transfers;
    bytes32[] public transferHistory;

    /// @notice Bridge configuration
    struct BridgeConfig {
        uint256 baseFee;            // Base fee in Wei
        uint256 feePercentage;      // Fee percentage in basis points
        uint256 minTransferAmount;  // Minimum transfer amount
        uint256 maxTransferAmount;  // Maximum transfer amount
        uint256 avgCompletionTime;  // Average completion time in seconds
        bool isActive;              // Whether bridge is active
    }

    BridgeConfig public config;

    /// @notice Performance metrics
    uint256 public totalTransfers;
    uint256 public successfulTransfers;
    uint256 public totalVolume;
    uint256 public lastHealthCheck;
    bool public healthyStatus = true;

    // Events
    event TransferExecuted(bytes32 indexed transferId, address indexed sender, uint256 amount);
    event LiquidityUpdated(address indexed token, uint256 indexed chainId, uint256 newLiquidity);
    event ConfigUpdated(BridgeConfig newConfig);

    // Errors
    error UnsupportedRoute();
    error InsufficientLiquidity();
    error TransferAmountTooLow();
    error TransferAmountTooHigh();
    error BridgeInactive();
    error InvalidChainId();

    constructor() Ownable(msg.sender) {
        _initializeChainMappings();
        _initializeConfig();
        _initializeLiquidity();
    }

    function _initializeChainMappings() internal {
        // Testnet mappings (corrected endpoint IDs)
        chainIdToLzChainId[11155111] = 40161; // Ethereum Sepolia (corrected from 10161)
        chainIdToLzChainId[421614] = 40231;   // Arbitrum Sepolia (corrected from 10231)
        chainIdToLzChainId[80001] = 10109;    // Polygon Mumbai

        // Mainnet mappings (for future use)
        chainIdToLzChainId[1] = 101;      // Ethereum
        chainIdToLzChainId[42161] = 110;  // Arbitrum
        chainIdToLzChainId[137] = 109;    // Polygon

        // Reverse mappings (corrected endpoint IDs)
        lzChainIdToChainId[40161] = 11155111; // Ethereum Sepolia (corrected from 10161)
        lzChainIdToChainId[40231] = 421614;   // Arbitrum Sepolia (corrected from 10231)
        lzChainIdToChainId[10109] = 80001;
        lzChainIdToChainId[101] = 1;
        lzChainIdToChainId[110] = 42161;
        lzChainIdToChainId[109] = 137;
    }

    function _initializeConfig() internal {
        config = BridgeConfig({
            baseFee: 0.002 ether,       // $3-5 equivalent
            feePercentage: 6,           // 0.06%
            minTransferAmount: 0.001 ether, // 0.001 ETH minimum (more reasonable for testing)
            maxTransferAmount: 100000 ether, // $100k maximum
            avgCompletionTime: 900,     // 15 minutes
            isActive: true
        });
    }

    function _initializeLiquidity() internal {
        // Native ETH liquidity
        address eth = address(0); // Native ETH
        tokenLiquidity[eth][11155111] = 10000 ether;    // 10k ETH on Sepolia
        tokenLiquidity[eth][421614] = 8000 ether;       // 8k ETH on Arbitrum Sepolia
        tokenLiquidity[eth][80001] = 6000 ether;        // 6k ETH on Mumbai

        supportedTokens[eth][11155111] = true;
        supportedTokens[eth][421614] = true;
        supportedTokens[eth][80001] = true;

        // Mock USDC liquidity
        address mockUSDC = address(0x1); // Placeholder
        tokenLiquidity[mockUSDC][11155111] = 1000000 ether; // 1M USDC on Sepolia
        tokenLiquidity[mockUSDC][421614] = 500000 ether;    // 500k USDC on Arbitrum Sepolia
        tokenLiquidity[mockUSDC][80001] = 750000 ether;     // 750k USDC on Mumbai

        supportedTokens[mockUSDC][11155111] = true;
        supportedTokens[mockUSDC][421614] = true;
        supportedTokens[mockUSDC][80001] = true;

        // Mock WETH liquidity
        address mockWETH = address(0x2); // Placeholder
        tokenLiquidity[mockWETH][11155111] = 1000 ether;    // 1k WETH on Sepolia
        tokenLiquidity[mockWETH][421614] = 800 ether;       // 800 WETH on Arbitrum Sepolia
        tokenLiquidity[mockWETH][80001] = 600 ether;        // 600 WETH on Mumbai

        supportedTokens[mockWETH][11155111] = true;
        supportedTokens[mockWETH][421614] = true;
        supportedTokens[mockWETH][80001] = true;
    }

    function getBridgeName() external pure override returns (string memory) {
        return "LayerZero Stargate";
    }

    function supportsRoute(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (bool supported) {
        // LayerZero typically transfers same token across chains
        if (tokenIn != tokenOut) return false;
        
        // Check if chains are supported
        if (chainIdToLzChainId[srcChainId] == 0 || chainIdToLzChainId[dstChainId] == 0) {
            return false;
        }

        // Check if token is supported on both chains
        return supportedTokens[tokenIn][srcChainId] && supportedTokens[tokenOut][dstChainId];
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

        // Calculate fees
        uint256 bridgeFee = config.baseFee + (amount * config.feePercentage / 10000);
        uint256 estimatedGas = _estimateGasCost(srcChainId, dstChainId);
        
        // Get available liquidity
        uint256 liquidity = tokenLiquidity[tokenIn][dstChainId];
        
        // Calculate success rate based on historical performance
        uint256 successRate = totalTransfers > 0 ? 
            (successfulTransfers * 100) / totalTransfers : 95;

        // Calculate congestion level (mock based on liquidity utilization)
        uint256 utilizationRate = liquidity > 0 ? (amount * 100) / liquidity : 100;
        uint256 congestionLevel = utilizationRate > 80 ? 
            ((utilizationRate - 80) * 100) / 20 : 0;

        return RouteMetrics({
            estimatedGasCost: estimatedGas,
            bridgeFee: bridgeFee,
            totalCostWei: estimatedGas + bridgeFee,
            estimatedTimeMinutes: config.avgCompletionTime / 60,
            liquidityAvailable: liquidity,
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
        uint256 availableLiquidity = tokenLiquidity[route.tokenOut][route.dstChainId];
        if (availableLiquidity < route.amountIn) revert InsufficientLiquidity();

        // Generate transfer ID
        transferId = keccak256(abi.encodePacked(
            msg.sender, recipient, route.amountIn, route.srcChainId, 
            route.dstChainId, block.timestamp, block.number
        ));

        // Handle token transfer
        if (route.tokenIn != address(0)) {
            IERC20(route.tokenIn).safeTransferFrom(msg.sender, address(this), route.amountIn);
        } else {
            require(msg.value >= route.amountIn, "Insufficient ETH");
        }

        // Update liquidity (simulate cross-chain transfer)
        tokenLiquidity[route.tokenIn][route.srcChainId] += route.amountIn;
        tokenLiquidity[route.tokenOut][route.dstChainId] -= route.amountIn;

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

        // Simulate async completion (in real implementation, this would be handled by LayerZero)
        _simulateAsyncCompletion(transferId);

        emit TransferInitiated(transferId, msg.sender, recipient, route);
        emit TransferExecuted(transferId, msg.sender, route.amountIn);

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
        return tokenLiquidity[tokenOut][dstChainId];
    }

    function getSuccessRate(
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 successRate) {
        // Mock success rate based on chain combination
        if (srcChainId == 11155111 && dstChainId == 421614) return 98; // ETH -> ARB
        if (srcChainId == 11155111 && dstChainId == 80001) return 96;  // ETH -> MATIC
        if (srcChainId == 421614 && dstChainId == 80001) return 97;    // ARB -> MATIC
        return 95; // Default
    }

    function isHealthy() external view override returns (bool healthy) {
        return healthyStatus && config.isActive && (block.timestamp - lastHealthCheck < 3600);
    }

    function getTransferLimits(
        address token,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 minAmount, uint256 maxAmount) {
        if (!supportedTokens[token][srcChainId] || !supportedTokens[token][dstChainId]) {
            return (0, 0);
        }
        return (config.minTransferAmount, config.maxTransferAmount);
    }

    // Internal functions

    function _estimateGasCost(uint256 srcChainId, uint256 dstChainId) internal pure returns (uint256 gasCost) {
        // Mock gas costs based on chain combinations
        if (srcChainId == 11155111) { // From Ethereum
            if (dstChainId == 421614) return 0.003 ether; // To Arbitrum
            if (dstChainId == 80001) return 0.004 ether;  // To Polygon
        } else if (srcChainId == 421614) { // From Arbitrum
            if (dstChainId == 11155111) return 0.001 ether; // To Ethereum
            if (dstChainId == 80001) return 0.002 ether;    // To Polygon
        } else if (srcChainId == 80001) { // From Polygon
            if (dstChainId == 11155111) return 0.005 ether; // To Ethereum
            if (dstChainId == 421614) return 0.003 ether;   // To Arbitrum
        }
        return 0.003 ether; // Default
    }

    function _simulateAsyncCompletion(bytes32 transferId) internal {
        // In a real implementation, this would be handled by LayerZero relayers
        // For testing, we'll mark as completed after a delay
        transfers[transferId].status = TransferStatus.CONFIRMED;
        
        // Simulate 95% success rate
        bool success = (uint256(keccak256(abi.encodePacked(transferId, block.timestamp))) % 100) < 95;
        
        if (success) {
            transfers[transferId].status = TransferStatus.COMPLETED;
            transfers[transferId].completedAt = block.timestamp + config.avgCompletionTime;
            successfulTransfers++;
            emit TransferCompleted(transferId, transfers[transferId].route.amountOut, 0, config.avgCompletionTime);
        } else {
            transfers[transferId].status = TransferStatus.FAILED;
            emit TransferFailed(transferId, "Simulated failure");
        }
    }

    // Admin functions

    function updateConfig(BridgeConfig memory newConfig) external onlyOwner {
        config = newConfig;
        emit ConfigUpdated(newConfig);
    }

    function addSupportedToken(
        address token,
        uint256 chainId,
        uint256 initialLiquidity
    ) external onlyOwner {
        supportedTokens[token][chainId] = true;
        tokenLiquidity[token][chainId] = initialLiquidity;
        emit LiquidityUpdated(token, chainId, initialLiquidity);
    }

    function updateLiquidity(
        address token,
        uint256 chainId,
        uint256 newLiquidity
    ) external onlyOwner {
        tokenLiquidity[token][chainId] = newLiquidity;
        emit LiquidityUpdated(token, chainId, newLiquidity);
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

    function getTransferHistory() external view returns (bytes32[] memory transferIds) {
        return transferHistory;
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

    receive() external payable {}
}