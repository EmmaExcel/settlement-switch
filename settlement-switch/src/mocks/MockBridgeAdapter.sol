// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockBridgeAdapter is IBridgeAdapter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Mock bridge configuration
    struct MockConfig {
        string bridgeName;          // Bridge name
        uint256 baseFee;            // Base fee in Wei
        uint256 feePercentage;      // Fee percentage in basis points
        uint256 minAmount;          // Minimum transfer amount
        uint256 maxAmount;          // Maximum transfer amount
        uint256 completionTime;     // Completion time in seconds
        uint256 successRate;        // Success rate (0-100)
        uint256 liquidityAmount;    // Available liquidity
        bool isHealthy;             // Health status
        bool isActive;              // Active status
    }

    /// @notice Failure modes for testing
    enum FailureMode {
        NONE,                       // No failures
        ALWAYS_FAIL,               // Always fail transfers
        RANDOM_FAIL,               // Random failures based on success rate
        INSUFFICIENT_LIQUIDITY,    // Simulate liquidity issues
        HIGH_SLIPPAGE,             // Simulate high slippage
        TIMEOUT,                   // Simulate timeouts
        REVERT_ON_CALL,           // Revert on function calls
        RETURN_ZERO               // Return zero/empty values
    }

    // State variables
    MockConfig public config;
    FailureMode public failureMode = FailureMode.NONE;
    
    mapping(bytes32 => Transfer) public transfers;
    mapping(uint256 => mapping(address => bool)) public supportedRoutes; // chainId => token => supported
    mapping(uint256 => mapping(address => uint256)) public tokenLiquidity; // chainId => token => liquidity
    
    bytes32[] public transferHistory;
    uint256 public totalTransfers;
    uint256 public successfulTransfers;
    uint256 public totalVolume;
    
    // Configurable delays and behaviors
    uint256 public artificialDelay = 0;
    uint256 public gasConsumption = 0;
    bool public shouldRevertOnHealthCheck = false;
    bool public shouldReturnStaleData = false;
    uint256 public customSlippage = 0;
    
    // Events for testing
    event MockTransferExecuted(bytes32 indexed transferId, bool success, string reason);
    event MockConfigUpdated(MockConfig newConfig);
    event FailureModeChanged(FailureMode oldMode, FailureMode newMode);
    event LiquidityUpdated(uint256 chainId, address token, uint256 newLiquidity);

    // Errors
    error MockBridgeInactive();
    error MockInsufficientLiquidity();
    error MockTransferFailed(string reason);
    error MockUnsupportedRoute();
    error MockAmountTooLow();
    error MockAmountTooHigh();

    constructor(
        string memory _bridgeName,
        uint256 _baseFee,
        uint256 _feePercentage,
        uint256 _completionTime
    ) Ownable(msg.sender) {
        config = MockConfig({
            bridgeName: _bridgeName,
            baseFee: _baseFee,
            feePercentage: _feePercentage,
            minAmount: 0.001 ether,
            maxAmount: 1000 ether,
            completionTime: _completionTime,
            successRate: 95, // 95% success rate by default
            liquidityAmount: 10000 ether,
            isHealthy: true,
            isActive: true
        });
        
        _initializeDefaultRoutes();
    }

    function _initializeDefaultRoutes() internal {
        // Support common test tokens on test chains
        address[] memory tokens = new address[](3);
        tokens[0] = address(0x1); // Mock USDC
        tokens[1] = address(0x2); // Mock WETH
        tokens[2] = address(0x0); // ETH
        
        uint256[] memory chains = new uint256[](3);
        chains[0] = 11155111; // Sepolia
        chains[1] = 421614;   // Arbitrum Sepolia
        chains[2] = 80001;    // Mumbai
        
        for (uint256 i = 0; i < chains.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                supportedRoutes[chains[i]][tokens[j]] = true;
                tokenLiquidity[chains[i]][tokens[j]] = config.liquidityAmount;
            }
        }
    }

    function getBridgeName() external view override returns (string memory) {
        if (failureMode == FailureMode.REVERT_ON_CALL) {
            revert MockTransferFailed("Simulated revert on getBridgeName");
        }
        if (failureMode == FailureMode.RETURN_ZERO) {
            return "";
        }
        return config.bridgeName;
    }

    function supportsRoute(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (bool supported) {
        if (failureMode == FailureMode.REVERT_ON_CALL) {
            revert MockTransferFailed("Simulated revert on supportsRoute");
        }
        if (failureMode == FailureMode.RETURN_ZERO) {
            return false;
        }
        
        // Mock bridges typically support same token transfers
        if (tokenIn != tokenOut) return false;
        
        return supportedRoutes[srcChainId][tokenIn] && supportedRoutes[dstChainId][tokenOut];
    }

    function getRouteMetrics(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (RouteMetrics memory metrics) {
        if (failureMode == FailureMode.REVERT_ON_CALL) {
            revert MockTransferFailed("Simulated revert on getRouteMetrics");
        }
        
        if (!this.supportsRoute(tokenIn, tokenOut, srcChainId, dstChainId)) {
            revert MockUnsupportedRoute();
        }

        // Calculate mock fees
        uint256 bridgeFee = config.baseFee + (amount * config.feePercentage / 10000);
        uint256 estimatedGas = _calculateMockGasCost(srcChainId, dstChainId);
        
        // Get available liquidity
        uint256 liquidity = tokenLiquidity[dstChainId][tokenOut];
        
        // Apply failure mode effects
        if (failureMode == FailureMode.INSUFFICIENT_LIQUIDITY) {
            liquidity = amount / 2; // Insufficient liquidity
        }
        if (failureMode == FailureMode.HIGH_SLIPPAGE) {
            bridgeFee = bridgeFee * 3; // 3x higher fees to simulate slippage
        }

        // Calculate congestion based on utilization
        uint256 utilizationRate = liquidity > 0 ? (amount * 100) / liquidity : 100;
        uint256 congestionLevel = utilizationRate > 80 ? 
            ((utilizationRate - 80) * 100) / 20 : 0;

        return RouteMetrics({
            estimatedGasCost: estimatedGas,
            bridgeFee: bridgeFee,
            totalCostWei: estimatedGas + bridgeFee,
            estimatedTimeMinutes: config.completionTime / 60,
            liquidityAvailable: liquidity,
            successRate: config.successRate,
            congestionLevel: congestionLevel
        });
    }

    function executeBridge(
        Route memory route,
        address recipient,
        bytes calldata permitData
    ) external payable override nonReentrant returns (bytes32 transferId) {
        if (failureMode == FailureMode.REVERT_ON_CALL) {
            revert MockTransferFailed("Simulated revert on executeBridge");
        }
        
        if (!config.isActive) revert MockBridgeInactive();
        if (route.amountIn < config.minAmount) revert MockAmountTooLow();
        if (route.amountIn > config.maxAmount) revert MockAmountTooHigh();

        // Check liquidity
        uint256 availableLiquidity = tokenLiquidity[route.dstChainId][route.tokenOut];
        if (availableLiquidity < route.amountIn) revert MockInsufficientLiquidity();

        // Generate transfer ID
        transferId = keccak256(abi.encodePacked(
            config.bridgeName, msg.sender, recipient, route.amountIn, 
            route.srcChainId, route.dstChainId, block.timestamp, totalTransfers
        ));

        // Handle token transfer
        if (route.tokenIn != address(0)) {
            IERC20(route.tokenIn).safeTransferFrom(msg.sender, address(this), route.amountIn);
        } else {
            require(msg.value >= route.amountIn, "Insufficient ETH");
        }

        // Update liquidity
        tokenLiquidity[route.srcChainId][route.tokenIn] += route.amountIn;
        tokenLiquidity[route.dstChainId][route.tokenOut] -= route.amountIn;

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

        // Simulate transfer processing
        _processMockTransfer(transferId);

        emit TransferInitiated(transferId, msg.sender, recipient, route);

        return transferId;
    }

    function _processMockTransfer(bytes32 transferId) internal {
        Transfer storage transfer = transfers[transferId];
        transfer.status = TransferStatus.CONFIRMED;

        bool success = _shouldTransferSucceed();
        string memory reason = "";

        if (failureMode == FailureMode.ALWAYS_FAIL) {
            success = false;
            reason = "Always fail mode enabled";
        } else if (failureMode == FailureMode.TIMEOUT) {
            success = false;
            reason = "Transfer timeout";
        } else if (failureMode == FailureMode.INSUFFICIENT_LIQUIDITY) {
            success = false;
            reason = "Insufficient liquidity";
        } else if (failureMode == FailureMode.HIGH_SLIPPAGE) {
            success = false;
            reason = "Slippage too high";
        }

        if (success) {
            transfer.status = TransferStatus.COMPLETED;
            transfer.completedAt = block.timestamp + config.completionTime;
            successfulTransfers++;
            emit TransferCompleted(transferId, transfer.route.amountOut, 0, config.completionTime);
        } else {
            transfer.status = TransferStatus.FAILED;
            emit TransferFailed(transferId, reason);
        }

        emit MockTransferExecuted(transferId, success, reason);
    }

    function _shouldTransferSucceed() internal view returns (bool success) {
        if (failureMode == FailureMode.RANDOM_FAIL) {
            uint256 random = uint256(keccak256(abi.encodePacked(
                block.timestamp, block.prevrandao, totalTransfers
            ))) % 100;
            return random < config.successRate;
        }
        return failureMode == FailureMode.NONE;
    }

    function _calculateMockGasCost(uint256 srcChainId, uint256 dstChainId) internal view returns (uint256 gasCost) {
        // Base gas cost
        gasCost = 0.001 ether;
        
        // Adjust based on chains
        if (srcChainId == 1 || dstChainId == 1) {
            gasCost = 0.005 ether; // Higher for mainnet
        }
        
        // Add artificial gas consumption if configured
        if (gasConsumption > 0) {
            gasCost += gasConsumption;
        }
        
        return gasCost;
    }

    function getTransfer(bytes32 transferId) external view override returns (Transfer memory transfer) {
        if (failureMode == FailureMode.REVERT_ON_CALL) {
            revert MockTransferFailed("Simulated revert on getTransfer");
        }
        return transfers[transferId];
    }

    function estimateGas(Route memory route) external view override returns (uint256 gasEstimate) {
        if (failureMode == FailureMode.REVERT_ON_CALL) {
            revert MockTransferFailed("Simulated revert on estimateGas");
        }
        return _calculateMockGasCost(route.srcChainId, route.dstChainId);
    }

    function getAvailableLiquidity(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 liquidity) {
        if (failureMode == FailureMode.REVERT_ON_CALL) {
            revert MockTransferFailed("Simulated revert on getAvailableLiquidity");
        }
        if (failureMode == FailureMode.RETURN_ZERO) {
            return 0;
        }
        if (tokenIn != tokenOut) return 0;
        
        liquidity = tokenLiquidity[dstChainId][tokenOut];
        
        if (failureMode == FailureMode.INSUFFICIENT_LIQUIDITY) {
            return liquidity / 10; // Return 10% of actual liquidity
        }
        
        return liquidity;
    }

    function getSuccessRate(
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 successRate) {
        if (failureMode == FailureMode.REVERT_ON_CALL) {
            revert MockTransferFailed("Simulated revert on getSuccessRate");
        }
        if (failureMode == FailureMode.RETURN_ZERO) {
            return 0;
        }
        return config.successRate;
    }

    function isHealthy() external view override returns (bool healthy) {
        if (shouldRevertOnHealthCheck) {
            revert MockTransferFailed("Simulated revert on health check");
        }
        if (failureMode == FailureMode.RETURN_ZERO) {
            return false;
        }
        return config.isHealthy && config.isActive;
    }

    function getTransferLimits(
        address token,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 minAmount, uint256 maxAmount) {
        if (failureMode == FailureMode.REVERT_ON_CALL) {
            revert MockTransferFailed("Simulated revert on getTransferLimits");
        }
        if (failureMode == FailureMode.RETURN_ZERO) {
            return (0, 0);
        }
        if (!supportedRoutes[srcChainId][token] || !supportedRoutes[dstChainId][token]) {
            return (0, 0);
        }
        return (config.minAmount, config.maxAmount);
    }

    // Configuration functions for testing

    function updateConfig(MockConfig memory newConfig) external onlyOwner {
        config = newConfig;
        emit MockConfigUpdated(newConfig);
    }

    function setFailureMode(FailureMode mode) external onlyOwner {
        FailureMode oldMode = failureMode;
        failureMode = mode;
        emit FailureModeChanged(oldMode, mode);
    }

    function addSupportedRoute(uint256 chainId, address token, uint256 liquidity) external onlyOwner {
        supportedRoutes[chainId][token] = true;
        tokenLiquidity[chainId][token] = liquidity;
        emit LiquidityUpdated(chainId, token, liquidity);
    }

    function updateLiquidity(uint256 chainId, address token, uint256 liquidity) external onlyOwner {
        tokenLiquidity[chainId][token] = liquidity;
        emit LiquidityUpdated(chainId, token, liquidity);
    }

    function setArtificialDelay(uint256 delay) external onlyOwner {
        artificialDelay = delay;
    }

    function setGasConsumption(uint256 gas) external onlyOwner {
        gasConsumption = gas;
    }

    function setShouldRevertOnHealthCheck(bool shouldRevert) external onlyOwner {
        shouldRevertOnHealthCheck = shouldRevert;
    }

    function setCustomSlippage(uint256 slippage) external onlyOwner {
        customSlippage = slippage;
    }

    function simulateCongestion(uint256 congestionLevel) external onlyOwner {
        require(congestionLevel <= 100, "Invalid congestion level");
        
        // Increase completion time based on congestion
        config.completionTime = config.completionTime * (100 + congestionLevel) / 100;
        
        // Decrease success rate based on congestion
        if (congestionLevel > 50) {
            config.successRate = config.successRate * (150 - congestionLevel) / 100;
        }
    }

    function forceCompleteTransfer(bytes32 transferId, bool success) external onlyOwner {
        Transfer storage transfer = transfers[transferId];
        require(transfer.transferId != bytes32(0), "Transfer not found");
        
        if (success) {
            transfer.status = TransferStatus.COMPLETED;
            transfer.completedAt = block.timestamp;
            successfulTransfers++;
            emit TransferCompleted(transferId, transfer.route.amountOut, 0, 0);
        } else {
            transfer.status = TransferStatus.FAILED;
            emit TransferFailed(transferId, "Force failed by admin");
        }
    }

    function getBridgeStats() external view returns (
        uint256 _totalTransfers,
        uint256 _successfulTransfers,
        uint256 _totalVolume,
        uint256 _successRate,
        FailureMode _failureMode
    ) {
        _totalTransfers = totalTransfers;
        _successfulTransfers = successfulTransfers;
        _totalVolume = totalVolume;
        _successRate = totalTransfers > 0 ? (successfulTransfers * 100) / totalTransfers : 0;
        _failureMode = failureMode;
    }

    function getTransferHistory() external view returns (bytes32[] memory transferIds) {
        return transferHistory;
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }

    receive() external payable {}
}