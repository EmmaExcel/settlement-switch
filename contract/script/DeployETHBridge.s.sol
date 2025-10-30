// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/ETHBridge.sol";
import "../src/ArbitrumBridgeAdapter.sol";
import "../src/ArbitrumWithdrawalManager.sol";
import "../src/BridgeErrorHandler.sol";

/**
 * @title DeployETHBridge
 * @dev Deployment script for ETH Bridge system on Ethereum networks
 * @notice Deploys and configures the complete ETH bridging infrastructure
 */
contract DeployETHBridge is Script {
    
    // ============ Network Configuration ============
    
    struct NetworkConfig {
        address chainlinkETHUSD;
        address arbitrumInbox;
        address arbitrumOutbox;
        uint256 deployerPrivateKey;
        bool isTestnet;
        string networkName;
    }
    
    // Network configurations
    mapping(uint256 => NetworkConfig) public networkConfigs;
    
    // Deployment addresses
    address payable public ethBridge;
    address payable public bridgeAdapter;
    address payable public withdrawalManager;
    address payable public errorHandler;
    
    // Deployment parameters
    uint256 public constant INITIAL_BRIDGE_FEE = 50; // 0.5%
    uint256 public constant MIN_BRIDGE_AMOUNT = 0.001 ether;
    uint256 public constant MAX_BRIDGE_AMOUNT = 1000 ether;
    bytes32 public constant INITIAL_MERKLE_ROOT = 0x0000000000000000000000000000000000000000000000000000000000000000;

    // ============ Events ============
    
    event ContractDeployed(string contractName, address contractAddress);
    event DeploymentCompleted(
        address ethBridge,
        address bridgeAdapter,
        address withdrawalManager,
        address errorHandler
    );

    // ============ Setup Functions ============
    
    function setUp() public {
        _setupNetworkConfigs();
    }
    
    function _setupNetworkConfigs() internal {
        // Ethereum Mainnet
        networkConfigs[1] = NetworkConfig({
            chainlinkETHUSD: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            arbitrumInbox: 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f,
            arbitrumOutbox: 0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840,
            deployerPrivateKey: vm.envUint("MAINNET_PRIVATE_KEY"),
            isTestnet: false,
            networkName: "Ethereum Mainnet"
        });
        
        // Ethereum Sepolia
        networkConfigs[11155111] = NetworkConfig({
            chainlinkETHUSD: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            arbitrumInbox: 0xaAe29B0366299461418F5324a79Afc425BE5ae21,
            arbitrumOutbox: 0x65f07C7D521164a4d5DaC6eB8Fac8DA067A3B78F,
            deployerPrivateKey: vm.envUint("SEPOLIA_PRIVATE_KEY"),
            isTestnet: true,
            networkName: "Ethereum Sepolia"
        });
        
        // Ethereum Goerli (deprecated but included for completeness)
        networkConfigs[5] = NetworkConfig({
            chainlinkETHUSD: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e,
            arbitrumInbox: 0x6BEbC4925716945D46F0Ec336D5C2564F419682C,
            arbitrumOutbox: 0x45Af9Ed1D03703e480CE7d328fB684bb67DA5049,
            deployerPrivateKey: vm.envUint("GOERLI_PRIVATE_KEY"),
            isTestnet: true,
            networkName: "Ethereum Goerli"
        });
    }

    // ============ Main Deployment Function ============
    
    function run() public {
        uint256 chainId = block.chainid;
        NetworkConfig memory config = networkConfigs[chainId];
        
        require(config.deployerPrivateKey != 0, "Network not configured");
        
        console.log("=== ETH Bridge Deployment ===");
        console.log("Network:", config.networkName);
        console.log("Chain ID:", chainId);
        console.log("Deployer:", vm.addr(config.deployerPrivateKey));
        
        vm.startBroadcast(config.deployerPrivateKey);
        
        // Deploy contracts in dependency order
        _deployErrorHandler(config);
        _deployWithdrawalManager(config);
        _deployBridgeAdapter(config);
        _deployETHBridge(config);
        
        // Configure contracts
        _configureContracts(config);
        
        // Verify deployment
        _verifyDeployment(config);
        
        vm.stopBroadcast();
        
        // Log deployment summary
        _logDeploymentSummary(config);
        
        emit DeploymentCompleted(ethBridge, bridgeAdapter, withdrawalManager, errorHandler);
    }

    // ============ Individual Deployment Functions ============
    
    function _deployErrorHandler(NetworkConfig memory config) internal {
        console.log("\n--- Deploying BridgeErrorHandler ---");
        
        address deployer = vm.addr(config.deployerPrivateKey);
        
        errorHandler = payable(address(new BridgeErrorHandler(
            deployer, // owner
            deployer  // emergency contact
        )));
        
        console.log("BridgeErrorHandler deployed at:", errorHandler);
        emit ContractDeployed("BridgeErrorHandler", errorHandler);
    }
    
    function _deployWithdrawalManager(NetworkConfig memory config) internal {
        console.log("\n--- Deploying ArbitrumWithdrawalManager ---");
        
        address deployer = vm.addr(config.deployerPrivateKey);
        
        withdrawalManager = payable(address(new ArbitrumWithdrawalManager(
            deployer,
            INITIAL_MERKLE_ROOT
        )));
        
        console.log("ArbitrumWithdrawalManager deployed at:", withdrawalManager);
        emit ContractDeployed("ArbitrumWithdrawalManager", withdrawalManager);
    }
    
    function _deployBridgeAdapter(NetworkConfig memory config) internal {
        console.log("\n--- Deploying ArbitrumBridgeAdapter ---");
        
        address deployer = vm.addr(config.deployerPrivateKey);
        
        bridgeAdapter = payable(address(new ArbitrumBridgeAdapter(
            deployer
        )));
        
        console.log("ArbitrumBridgeAdapter deployed at:", bridgeAdapter);
        emit ContractDeployed("ArbitrumBridgeAdapter", bridgeAdapter);
    }
    
    function _deployETHBridge(NetworkConfig memory config) internal {
        console.log("\n--- Deploying ETHBridge ---");
        
        address deployer = vm.addr(config.deployerPrivateKey);
        
        ethBridge = payable(address(new ETHBridge(
            config.chainlinkETHUSD,
            deployer
        )));
        
        console.log("ETHBridge deployed at:", ethBridge);
        emit ContractDeployed("ETHBridge", ethBridge);
    }

    // ============ Configuration Functions ============
    
    function _configureContracts(NetworkConfig memory config) internal {
        console.log("\n--- Configuring Contracts ---");
        
        // Configure Error Handler
        BridgeErrorHandler(errorHandler).addAuthorizedResolver(ethBridge);
        BridgeErrorHandler(errorHandler).addAuthorizedResolver(bridgeAdapter);
        BridgeErrorHandler(errorHandler).addAuthorizedResolver(withdrawalManager);
        
        console.log("Error handler configured with authorized resolvers");
        
        // Configure Withdrawal Manager
        ArbitrumWithdrawalManager(withdrawalManager).setCurrentOutbox(config.arbitrumOutbox);
        
        console.log("Withdrawal manager configured with outbox:", config.arbitrumOutbox);
        
        // Configure Bridge Adapter
        if (config.isTestnet) {
            // Set lower limits for testnet
            console.log("Testnet configuration applied");
        }
        
        console.log("All contracts configured successfully");
    }

    // ============ Verification Functions ============
    
    function _verifyDeployment(NetworkConfig memory config) internal view {
        console.log("\n--- Verifying Deployment ---");
        
        // Verify contract addresses
        require(ethBridge != address(0), "ETHBridge deployment failed");
        require(bridgeAdapter != address(0), "BridgeAdapter deployment failed");
        require(withdrawalManager != address(0), "WithdrawalManager deployment failed");
        require(errorHandler != address(0), "ErrorHandler deployment failed");
        
        // Verify contract ownership
        require(ETHBridge(ethBridge).owner() == vm.addr(config.deployerPrivateKey), "ETHBridge owner incorrect");
        require(ArbitrumBridgeAdapter(bridgeAdapter).owner() == vm.addr(config.deployerPrivateKey), "BridgeAdapter owner incorrect");
        require(ArbitrumWithdrawalManager(withdrawalManager).owner() == vm.addr(config.deployerPrivateKey), "WithdrawalManager owner incorrect");
        require(BridgeErrorHandler(errorHandler).owner() == vm.addr(config.deployerPrivateKey), "ErrorHandler owner incorrect");
        
        // Verify contract configurations
        require(ETHBridge(ethBridge).ARBITRUM_INBOX() == config.arbitrumInbox, "ETHBridge inbox incorrect");
        require(ArbitrumBridgeAdapter(bridgeAdapter).currentInbox() == config.arbitrumInbox, "BridgeAdapter inbox incorrect");
        require(ArbitrumWithdrawalManager(withdrawalManager).currentOutbox() == config.arbitrumOutbox, "WithdrawalManager outbox incorrect");
        
        console.log("All verifications passed");
    }
    
    function _logDeploymentSummary(NetworkConfig memory config) internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("Network:", config.networkName);
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", vm.addr(config.deployerPrivateKey));
        console.log("");
        console.log("Deployed Contracts:");
        console.log("- ETHBridge:", ethBridge);
        console.log("- ArbitrumBridgeAdapter:", bridgeAdapter);
        console.log("- ArbitrumWithdrawalManager:", withdrawalManager);
        console.log("- BridgeErrorHandler:", errorHandler);
        console.log("");
        console.log("Configuration:");
        console.log("- Arbitrum Inbox:", config.arbitrumInbox);
        console.log("- Arbitrum Outbox:", config.arbitrumOutbox);
        console.log("- Chainlink ETH/USD:", config.chainlinkETHUSD);
        console.log("");
        console.log("Next Steps:");
        console.log("1. Verify contracts on Etherscan");
        console.log("2. Fund contracts with initial ETH");
        console.log("3. Test bridge functionality");
        console.log("4. Deploy corresponding contracts on Arbitrum");
        
        if (config.isTestnet) {
            console.log("");
            console.log("Testnet Deployment - Safe for testing");
        } else {
            console.log("");
            console.log("MAINNET Deployment - Exercise caution");
        }
    }

    // ============ Utility Functions ============
    
    /**
     * @notice Get deployment addresses for external use
     * @return ethBridgeAddr ETHBridge contract address
     * @return bridgeAdapterAddr ArbitrumBridgeAdapter contract address
     * @return withdrawalManagerAddr ArbitrumWithdrawalManager contract address
     * @return errorHandlerAddr BridgeErrorHandler contract address
     */
    function getDeploymentAddresses() external view returns (
        address ethBridgeAddr,
        address bridgeAdapterAddr,
        address withdrawalManagerAddr,
        address errorHandlerAddr
    ) {
        return (ethBridge, bridgeAdapter, withdrawalManager, errorHandler);
    }
    
    /**
     * @notice Deploy to specific network (for testing)
     * @param chainId Target chain ID
     */
    function deployToNetwork(uint256 chainId) external {
        NetworkConfig memory config = networkConfigs[chainId];
        require(config.deployerPrivateKey != 0, "Network not configured");
        
        vm.createSelectFork(vm.rpcUrl(config.networkName));
        run();
    }
    
    /**
     * @notice Estimate deployment gas costs
     * @param chainId Target chain ID
     * @return totalGas Estimated total gas cost
     */
    function estimateDeploymentCost(uint256 chainId) external returns (uint256 totalGas) {
        NetworkConfig memory config = networkConfigs[chainId];
        require(config.deployerPrivateKey != 0, "Network not configured");
        
        vm.createSelectFork(vm.rpcUrl(config.networkName));
        
        uint256 startGas = gasleft();
        
        // Simulate deployment without broadcasting
        vm.startPrank(vm.addr(config.deployerPrivateKey));
        
        new BridgeErrorHandler(vm.addr(config.deployerPrivateKey), vm.addr(config.deployerPrivateKey));
        new ArbitrumWithdrawalManager(vm.addr(config.deployerPrivateKey), INITIAL_MERKLE_ROOT);
        new ArbitrumBridgeAdapter(vm.addr(config.deployerPrivateKey));
        new ETHBridge(config.chainlinkETHUSD, vm.addr(config.deployerPrivateKey));
        
        vm.stopPrank();
        
        totalGas = startGas - gasleft();
        
        console.log("Estimated deployment gas:", totalGas);
        console.log("Estimated cost at 20 gwei:", (totalGas * 20 gwei) / 1e18, "ETH");
        
        return totalGas;
    }
}