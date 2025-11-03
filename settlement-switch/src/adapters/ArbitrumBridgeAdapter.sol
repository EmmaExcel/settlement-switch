// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ArbitrumBridgeAdapter is IBridgeAdapter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Arbitrum bridge configuration
    struct BridgeConfig {
        uint256 baseFee;            // Base fee in Wei
        uint256 feePercentage;      // Fee percentage in basis points
        uint256 minTransferAmount;  // Minimum transfer amount
        uint256 maxTransferAmount;  // Maximum transfer amount
        uint256 avgDepositTime;     // Average deposit time (ETH -> Arbitrum)
        uint256 avgWithdrawTime;    // Average withdrawal time (Arbitrum -> ETH)
        uint256 challengePeriod;    // Challenge period for withdrawals
        bool isActive;              // Whether bridge is active
    }

    /// @notice Retryable ticket for L1 to L2 transfers
    struct RetryableTicket {
        bytes32 transferId;         // Associated transfer ID
        address sender;             // Sender address
        address recipient;          // Recipient address
        uint256 amount;             // Transfer amount
        uint256 maxGas;             // Maximum gas for L2 execution
        uint256 gasPriceBid;        // Gas price bid
        uint256 submissionFee;      // Submission fee
        uint256 createdAt;          // Creation timestamp
        bool isRedeemed;            // Whether ticket is redeemed
        bool isExpired;             // Whether ticket is expired
    }

    /// @notice Withdrawal proof for L2 to L1 transfers
    struct WithdrawalProof {
        bytes32 transferId;         // Transfer ID
        uint256 batchNumber;        // Batch number
        bytes32[] merkleProof;      // Merkle proof
        uint256 challengeableUntil; // Challenge deadline
        bool isChallenged;          // Whether withdrawal is challenged
        bool isConfirmed;           // Whether withdrawal is confirmed
    }

    // State variables
    mapping(bytes32 => Transfer) public transfers;
    mapping(bytes32 => RetryableTicket) public retryableTickets;
    mapping(bytes32 => WithdrawalProof) public withdrawalProofs;
    
    bytes32[] public transferHistory;
    uint256 public currentBatch;
    uint256 public totalTransfers;
    uint256 public successfulTransfers;
    uint256 public totalVolume;
    uint256 public lastHealthCheck;
    bool public healthyStatus = true;

    BridgeConfig public config;

    // Events
    event RetryableTicketCreated(bytes32 indexed transferId, bytes32 indexed ticketId);
    event WithdrawalInitiated(bytes32 indexed transferId, uint256 batchNumber);
    event WithdrawalChallenged(bytes32 indexed transferId, address challenger);
    event WithdrawalConfirmed(bytes32 indexed transferId);

    // Errors
    error UnsupportedRoute();
    error TransferAmountTooLow();
    error TransferAmountTooHigh();
    error BridgeInactive();
    error InsufficientFee();
    error TicketExpired();
    error WithdrawalChallengedError();
    error WithdrawalNotReady();

    constructor() Ownable(msg.sender) {
        _initializeConfig();
    }

    function _initializeConfig() internal {
        config = BridgeConfig({
            baseFee: 0.003 ether,       // Moderate base fee
            feePercentage: 0,           // No percentage fee for native bridge
            minTransferAmount: 0.001 ether, // 0.001 ETH minimum
            maxTransferAmount: 5000 ether,  // 5000 ETH maximum
            avgDepositTime: 900,        // 15 minutes for deposits
            avgWithdrawTime: 604800,    // 7 days for withdrawals (challenge period)
            challengePeriod: 604800,    // 7 days challenge period
            isActive: true
        });
    }

    function getBridgeName() external pure override returns (string memory) {
        return "Arbitrum Native Bridge";
    }

    function supportsRoute(
        address tokenIn,
        address tokenOut,
        uint256 srcChainId,
        uint256 dstChainId
    ) external pure override returns (bool supported) {
        // Only supports ETH <-> Arbitrum routes
        bool isEthToArb = (srcChainId == 11155111 && dstChainId == 421614) || 
                         (srcChainId == 1 && dstChainId == 42161);
        bool isArbToEth = (srcChainId == 421614 && dstChainId == 11155111) || 
                         (srcChainId == 42161 && dstChainId == 1);
        
        if (!isEthToArb && !isArbToEth) return false;

        // For simplicity, only support ETH transfers (tokenIn == tokenOut == address(0))
        return tokenIn == address(0) && tokenOut == address(0);
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
        uint256 bridgeFee = config.baseFee;
        uint256 estimatedGas = _estimateGasCost(srcChainId, dstChainId);
        
        // Determine transfer time based on direction
        bool isDeposit = (srcChainId == 11155111 || srcChainId == 1);
        uint256 estimatedTime = isDeposit ? config.avgDepositTime : config.avgWithdrawTime;
        
        // Arbitrum has high liquidity capacity
        uint256 availableLiquidity = 100000 ether; // Mock high liquidity
        
        // High success rate for native bridge
        uint256 successRate = totalTransfers > 0 ? 
            (successfulTransfers * 100) / totalTransfers : 98;

        // Low congestion for Arbitrum
        uint256 congestionLevel = 10; // Generally low congestion

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

        if (route.amountIn < config.minTransferAmount) revert TransferAmountTooLow();
        if (route.amountIn > config.maxTransferAmount) revert TransferAmountTooHigh();

        // Check sufficient ETH for transfer + fees
        if (msg.value < route.amountIn + config.baseFee) revert InsufficientFee();

        // Generate transfer ID
        transferId = keccak256(abi.encodePacked(
            "ARBITRUM", msg.sender, recipient, route.amountIn, 
            route.srcChainId, route.dstChainId, block.timestamp
        ));

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
            // Create retryable ticket for L1 -> L2 transfer
            _createRetryableTicket(transferId, route.amountIn, recipient);
        } else {
            // Initiate withdrawal for L2 -> L1 transfer
            _initiateWithdrawal(transferId, route.amountIn);
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
        return 100000 ether; // Mock high liquidity
    }

    function getSuccessRate(
        uint256 srcChainId,
        uint256 dstChainId
    ) external pure override returns (uint256 successRate) {
        // Arbitrum native bridge has very high success rate
        return 98;
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
        return (config.minTransferAmount, config.maxTransferAmount);
    }

    // Internal functions

    function _estimateGasCost(uint256 srcChainId, uint256 dstChainId) internal pure returns (uint256 gasCost) {
        // Deposits (ETH -> Arbitrum) have higher gas costs
        bool isDeposit = (srcChainId == 11155111 || srcChainId == 1);
        
        if (isDeposit) {
            return 0.005 ether; // Higher gas cost for L1 transactions
        } else {
            return 0.0005 ether; // Lower gas cost for L2 transactions
        }
    }

    function _createRetryableTicket(
        bytes32 transferId,
        uint256 amount,
        address recipient
    ) internal {
        bytes32 ticketId = keccak256(abi.encodePacked(transferId, "ticket"));
        
        retryableTickets[ticketId] = RetryableTicket({
            transferId: transferId,
            sender: msg.sender,
            recipient: recipient,
            amount: amount,
            maxGas: 100000,
            gasPriceBid: 1 gwei,
            submissionFee: 0.001 ether,
            createdAt: block.timestamp,
            isRedeemed: false,
            isExpired: false
        });

        // Simulate automatic redemption
        _simulateTicketRedemption(transferId, ticketId);
        
        emit RetryableTicketCreated(transferId, ticketId);
    }

    function _simulateTicketRedemption(bytes32 transferId, bytes32 ticketId) internal {
        transfers[transferId].status = TransferStatus.CONFIRMED;
        
        // 98% success rate for deposits
        bool success = (uint256(keccak256(abi.encodePacked(transferId, block.timestamp))) % 100) < 98;
        
        if (success) {
            retryableTickets[ticketId].isRedeemed = true;
            transfers[transferId].status = TransferStatus.COMPLETED;
            transfers[transferId].completedAt = block.timestamp + config.avgDepositTime;
            successfulTransfers++;
            emit TransferCompleted(transferId, transfers[transferId].route.amountOut, 0, config.avgDepositTime);
        } else {
            retryableTickets[ticketId].isExpired = true;
            transfers[transferId].status = TransferStatus.FAILED;
            emit TransferFailed(transferId, "Retryable ticket expired");
        }
    }

    function _initiateWithdrawal(bytes32 transferId, uint256 amount) internal {
        currentBatch++;
        
        withdrawalProofs[transferId] = WithdrawalProof({
            transferId: transferId,
            batchNumber: currentBatch,
            merkleProof: new bytes32[](0), // Simplified
            challengeableUntil: block.timestamp + config.challengePeriod,
            isChallenged: false,
            isConfirmed: false
        });

        transfers[transferId].status = TransferStatus.CONFIRMED;
        
        // Simulate withdrawal processing
        _simulateWithdrawalProcessing(transferId);
        
        emit WithdrawalInitiated(transferId, currentBatch);
    }

    function _simulateWithdrawalProcessing(bytes32 transferId) internal {
        // 98% success rate for withdrawals
        bool success = (uint256(keccak256(abi.encodePacked(transferId, block.timestamp))) % 100) < 98;
        
        if (success) {
            transfers[transferId].status = TransferStatus.COMPLETED;
            transfers[transferId].completedAt = block.timestamp + config.avgWithdrawTime;
            withdrawalProofs[transferId].isConfirmed = true;
            successfulTransfers++;
            emit TransferCompleted(transferId, transfers[transferId].route.amountOut, 0, config.avgWithdrawTime);
            emit WithdrawalConfirmed(transferId);
        } else {
            transfers[transferId].status = TransferStatus.FAILED;
            emit TransferFailed(transferId, "Withdrawal proof invalid");
        }
    }

    // Admin functions

    function updateConfig(BridgeConfig memory newConfig) external onlyOwner {
        config = newConfig;
    }

    function updateHealthStatus(bool healthy) external onlyOwner {
        healthyStatus = healthy;
        lastHealthCheck = block.timestamp;
    }

    function challengeWithdrawal(bytes32 transferId) external onlyOwner {
        WithdrawalProof storage proof = withdrawalProofs[transferId];
        if (block.timestamp > proof.challengeableUntil) revert WithdrawalNotReady();
        
        proof.isChallenged = true;
        transfers[transferId].status = TransferStatus.FAILED;
        
        emit WithdrawalChallenged(transferId, msg.sender);
        emit TransferFailed(transferId, "Withdrawal challenged");
    }

    function emergencyWithdraw(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
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

    function getRetryableTicket(bytes32 ticketId) external view returns (RetryableTicket memory ticket) {
        return retryableTickets[ticketId];
    }

    function getWithdrawalProof(bytes32 transferId) external view returns (WithdrawalProof memory proof) {
        return withdrawalProofs[transferId];
    }

    receive() external payable {}
}