// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeAdapter.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";


contract BridgeRegistry is AccessControl, ReentrancyGuard, Pausable {
    /// @notice Role for bridge adapter management
    bytes32 public constant BRIDGE_MANAGER_ROLE = keccak256("BRIDGE_MANAGER_ROLE");
    
    /// @notice Role for emergency operations
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /// @notice Bridge adapter information
    struct BridgeInfo {
        address adapter;            // Bridge adapter contract address
        string name;                // Bridge protocol name
        bool isEnabled;             // Whether bridge is currently enabled
        bool isHealthy;             // Current health status
        uint256 registeredAt;       // Registration timestamp
        uint256 lastHealthCheck;    // Last health check timestamp
        uint256 totalTransfers;     // Total number of transfers
        uint256 failedTransfers;    // Number of failed transfers
        uint256 totalVolume;        // Total volume transferred (in Wei)
        string[] supportedChains;   // List of supported chain names
        address[] supportedTokens;  // List of supported token addresses
    }

  
    struct HealthConfig {
        uint256 checkInterval;      // Minimum interval between health checks
        uint256 failureThreshold;  // Max failure rate before marking unhealthy (basis points)
        uint256 volumeThreshold;    // Minimum volume for health assessment
        bool autoDisable;           // Whether to auto-disable unhealthy bridges
    }

    
    struct PerformanceMetrics {
        uint256 avgGasCost;         // Average gas cost
        uint256 avgCompletionTime;  // Average completion time in seconds
        uint256 successRate;        // Success rate in basis points (0-10000)
        uint256 liquidityScore;     // Liquidity availability score (0-100)
        uint256 reliabilityScore;   // Overall reliability score (0-100)
        uint256 lastUpdated;        // Last metrics update timestamp
    }

 
    mapping(address => BridgeInfo) public bridgeInfo;
    mapping(address => PerformanceMetrics) public performanceMetrics;
    mapping(uint256 => address[]) public chainToBridges; // chainId => bridge adapters
    mapping(address => mapping(uint256 => bool)) public bridgeSupportsChain;
    
    address[] public registeredBridges;
    address[] public enabledBridges;
    
    HealthConfig public healthConfig;
    

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DEFAULT_FAILURE_THRESHOLD = 1000; // 10%
    uint256 public constant DEFAULT_CHECK_INTERVAL = 3600; // 1 hour
    uint256 public constant MIN_VOLUME_FOR_HEALTH = 1000 ether;


    event BridgeRegistered(
        address indexed adapter,
        string name,
        address indexed registrar
    );
    
    event BridgeDeregistered(
        address indexed adapter,
        address indexed deregistrar,
        string reason
    );
    
    event BridgeEnabled(address indexed adapter, address indexed enabler);
    event BridgeDisabled(address indexed adapter, address indexed disabler, string reason);
    
    event HealthStatusChanged(
        address indexed adapter,
        bool isHealthy,
        uint256 successRate,
        string reason
    );
    
    event PerformanceMetricsUpdated(
        address indexed adapter,
        PerformanceMetrics metrics
    );
    
    event HealthConfigUpdated(HealthConfig newConfig);
    
    event EmergencyBridgeShutdown(
        address indexed adapter,
        address indexed emergency_admin,
        string reason
    );

    // Errors
    error BridgeAlreadyRegistered();
    error BridgeNotRegistered();
    error BridgeNotEnabled();
    error InvalidBridgeAdapter();
    error UnauthorizedHealthCheck();
    error InvalidHealthConfig();
    error EmergencyShutdownActive();

  
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(BRIDGE_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        
        // Initialize default health config
        healthConfig = HealthConfig({
            checkInterval: DEFAULT_CHECK_INTERVAL,
            failureThreshold: DEFAULT_FAILURE_THRESHOLD,
            volumeThreshold: MIN_VOLUME_FOR_HEALTH,
            autoDisable: true
        });
    }

  
    function registerBridge(
        address adapter,
        uint256[] calldata supportedChainIds,
        address[] calldata supportedTokens
    ) external onlyRole(BRIDGE_MANAGER_ROLE) whenNotPaused {
        if (adapter == address(0)) revert InvalidBridgeAdapter();
        if (bridgeInfo[adapter].adapter != address(0)) revert BridgeAlreadyRegistered();

        // Verify adapter implements IBridgeAdapter
        try IBridgeAdapter(adapter).getBridgeName() returns (string memory name) {
            // Create bridge info
            BridgeInfo storage info = bridgeInfo[adapter];
            info.adapter = adapter;
            info.name = name;
            info.isEnabled = true; // Enable by default
            info.isHealthy = true; // Assume healthy initially
            info.registeredAt = block.timestamp;
            info.lastHealthCheck = block.timestamp;
            info.supportedTokens = supportedTokens;

            // Store supported chains
            for (uint256 i = 0; i < supportedChainIds.length; i++) {
                uint256 chainId = supportedChainIds[i];
                chainToBridges[chainId].push(adapter);
                bridgeSupportsChain[adapter][chainId] = true;
                info.supportedChains.push(_chainIdToName(chainId));
            }

            // Add to registries
            registeredBridges.push(adapter);
            enabledBridges.push(adapter);

            // Initialize performance metrics
            performanceMetrics[adapter] = PerformanceMetrics({
                avgGasCost: 0,
                avgCompletionTime: 0,
                successRate: BASIS_POINTS, // Start with 100% success rate
                liquidityScore: 100,
                reliabilityScore: 100,
                lastUpdated: block.timestamp
            });

            emit BridgeRegistered(adapter, name, msg.sender);
        } catch {
            revert InvalidBridgeAdapter();
        }
    }

   
    function deregisterBridge(
        address adapter,
        string calldata reason
    ) external onlyRole(BRIDGE_MANAGER_ROLE) {
        if (bridgeInfo[adapter].adapter == address(0)) revert BridgeNotRegistered();

        // Remove from enabled bridges if present
        _removeFromEnabledBridges(adapter);
        
        // Remove from registered bridges
        _removeFromRegisteredBridges(adapter);
        
        // Remove from chain mappings
        BridgeInfo storage info = bridgeInfo[adapter];
        for (uint256 i = 0; i < info.supportedChains.length; i++) {
            uint256 chainId = _chainNameToId(info.supportedChains[i]);
            _removeFromChainBridges(chainId, adapter);
            bridgeSupportsChain[adapter][chainId] = false;
        }

        // Clear bridge info
        delete bridgeInfo[adapter];
        delete performanceMetrics[adapter];

        emit BridgeDeregistered(adapter, msg.sender, reason);
    }

    function enableBridge(address adapter) external onlyRole(BRIDGE_MANAGER_ROLE) whenNotPaused {
        BridgeInfo storage info = bridgeInfo[adapter];
        if (info.adapter == address(0)) revert BridgeNotRegistered();
        
        if (!info.isEnabled) {
            info.isEnabled = true;
            enabledBridges.push(adapter);
            emit BridgeEnabled(adapter, msg.sender);
        }
    }

 
    function disableBridge(
        address adapter,
        string calldata reason
    ) external onlyRole(BRIDGE_MANAGER_ROLE) {
        BridgeInfo storage info = bridgeInfo[adapter];
        if (info.adapter == address(0)) revert BridgeNotRegistered();
        
        if (info.isEnabled) {
            info.isEnabled = false;
            _removeFromEnabledBridges(adapter);
            emit BridgeDisabled(adapter, msg.sender, reason);
        }
    }

    
    function emergencyShutdown(
        address adapter,
        string calldata reason
    ) external onlyRole(EMERGENCY_ROLE) {
        BridgeInfo storage info = bridgeInfo[adapter];
        if (info.adapter == address(0)) revert BridgeNotRegistered();
        
        info.isEnabled = false;
        info.isHealthy = false;
        _removeFromEnabledBridges(adapter);
        
        emit EmergencyBridgeShutdown(adapter, msg.sender, reason);
        emit BridgeDisabled(adapter, msg.sender, reason);
    }

 
    function performHealthCheck(address adapter) external nonReentrant {
        BridgeInfo storage info = bridgeInfo[adapter];
        if (info.adapter == address(0)) revert BridgeNotRegistered();
        
        // Check if enough time has passed since last health check
        if (block.timestamp - info.lastHealthCheck < healthConfig.checkInterval) {
            revert UnauthorizedHealthCheck();
        }

        bool wasHealthy = info.isHealthy;
        bool isCurrentlyHealthy = _assessBridgeHealth(adapter);
        
        info.isHealthy = isCurrentlyHealthy;
        info.lastHealthCheck = block.timestamp;

        // Auto-disable if configured and bridge becomes unhealthy
        if (healthConfig.autoDisable && wasHealthy && !isCurrentlyHealthy && info.isEnabled) {
            info.isEnabled = false;
            _removeFromEnabledBridges(adapter);
            emit BridgeDisabled(adapter, address(this), "Auto-disabled due to poor health");
        }

        if (wasHealthy != isCurrentlyHealthy) {
            PerformanceMetrics memory metrics = performanceMetrics[adapter];
            emit HealthStatusChanged(
                adapter,
                isCurrentlyHealthy,
                metrics.successRate,
                isCurrentlyHealthy ? "Health restored" : "Health degraded"
            );
        }
    }

    function updatePerformanceMetrics(
        address adapter,
        uint256 gasCost,
        uint256 completionTime,
        bool successful,
        uint256 volume
    ) external {
        BridgeInfo storage info = bridgeInfo[adapter];
        if (info.adapter == address(0)) revert BridgeNotRegistered();

        // Update transfer counts
        info.totalTransfers++;
        info.totalVolume += volume;
        
        if (!successful) {
            info.failedTransfers++;
        }

        // Update performance metrics using exponential moving average
        PerformanceMetrics storage metrics = performanceMetrics[adapter];
        
        // Update average gas cost
        if (metrics.avgGasCost == 0) {
            metrics.avgGasCost = gasCost;
        } else {
            metrics.avgGasCost = (metrics.avgGasCost * 9 + gasCost) / 10;
        }

        // Update average completion time
        if (metrics.avgCompletionTime == 0) {
            metrics.avgCompletionTime = completionTime;
        } else {
            metrics.avgCompletionTime = (metrics.avgCompletionTime * 9 + completionTime) / 10;
        }

        // Update success rate
        metrics.successRate = ((info.totalTransfers - info.failedTransfers) * BASIS_POINTS) / info.totalTransfers;

        // Update reliability score based on success rate and consistency
        metrics.reliabilityScore = _calculateReliabilityScore(adapter);

        metrics.lastUpdated = block.timestamp;

        emit PerformanceMetricsUpdated(adapter, metrics);
    }

  
    function getEnabledBridges() external view returns (address[] memory bridges) {
        return enabledBridges;
    }

  
    function getRegisteredBridges() external view returns (address[] memory bridges) {
        return registeredBridges;
    }

  
    function getBridgesForChain(uint256 chainId) external view returns (address[] memory bridges) {
        address[] memory allBridges = chainToBridges[chainId];
        uint256 enabledCount = 0;

        // Count enabled bridges
        for (uint256 i = 0; i < allBridges.length; i++) {
            if (bridgeInfo[allBridges[i]].isEnabled && bridgeInfo[allBridges[i]].isHealthy) {
                enabledCount++;
            }
        }

        // Create result array
        bridges = new address[](enabledCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allBridges.length; i++) {
            if (bridgeInfo[allBridges[i]].isEnabled && bridgeInfo[allBridges[i]].isHealthy) {
                bridges[index] = allBridges[i];
                index++;
            }
        }

        return bridges;
    }

  
    function doesBridgeSupportChain(address adapter, uint256 chainId) external view returns (bool supported) {
        return bridgeSupportsChain[adapter][chainId];
    }

 
    function getBridgeDetails(address adapter) external view returns (
        BridgeInfo memory info,
        PerformanceMetrics memory metrics
    ) {
        return (bridgeInfo[adapter], performanceMetrics[adapter]);
    }

    
    function updateHealthConfig(HealthConfig calldata newConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newConfig.failureThreshold > BASIS_POINTS) revert InvalidHealthConfig();
        if (newConfig.checkInterval == 0) revert InvalidHealthConfig();
        
        healthConfig = newConfig;
        emit HealthConfigUpdated(newConfig);
    }

    
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

   
    function _assessBridgeHealth(address adapter) internal view returns (bool healthy) {
        BridgeInfo memory info = bridgeInfo[adapter];
        PerformanceMetrics memory metrics = performanceMetrics[adapter];

        // Check if bridge is responsive
        try IBridgeAdapter(adapter).isHealthy() returns (bool bridgeHealthy) {
            if (!bridgeHealthy) return false;
        } catch {
            return false; // Bridge is not responsive
        }

        // Check minimum volume threshold
        if (info.totalVolume < healthConfig.volumeThreshold) {
            return true; // Not enough data, assume healthy
        }

        // Check failure rate
        uint256 failureRate = (info.failedTransfers * BASIS_POINTS) / info.totalTransfers;
        if (failureRate > healthConfig.failureThreshold) {
            return false;
        }

        // Check success rate from metrics
        if (metrics.successRate < (BASIS_POINTS - healthConfig.failureThreshold)) {
            return false;
        }

        return true;
    }

    function _calculateReliabilityScore(address adapter) internal view returns (uint256 score) {
        BridgeInfo memory info = bridgeInfo[adapter];
        PerformanceMetrics memory metrics = performanceMetrics[adapter];

        if (info.totalTransfers == 0) return 100;

        // Base score from success rate
        score = metrics.successRate / 100; // Convert from basis points to percentage

        // Adjust for volume (more volume = more reliable data)
        if (info.totalVolume >= healthConfig.volumeThreshold * 10) {
            score = (score * 110) / 100; // 10% bonus for high volume
        } else if (info.totalVolume < healthConfig.volumeThreshold) {
            score = (score * 90) / 100; // 10% penalty for low volume
        }

        // Adjust for consistency (lower variance in completion time = higher score)
        // This is simplified - in production, you'd track variance
        if (metrics.avgCompletionTime > 0 && metrics.avgCompletionTime < 1800) { // < 30 minutes
            score = (score * 105) / 100; // 5% bonus for fast completion
        }

        // Cap at 100
        return score > 100 ? 100 : score;
    }

   
    function _removeFromEnabledBridges(address adapter) internal {
        for (uint256 i = 0; i < enabledBridges.length; i++) {
            if (enabledBridges[i] == adapter) {
                enabledBridges[i] = enabledBridges[enabledBridges.length - 1];
                enabledBridges.pop();
                break;
            }
        }
    }


    function _removeFromRegisteredBridges(address adapter) internal {
        for (uint256 i = 0; i < registeredBridges.length; i++) {
            if (registeredBridges[i] == adapter) {
                registeredBridges[i] = registeredBridges[registeredBridges.length - 1];
                registeredBridges.pop();
                break;
            }
        }
    }

   
    function _removeFromChainBridges(uint256 chainId, address adapter) internal {
        address[] storage bridges = chainToBridges[chainId];
        for (uint256 i = 0; i < bridges.length; i++) {
            if (bridges[i] == adapter) {
                bridges[i] = bridges[bridges.length - 1];
                bridges.pop();
                break;
            }
        }
    }

  
    function _chainIdToName(uint256 chainId) internal pure returns (string memory name) {
        if (chainId == 1) return "Ethereum";
        if (chainId == 11155111) return "Sepolia";
        if (chainId == 42161) return "Arbitrum";
        if (chainId == 421614) return "Arbitrum Sepolia";
        if (chainId == 137) return "Polygon";
        if (chainId == 80001) return "Mumbai";
        return "Unknown";
    }

   
    function _chainNameToId(string memory name) internal pure returns (uint256 chainId) {
        bytes32 nameHash = keccak256(bytes(name));
        if (nameHash == keccak256("Ethereum")) return 1;
        if (nameHash == keccak256("Sepolia")) return 11155111;
        if (nameHash == keccak256("Arbitrum")) return 42161;
        if (nameHash == keccak256("Arbitrum Sepolia")) return 421614;
        if (nameHash == keccak256("Polygon")) return 137;
        if (nameHash == keccak256("Mumbai")) return 80001;
        return 0;
    }
}