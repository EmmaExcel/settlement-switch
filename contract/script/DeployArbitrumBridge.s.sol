// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../src/BridgeErrorHandler.sol";
import "../src/interfaces/IInbox.sol";

/**
 * @title ArbitrumL2Bridge
 * @dev L2-specific bridge contract for handling ETH on Arbitrum
 * @notice Manages ETH deposits and withdrawal initiations on Arbitrum
 */
contract ArbitrumL2Bridge {
    
    // ============ Constants ============
    
    /// @notice ArbSys precompile address
    address public constant ARB_SYS = 0x0000000000000000000000000000000000000064;
    
    /// @notice Minimum withdrawal amount
    uint256 public constant MIN_WITHDRAWAL = 0.001 ether;
    
    /// @notice Maximum withdrawal amount
    uint256 public constant MAX_WITHDRAWAL = 1000 ether;
    
    /// @notice Withdrawal fee in basis points (25 = 0.25%)
    uint256 public constant WITHDRAWAL_FEE_BPS = 25;
    
    // ============ State Variables ============
    
    address public owner;
    bool public paused;
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    
    mapping(address => uint256) public userDeposits;
    mapping(bytes32 => bool) public processedWithdrawals;
    
    // ============ Events ============
    
    event ETHDeposited(address indexed user, uint256 amount, uint256 timestamp);
    event WithdrawalInitiated(
        bytes32 indexed withdrawalId,
        address indexed user,
        uint256 amount,
        address l1Recipient
    );
    
    // ============ Errors ============
    
    error InvalidAmount();
    error InvalidRecipient();
    error InsufficientBalance();
    error WithdrawalAlreadyProcessed();
    error ContractPaused();
    error OnlyOwner();
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _owner) {
        owner = _owner;
    }
    
    // ============ Main Functions ============
    
    /**
     * @notice Deposit ETH to the L2 bridge
     */
    function depositETH() external payable whenNotPaused {
        if (msg.value < MIN_WITHDRAWAL) revert InvalidAmount();
        if (msg.value > MAX_WITHDRAWAL) revert InvalidAmount();
        
        userDeposits[msg.sender] += msg.value;
        totalDeposited += msg.value;
        
        emit ETHDeposited(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @notice Initiate withdrawal to L1
     * @param amount Amount to withdraw
     * @param l1Recipient Recipient address on L1
     */
    function initiateWithdrawal(
        uint256 amount,
        address l1Recipient
    ) external whenNotPaused {
        if (amount < MIN_WITHDRAWAL) revert InvalidAmount();
        if (amount > MAX_WITHDRAWAL) revert InvalidAmount();
        if (l1Recipient == address(0)) revert InvalidRecipient();
        if (userDeposits[msg.sender] < amount) revert InsufficientBalance();
        
        bytes32 withdrawalId = keccak256(
            abi.encodePacked(msg.sender, amount, l1Recipient, block.timestamp)
        );
        
        if (processedWithdrawals[withdrawalId]) revert WithdrawalAlreadyProcessed();
        
        userDeposits[msg.sender] -= amount;
        totalWithdrawn += amount;
        processedWithdrawals[withdrawalId] = true;
        
        // Calculate fee
        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / 10000;
        uint256 netAmount = amount - fee;
        
        // Send withdrawal message to L1
        bytes memory data = abi.encodeWithSignature(
            "processWithdrawal(address,uint256,bytes32)",
            l1Recipient,
            netAmount,
            withdrawalId
        );
        
        IArbSys(ARB_SYS).sendTxToL1(l1Recipient, data);
        
        emit WithdrawalInitiated(withdrawalId, msg.sender, netAmount, l1Recipient);
    }
    
    // ============ Admin Functions ============
    
    function pause() external onlyOwner {
        paused = true;
    }
    
    function unpause() external onlyOwner {
        paused = false;
    }
    
    function withdrawFees(address recipient) external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = recipient.call{value: balance}("");
        require(success, "Transfer failed");
    }
    
    // ============ View Functions ============
    
    function getUserBalance(address user) external view returns (uint256) {
        return userDeposits[user];
    }
    
    /**
     * @notice Receive function to handle direct ETH transfers
     */
    receive() external payable {
        if (msg.value < MIN_WITHDRAWAL) revert InvalidAmount();
        if (msg.value > MAX_WITHDRAWAL) revert InvalidAmount();
        
        userDeposits[msg.sender] += msg.value;
        totalDeposited += msg.value;
        
        emit ETHDeposited(msg.sender, msg.value, block.timestamp);
    }
}

/**
 * @title DeployArbitrumBridge
 * @dev Deployment script for Arbitrum bridge components
 * @notice Deploys L2 bridge contracts on Arbitrum networks
 */
