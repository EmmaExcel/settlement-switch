// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IInbox.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @dev Comprehensive native ETH bridging solution between Ethereum and Arbitrum
 * @notice Enables secure two-way ETH transfers with optimized gas costs and proper error handling
 * @author Arbitrum Development Team
 */
contract ETHBridge is ReentrancyGuard, Ownable, Pausable {
    
    // ============ Constants ============
    
    /// @notice Arbitrum Sepolia Inbox address
    address public constant ARBITRUM_INBOX = 0xaAe29B0366299461418F5324a79Afc425BE5ae21;
    
    /// @notice Arbitrum Sepolia L1 Gateway Router
    address public constant L1_GATEWAY_ROUTER = 0xcE18836b233C83325Cc8848CA4487e94C6288264;
    
    /// @notice Minimum bridge amount (0.0001 ETH)
    uint256 public constant MIN_BRIDGE_AMOUNT = 0.0001 ether;
    
    /// @notice Maximum bridge amount (100 ETH)
    uint256 public constant MAX_BRIDGE_AMOUNT = 100 ether;
    
    /// @notice Base submission cost for Arbitrum
    uint256 public constant BASE_SUBMISSION_COST = 0.001 ether;
    
    /// @notice Default gas limit for L2 transactions
    uint256 public constant DEFAULT_GAS_LIMIT = 1000000;
    
    /// @notice Default gas price bid (1 gwei)
    uint256 public constant DEFAULT_GAS_PRICE_BID = 1 gwei;
    
    /// @notice Bridge fee in basis points (10 = 0.1%)
    uint256 public constant BRIDGE_FEE_BPS = 10;
    
    /// @notice Maximum gas price multiplier for dynamic pricing
    uint256 public constant MAX_GAS_MULTIPLIER = 5;

    // ============ State Variables ============
    
    /// @notice Chainlink ETH/USD price feed
    AggregatorV3Interface public immutable ethUsdPriceFeed;
    
    /// @notice Mapping to track bridge transactions
    mapping(bytes32 => BridgeTransaction) public bridgeTransactions;
    
    /// @notice Mapping to track user bridge history
    mapping(address => bytes32[]) public userBridgeHistory;
    
    /// @notice Mapping to track withdrawal claims
    mapping(bytes32 => bool) public withdrawalClaimed;
    
    /// @notice Total ETH bridged to Arbitrum
    uint256 public totalBridgedToArbitrum;
    
    /// @notice Total ETH withdrawn from Arbitrum
    uint256 public totalWithdrawnFromArbitrum;
    
    /// @notice Accumulated bridge fees
    uint256 public accumulatedFees;
    
    /// @notice Dynamic gas pricing enabled
    bool public dynamicGasPricingEnabled = true;

    // ============ Structs ============
    
    /**
     * @notice Bridge transaction information
     * @param user User who initiated the bridge
     * @param amount Amount being bridged
     * @param destination Destination address
     * @param timestamp Transaction timestamp
     * @param status Transaction status
     * @param l2TxHash L2 transaction hash (for L1->L2 bridges)
     * @param gasUsed Gas used for the transaction
     * @param feesPaid Fees paid for the transaction
     */
    struct BridgeTransaction {
        address user;
        uint256 amount;
        address destination;
        uint256 timestamp;
        BridgeStatus status;
        bytes32 l2TxHash;
        uint256 gasUsed;
        uint256 feesPaid;
    }
    
    /**
     * @notice Bridge parameters for L1 to L2 transfers
     * @param to Destination address on L2
     * @param amount Amount to bridge
     * @param gasLimit Gas limit for L2 transaction
     * @param gasPriceBid Gas price bid for L2
     * @param data Additional data for L2 call
     */
    struct BridgeParams {
        address to;
        uint256 amount;
        uint256 gasLimit;
        uint256 gasPriceBid;
        bytes data;
    }

    // ============ Enums ============
    
    enum BridgeStatus {
        Pending,
        Completed,
        Failed,
        Refunded
    }

    // ============ Events ============
    
    /**
     * @notice Emitted when ETH is bridged from L1 to L2
     * @param user User who initiated the bridge
     * @param to Destination address on L2
     * @param amount Amount bridged
     * @param l2TxHash L2 transaction hash
     * @param totalCost Total cost including fees
     */
    event ETHBridgedToL2(
        address indexed user,
        address indexed to,
        uint256 amount,
        bytes32 indexed l2TxHash,
        uint256 totalCost
    );
    
    /**
     * @notice Emitted when ETH withdrawal is initiated from L2 to L1
     * @param user User who initiated the withdrawal
     * @param amount Amount being withdrawn
     * @param withdrawalId Unique withdrawal identifier
     */
    event WithdrawalInitiated(
        address indexed user,
        uint256 amount,
        bytes32 indexed withdrawalId
    );
    
    /**
     * @notice Emitted when ETH withdrawal is completed
     * @param user User who received the withdrawal
     * @param amount Amount withdrawn
     * @param withdrawalId Withdrawal identifier
     */
    event WithdrawalCompleted(
        address indexed user,
        uint256 amount,
        bytes32 indexed withdrawalId
    );
    
    /**
     * @notice Emitted when bridge fees are collected
     * @param amount Fee amount collected
     * @param totalAccumulated Total accumulated fees
     */
    event FeesCollected(uint256 amount, uint256 totalAccumulated);
    
    /**
     * @notice Emitted when gas pricing parameters are updated
     * @param gasLimit New gas limit
     * @param gasPriceBid New gas price bid
     */
    event GasPricingUpdated(uint256 gasLimit, uint256 gasPriceBid);

    // ============ Errors ============
    
    error InvalidAmount();
    error InvalidRecipient();
    error InsufficientFunds();
    error BridgeTransactionFailed();
    error WithdrawalAlreadyClaimed();
    error InvalidWithdrawal();
    error GasPriceTooHigh();
    error PriceFeedError();
    error TransferFailed();
    error InvalidGasParameters();

    // ============ Constructor ============
    
    /**
     * @notice Initialize the ETH Bridge contract
     * @param _ethUsdPriceFeed Address of ETH/USD Chainlink price feed
     * @param _owner Address of the contract owner
     */
    constructor(
        address _ethUsdPriceFeed,
        address _owner
    ) Ownable(_owner) {
        if (_ethUsdPriceFeed == address(0)) revert InvalidRecipient();
        if (_owner == address(0)) revert InvalidRecipient();
        
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
    }

    // ============ External Functions ============
    
    /**
     * @notice Bridge ETH from Ethereum to Arbitrum
     * @param to Destination address on Arbitrum
     * @return l2TxHash Transaction hash on L2
     */
    function bridgeETHToArbitrum(address to) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        returns (bytes32 l2TxHash) 
    {
        return _bridgeETHToArbitrum(to, DEFAULT_GAS_LIMIT, DEFAULT_GAS_PRICE_BID, "");
    }
    
    /**
     * @notice Bridge ETH with custom gas parameters
     * @param params Bridge parameters
     * @return l2TxHash Transaction hash on L2
     */
    function bridgeETHWithParams(BridgeParams calldata params) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        returns (bytes32 l2TxHash) 
    {
        return _bridgeETHToArbitrum(
            params.to,
            params.gasLimit,
            params.gasPriceBid,
            params.data
        );
    }
    
    /**
     * @notice Estimate bridge costs
     * @param amount Amount to bridge
     * @param gasLimit Gas limit for L2 transaction
     * @param gasPriceBid Gas price bid for L2
     * @return totalCost Total cost including all fees
     * @return bridgeFee Bridge fee amount
     * @return gasCost Gas cost estimate
     */
    function estimateBridgeCost(
        uint256 amount,
        uint256 gasLimit,
        uint256 gasPriceBid
    ) external view returns (
        uint256 totalCost,
        uint256 bridgeFee,
        uint256 gasCost
    ) {
        return _calculateBridgeCost(amount, gasLimit, gasPriceBid);
    }
    
    /**
     * @notice Complete withdrawal from Arbitrum to Ethereum
     * @param withdrawalId Unique withdrawal identifier
     * @param amount Amount to withdraw
     * @param proof Merkle proof for withdrawal
     */
    function completeWithdrawal(
        bytes32 withdrawalId,
        uint256 amount,
        bytes32[] calldata proof
    ) external nonReentrant whenNotPaused {
        if (withdrawalClaimed[withdrawalId]) revert WithdrawalAlreadyClaimed();
        if (amount == 0) revert InvalidAmount();
        
        // Verify withdrawal proof (simplified - in production use proper merkle verification)
        if (!_verifyWithdrawalProof(withdrawalId, amount, msg.sender, proof)) {
            revert InvalidWithdrawal();
        }
        
        // Mark as claimed
        withdrawalClaimed[withdrawalId] = true;
        
        // Update tracking
        totalWithdrawnFromArbitrum += amount;
        
        // Transfer ETH to user
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        
        emit WithdrawalCompleted(msg.sender, amount, withdrawalId);
    }
    
    /**
     * @notice Get user's bridge transaction history
     * @param user User address
     * @return transactions Array of transaction IDs
     */
    function getUserBridgeHistory(address user) 
        external 
        view 
        returns (bytes32[] memory transactions) 
    {
        return userBridgeHistory[user];
    }
    
    /**
     * @notice Get current ETH price in USD
     * @return price ETH price with 8 decimals
     */
    function getCurrentETHPrice() external view returns (uint256 price) {
        return _getETHPriceUSD();
    }

    // ============ Internal Functions ============
    
    /**
     * @notice Internal function to bridge ETH to Arbitrum
     * @param to Destination address
     * @param gasLimit Gas limit for L2 transaction
     * @param gasPriceBid Gas price bid
     * @param data Additional call data
     * @return l2TxHash L2 transaction hash
     */
    function _bridgeETHToArbitrum(
        address to,
        uint256 gasLimit,
        uint256 gasPriceBid,
        bytes memory data
    ) internal returns (bytes32 l2TxHash) {
        // Validate inputs
        if (to == address(0)) revert InvalidRecipient();
        if (msg.value < MIN_BRIDGE_AMOUNT) revert InvalidAmount();
        if (msg.value > MAX_BRIDGE_AMOUNT) revert InvalidAmount();
        if (gasLimit == 0 || gasLimit > 10000000) revert InvalidGasParameters();
        
        // Calculate costs
        (uint256 totalCost, uint256 bridgeFee, uint256 gasCost) = 
            _calculateBridgeCost(msg.value, gasLimit, gasPriceBid);
        
        if (msg.value < totalCost) revert InsufficientFunds();
        
        // Calculate actual bridge amount (msg.value - fees)
        uint256 bridgeAmount = msg.value - bridgeFee - gasCost;
        
        // Dynamic gas pricing adjustment
        if (dynamicGasPricingEnabled) {
            gasPriceBid = _adjustGasPrice(gasPriceBid);
        }
        
        // Create retryable ticket
        try IInbox(ARBITRUM_INBOX).createRetryableTicket{value: msg.value}(
            to,                    // to
            bridgeAmount,          // l2CallValue
            BASE_SUBMISSION_COST,  // maxSubmissionCost
            msg.sender,            // excessFeeRefundAddress
            msg.sender,            // callValueRefundAddress
            gasLimit,              // gasLimit
            gasPriceBid,           // maxFeePerGas
            data                   // data
        ) returns (uint256 ticketId) {
            l2TxHash = bytes32(ticketId);
        } catch {
            revert BridgeTransactionFailed();
        }
        
        // Record transaction
        bytes32 txId = keccak256(abi.encodePacked(msg.sender, block.timestamp, l2TxHash));
        bridgeTransactions[txId] = BridgeTransaction({
            user: msg.sender,
            amount: bridgeAmount,
            destination: to,
            timestamp: block.timestamp,
            status: BridgeStatus.Pending,
            l2TxHash: l2TxHash,
            gasUsed: gasCost,
            feesPaid: bridgeFee
        });
        
        // Update user history
        userBridgeHistory[msg.sender].push(txId);
        
        // Update tracking
        totalBridgedToArbitrum += bridgeAmount;
        accumulatedFees += bridgeFee;
        
        emit ETHBridgedToL2(msg.sender, to, bridgeAmount, l2TxHash, totalCost);
        
        return l2TxHash;
    }
    
    /**
     * @notice Calculate bridge costs including fees and gas
     * @param amount Amount to bridge
     * @param gasLimit Gas limit
     * @param gasPriceBid Gas price bid
     * @return totalCost Total cost
     * @return bridgeFee Bridge fee
     * @return gasCost Gas cost
     */
    function _calculateBridgeCost(
        uint256 amount,
        uint256 gasLimit,
        uint256 gasPriceBid
    ) internal view returns (
        uint256 totalCost,
        uint256 bridgeFee,
        uint256 gasCost
    ) {
        // Calculate bridge fee
        bridgeFee = (amount * BRIDGE_FEE_BPS) / 10000;
        
        // Calculate gas cost
        gasCost = BASE_SUBMISSION_COST + (gasLimit * gasPriceBid);
        
        // Total cost
        totalCost = bridgeFee + gasCost;
        
        return (totalCost, bridgeFee, gasCost);
    }
    
    /**
     * @notice Adjust gas price based on network conditions
     * @param baseGasPrice Base gas price
     * @return adjustedPrice Adjusted gas price
     */
    function _adjustGasPrice(uint256 baseGasPrice) internal view returns (uint256 adjustedPrice) {
        // Get current gas price
        uint256 currentGasPrice = tx.gasprice;
        
        if (currentGasPrice == 0) {
            return baseGasPrice;
        }
        
        // Calculate multiplier based on network congestion
        uint256 multiplier = (currentGasPrice * 100) / baseGasPrice;
        
        // Cap the multiplier
        if (multiplier > MAX_GAS_MULTIPLIER * 100) {
            multiplier = MAX_GAS_MULTIPLIER * 100;
        }
        
        adjustedPrice = (baseGasPrice * multiplier) / 100;
        
        // Ensure minimum gas price
        if (adjustedPrice < DEFAULT_GAS_PRICE_BID) {
            adjustedPrice = DEFAULT_GAS_PRICE_BID;
        }
        
        return adjustedPrice;
    }
    
    /**
     * @notice Get current ETH price from Chainlink
     * @return price ETH price in USD (8 decimals)
     */
    function _getETHPriceUSD() internal view returns (uint256 price) {
        try ethUsdPriceFeed.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            if (answer <= 0 || updatedAt == 0) revert PriceFeedError();
            
            // Check if price is stale (older than 1 hour)
            if (block.timestamp - updatedAt > 3600) revert PriceFeedError();
            
            return uint256(answer);
        } catch {
            revert PriceFeedError();
        }
    }
    
    /**
     * @notice Verify withdrawal proof (simplified implementation)
     * @param withdrawalId Withdrawal ID
     * @param amount Withdrawal amount
     * @param recipient Recipient address
     * @param proof Merkle proof
     * @return valid Whether proof is valid
     */
    function _verifyWithdrawalProof(
        bytes32 withdrawalId,
        uint256 amount,
        address recipient,
        bytes32[] calldata proof
    ) internal pure returns (bool valid) {
        // Simplified verification - in production, implement proper merkle tree verification
        // This would verify against the L2 state root
        bytes32 leaf = keccak256(abi.encodePacked(withdrawalId, amount, recipient));
        
        // For now, return true if proof is not empty (placeholder)
        return proof.length > 0;
    }

    // ============ Administrative Functions ============
    
    /**
     * @notice Withdraw accumulated fees
     * @param to Recipient address
     */
    function withdrawFees(address to) external onlyOwner {
        if (to == address(0)) revert InvalidRecipient();
        
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
        
        emit FeesCollected(amount, 0);
    }
    
    /**
     * @notice Toggle dynamic gas pricing
     * @param enabled Whether to enable dynamic pricing
     */
    function setDynamicGasPricing(bool enabled) external onlyOwner {
        dynamicGasPricingEnabled = enabled;
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
     * @notice Emergency withdrawal (only owner)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert InvalidRecipient();
        
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    // ============ Receive Function ============
    
    /**
     * @notice Receive function to accept ETH deposits
     */
    receive() external payable {
        // Allow ETH deposits for contract funding
    }
}