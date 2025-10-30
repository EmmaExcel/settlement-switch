// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title ArbitrumWithdrawalManager
 * @dev Manages ETH withdrawals from Arbitrum to Ethereum with comprehensive validation
 * @notice Handles the complete withdrawal lifecycle including initiation, validation, and execution
 * @author Arbitrum Development Team
 */
contract ArbitrumWithdrawalManager is ReentrancyGuard, Ownable, Pausable {
    
    // ============ Constants ============
    
    /// @notice Arbitrum Outbox address (Sepolia)
    address public constant ARBITRUM_OUTBOX = 0x65f07C7D521164a4d5DaC6eB8Fac8DA067A3B78F;
    
    /// @notice Arbitrum Mainnet Outbox address
    address public constant ARBITRUM_MAINNET_OUTBOX = 0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840;
    
    /// @notice Minimum withdrawal amount (0.0001 ETH)
    uint256 public constant MIN_WITHDRAWAL_AMOUNT = 0.0001 ether;
    
    /// @notice Maximum withdrawal amount (1000 ETH)
    uint256 public constant MAX_WITHDRAWAL_AMOUNT = 1000 ether;
    
    /// @notice Withdrawal challenge period (7 days for mainnet, 1 hour for testnet)
    uint256 public constant CHALLENGE_PERIOD = 1 hours; // Testnet value
    
    /// @notice Maximum age for withdrawal proofs (30 days)
    uint256 public constant MAX_PROOF_AGE = 30 days;
    
    /// @notice Withdrawal fee in basis points (50 = 0.5%)
    uint256 public constant WITHDRAWAL_FEE_BPS = 50;

    // ============ State Variables ============
    
    /// @notice Current Arbitrum Outbox being used
    address public currentOutbox;
    
    /// @notice Mapping of withdrawal IDs to withdrawal data
    mapping(bytes32 => WithdrawalData) public withdrawals;
    
    /// @notice Mapping of user addresses to their withdrawal history
    mapping(address => bytes32[]) public userWithdrawals;
    
    /// @notice Mapping to track executed withdrawals
    mapping(bytes32 => bool) public executedWithdrawals;
    
    /// @notice Mapping to track challenged withdrawals
    mapping(bytes32 => ChallengeData) public challengedWithdrawals;
    
    /// @notice Merkle root for valid withdrawals
    bytes32 public withdrawalMerkleRoot;
    
    /// @notice Total withdrawals processed
    uint256 public totalWithdrawals;
    
    /// @notice Total ETH withdrawn
    uint256 public totalETHWithdrawn;
    
    /// @notice Accumulated withdrawal fees
    uint256 public accumulatedFees;
    
    /// @notice Emergency withdrawal enabled
    bool public emergencyWithdrawalEnabled;

    // ============ Structs ============
    
    /**
     * @notice Withdrawal data structure
     * @param user User initiating the withdrawal
     * @param amount Amount to withdraw
     * @param recipient Recipient address on L1
     * @param timestamp Withdrawal initiation timestamp
     * @param status Current withdrawal status
     * @param l2TxHash L2 transaction hash
     * @param merkleProof Merkle proof for validation
     * @param challengePeriodEnd End of challenge period
     * @param feesPaid Fees paid for withdrawal
     */
    struct WithdrawalData {
        address user;
        uint256 amount;
        address recipient;
        uint256 timestamp;
        WithdrawalStatus status;
        bytes32 l2TxHash;
        bytes32[] merkleProof;
        uint256 challengePeriodEnd;
        uint256 feesPaid;
    }
    
    /**
     * @notice Challenge data for disputed withdrawals
     * @param challenger Address that initiated the challenge
     * @param challengeTimestamp When the challenge was initiated
     * @param challengeReason Reason for the challenge
     * @param resolved Whether the challenge has been resolved
     * @param challengeValid Whether the challenge was valid
     */
    struct ChallengeData {
        address challenger;
        uint256 challengeTimestamp;
        string challengeReason;
        bool resolved;
        bool challengeValid;
    }
    
    /**
     * @notice Withdrawal request parameters
     * @param recipient Recipient address on L1
     * @param amount Amount to withdraw
     * @param l2TxHash L2 transaction hash
     * @param merkleProof Merkle proof for validation
     * @param index Index in the merkle tree
     */
    struct WithdrawalRequest {
        address recipient;
        uint256 amount;
        bytes32 l2TxHash;
        bytes32[] merkleProof;
        uint256 index;
    }

    // ============ Enums ============
    
    enum WithdrawalStatus {
        Initiated,
        ChallengePeriod,
        ReadyForExecution,
        Executed,
        Challenged,
        Failed
    }

    // ============ Events ============
    
    /**
     * @notice Emitted when a withdrawal is initiated
     * @param withdrawalId Unique withdrawal identifier
     * @param user User initiating withdrawal
     * @param recipient Recipient address
     * @param amount Amount to withdraw
     * @param l2TxHash L2 transaction hash
     */
    event WithdrawalInitiated(
        bytes32 indexed withdrawalId,
        address indexed user,
        address indexed recipient,
        uint256 amount,
        bytes32 l2TxHash
    );
    
    /**
     * @notice Emitted when a withdrawal is executed
     * @param withdrawalId Withdrawal identifier
     * @param recipient Recipient address
     * @param amount Amount withdrawn
     * @param feesPaid Fees paid
     */
    event WithdrawalExecuted(
        bytes32 indexed withdrawalId,
        address indexed recipient,
        uint256 amount,
        uint256 feesPaid
    );
    
    /**
     * @notice Emitted when a withdrawal is challenged
     * @param withdrawalId Withdrawal identifier
     * @param challenger Address that challenged
     * @param reason Challenge reason
     */
    event WithdrawalChallenged(
        bytes32 indexed withdrawalId,
        address indexed challenger,
        string reason
    );
    
    /**
     * @notice Emitted when a challenge is resolved
     * @param withdrawalId Withdrawal identifier
     * @param challenger Challenger address
     * @param valid Whether challenge was valid
     */
    event ChallengeResolved(
        bytes32 indexed withdrawalId,
        address indexed challenger,
        bool valid
    );
    
    /**
     * @notice Emitted when withdrawal merkle root is updated
     * @param oldRoot Previous merkle root
     * @param newRoot New merkle root
     * @param updatedBy Address that updated the root
     */
    event WithdrawalMerkleRootUpdated(
        bytes32 oldRoot,
        bytes32 newRoot,
        address indexed updatedBy
    );

    // ============ Errors ============
    
    error InvalidWithdrawalAmount();
    error InvalidRecipient();
    error WithdrawalNotFound();
    error WithdrawalAlreadyExecuted();
    error WithdrawalStillInChallengePeriod();
    error InvalidMerkleProof();
    error WithdrawalCurrentlyChallenged();
    error ChallengeAlreadyResolved();
    error InsufficientContractBalance();
    error TransferFailed();
    error ProofTooOld();
    error InvalidOutbox();
    error EmergencyWithdrawalNotEnabled();

    // ============ Constructor ============
    
    /**
     * @notice Initialize the Arbitrum Withdrawal Manager
     * @param _owner Address of the contract owner
     * @param _initialMerkleRoot Initial merkle root for withdrawals
     */
    constructor(
        address _owner,
        bytes32 _initialMerkleRoot
    ) Ownable(_owner) {
        if (_owner == address(0)) revert InvalidRecipient();
        
        currentOutbox = ARBITRUM_OUTBOX;
        withdrawalMerkleRoot = _initialMerkleRoot;
    }

    // ============ External Functions ============
    
    /**
     * @notice Initiate a withdrawal from Arbitrum to Ethereum
     * @param request Withdrawal request parameters
     * @return withdrawalId Unique withdrawal identifier
     */
    function initiateWithdrawal(WithdrawalRequest calldata request) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (bytes32 withdrawalId) 
    {
        // Validate request
        _validateWithdrawalRequest(request);
        
        // Generate withdrawal ID
        withdrawalId = keccak256(abi.encodePacked(
            msg.sender,
            request.recipient,
            request.amount,
            request.l2TxHash,
            block.timestamp
        ));
        
        // Verify merkle proof
        if (!_verifyWithdrawalProof(request, withdrawalId)) {
            revert InvalidMerkleProof();
        }
        
        // Calculate fees
        uint256 withdrawalFee = (request.amount * WITHDRAWAL_FEE_BPS) / 10000;
        uint256 netAmount = request.amount - withdrawalFee;
        
        // Create withdrawal data
        withdrawals[withdrawalId] = WithdrawalData({
            user: msg.sender,
            amount: netAmount,
            recipient: request.recipient,
            timestamp: block.timestamp,
            status: WithdrawalStatus.ChallengePeriod,
            l2TxHash: request.l2TxHash,
            merkleProof: request.merkleProof,
            challengePeriodEnd: block.timestamp + CHALLENGE_PERIOD,
            feesPaid: withdrawalFee
        });
        
        // Update user history
        userWithdrawals[msg.sender].push(withdrawalId);
        
        // Update statistics
        totalWithdrawals++;
        accumulatedFees += withdrawalFee;
        
        emit WithdrawalInitiated(
            withdrawalId,
            msg.sender,
            request.recipient,
            netAmount,
            request.l2TxHash
        );
        
        return withdrawalId;
    }
    
    /**
     * @notice Execute a withdrawal after challenge period
     * @param withdrawalId Withdrawal identifier
     */
    function executeWithdrawal(bytes32 withdrawalId) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        WithdrawalData storage withdrawal = withdrawals[withdrawalId];
        
        // Validate withdrawal
        if (withdrawal.user == address(0)) revert WithdrawalNotFound();
        if (executedWithdrawals[withdrawalId]) revert WithdrawalAlreadyExecuted();
        if (withdrawal.status == WithdrawalStatus.Challenged) revert WithdrawalCurrentlyChallenged();
        if (block.timestamp < withdrawal.challengePeriodEnd) {
            revert WithdrawalStillInChallengePeriod();
        }
        
        // Check contract balance
        if (address(this).balance < withdrawal.amount) {
            revert InsufficientContractBalance();
        }
        
        // Mark as executed
        executedWithdrawals[withdrawalId] = true;
        withdrawal.status = WithdrawalStatus.Executed;
        
        // Update statistics
        totalETHWithdrawn += withdrawal.amount;
        
        // Transfer ETH to recipient
        (bool success, ) = payable(withdrawal.recipient).call{value: withdrawal.amount}("");
        if (!success) revert TransferFailed();
        
        emit WithdrawalExecuted(
            withdrawalId,
            withdrawal.recipient,
            withdrawal.amount,
            withdrawal.feesPaid
        );
    }
    
    /**
     * @notice Challenge a withdrawal during challenge period
     * @param withdrawalId Withdrawal identifier
     * @param reason Reason for challenge
     */
    function challengeWithdrawal(
        bytes32 withdrawalId,
        string calldata reason
    ) external whenNotPaused {
        WithdrawalData storage withdrawal = withdrawals[withdrawalId];
        
        if (withdrawal.user == address(0)) revert WithdrawalNotFound();
        if (block.timestamp > withdrawal.challengePeriodEnd) {
            revert WithdrawalStillInChallengePeriod();
        }
        if (withdrawal.status == WithdrawalStatus.Challenged) {
            revert WithdrawalCurrentlyChallenged();
        }
        
        // Update withdrawal status
        withdrawal.status = WithdrawalStatus.Challenged;
        
        // Record challenge
        challengedWithdrawals[withdrawalId] = ChallengeData({
            challenger: msg.sender,
            challengeTimestamp: block.timestamp,
            challengeReason: reason,
            resolved: false,
            challengeValid: false
        });
        
        emit WithdrawalChallenged(withdrawalId, msg.sender, reason);
    }
    
    /**
     * @notice Resolve a challenged withdrawal (owner only)
     * @param withdrawalId Withdrawal identifier
     * @param challengeValid Whether the challenge is valid
     */
    function resolveChallenge(
        bytes32 withdrawalId,
        bool challengeValid
    ) external onlyOwner {
        ChallengeData storage challenge = challengedWithdrawals[withdrawalId];
        WithdrawalData storage withdrawal = withdrawals[withdrawalId];
        
        if (challenge.challenger == address(0)) revert WithdrawalNotFound();
        if (challenge.resolved) revert ChallengeAlreadyResolved();
        
        // Mark challenge as resolved
        challenge.resolved = true;
        challenge.challengeValid = challengeValid;
        
        if (challengeValid) {
            // Challenge was valid - mark withdrawal as failed
            withdrawal.status = WithdrawalStatus.Failed;
        } else {
            // Challenge was invalid - allow withdrawal to proceed
            withdrawal.status = WithdrawalStatus.ReadyForExecution;
            withdrawal.challengePeriodEnd = block.timestamp; // Allow immediate execution
        }
        
        emit ChallengeResolved(withdrawalId, challenge.challenger, challengeValid);
    }
    
    /**
     * @notice Emergency withdrawal (bypasses normal process)
     * @param recipient Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address recipient,
        uint256 amount
    ) external onlyOwner {
        if (!emergencyWithdrawalEnabled) revert EmergencyWithdrawalNotEnabled();
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidWithdrawalAmount();
        
        (bool success, ) = payable(recipient).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
    
    /**
     * @notice Get withdrawal data
     * @param withdrawalId Withdrawal identifier
     * @return withdrawal Withdrawal data
     */
    function getWithdrawal(bytes32 withdrawalId) 
        external 
        view 
        returns (WithdrawalData memory withdrawal) 
    {
        return withdrawals[withdrawalId];
    }
    
    /**
     * @notice Get user's withdrawal history
     * @param user User address
     * @return withdrawalIds Array of withdrawal IDs
     */
    function getUserWithdrawals(address user) 
        external 
        view 
        returns (bytes32[] memory withdrawalIds) 
    {
        return userWithdrawals[user];
    }
    
    /**
     * @notice Check if withdrawal is ready for execution
     * @param withdrawalId Withdrawal identifier
     * @return ready Whether withdrawal is ready
     */
    function isWithdrawalReady(bytes32 withdrawalId) 
        external 
        view 
        returns (bool ready) 
    {
        WithdrawalData memory withdrawal = withdrawals[withdrawalId];
        
        return withdrawal.user != address(0) &&
               !executedWithdrawals[withdrawalId] &&
               withdrawal.status != WithdrawalStatus.Challenged &&
               withdrawal.status != WithdrawalStatus.Failed &&
               block.timestamp >= withdrawal.challengePeriodEnd;
    }

    // ============ Internal Functions ============
    
    /**
     * @notice Validate withdrawal request
     * @param request Withdrawal request to validate
     */
    function _validateWithdrawalRequest(WithdrawalRequest calldata request) internal view {
        if (request.recipient == address(0)) revert InvalidRecipient();
        if (request.amount < MIN_WITHDRAWAL_AMOUNT || 
            request.amount > MAX_WITHDRAWAL_AMOUNT) {
            revert InvalidWithdrawalAmount();
        }
        if (request.l2TxHash == bytes32(0)) revert InvalidMerkleProof();
        if (request.merkleProof.length == 0) revert InvalidMerkleProof();
    }
    
    /**
     * @notice Verify withdrawal merkle proof
     * @param request Withdrawal request
     * @param withdrawalId Withdrawal identifier
     * @return valid Whether proof is valid
     */
    function _verifyWithdrawalProof(
        WithdrawalRequest calldata request,
        bytes32 withdrawalId
    ) internal view returns (bool valid) {
        // Create leaf hash
        bytes32 leaf = keccak256(abi.encodePacked(
            request.recipient,
            request.amount,
            request.l2TxHash,
            withdrawalId
        ));
        
        // Verify against merkle root
        return MerkleProof.verify(
            request.merkleProof,
            withdrawalMerkleRoot,
            leaf
        );
    }

    // ============ Administrative Functions ============
    
    /**
     * @notice Update withdrawal merkle root
     * @param newRoot New merkle root
     */
    function updateWithdrawalMerkleRoot(bytes32 newRoot) external onlyOwner {
        bytes32 oldRoot = withdrawalMerkleRoot;
        withdrawalMerkleRoot = newRoot;
        
        emit WithdrawalMerkleRootUpdated(oldRoot, newRoot, msg.sender);
    }
    
    /**
     * @notice Set current outbox address
     * @param outboxAddress New outbox address
     */
    function setCurrentOutbox(address outboxAddress) external onlyOwner {
        if (outboxAddress == address(0)) revert InvalidOutbox();
        currentOutbox = outboxAddress;
    }
    
    /**
     * @notice Toggle emergency withdrawal mode
     * @param enabled Whether to enable emergency withdrawals
     */
    function setEmergencyWithdrawalEnabled(bool enabled) external onlyOwner {
        emergencyWithdrawalEnabled = enabled;
    }
    
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

    // ============ Receive Function ============
    
    /**
     * @notice Receive function to accept ETH deposits
     */
    receive() external payable {
        // Allow ETH deposits to fund withdrawals
    }
}