contract DeployArbitrumBridge is Script {
    
    // ============ Deployed Contracts ============
    
    ArbitrumL2Bridge public l2Bridge;
    BridgeErrorHandler public errorHandler;
    
    // ============ Network Configurations ============
    
    struct ArbitrumNetworkConfig {
        string networkName;
        uint256 chainId;
        uint256 deployerPrivateKey;
        address expectedDeployer;
    }
    
    mapping(uint256 => ArbitrumNetworkConfig) public arbitrumNetworkConfigs;
    
    // ============ Setup ============
    
    function setUp() public {
        // Arbitrum One (Mainnet)
        arbitrumNetworkConfigs[42161] = ArbitrumNetworkConfig({
            networkName: "arbitrum",
            chainId: 42161,
            deployerPrivateKey: vm.envUint("PRIVATE_KEY"),
            expectedDeployer: vm.addr(vm.envUint("PRIVATE_KEY"))
        });
        
        // Arbitrum Sepolia (Testnet)
        arbitrumNetworkConfigs[421614] = ArbitrumNetworkConfig({
            networkName: "arbitrum_sepolia",
            chainId: 421614,
            deployerPrivateKey: vm.envUint("PRIVATE_KEY"),
            expectedDeployer: vm.addr(vm.envUint("PRIVATE_KEY"))
        });
        
        // Arbitrum Goerli (Deprecated but included for completeness)
        arbitrumNetworkConfigs[421613] = ArbitrumNetworkConfig({
            networkName: "arbitrum_goerli",
            chainId: 421613,
            deployerPrivateKey: vm.envUint("PRIVATE_KEY"),
            expectedDeployer: vm.addr(vm.envUint("PRIVATE_KEY"))
        });
    }
    
    // ============ Main Deployment ============
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying Arbitrum Bridge contracts...");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy error handler
        errorHandler = new BridgeErrorHandler(deployer, deployer); // Using deployer as both owner and emergency contact
        console2.log("BridgeErrorHandler deployed at:", address(errorHandler));
        
        // Deploy L2 bridge
        l2Bridge = new ArbitrumL2Bridge(deployer);
        console2.log("ArbitrumL2Bridge deployed at:", address(l2Bridge));
        
        // Configure contracts
        _configureContracts(deployer);
        
        vm.stopBroadcast();
        
        // Verify contracts
        _verifyContracts();
        
        // Log deployment summary
        _logDeploymentSummary();
    }
    
    // ============ Configuration ============
    
    function _configureContracts(address deployer) internal {
        console2.log("Configuring contracts...");
        
        // Configuration completed - no additional setup needed for error handler
        
        console2.log("Configuration completed");
    }
    
    // ============ Verification ============
    
    function _verifyContracts() internal {
        console2.log("Verifying contracts...");
        
        // Verify BridgeErrorHandler
        try vm.ffi(_buildVerifyCommand(
            address(errorHandler),
            "src/BridgeErrorHandler.sol:BridgeErrorHandler"
        )) {
            console2.log("BridgeErrorHandler verified successfully");
        } catch {
            console2.log("BridgeErrorHandler verification failed");
        }
        
        // Verify ArbitrumL2Bridge
        try vm.ffi(_buildVerifyCommand(
            address(l2Bridge),
            "script/DeployArbitrumBridge.s.sol:ArbitrumL2Bridge"
        )) {
            console2.log("ArbitrumL2Bridge verified successfully");
        } catch {
            console2.log("ArbitrumL2Bridge verification failed");
        }
    }
    
    function _buildVerifyCommand(
        address contractAddress,
        string memory contractPath
    ) internal view returns (string[] memory) {
        string[] memory cmd = new string[](6);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(contractAddress);
        cmd[3] = contractPath;
        cmd[4] = "--chain-id";
        cmd[5] = vm.toString(block.chainid);
        return cmd;
    }
    
    // ============ Logging ============
    
    function _logDeploymentSummary() internal view {
        console2.log("\n=== Arbitrum Bridge Deployment Summary ===");
        console2.log("Network:", _getNetworkName());
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", msg.sender);
        console2.log("");
        console2.log("Deployed Contracts:");
        console2.log("- BridgeErrorHandler:", address(errorHandler));
        console2.log("- ArbitrumL2Bridge:", address(l2Bridge));
        console2.log("");
        console2.log("Next Steps:");
        console2.log("1. Fund the L2Bridge contract with initial ETH");
        console2.log("2. Configure cross-chain message passing");
        console2.log("3. Set up monitoring and alerting");
        console2.log("4. Test bridge functionality on testnet");
        console2.log("==========================================");
    }
    
    function _getNetworkName() internal view returns (string memory) {
        if (block.chainid == 42161) return "Arbitrum One";
        if (block.chainid == 421614) return "Arbitrum Sepolia";
        if (block.chainid == 421613) return "Arbitrum Goerli";
        return "Unknown Network";
    }
    
    // ============ Utility Functions ============
    
    /**
     * @notice Deploy to specific Arbitrum network
     * @param chainId Target Arbitrum chain ID
     */
    function deployToArbitrumNetwork(uint256 chainId) external {
        ArbitrumNetworkConfig memory config = arbitrumNetworkConfigs[chainId];
        require(config.deployerPrivateKey != 0, "Network not configured");
        
        vm.createSelectFork(vm.rpcUrl(config.networkName));
        run();
    }
}

// ============ Interface Definitions ============

/**
 * @notice ArbSys interface for L2 to L1 messaging
 */
interface IArbSys {
    function sendTxToL1(address destination, bytes calldata data) external payable returns (uint256);
}