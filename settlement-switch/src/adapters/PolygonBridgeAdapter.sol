// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PolygonBridgeAdapter is IBridgeAdapter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Polygon bridge token mapping
    struct TokenMapping {
        address rootToken;          // Ethereum token address
        address childToken;         // Polygon token address
        bool isSupported;           // Whether mapping is active
        uint256 minAmount;          // Minimum transfer amount
        uint256 maxAmount;          // Maximum transfer amount
        uint256 dailyLimit;         // Daily transfer limit
        uint256 dailyTransferred;   // Amount transferred today
        uint256 lastResetTime;      // Last daily limit reset time
    }

    /// @notice Checkpoint system for exit proofs
    struct Checkpoint {
        uint256 blockNumber;        // Block number
        bytes32 rootHash;           // Merkle root hash
        uint256 timestamp;          // Checkpoint timestamp
        bool isFinalized;           // Whether checkpoint is finalized
    }

    /// @notice Exit proof for withdrawals
    struct ExitProof {
        bytes32 transferId;         // Transfer ID
        bytes32[] merkleProof;      // Merkle proof
        uint256 checkpointIndex;    // Checkpoint index
        bool isProcessed;           // Whether exit is processed
        uint256 exitableAt;         // When exit becomes available
    }

    /// @notice Bridge state variables
    mapping(address => TokenMapping) public tokenMappings;
    mapping(bytes32 => Transfer) public transfers;
    mapping(bytes32 => ExitProof) public exitProofs;
    mapping(uint256 => Checkpoint) public checkpoints;
    
    bytes32[] public transferHistory;
    address[] public supportedTokens;
    
    uint256 public currentCheckpoint;
    uint256 public checkpointInterval = 256; // blocks
    uint256 public challengePeriod = 604800; // 7 days in seconds

    /// @notice Bridge performance metrics
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
        uint256 avgDepositTime;     // Average deposit time (ETH -> Polygon)
        uint256 avgWithdrawTime;    // Average withdrawal time (Polygon -> ETH)
        bool isActive;              // Whether bridge is active
    }

    BridgeConfig public config;

    // Events
    event TokenMappingAdded(address indexed rootToken, address indexed childToken);
    event DepositInitiated(bytes32 indexed transferId, address indexed user, uint256 amount);
    event WithdrawalInitiated(bytes32 indexed transferId, address indexed user, uint256 amount);
    event CheckpointSubmitted(uint256 indexed checkpointId, bytes32 rootHash);
    event ExitProcessed(bytes32 indexed transferId, address indexed user);

    // Errors
    error UnsupportedRoute();
    error TokenNotMapped();
    error TransferAmountTooLow();
    error TransferAmountTooHigh();
    error DailyLimitExceeded();
    error BridgeInactive();
    error InvalidExitProof();
    error ExitNotReady();
    error ExitAlreadyProcessed();

    constructor() Ownable(msg.sender) {
        _initializeConfig();
        _initializeTokenMappings();
        _initializeCheckpoints();
    }

    function _initializeConfig() internal {
        config = BridgeConfig({
            baseFee: 0.005 ether,       // Higher base fee due to Ethereum gas costs
            feePercentage: 0,           // No percentage fee for native bridge
            minTransferAmount: 0.01 ether, // 0.01 ETH minimum
            maxTransferAmount: 1000 ether,  // 1000 ETH maximum
            avgDepositTime: 1800,       // 30 minutes for deposits
            avgWithdrawTime: 604800,    // 7 days for withdrawals (challenge period)
            isActive: true
        });
    }

    function _initializeTokenMappings() internal {
        // ETH mapping
        address ethToken = address(0);
        address maticToken = address(0x3); // Mock MATIC address
        
        tokenMappings[ethToken] = TokenMapping({
            rootToken: ethToken,
            childToken: maticToken,
            isSupported: true,
            minAmount: 0.01 ether,
            maxAmount: 1000 ether,
            dailyLimit: 10000 ether,
            dailyTransferred: 0,
            lastResetTime: block.timestamp
        });

        supportedTokens.push(ethToken);

        // USDC mapping
        address rootUSDC = address(0x1); // Mock root USDC
        address childUSDC = address(0x4); // Mock child USDC
        
        tokenMappings[rootUSDC] = TokenMapping({
            rootToken: rootUSDC,
            childToken: childUSDC,
            isSupported: true,
            minAmount: 1 ether, // 1 USDC
            maxAmount: 1000000 ether, // 1M USDC
            dailyLimit: 5000000 ether, // 5M USDC daily
            dailyTransferred: 0,
            lastResetTime: block.timestamp
        });

        supportedTokens.push(rootUSDC);

        // WETH mapping
        address rootWETH = address(0x2); // Mock root WETH
        address childWETH = address(0x5); // Mock child WETH
        
        tokenMappings[rootWETH] = TokenMapping({
            rootToken: rootWETH,
            childToken: childWETH,
            isSupported: true,
            minAmount: 0.01 ether,
            maxAmount: 1000 ether,
            dailyLimit: 5000 ether,
            dailyTransferred: 0,
            lastResetTime: block.timestamp
        });

        supportedTokens.push(rootWETH);
    }

    function _initializeCheckpoints() internal {
        // Initialize genesis checkpoint
        checkpoints[0] = Checkpoint({
            blockNumber: block.number,
            rootHash: keccak256(abi.encodePacked("genesis")),
            timestamp: block.timestamp,
            isFinalized: true
        });
        currentCheckpoint = 0;
    }

    function getBridgeName() external pure override returns (string memory) {
        return "Polygon PoS Bridge";
    }

    function supportsRoute(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (bool supported) {
        // Only supports ETH <-> Polygon routes
        bool isEthToPolygon = (srcChainId == 11155111 && dstChainId == 80001) || 
                             (srcChainId == 1 && dstChainId == 137);
        bool isPolygonToEth = (srcChainId == 80001 && dstChainId == 11155111) || 
                             (srcChainId == 137 && dstChainId == 1);
        
        if (!isEthToPolygon && !isPolygonToEth) return false;

        // Check token mapping
        TokenMapping memory tokenMapping = tokenMappings[tokenIn];
        if (!tokenMapping.isSupported) return false;

        // For ETH -> Polygon: tokenOut should be child token
        // For Polygon -> ETH: tokenOut should be root token
        if (isEthToPolygon) {
            return tokenOut == tokenMapping.childToken;
        } else {
            return tokenOut == tokenMapping.rootToken;
        }
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

        TokenMapping memory tokenMapping = tokenMappings[tokenIn];
        
        // Calculate fees (only base fee for native bridge)
        uint256 bridgeFee = config.baseFee;
        uint256 estimatedGas = _estimateGasCost(srcChainId, dstChainId);
        
        // Determine transfer time based on direction
        bool isDeposit = (srcChainId == 11155111 || srcChainId == 1);
        uint256 estimatedTime = isDeposit ? config.avgDepositTime : config.avgWithdrawTime;
        
        // Available liquidity is effectively unlimited for native bridge
        uint256 availableLiquidity = tokenMapping.dailyLimit - tokenMapping.dailyTransferred;
        
        // High success rate for native bridge
        uint256 successRate = totalTransfers > 0 ? 
            (successfulTransfers * 100) / totalTransfers : 99;

        // Low congestion for native bridge
        uint256 utilizationRate = tokenMapping.dailyLimit > 0 ? 
            (tokenMapping.dailyTransferred * 100) / tokenMapping.dailyLimit : 0;
        uint256 congestionLevel = utilizationRate > 80 ? 
            ((utilizationRate - 80) * 100) / 20 : 0;

        return RouteMetrics({
            estimatedGasCost: estimatedGas,
            bridgeFee: bridgeFee,
            totalCostWei: estimatedGas + bridgeFee,
            estimatedTimeMinutes: estimatedTime / 60,
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

        TokenMapping storage tokenMapping = tokenMappings[route.tokenIn];
        if (!tokenMapping.isSupported) revert TokenNotMapped();

        // Reset daily limit if needed
        if (block.timestamp >= tokenMapping.lastResetTime + 1 days) {
            tokenMapping.dailyTransferred = 0;
            tokenMapping.lastResetTime = block.timestamp;
        }

        // Validate amounts and limits
        if (route.amountIn < tokenMapping.minAmount) revert TransferAmountTooLow();
        if (route.amountIn > tokenMapping.maxAmount) revert TransferAmountTooHigh();
        if (tokenMapping.dailyTransferred + route.amountIn > tokenMapping.dailyLimit) {
            revert DailyLimitExceeded();
        }

        // Generate transfer ID
        transferId = keccak256(abi.encodePacked(
            "POLYGON", msg.sender, recipient, route.amountIn, 
            route.srcChainId, route.dstChainId, block.timestamp
        ));

        // Handle token transfer
        if (route.tokenIn != address(0)) {
            IERC20(route.tokenIn).safeTransferFrom(msg.sender, address(this), route.amountIn);
        } else {
            require(msg.value >= route.amountIn + config.baseFee, "Insufficient ETH");
        }

        // Update daily transferred amount
        tokenMapping.dailyTransferred += route.amountIn;

        // Determine if this is a deposit or withdrawal
        bool isDeposit = (route.srcChainId == 11155111 || route.srcChainId == 1);

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

        if (isDeposit) {
            // Simulate deposit (ETH -> Polygon)
            _simulateDeposit(transferId);
            emit DepositInitiated(transferId, msg.sender, route.amountIn);
        } else {
            // Simulate withdrawal (Polygon -> ETH)
            _simulateWithdrawal(transferId);
            emit WithdrawalInitiated(transferId, msg.sender, route.amountIn);
        }

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
        if (!this.supportsRoute(tokenIn, tokenOut, srcChainId, dstChainId)) {
            return 0;
        }
        
        TokenMapping memory tokenMapping = tokenMappings[tokenIn];
        return tokenMapping.dailyLimit - tokenMapping.dailyTransferred;
    }

    function getSuccessRate(
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 successRate) {
        // Native bridge has very high success rate
        return 99;
    }

    function isHealthy() external view override returns (bool healthy) {
        return healthyStatus && config.isActive;
    }

    function getTransferLimits(
        address token,
        uint256 srcChainId,
        uint256 dstChainId
    ) external view override returns (uint256 minAmount, uint256 maxAmount) {
        if (!this.supportsRoute(token, token, srcChainId, dstChainId)) {
            return (0, 0);
        }
        
        TokenMapping memory tokenMapping = tokenMappings[token];
        return (tokenMapping.minAmount, tokenMapping.maxAmount);
    }

    // Internal functions

    function _estimateGasCost(uint256 srcChainId, uint256 dstChainId) internal pure returns (uint256 gasCost) {
        // Deposits (ETH -> Polygon) have higher gas costs
        bool isDeposit = (srcChainId == 11155111 || srcChainId == 1);
        
        if (isDeposit) {
            return 0.008 ether; // Higher gas cost for Ethereum transactions
        } else {
            return 0.001 ether; // Lower gas cost for Polygon transactions
        }
    }

    function _simulateDeposit(bytes32 transferId) internal {
        // Deposits are faster and more reliable
        transfers[transferId].status = TransferStatus.CONFIRMED;
        
        // 99.5% success rate for deposits
        bool success = (uint256(keccak256(abi.encodePacked(transferId, block.timestamp))) % 1000) < 995;
        
        if (success) {
            transfers[transferId].status = TransferStatus.COMPLETED;
            transfers[transferId].completedAt = block.timestamp + config.avgDepositTime;
            successfulTransfers++;
            emit TransferCompleted(transferId, transfers[transferId].route.amountOut, 0, config.avgDepositTime);
        } else {
            transfers[transferId].status = TransferStatus.FAILED;
            emit TransferFailed(transferId, "Deposit failed on Polygon");
        }
    }

    function _simulateWithdrawal(bytes32 transferId) internal {
        // Withdrawals require checkpoint and challenge period
        transfers[transferId].status = TransferStatus.CONFIRMED;
        
        // Create exit proof
        exitProofs[transferId] = ExitProof({
            transferId: transferId,
            merkleProof: new bytes32[](0), // Simplified
            checkpointIndex: currentCheckpoint,
            isProcessed: false,
            exitableAt: block.timestamp + challengePeriod
        });
        
        // 99% success rate for withdrawals (slightly lower due to complexity)
        bool success = (uint256(keccak256(abi.encodePacked(transferId, block.timestamp))) % 100) < 99;
        
        if (success) {
            // Withdrawal will be completed after challenge period
            transfers[transferId].status = TransferStatus.COMPLETED;
            transfers[transferId].completedAt = block.timestamp + config.avgWithdrawTime;
            successfulTransfers++;
            emit TransferCompleted(transferId, transfers[transferId].route.amountOut, 0, config.avgWithdrawTime);
        } else {
            transfers[transferId].status = TransferStatus.FAILED;
            emit TransferFailed(transferId, "Withdrawal proof invalid");
        }
    }

    function submitCheckpoint(bytes32 rootHash) external onlyOwner {
        currentCheckpoint++;
        checkpoints[currentCheckpoint] = Checkpoint({
            blockNumber: block.number,
            rootHash: rootHash,
            timestamp: block.timestamp,
            isFinalized: false
        });
        
        // Finalize previous checkpoint
        if (currentCheckpoint > 0) {
            checkpoints[currentCheckpoint - 1].isFinalized = true;
        }
        
        emit CheckpointSubmitted(currentCheckpoint, rootHash);
    }

    function processExit(bytes32 transferId) external nonReentrant {
        ExitProof storage exitProof = exitProofs[transferId];
        Transfer storage transfer = transfers[transferId];
        
        if (exitProof.transferId == bytes32(0)) revert InvalidExitProof();
        if (exitProof.isProcessed) revert ExitAlreadyProcessed();
        if (block.timestamp < exitProof.exitableAt) revert ExitNotReady();
        
        // Mark as processed
        exitProof.isProcessed = true;
        transfer.status = TransferStatus.COMPLETED;
        transfer.completedAt = block.timestamp;
        
        // Transfer tokens to recipient
        if (transfer.route.tokenOut != address(0)) {
            IERC20(transfer.route.tokenOut).safeTransfer(transfer.recipient, transfer.route.amountOut);
        } else {
            payable(transfer.recipient).transfer(transfer.route.amountOut);
        }
        
        emit ExitProcessed(transferId, transfer.recipient);
    }

    // Admin functions

    function updateConfig(BridgeConfig memory newConfig) external onlyOwner {
        config = newConfig;
    }

    function addTokenMapping(
        address rootToken,
        address childToken,
        TokenMapping memory tokenMapping
    ) external onlyOwner {
        tokenMappings[rootToken] = tokenMapping;
        supportedTokens.push(rootToken);
        emit TokenMappingAdded(rootToken, childToken);
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

    function getTokenMapping(address token) external view returns (TokenMapping memory tokenMapping) {
        return tokenMappings[token];
    }

    function getExitProof(bytes32 transferId) external view returns (ExitProof memory exitProof) {
        return exitProofs[transferId];
    }

    function getCheckpoint(uint256 checkpointId) external view returns (Checkpoint memory checkpoint) {
        return checkpoints[checkpointId];
    }

    receive() external payable {}
}