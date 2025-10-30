// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title BridgeErrorHandler
 * @dev Comprehensive error handling and edge case management for bridge operations
 * @notice Handles network congestion, failed transactions, insufficient funds, and security vulnerabilities
 * @author Bridge Development Team
 */
contract BridgeErrorHandler is ReentrancyGuard, Ownable, Pausable {
    
    // ============ Constants ============
    
    /// @notice Maximum retry attempts for failed transactions
    uint256 public constant MAX_RETRY_ATTEMPTS = 5;
    
    /// @notice Base retry delay (1 minute)
    uint256 public constant BASE_RETRY_DELAY = 60;
    
    /// @notice Maximum retry delay (1 hour)
    uint256 public constant MAX_RETRY_DELAY = 3600;
    
    /// @notice Network congestion threshold (gas price in gwei)
    uint256 public constant CONGESTION_THRESHOLD = 100 gwei;
    
    /// @notice Critical gas price threshold (500 gwei)
    uint256 public constant CRITICAL_GAS_THRESHOLD = 500 gwei;
    
    /// @notice Minimum balance threshold for operations
    uint256 public constant MIN_BALANCE_THRESHOLD = 0.01 ether;
    
    /// @notice Maximum transaction value for security
    uint256 public constant MAX_TRANSACTION_VALUE = 1000 ether;
    
    /// @notice Circuit breaker threshold (number of failures)
    uint256 public constant CIRCUIT_BREAKER_THRESHOLD = 10;
    
    /// @notice Circuit breaker cooldown period (30 minutes)
    uint256 public constant CIRCUIT_BREAKER_COOLDOWN = 1800;

    // ============ State Variables ============
    
    /// @notice Mapping of transaction hashes to error data
    mapping(bytes32 => ErrorData) public transactionErrors;
    
    /// @notice Mapping of addresses to their failure counts
    mapping(address => uint256) public userFailureCounts;
    
    /// @notice Mapping of error types to their occurrence counts
    mapping(ErrorType => uint256) public errorTypeCounts;
    
    /// @notice Network congestion status
    NetworkStatus public currentNetworkStatus;
    
    /// @notice Circuit breaker status
    CircuitBreakerStatus public circuitBreakerStatus;
    
    /// @notice Total error count
    uint256 public totalErrors;
    
    /// @notice Last network status update timestamp
    uint256 public lastNetworkUpdate;
    
    /// @notice Emergency contact address
    address public emergencyContact;
    
    /// @notice Authorized error resolvers
    mapping(address => bool) public authorizedResolvers;
    
    /// @notice Blacklisted addresses
    mapping(address => bool) public blacklistedAddresses;
    
    /// @notice Rate limiting data
    mapping(address => RateLimitData) public rateLimits;

    // ============ Structs ============
    
    /**
     * @notice Error data structure
     * @param errorType Type of error encountered
     * @param timestamp When the error occurred
     * @param retryCount Number of retry attempts
     * @param lastRetryTimestamp Last retry attempt timestamp
     * @param resolved Whether the error has been resolved
     * @param errorMessage Detailed error message
     * @param gasUsed Gas used in failed transaction
     * @param gasPrice Gas price at time of error
     * @param blockNumber Block number when error occurred
     * @param severity Error severity level
     */
    struct ErrorData {
        ErrorType errorType;
        uint256 timestamp;
        uint256 retryCount;
        uint256 lastRetryTimestamp;
        bool resolved;
        string errorMessage;
        uint256 gasUsed;
        uint256 gasPrice;
        uint256 blockNumber;
        ErrorSeverity severity;
    }
    
    /**
     * @notice Network status information
     * @param congestionLevel Current congestion level
     * @param averageGasPrice Average gas price
     * @param blockUtilization Block space utilization percentage
     * @param lastUpdate Last status update timestamp
     * @param isHealthy Whether network is healthy
     */
    struct NetworkStatus {
        CongestionLevel congestionLevel;
        uint256 averageGasPrice;
        uint256 blockUtilization;
        uint256 lastUpdate;
        bool isHealthy;
    }
    
    /**
     * @notice Circuit breaker status
     * @param isTripped Whether circuit breaker is active
     * @param tripTimestamp When circuit breaker was triggered
     * @param failureCount Number of failures that triggered it
     * @param lastResetAttempt Last reset attempt timestamp
     * @param autoResetEnabled Whether auto-reset is enabled
     */
    struct CircuitBreakerStatus {
        bool isTripped;
        uint256 tripTimestamp;
        uint256 failureCount;
        uint256 lastResetAttempt;
        bool autoResetEnabled;
    }
    
    /**
     * @notice Rate limiting data
     * @param requestCount Number of requests in current window
     * @param windowStart Start of current rate limit window
     * @param isLimited Whether user is currently rate limited
     * @param limitExpiry When rate limit expires
     */
    struct RateLimitData {
        uint256 requestCount;
        uint256 windowStart;
        bool isLimited;
        uint256 limitExpiry;
    }
    
    /**
     * @notice Recovery parameters for failed transactions
     * @param maxRetries Maximum retry attempts
     * @param retryDelay Delay between retries
     * @param gasMultiplier Gas price multiplier for retries
     * @param requireManualApproval Whether manual approval is required
     */
    struct RecoveryParams {
        uint256 maxRetries;
        uint256 retryDelay;
        uint256 gasMultiplier;
        bool requireManualApproval;
    }

    // ============ Enums ============
    
    enum ErrorType {
        NetworkCongestion,
        InsufficientFunds,
        TransactionFailed,
        ContractVulnerability,
        InvalidParameters,
        UnauthorizedAccess,
        RateLimitExceeded,
        CircuitBreakerTripped,
        GasPriceTooHigh,
        SlippageExceeded,
        DeadlineExceeded,
        BridgeUnavailable
    }
    
    enum ErrorSeverity {
        Low,
        Medium,
        High,
        Critical
    }
    
    enum CongestionLevel {
        Low,
        Medium,
        High,
        Critical
    }

    // ============ Events ============
    
    /**
     * @notice Emitted when an error is recorded
     * @param txHash Transaction hash
     * @param user User address
     * @param errorType Type of error
     * @param severity Error severity
     * @param message Error message
     */
    event ErrorRecorded(
        bytes32 indexed txHash,
        address indexed user,
        ErrorType indexed errorType,
        ErrorSeverity severity,
        string message
    );
    
    /**
     * @notice Emitted when an error is resolved
     * @param txHash Transaction hash
     * @param resolver Address that resolved the error
     * @param resolution Resolution method used
     */
    event ErrorResolved(
        bytes32 indexed txHash,
        address indexed resolver,
        string resolution
    );
    
    /**
     * @notice Emitted when network status is updated
     * @param congestionLevel New congestion level
     * @param averageGasPrice Average gas price
     * @param isHealthy Network health status
     */
    event NetworkStatusUpdated(
        CongestionLevel congestionLevel,
        uint256 averageGasPrice,
        bool isHealthy
    );
    
    /**
     * @notice Emitted when circuit breaker is triggered
     * @param triggerReason Reason for triggering
     * @param failureCount Number of failures
     * @param cooldownPeriod Cooldown period
     */
    event CircuitBreakerTriggered(
        string triggerReason,
        uint256 failureCount,
        uint256 cooldownPeriod
    );
    
    /**
     * @notice Emitted when circuit breaker is reset
     * @param resetBy Address that reset the breaker
     * @param resetReason Reason for reset
     */
    event CircuitBreakerReset(
        address indexed resetBy,
        string resetReason
    );
    
    /**
     * @notice Emitted when a user is rate limited
     * @param user User address
     * @param limitDuration Duration of rate limit
     * @param reason Reason for rate limiting
     */
    event UserRateLimited(
        address indexed user,
        uint256 limitDuration,
        string reason
    );

    // ============ Errors ============
    
    error InvalidParameters();
    error ErrorAlreadyResolved();
    error MaxRetriesExceeded();
    error CircuitBreakerActive();
    error NetworkCongested();
    error InsufficientBalance();
    error UnauthorizedResolver();
    error InvalidErrorType();
    error RateLimitActive();
    error BlacklistedAddress();
    error CriticalGasPrice();
    error TransactionValueTooHigh();
    error EmergencyModeActive();

    // ============ Modifiers ============
    
    modifier onlyAuthorizedResolver() {
        if (!authorizedResolvers[msg.sender] && msg.sender != owner()) {
            revert UnauthorizedResolver();
        }
        _;
    }
    
    modifier notBlacklisted(address user) {
        if (blacklistedAddresses[user]) revert BlacklistedAddress();
        _;
    }
    
    modifier circuitBreakerCheck() {
        if (circuitBreakerStatus.isTripped) {
            if (block.timestamp < circuitBreakerStatus.tripTimestamp + CIRCUIT_BREAKER_COOLDOWN) {
                revert CircuitBreakerActive();
            } else if (circuitBreakerStatus.autoResetEnabled) {
                _resetCircuitBreaker("Auto-reset after cooldown");
            }
        }
        _;
    }
    
    modifier rateLimitCheck(address user) {
        _checkRateLimit(user);
        _;
    }

    // ============ Constructor ============
    
    /**
     * @notice Initialize the Bridge Error Handler
     * @param _owner Address of the contract owner
     * @param _emergencyContact Emergency contact address
     */
    constructor(
        address _owner,
        address _emergencyContact
    ) Ownable(_owner) {
        if (_owner == address(0) || _emergencyContact == address(0)) {
            revert InvalidParameters();
        }
        
        emergencyContact = _emergencyContact;
        
        // Initialize network status
        currentNetworkStatus = NetworkStatus({
            congestionLevel: CongestionLevel.Low,
            averageGasPrice: 20 gwei,
            blockUtilization: 50,
            lastUpdate: block.timestamp,
            isHealthy: true
        });
        
        // Initialize circuit breaker
        circuitBreakerStatus = CircuitBreakerStatus({
            isTripped: false,
            tripTimestamp: 0,
            failureCount: 0,
            lastResetAttempt: 0,
            autoResetEnabled: true
        });
    }

    // ============ External Functions ============
    
    /**
     * @notice Record a transaction error
     * @param txHash Transaction hash
     * @param user User address
     * @param errorType Type of error
     * @param errorMessage Detailed error message
     * @param gasUsed Gas used in transaction
     */
    function recordError(
        bytes32 txHash,
        address user,
        ErrorType errorType,
        string calldata errorMessage,
        uint256 gasUsed
    ) external onlyAuthorizedResolver {
        ErrorSeverity severity = _determineErrorSeverity(errorType, gasUsed);
        
        transactionErrors[txHash] = ErrorData({
            errorType: errorType,
            timestamp: block.timestamp,
            retryCount: 0,
            lastRetryTimestamp: 0,
            resolved: false,
            errorMessage: errorMessage,
            gasUsed: gasUsed,
            gasPrice: tx.gasprice,
            blockNumber: block.number,
            severity: severity
        });
        
        // Update statistics
        errorTypeCounts[errorType]++;
        userFailureCounts[user]++;
        totalErrors++;
        
        // Check for circuit breaker trigger
        if (severity == ErrorSeverity.Critical || userFailureCounts[user] >= CIRCUIT_BREAKER_THRESHOLD) {
            _triggerCircuitBreaker("Critical error or failure threshold exceeded");
        }
        
        emit ErrorRecorded(txHash, user, errorType, severity, errorMessage);
    }
    
    /**
     * @notice Attempt to recover from a failed transaction
     * @param txHash Transaction hash
     * @param recoveryParams Recovery parameters
     * @return success Whether recovery was successful
     */
    function attemptRecovery(
        bytes32 txHash,
        RecoveryParams calldata recoveryParams
    ) external onlyAuthorizedResolver circuitBreakerCheck returns (bool success) {
        ErrorData storage errorData = transactionErrors[txHash];
        
        if (errorData.timestamp == 0) revert InvalidErrorType();
        if (errorData.resolved) revert ErrorAlreadyResolved();
        if (errorData.retryCount >= recoveryParams.maxRetries) revert MaxRetriesExceeded();
        
        // Check retry delay
        if (block.timestamp < errorData.lastRetryTimestamp + recoveryParams.retryDelay) {
            return false;
        }
        
        // Update retry information
        errorData.retryCount++;
        errorData.lastRetryTimestamp = block.timestamp;
        
        // Implement recovery logic based on error type
        success = _executeRecovery(errorData.errorType, recoveryParams);
        
        if (success) {
            errorData.resolved = true;
            emit ErrorResolved(txHash, msg.sender, "Automatic recovery");
        }
        
        return success;
    }
    
    /**
     * @notice Manually resolve an error
     * @param txHash Transaction hash
     * @param resolution Resolution description
     */
    function resolveError(
        bytes32 txHash,
        string calldata resolution
    ) external onlyAuthorizedResolver {
        ErrorData storage errorData = transactionErrors[txHash];
        
        if (errorData.timestamp == 0) revert InvalidErrorType();
        if (errorData.resolved) revert ErrorAlreadyResolved();
        
        errorData.resolved = true;
        
        emit ErrorResolved(txHash, msg.sender, resolution);
    }
    
    /**
     * @notice Update network status
     * @param congestionLevel Current congestion level
     * @param averageGasPrice Average gas price
     * @param blockUtilization Block utilization percentage
     */
    function updateNetworkStatus(
        CongestionLevel congestionLevel,
        uint256 averageGasPrice,
        uint256 blockUtilization
    ) external onlyAuthorizedResolver {
        currentNetworkStatus = NetworkStatus({
            congestionLevel: congestionLevel,
            averageGasPrice: averageGasPrice,
            blockUtilization: blockUtilization,
            lastUpdate: block.timestamp,
            isHealthy: _determineNetworkHealth(congestionLevel, averageGasPrice)
        });
        
        lastNetworkUpdate = block.timestamp;
        
        emit NetworkStatusUpdated(congestionLevel, averageGasPrice, currentNetworkStatus.isHealthy);
    }
    
    /**
     * @notice Check if operation should proceed based on current conditions
     * @param user User address
     * @param value Transaction value
     * @param gasPrice Proposed gas price
     * @return allowed Whether operation is allowed
     * @return reason Reason if not allowed
     */
    function checkOperationAllowed(
        address user,
        uint256 value,
        uint256 gasPrice
    ) external view returns (bool allowed, string memory reason) {
        // Check blacklist
        if (blacklistedAddresses[user]) {
            return (false, "Address is blacklisted");
        }
        
        // Check circuit breaker
        if (circuitBreakerStatus.isTripped) {
            if (block.timestamp < circuitBreakerStatus.tripTimestamp + CIRCUIT_BREAKER_COOLDOWN) {
                return (false, "Circuit breaker is active");
            }
        }
        
        // Check rate limits
        RateLimitData memory rateLimit = rateLimits[user];
        if (rateLimit.isLimited && block.timestamp < rateLimit.limitExpiry) {
            return (false, "User is rate limited");
        }
        
        // Check network conditions
        if (!currentNetworkStatus.isHealthy) {
            return (false, "Network is unhealthy");
        }
        
        // Check gas price
        if (gasPrice > CRITICAL_GAS_THRESHOLD) {
            return (false, "Gas price too high");
        }
        
        // Check transaction value
        if (value > MAX_TRANSACTION_VALUE) {
            return (false, "Transaction value too high");
        }
        
        // Check user balance (simplified check)
        if (user.balance < MIN_BALANCE_THRESHOLD) {
            return (false, "Insufficient balance");
        }
        
        return (true, "");
    }
    
    /**
     * @notice Get error statistics
     * @return totalErrorCount Total number of errors
     * @return errorsByType Array of error counts by type
     * @return networkHealth Current network health status
     */
    function getErrorStatistics() external view returns (
        uint256 totalErrorCount,
        uint256[12] memory errorsByType,
        bool networkHealth
    ) {
        totalErrorCount = totalErrors;
        
        for (uint256 i = 0; i < 12; i++) {
            errorsByType[i] = errorTypeCounts[ErrorType(i)];
        }
        
        networkHealth = currentNetworkStatus.isHealthy;
    }

    // ============ Internal Functions ============
    
    /**
     * @notice Determine error severity based on type and context
     * @param errorType Type of error
     * @param gasUsed Gas used in failed transaction
     * @return severity Error severity level
     */
    function _determineErrorSeverity(
        ErrorType errorType,
        uint256 gasUsed
    ) internal pure returns (ErrorSeverity severity) {
        if (errorType == ErrorType.ContractVulnerability || 
            errorType == ErrorType.UnauthorizedAccess) {
            return ErrorSeverity.Critical;
        }
        
        if (errorType == ErrorType.NetworkCongestion || 
            errorType == ErrorType.GasPriceTooHigh ||
            gasUsed > 500000) {
            return ErrorSeverity.High;
        }
        
        if (errorType == ErrorType.TransactionFailed || 
            errorType == ErrorType.InsufficientFunds) {
            return ErrorSeverity.Medium;
        }
        
        return ErrorSeverity.Low;
    }
    
    /**
     * @notice Execute recovery based on error type
     * @param errorType Type of error to recover from
     * @param recoveryParams Recovery parameters
     * @return success Whether recovery was successful
     */
    function _executeRecovery(
        ErrorType errorType,
        RecoveryParams calldata recoveryParams
    ) internal returns (bool success) {
        if (errorType == ErrorType.NetworkCongestion) {
            // Wait for network congestion to subside
            return currentNetworkStatus.congestionLevel <= CongestionLevel.Medium;
        }
        
        if (errorType == ErrorType.GasPriceTooHigh) {
            // Check if gas price has decreased
            return tx.gasprice <= CONGESTION_THRESHOLD;
        }
        
        if (errorType == ErrorType.TransactionFailed) {
            // Generic retry logic
            return recoveryParams.maxRetries > 0;
        }
        
        // For other error types, require manual intervention
        return false;
    }
    
    /**
     * @notice Determine network health based on conditions
     * @param congestionLevel Current congestion level
     * @param averageGasPrice Average gas price
     * @return healthy Whether network is healthy
     */
    function _determineNetworkHealth(
        CongestionLevel congestionLevel,
        uint256 averageGasPrice
    ) internal pure returns (bool healthy) {
        return congestionLevel <= CongestionLevel.Medium && 
               averageGasPrice <= CONGESTION_THRESHOLD;
    }
    
    /**
     * @notice Trigger circuit breaker
     * @param reason Reason for triggering
     */
    function _triggerCircuitBreaker(string memory reason) internal {
        circuitBreakerStatus.isTripped = true;
        circuitBreakerStatus.tripTimestamp = block.timestamp;
        circuitBreakerStatus.failureCount++;
        
        emit CircuitBreakerTriggered(reason, circuitBreakerStatus.failureCount, CIRCUIT_BREAKER_COOLDOWN);
    }
    
    /**
     * @notice Reset circuit breaker
     * @param reason Reason for reset
     */
    function _resetCircuitBreaker(string memory reason) internal {
        circuitBreakerStatus.isTripped = false;
        circuitBreakerStatus.lastResetAttempt = block.timestamp;
        
        emit CircuitBreakerReset(msg.sender, reason);
    }
    
    /**
     * @notice Check and update rate limits for user
     * @param user User address to check
     */
    function _checkRateLimit(address user) internal {
        RateLimitData storage rateLimit = rateLimits[user];
        
        // Reset window if needed
        if (block.timestamp >= rateLimit.windowStart + 3600) { // 1 hour window
            rateLimit.requestCount = 0;
            rateLimit.windowStart = block.timestamp;
        }
        
        // Check if user is currently limited
        if (rateLimit.isLimited && block.timestamp < rateLimit.limitExpiry) {
            revert RateLimitActive();
        }
        
        // Increment request count
        rateLimit.requestCount++;
        
        // Apply rate limit if threshold exceeded
        if (rateLimit.requestCount > 100) { // 100 requests per hour
            rateLimit.isLimited = true;
            rateLimit.limitExpiry = block.timestamp + 3600; // 1 hour limit
            
            emit UserRateLimited(user, 3600, "Request rate exceeded");
            revert RateLimitActive();
        }
    }

    // ============ Administrative Functions ============
    
    /**
     * @notice Add authorized error resolver
     * @param resolver Address to authorize
     */
    function addAuthorizedResolver(address resolver) external onlyOwner {
        authorizedResolvers[resolver] = true;
    }
    
    /**
     * @notice Remove authorized error resolver
     * @param resolver Address to remove
     */
    function removeAuthorizedResolver(address resolver) external onlyOwner {
        authorizedResolvers[resolver] = false;
    }
    
    /**
     * @notice Add address to blacklist
     * @param user Address to blacklist
     */
    function addToBlacklist(address user) external onlyOwner {
        blacklistedAddresses[user] = true;
    }
    
    /**
     * @notice Remove address from blacklist
     * @param user Address to remove from blacklist
     */
    function removeFromBlacklist(address user) external onlyOwner {
        blacklistedAddresses[user] = false;
    }
    
    /**
     * @notice Manually reset circuit breaker
     * @param reason Reason for manual reset
     */
    function resetCircuitBreaker(string calldata reason) external onlyOwner {
        _resetCircuitBreaker(reason);
    }
    
    /**
     * @notice Set emergency contact
     * @param newEmergencyContact New emergency contact address
     */
    function setEmergencyContact(address newEmergencyContact) external onlyOwner {
        emergencyContact = newEmergencyContact;
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
}