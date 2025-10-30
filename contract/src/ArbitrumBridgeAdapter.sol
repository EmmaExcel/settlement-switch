// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IInbox.sol";

/**
 * @title ArbitrumBridgeAdapter
 * @dev Optimized adapter for Arbitrum native bridge integration
 * @notice Provides direct integration with Arbitrum Inbox for efficient ETH bridging
 * @author Arbitrum Development Team
 */
contract ArbitrumBridgeAdapter is ReentrancyGuard, Ownable, Pausable {
    
    // ============ Constants ============
    
    /// @notice Arbitrum Sepolia Inbox address
    address public constant ARBITRUM_INBOX = 0xaAe29B0366299461418F5324a79Afc425BE5ae21;
    
    /// @notice Arbitrum Mainnet Inbox address
    address public constant ARBITRUM_MAINNET_INBOX = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;
    
    /// @notice Minimum submission cost
    uint256 public constant MIN_SUBMISSION_COST = 0.001 ether;
    
    /// @notice Maximum gas limit
    uint256 public constant MAX_GAS_LIMIT = 10000000;
    
    /// @notice Default gas limit for simple transfers
    uint256 public constant DEFAULT_GAS_LIMIT = 1000000;
    
    /// @notice Gas price multiplier for priority transactions
    uint256 public constant PRIORITY_GAS_MULTIPLIER = 150; // 1.5x

    // ============ State Variables ============
    
    /// @notice Current Arbitrum Inbox being used
    address public currentInbox;
    
    /// @notice Mapping of supported chain IDs to their Inbox addresses
    mapping(uint256 => address) public chainInboxes;
    
    /// @notice Mapping to track transaction status
    mapping(bytes32 => TransactionStatus) public transactionStatus;
    
    /// @notice Mapping to track gas usage statistics
    mapping(address => GasStats) public userGasStats;
    
    /// @notice Total transactions processed
    uint256 public totalTransactions;
    
    /// @notice Total ETH bridged
    uint256 public totalETHBridged;

    // ============ Structs ============
    
    /**
     * @notice Transaction status tracking
     * @param exists Whether transaction exists
     * @param completed Whether transaction is completed
     * @param failed Whether transaction failed
     * @param timestamp Transaction timestamp
     * @param gasUsed Gas used for transaction
     */
    struct TransactionStatus {
        bool exists;
        bool completed;
        bool failed;
        uint256 timestamp;
        uint256 gasUsed;
    }
    
    /**
     * @notice Gas usage statistics per user
     * @param totalTransactions Total transactions by user
     * @param totalGasUsed Total gas used by user
     * @param averageGasUsed Average gas used per transaction
     */
    struct GasStats {
        uint256 totalTransactions;
        uint256 totalGasUsed;
        uint256 averageGasUsed;
    }
    
    /**
     * @notice Bridge parameters for optimized transactions
     * @param to Destination address on L2
     * @param amount Amount to bridge
     * @param gasLimit Gas limit for L2 transaction
     * @param gasPriceBid Gas price bid
     * @param maxSubmissionCost Maximum submission cost
     * @param data Additional call data
     * @param priority Priority level (0 = normal, 1 = high)
     */
    struct OptimizedBridgeParams {
        address to;
        uint256 amount;
        uint256 gasLimit;
        uint256 gasPriceBid;
        uint256 maxSubmissionCost;
        bytes data;
        uint8 priority;
    }

    // ============ Events ============
    
    /**
     * @notice Emitted when a bridge transaction is initiated
     * @param user User initiating the bridge
     * @param to Destination address
     * @param amount Amount being bridged
     * @param ticketId Retryable ticket ID
     * @param gasLimit Gas limit used
     * @param gasPriceBid Gas price bid used
     */
    event BridgeInitiated(
        address indexed user,
        address indexed to,
        uint256 amount,
        uint256 indexed ticketId,
        uint256 gasLimit,
        uint256 gasPriceBid
    );
    
    /**
     * @notice Emitted when bridge parameters are optimized
     * @param user User address
     * @param originalGasLimit Original gas limit
     * @param optimizedGasLimit Optimized gas limit
     * @param gasSaved Gas saved through optimization
     */
    event BridgeOptimized(
        address indexed user,
        uint256 originalGasLimit,
        uint256 optimizedGasLimit,
        uint256 gasSaved
    );
    
    /**
     * @notice Emitted when inbox address is updated
     * @param chainId Chain ID
     * @param oldInbox Old inbox address
     * @param newInbox New inbox address
     */
    event InboxUpdated(
        uint256 indexed chainId,
        address oldInbox,
        address newInbox
    );

    // ============ Errors ============
    
    error InvalidInbox();
    error InvalidAmount();
    error InvalidRecipient();
    error InvalidGasParameters();
    error BridgeTransactionFailed();
    error UnsupportedChain();
    error TransactionAlreadyExists();

    // ============ Constructor ============
    
    /**
     * @notice Initialize the Arbitrum Bridge Adapter
     * @param _owner Address of the contract owner
     */
    constructor(address _owner) Ownable(_owner) {
        if (_owner == address(0)) revert InvalidRecipient();
        
        // Set default inboxes
        chainInboxes[42161] = ARBITRUM_MAINNET_INBOX; // Arbitrum Mainnet
        chainInboxes[421614] = ARBITRUM_INBOX;        // Arbitrum Sepolia
        
        // Set current inbox to Sepolia for testing
        currentInbox = ARBITRUM_INBOX;
    }

    // ============ External Functions ============
    
    /**
     * @notice Bridge ETH to Arbitrum with automatic optimization
     * @param to Destination address on Arbitrum
     * @return ticketId Retryable ticket ID
     */
    function bridgeETH(address to) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        returns (uint256 ticketId) 
    {
        if (to == address(0)) revert InvalidRecipient();
        if (msg.value == 0) revert InvalidAmount();
        
        // Optimize bridge parameters based on user history
        OptimizedBridgeParams memory params = _optimizeBridgeParams(
            to,
            msg.value,
            DEFAULT_GAS_LIMIT,
            tx.gasprice > 0 ? tx.gasprice : 1 gwei,
            MIN_SUBMISSION_COST,
            "",
            0
        );
        
        return _executeBridge(params);
    }
    
    /**
     * @notice Bridge ETH with custom parameters
     * @param params Bridge parameters
     * @return ticketId Retryable ticket ID
     */
    function bridgeETHWithParams(OptimizedBridgeParams calldata params) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        returns (uint256 ticketId) 
    {
        _validateBridgeParams(params);
        return _executeBridge(params);
    }
    
    /**
     * @notice Get optimized bridge parameters for a transaction
     * @param to Destination address
     * @param amount Amount to bridge
     * @param baseGasLimit Base gas limit
     * @param baseGasPrice Base gas price
     * @return params Optimized parameters
     */
    function getOptimizedParams(
        address to,
        uint256 amount,
        uint256 baseGasLimit,
        uint256 baseGasPrice
    ) external view returns (OptimizedBridgeParams memory params) {
        return _optimizeBridgeParams(
            to,
            amount,
            baseGasLimit,
            baseGasPrice,
            MIN_SUBMISSION_COST,
            "",
            0
        );
    }
    
    /**
     * @notice Estimate total bridge cost
     * @param amount Amount to bridge
     * @param gasLimit Gas limit
     * @param gasPriceBid Gas price bid
     * @param maxSubmissionCost Maximum submission cost
     * @return totalCost Total cost including all fees
     */
    function estimateBridgeCost(
        uint256 amount,
        uint256 gasLimit,
        uint256 gasPriceBid,
        uint256 maxSubmissionCost
    ) external pure returns (uint256 totalCost) {
        return amount + maxSubmissionCost + (gasLimit * gasPriceBid);
    }
    
    /**
     * @notice Get user's gas usage statistics
     * @param user User address
     * @return stats Gas usage statistics
     */
    function getUserGasStats(address user) 
        external 
        view 
        returns (GasStats memory stats) 
    {
        return userGasStats[user];
    }
    
    /**
     * @notice Check if a transaction exists and its status
     * @param txHash Transaction hash
     * @return status Transaction status
     */
    function getTransactionStatus(bytes32 txHash) 
        external 
        view 
        returns (TransactionStatus memory status) 
    {
        return transactionStatus[txHash];
    }

    // ============ Internal Functions ============
    
    /**
     * @notice Execute the bridge transaction
     * @param params Bridge parameters
     * @return ticketId Retryable ticket ID
     */
    function _executeBridge(OptimizedBridgeParams memory params) 
        internal 
        returns (uint256 ticketId) 
    {
        // Calculate total cost
        uint256 totalCost = params.amount + params.maxSubmissionCost + 
                           (params.gasLimit * params.gasPriceBid);
        
        if (msg.value < totalCost) revert InvalidAmount();
        
        // Create transaction hash for tracking
        bytes32 txHash = keccak256(abi.encodePacked(
            msg.sender,
            params.to,
            params.amount,
            block.timestamp
        ));
        
        if (transactionStatus[txHash].exists) revert TransactionAlreadyExists();
        
        // Record transaction
        transactionStatus[txHash] = TransactionStatus({
            exists: true,
            completed: false,
            failed: false,
            timestamp: block.timestamp,
            gasUsed: params.gasLimit
        });
        
        // Execute bridge transaction
        try IInbox(currentInbox).createRetryableTicket{value: msg.value}(
            params.to,
            params.amount,
            params.maxSubmissionCost,
            msg.sender, // excessFeeRefundAddress
            msg.sender, // callValueRefundAddress
            params.gasLimit,
            params.gasPriceBid,
            params.data
        ) returns (uint256 _ticketId) {
            ticketId = _ticketId;
            
            // Mark as completed
            transactionStatus[txHash].completed = true;
            
            // Update statistics
            _updateGasStats(msg.sender, params.gasLimit);
            totalTransactions++;
            totalETHBridged += params.amount;
            
            emit BridgeInitiated(
                msg.sender,
                params.to,
                params.amount,
                ticketId,
                params.gasLimit,
                params.gasPriceBid
            );
            
        } catch {
            // Mark as failed
            transactionStatus[txHash].failed = true;
            revert BridgeTransactionFailed();
        }
        
        return ticketId;
    }
    
    /**
     * @notice Optimize bridge parameters based on user history and network conditions
     * @param to Destination address
     * @param amount Amount to bridge
     * @param baseGasLimit Base gas limit
     * @param baseGasPrice Base gas price
     * @param maxSubmissionCost Maximum submission cost
     * @param data Call data
     * @param priority Priority level
     * @return params Optimized parameters
     */
    function _optimizeBridgeParams(
        address to,
        uint256 amount,
        uint256 baseGasLimit,
        uint256 baseGasPrice,
        uint256 maxSubmissionCost,
        bytes memory data,
        uint8 priority
    ) internal view returns (OptimizedBridgeParams memory params) {
        // Get user's historical gas usage
        GasStats memory userStats = userGasStats[msg.sender];
        
        uint256 optimizedGasLimit = baseGasLimit;
        uint256 optimizedGasPrice = baseGasPrice;
        
        // Optimize gas limit based on user history
        if (userStats.totalTransactions > 0 && userStats.averageGasUsed > 0) {
            // Use 110% of user's average gas usage for safety margin
            optimizedGasLimit = (userStats.averageGasUsed * 110) / 100;
            
            // Ensure within bounds
            if (optimizedGasLimit < baseGasLimit) {
                optimizedGasLimit = baseGasLimit;
            }
            if (optimizedGasLimit > MAX_GAS_LIMIT) {
                optimizedGasLimit = MAX_GAS_LIMIT;
            }
        }
        
        // Adjust gas price based on priority
        if (priority == 1) {
            optimizedGasPrice = (baseGasPrice * PRIORITY_GAS_MULTIPLIER) / 100;
        }
        
        // Adjust submission cost based on amount
        uint256 optimizedSubmissionCost = maxSubmissionCost;
        if (amount > 1 ether) {
            // Increase submission cost for larger amounts
            optimizedSubmissionCost = (maxSubmissionCost * 120) / 100;
        }
        
        return OptimizedBridgeParams({
            to: to,
            amount: amount,
            gasLimit: optimizedGasLimit,
            gasPriceBid: optimizedGasPrice,
            maxSubmissionCost: optimizedSubmissionCost,
            data: data,
            priority: priority
        });
    }
    
    /**
     * @notice Validate bridge parameters
     * @param params Bridge parameters to validate
     */
    function _validateBridgeParams(OptimizedBridgeParams calldata params) internal pure {
        if (params.to == address(0)) revert InvalidRecipient();
        if (params.amount == 0) revert InvalidAmount();
        if (params.gasLimit == 0 || params.gasLimit > MAX_GAS_LIMIT) {
            revert InvalidGasParameters();
        }
        if (params.gasPriceBid == 0) revert InvalidGasParameters();
        if (params.priority > 1) revert InvalidGasParameters();
    }
    
    /**
     * @notice Update gas usage statistics for a user
     * @param user User address
     * @param gasUsed Gas used in transaction
     */
    function _updateGasStats(address user, uint256 gasUsed) internal {
        GasStats storage stats = userGasStats[user];
        
        stats.totalTransactions++;
        stats.totalGasUsed += gasUsed;
        stats.averageGasUsed = stats.totalGasUsed / stats.totalTransactions;
    }

    // ============ Administrative Functions ============
    
    /**
     * @notice Set inbox address for a specific chain
     * @param chainId Chain ID
     * @param inboxAddress Inbox address
     */
    function setInboxForChain(uint256 chainId, address inboxAddress) 
        external 
        onlyOwner 
    {
        if (inboxAddress == address(0)) revert InvalidInbox();
        
        address oldInbox = chainInboxes[chainId];
        chainInboxes[chainId] = inboxAddress;
        
        emit InboxUpdated(chainId, oldInbox, inboxAddress);
    }
    
    /**
     * @notice Set current active inbox
     * @param inboxAddress New inbox address
     */
    function setCurrentInbox(address inboxAddress) external onlyOwner {
        if (inboxAddress == address(0)) revert InvalidInbox();
        
        address oldInbox = currentInbox;
        currentInbox = inboxAddress;
        
        emit InboxUpdated(block.chainid, oldInbox, inboxAddress);
    }
    
    /**
     * @notice Emergency pause
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Emergency unpause
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @notice Emergency withdrawal
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert InvalidRecipient();
        
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert BridgeTransactionFailed();
    }

    // ============ Receive Function ============
    
    /**
     * @notice Receive function to accept ETH
     */
    receive() external payable {
        // Allow ETH deposits
    }
}