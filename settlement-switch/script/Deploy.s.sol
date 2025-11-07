// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/core/SettlementSwitch.sol";
import "../src/core/RouteCalculator.sol";
import "../src/core/BridgeRegistry.sol";
import "../src/core/FeeManager.sol";
import "../src/adapters/LayerZeroAdapter.sol";
import "../src/adapters/HopProtocolAdapter.sol";
import "../src/adapters/PolygonBridgeAdapter.sol";
import "../src/adapters/ArbitrumBridgeAdapter.sol";
import "../src/adapters/AcrossAdapter.sol";
import "../src/adapters/ConnextAdapter.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockPriceFeed.sol";

/**
 * @title Deploy
 * @notice Deployment script for SettlementSwitch system
 * @dev Supports deployment to testnet and mainnet with different configurations
 */
contract Deploy is Script {
    // Deployment configuration
    struct DeploymentConfig {
        string networkName;
        uint256 chainId;
        address admin;
        address treasury;
        bool isTestnet;
        bool deployMocks;
        address[] existingTokens;
        address[] existingPriceFeeds;
    }

    // Deployed contracts
    struct DeployedContracts {
        SettlementSwitch settlementSwitch;
        RouteCalculator routeCalculator;
        BridgeRegistry bridgeRegistry;
        FeeManager feeManager;
        address[] bridgeAdapters;
        address[] mockTokens;
        address[] priceFeeds;
    }

    // Network configurations
    mapping(uint256 => DeploymentConfig) public networkConfigs;
    
    // Constants
    uint256 public constant ETHEREUM_MAINNET = 1;
    uint256 public constant ETHEREUM_SEPOLIA = 11155111;
    uint256 public constant ARBITRUM_ONE = 42161;
    uint256 public constant ARBITRUM_SEPOLIA = 421614;
    uint256 public constant POLYGON_MAINNET = 137;
    uint256 public constant POLYGON_MUMBAI = 80001;

    function setUp() public {
        _initializeNetworkConfigs();
    }

    /**
     * @notice Initialize network configurations
     */
    function _initializeNetworkConfigs() internal {
        // Ethereum Sepolia (Testnet)
        networkConfigs[ETHEREUM_SEPOLIA] = DeploymentConfig({
            networkName: "Ethereum Sepolia",
            chainId: ETHEREUM_SEPOLIA,
            admin: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6, // Replace with actual admin
            treasury: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6, // Replace with actual treasury
            isTestnet: true,
            deployMocks: true,
            existingTokens: new address[](0),
            existingPriceFeeds: new address[](0)
        });

        // Arbitrum Sepolia (Testnet)
        networkConfigs[ARBITRUM_SEPOLIA] = DeploymentConfig({
            networkName: "Arbitrum Sepolia",
            chainId: ARBITRUM_SEPOLIA,
            admin: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            treasury: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            isTestnet: true,
            deployMocks: true,
            existingTokens: new address[](0),
            existingPriceFeeds: new address[](0)
        });

        // Polygon Mumbai (Testnet)
        networkConfigs[POLYGON_MUMBAI] = DeploymentConfig({
            networkName: "Polygon Mumbai",
            chainId: POLYGON_MUMBAI,
            admin: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            treasury: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            isTestnet: true,
            deployMocks: true,
            existingTokens: new address[](0),
            existingPriceFeeds: new address[](0)
        });

        // Ethereum Mainnet (Production)
        {
            address adminMainnet = vm.envAddress("ADMIN_ADDRESS_MAINNET");
            address treasuryMainnet = vm.envAddress("TREASURY_ADDRESS_MAINNET");

            // Token addresses from environment
            address usdcMainnet = vm.envAddress("USDC_ETHEREUM");
            address wethMainnet = vm.envAddress("WETH_ETHEREUM");

            // Price feeds from environment
            address ethUsdFeed = vm.envAddress("ETH_USD_FEED_ETHEREUM");
            address usdcUsdFeed = vm.envAddress("USDC_USD_FEED_ETHEREUM");

            address[] memory existingTokens = new address[](2);
            existingTokens[0] = usdcMainnet;
            existingTokens[1] = wethMainnet;

            address[] memory existingFeeds = new address[](2);
            existingFeeds[0] = ethUsdFeed;
            existingFeeds[1] = usdcUsdFeed;

            networkConfigs[ETHEREUM_MAINNET] = DeploymentConfig({
                networkName: "Ethereum Mainnet",
                chainId: ETHEREUM_MAINNET,
                admin: adminMainnet,
                treasury: treasuryMainnet,
                isTestnet: false,
                deployMocks: false,
                existingTokens: existingTokens,
                existingPriceFeeds: existingFeeds
            });
        }

        // Arbitrum One (Production)
        {
            address adminArbitrum = vm.envAddress("ADMIN_ADDRESS_MAINNET");
            address treasuryArbitrum = vm.envAddress("TREASURY_ADDRESS_MAINNET");

            // Token addresses from environment (Arbitrum)
            address usdcArbitrum = vm.envAddress("USDC_ARBITRUM");
            address wethArbitrum = vm.envAddress("WETH_ARBITRUM");

            // Price feeds from environment (Arbitrum)
            address ethUsdFeedArb = vm.envAddress("ETH_USD_FEED_ARBITRUM");
            address usdcUsdFeedArb = vm.envAddress("USDC_USD_FEED_ARBITRUM");

            address[] memory existingTokensArb = new address[](2);
            existingTokensArb[0] = usdcArbitrum;
            existingTokensArb[1] = wethArbitrum;

            address[] memory existingFeedsArb = new address[](2);
            existingFeedsArb[0] = ethUsdFeedArb;
            existingFeedsArb[1] = usdcUsdFeedArb;

            networkConfigs[ARBITRUM_ONE] = DeploymentConfig({
                networkName: "Arbitrum One",
                chainId: ARBITRUM_ONE,
                admin: adminArbitrum,
                treasury: treasuryArbitrum,
                isTestnet: false,
                deployMocks: false,
                existingTokens: existingTokensArb,
                existingPriceFeeds: existingFeedsArb
            });
        }
    }

    /**
     * @notice Main deployment function
     */
    function run() external {
        // Allow overriding chain id in environments where the RPC alias may not reflect the actual chain id
        uint256 chainId = vm.envOr("CHAIN_ID_OVERRIDE", block.chainid);
        DeploymentConfig memory config = networkConfigs[chainId];
        
        require(config.chainId != 0, "Unsupported network");
        
        console.log("Deploying to:", config.networkName);
        console.log("Chain ID:", config.chainId);
        console.log("Admin:", config.admin);
        console.log("Treasury:", config.treasury);

        vm.startBroadcast();
        // Minimal mode: skip core deployment and only deploy adapters (e.g., LayerZero-only)
        bool skipCore = vm.envOr("SKIP_CORE_DEPLOYMENT", false);
        DeployedContracts memory deployed;
        if (skipCore) {
            console.log("Skipping core deployment due to SKIP_CORE_DEPLOYMENT=true");
            deployed.bridgeAdapters = _deployBridgeAdapters(config);

            vm.stopBroadcast();
            _logDeploymentSummary(deployed, config);
            return;
        }

        deployed = _deploySystem(config);
        
        _configureSystem(deployed, config);
        
        _verifyDeployment(deployed, config);

        vm.stopBroadcast();

        _logDeploymentSummary(deployed, config);
    }

    /**
     * @notice Deploy the complete system
     * @param config Deployment configuration
     * @return deployed Deployed contracts
     */
    function _deploySystem(DeploymentConfig memory config) internal returns (DeployedContracts memory deployed) {
        console.log("Deploying core contracts...");

        // Deploy core contracts
        deployed.routeCalculator = new RouteCalculator();
        console.log("RouteCalculator deployed at:", address(deployed.routeCalculator));

        deployed.bridgeRegistry = new BridgeRegistry(config.admin);
        console.log("BridgeRegistry deployed at:", address(deployed.bridgeRegistry));

        deployed.feeManager = new FeeManager(config.admin, config.treasury);
        console.log("FeeManager deployed at:", address(deployed.feeManager));

        deployed.settlementSwitch = new SettlementSwitch(
            config.admin,
            address(deployed.routeCalculator),
            address(deployed.bridgeRegistry),
            payable(address(deployed.feeManager))
        );
        console.log("SettlementSwitch deployed at:", address(deployed.settlementSwitch));

        // Deploy bridge adapters
        deployed.bridgeAdapters = _deployBridgeAdapters(config);

        // Deploy mock contracts if needed
        if (config.deployMocks) {
            deployed.mockTokens = _deployMockTokens(config);
            deployed.priceFeeds = _deployMockPriceFeeds(config);
        }

        return deployed;
    }

    /**
     * @notice Deploy bridge adapters
     * @param config Deployment configuration
     * @return adapters Array of deployed adapter addresses
     */
    function _deployBridgeAdapters(DeploymentConfig memory config) internal returns (address[] memory adapters) {
        console.log("Deploying bridge adapters...");
        // Support a minimal deployment mode that only deploys the LayerZero adapter
        bool layerZeroOnly = vm.envOr("DEPLOY_LAYERZERO_ONLY", false);

        if (layerZeroOnly) {
            adapters = new address[](1);

            // LayerZero Adapter only
            LayerZeroAdapter layerZero = new LayerZeroAdapter();
            adapters[0] = address(layerZero);
            console.log("[LayerZero-only] LayerZeroAdapter deployed at:", address(layerZero));
        } else {
            adapters = new address[](6);

            // LayerZero Adapter
            LayerZeroAdapter layerZero = new LayerZeroAdapter();
            adapters[0] = address(layerZero);
            console.log("LayerZeroAdapter deployed at:", address(layerZero));

            // Hop Protocol Adapter
            HopProtocolAdapter hop = new HopProtocolAdapter();
            adapters[1] = address(hop);
            console.log("HopProtocolAdapter deployed at:", address(hop));

            // Polygon Bridge Adapter
            PolygonBridgeAdapter polygon = new PolygonBridgeAdapter();
            adapters[2] = address(polygon);
            console.log("PolygonBridgeAdapter deployed at:", address(polygon));

            // Arbitrum Bridge Adapter
            ArbitrumBridgeAdapter arbitrum = new ArbitrumBridgeAdapter();
            adapters[3] = address(arbitrum);
            console.log("ArbitrumBridgeAdapter deployed at:", address(arbitrum));

            // Across Adapter
            AcrossAdapter across = new AcrossAdapter();
            adapters[4] = address(across);
            console.log("AcrossAdapter deployed at:", address(across));

            // Connext Adapter
            ConnextAdapter connext = new ConnextAdapter();
            adapters[5] = address(connext);
            console.log("ConnextAdapter deployed at:", address(connext));
        }

        return adapters;
    }

    /**
     * @notice Deploy mock tokens for testing
     * @param config Deployment configuration
     * @return tokens Array of deployed token addresses
     */
    function _deployMockTokens(DeploymentConfig memory config) internal returns (address[] memory tokens) {
        if (!config.deployMocks) return tokens;

        console.log("Deploying mock tokens...");

        tokens = new address[](3);

        // Mock USDC
        MockERC20 usdc = new MockERC20("Mock USDC", "USDC", 6, 1000000000 * 1e6); // 1B USDC
        tokens[0] = address(usdc);
        console.log("Mock USDC deployed at:", address(usdc));

        // Mock WETH
        MockERC20 weth = new MockERC20("Mock WETH", "WETH", 18, 1000000 * 1e18); // 1M WETH
        tokens[1] = address(weth);
        console.log("Mock WETH deployed at:", address(weth));

        // Mock DAI
        MockERC20 dai = new MockERC20("Mock DAI", "DAI", 18, 1000000000 * 1e18); // 1B DAI
        tokens[2] = address(dai);
        console.log("Mock DAI deployed at:", address(dai));

        return tokens;
    }

    /**
     * @notice Deploy mock price feeds for testing
     * @param config Deployment configuration
     * @return priceFeeds Array of deployed price feed addresses
     */
    function _deployMockPriceFeeds(DeploymentConfig memory config) internal returns (address[] memory priceFeeds) {
        if (!config.deployMocks) return priceFeeds;

        console.log("Deploying mock price feeds...");

        priceFeeds = new address[](4);

        // ETH/USD Price Feed
        MockPriceFeed ethUsd = new MockPriceFeed(8, "ETH/USD", 2000 * 1e8); // $2000
        priceFeeds[0] = address(ethUsd);
        console.log("ETH/USD Price Feed deployed at:", address(ethUsd));

        // USDC/USD Price Feed
        MockPriceFeed usdcUsd = new MockPriceFeed(8, "USDC/USD", 1 * 1e8); // $1
        priceFeeds[1] = address(usdcUsd);
        console.log("USDC/USD Price Feed deployed at:", address(usdcUsd));

        // MATIC/USD Price Feed
        MockPriceFeed maticUsd = new MockPriceFeed(8, "MATIC/USD", 1 * 1e8); // $1
        priceFeeds[2] = address(maticUsd);
        console.log("MATIC/USD Price Feed deployed at:", address(maticUsd));

        // DAI/USD Price Feed
        MockPriceFeed daiUsd = new MockPriceFeed(8, "DAI/USD", 1 * 1e8); // $1
        priceFeeds[3] = address(daiUsd);
        console.log("DAI/USD Price Feed deployed at:", address(daiUsd));

        return priceFeeds;
    }

    /**
     * @notice Configure the deployed system
     * @param deployed Deployed contracts
     * @param config Deployment configuration
     */
    function _configureSystem(DeployedContracts memory deployed, DeploymentConfig memory config) internal {
        console.log("Configuring system...");

        // Register adapters with RouteCalculator
        for (uint256 i = 0; i < deployed.bridgeAdapters.length; i++) {
            deployed.routeCalculator.registerAdapter(deployed.bridgeAdapters[i]);
            console.log("Registered adapter with RouteCalculator:", deployed.bridgeAdapters[i]);
        }

        // Register adapters with BridgeRegistry
        uint256[] memory supportedChains = _getSupportedChains(config.chainId);
        address[] memory supportedTokens = config.deployMocks ? deployed.mockTokens : config.existingTokens;

        for (uint256 i = 0; i < deployed.bridgeAdapters.length; i++) {
            deployed.bridgeRegistry.registerBridge(
                deployed.bridgeAdapters[i],
                supportedChains,
                supportedTokens
            );
            console.log("Registered adapter with BridgeRegistry:", deployed.bridgeAdapters[i]);
        }

        // Grant required roles to SettlementSwitch before it performs privileged operations
        // SettlementSwitch needs permission to update fees and interact with BridgeRegistry in certain flows
        // Ensure the deployer (admin) is the caller here so grantRole succeeds
        // Optionally skip role grants to save gas in minimal deployments
        bool skipRoleGrants = vm.envOr("SKIP_ROLE_GRANTS", false);
        if (!skipRoleGrants) {
            // Grant FEE_MANAGER_ROLE to SettlementSwitch on FeeManager
            bytes32 feeManagerRole = deployed.feeManager.FEE_MANAGER_ROLE();
            deployed.feeManager.grantRole(feeManagerRole, address(deployed.settlementSwitch));
            console.log("Granted FEE_MANAGER_ROLE to SettlementSwitch:", address(deployed.settlementSwitch));

            // Grant BRIDGE_MANAGER_ROLE to SettlementSwitch on BridgeRegistry
            bytes32 bridgeManagerRole = deployed.bridgeRegistry.BRIDGE_MANAGER_ROLE();
            deployed.bridgeRegistry.grantRole(bridgeManagerRole, address(deployed.settlementSwitch));
            console.log("Granted BRIDGE_MANAGER_ROLE to SettlementSwitch:", address(deployed.settlementSwitch));
        } else {
            console.log("Skipping role grants due to SKIP_ROLE_GRANTS=true");
        }

        // Register adapters with SettlementSwitch
        bool skipSsRegistration = vm.envOr("SKIP_SS_REGISTRATION", false);
        if (!skipSsRegistration) {
            for (uint256 i = 0; i < deployed.bridgeAdapters.length; i++) {
                (BridgeRegistry.BridgeInfo memory info,) = deployed.bridgeRegistry.getBridgeDetails(deployed.bridgeAdapters[i]);
                if (info.adapter == address(0)) {
                    deployed.settlementSwitch.registerBridgeAdapter(deployed.bridgeAdapters[i], true);
                    console.log("Registered adapter with SettlementSwitch:", deployed.bridgeAdapters[i]);
                } else {
                    console.log("Adapter already registered in BridgeRegistry; skipping SettlementSwitch registration:", deployed.bridgeAdapters[i]);
                }
            }
        } else {
            console.log("Skipping SettlementSwitch adapter registration due to SKIP_SS_REGISTRATION=true");
        }

        // Configure fee structures (optional)
        bool skipFeeConfig = vm.envOr("SKIP_FEE_CONFIG", false);
        if (!skipFeeConfig) {
            _configureFees(deployed.feeManager, config);
        } else {
            console.log("Skipping fee configuration due to SKIP_FEE_CONFIG=true");
        }

        // Update chain configurations (optional)
        bool skipChainConfig = vm.envOr("SKIP_CHAIN_CONFIG", false);
        if (!skipChainConfig) {
            _configureChains(deployed.settlementSwitch, config);
        } else {
            console.log("Skipping chain configuration due to SKIP_CHAIN_CONFIG=true");
        }

        console.log("System configuration completed");
    }

    /**
     * @notice Get supported chains for current network
     * @param currentChainId Current chain ID
     * @return chains Array of supported chain IDs
     */
    function _getSupportedChains(uint256 currentChainId) internal pure returns (uint256[] memory chains) {
        if (currentChainId == ETHEREUM_SEPOLIA) {
            chains = new uint256[](3);
            chains[0] = ETHEREUM_SEPOLIA;
            chains[1] = ARBITRUM_SEPOLIA;
            chains[2] = POLYGON_MUMBAI;
        } else if (currentChainId == ARBITRUM_SEPOLIA) {
            chains = new uint256[](3);
            chains[0] = ETHEREUM_SEPOLIA;
            chains[1] = ARBITRUM_SEPOLIA;
            chains[2] = POLYGON_MUMBAI;
        } else if (currentChainId == POLYGON_MUMBAI) {
            chains = new uint256[](3);
            chains[0] = ETHEREUM_SEPOLIA;
            chains[1] = ARBITRUM_SEPOLIA;
            chains[2] = POLYGON_MUMBAI;
        } else {
            // Mainnet configuration (commented for safety)
            chains = new uint256[](1);
            chains[0] = currentChainId;
        }
        return chains;
    }

    /**
     * @notice Configure fee structures
     * @param feeManager Fee manager contract
     * @param config Deployment configuration
     */
    function _configureFees(FeeManager feeManager, DeploymentConfig memory config) internal {
        console.log("Configuring fees...");

        // Set protocol fee (0.1% for testnet, 0.05% for mainnet)
        uint256 protocolFeeRate = config.isTestnet ? 10 : 5; // basis points
        
        FeeManager.FeeStructure memory protocolFee = FeeManager.FeeStructure({
            baseFeeRate: protocolFeeRate,
            minFeeAmount: 0.001 ether,
            maxFeeAmount: 1 ether,
            congestionMultiplier: 2000, // 20% increase during congestion
            isActive: true
        });

        feeManager.updateFeeStructure("protocol", protocolFee);

        // Set bridge fee structure
        FeeManager.FeeStructure memory bridgeFee = FeeManager.FeeStructure({
            baseFeeRate: 5, // 0.05%
            minFeeAmount: 0.0005 ether,
            maxFeeAmount: 0.5 ether,
            congestionMultiplier: 1500, // 15% increase during congestion
            isActive: true
        });

        feeManager.updateFeeStructure("bridge", bridgeFee);

        console.log("Fee configuration completed");
    }

    /**
     * @notice Configure chain settings
     * @param settlementSwitch Settlement switch contract
     * @param config Deployment configuration
     */
    function _configureChains(SettlementSwitch settlementSwitch, DeploymentConfig memory config) internal {
        console.log("Configuring chains...");

        if (config.isTestnet) {
            // Configure testnet chains
            settlementSwitch.updateChainConfig(ETHEREUM_SEPOLIA, "Ethereum Sepolia", true, 50 gwei);
            settlementSwitch.updateChainConfig(ARBITRUM_SEPOLIA, "Arbitrum Sepolia", true, 1 gwei);
            settlementSwitch.updateChainConfig(POLYGON_MUMBAI, "Polygon Mumbai", true, 30 gwei);
        } else {
            // Configure mainnet chains (commented for safety)
            /*
            settlementSwitch.updateChainConfig(ETHEREUM_MAINNET, "Ethereum Mainnet", true, 100 gwei);
            settlementSwitch.updateChainConfig(ARBITRUM_ONE, "Arbitrum One", true, 1 gwei);
            settlementSwitch.updateChainConfig(POLYGON_MAINNET, "Polygon Mainnet", true, 50 gwei);
            */
        }

        console.log("Chain configuration completed");
    }

    /**
     * @notice Verify deployment
     * @param deployed Deployed contracts
     * @param config Deployment configuration
     */
    function _verifyDeployment(DeployedContracts memory deployed, DeploymentConfig memory config) internal view {
        console.log("Verifying deployment...");

        // Verify core contracts
        require(address(deployed.settlementSwitch) != address(0), "SettlementSwitch not deployed");
        require(address(deployed.routeCalculator) != address(0), "RouteCalculator not deployed");
        require(address(deployed.bridgeRegistry) != address(0), "BridgeRegistry not deployed");
        require(address(deployed.feeManager) != address(0), "FeeManager not deployed");

        // Verify bridge adapters
        bool layerZeroOnly = vm.envOr("DEPLOY_LAYERZERO_ONLY", false);
        if (layerZeroOnly) {
            require(deployed.bridgeAdapters.length == 1, "Expected 1 adapter in LayerZero-only mode");
        } else {
            require(deployed.bridgeAdapters.length >= 1, "No bridge adapters deployed");
        }
        for (uint256 i = 0; i < deployed.bridgeAdapters.length; i++) {
            require(deployed.bridgeAdapters[i] != address(0), "Bridge adapter not deployed");
        }

        // Verify mock contracts if deployed
        if (config.deployMocks) {
            require(deployed.mockTokens.length > 0, "Mock tokens not deployed");
            require(deployed.priceFeeds.length > 0, "Price feeds not deployed");
        }

        // Verify system configuration
        require(!deployed.settlementSwitch.isPaused(), "System should not be paused");
        
        bool skipSsRegistration = vm.envOr("SKIP_SS_REGISTRATION", false);
        (address[] memory adapters,,) = deployed.settlementSwitch.getRegisteredAdapters();
        if (!skipSsRegistration) {
            require(adapters.length == deployed.bridgeAdapters.length, "Adapters not registered");
        } else {
            // In skip mode, just ensure the call does not revert and adapters length is <= deployed count
            require(adapters.length <= deployed.bridgeAdapters.length, "Unexpected adapters count in skip mode");
        }

        console.log("Deployment verification completed successfully");
    }

    /**
     * @notice Log deployment summary
     * @param deployed Deployed contracts
     * @param config Deployment configuration
     */
    function _logDeploymentSummary(DeployedContracts memory deployed, DeploymentConfig memory config) internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:", config.networkName);
        console.log("Chain ID:", config.chainId);
        console.log("Admin:", config.admin);
        console.log("Treasury:", config.treasury);
        
        console.log("\n--- Core Contracts ---");
        if (address(deployed.settlementSwitch) != address(0)) {
            console.log("SettlementSwitch:", address(deployed.settlementSwitch));
            console.log("RouteCalculator:", address(deployed.routeCalculator));
            console.log("BridgeRegistry:", address(deployed.bridgeRegistry));
            console.log("FeeManager:", address(deployed.feeManager));
        } else {
            console.log("(skipped core deployment)");
        }
        
        console.log("\n--- Bridge Adapters ---");
        if (deployed.bridgeAdapters.length > 0) {
            for (uint256 i = 0; i < deployed.bridgeAdapters.length; i++) {
                console.log("Adapter:", deployed.bridgeAdapters[i]);
            }
        } else {
            console.log("(no adapters deployed)");
        }

        if (config.deployMocks) {
            console.log("\n--- Mock Tokens ---");
            string[3] memory tokenNames = ["USDC", "WETH", "DAI"];
            for (uint256 i = 0; i < deployed.mockTokens.length; i++) {
                console.log(string.concat("Mock ", tokenNames[i], ":"), deployed.mockTokens[i]);
            }

            console.log("\n--- Price Feeds ---");
            string[4] memory feedNames = ["ETH/USD", "USDC/USD", "MATIC/USD", "DAI/USD"];
            for (uint256 i = 0; i < deployed.priceFeeds.length; i++) {
                console.log(string.concat(feedNames[i], ":"), deployed.priceFeeds[i]);
            }
        }

        console.log("\n=== DEPLOYMENT COMPLETED SUCCESSFULLY ===");
    }

    /**
     * @notice Deploy to specific network (helper function)
     * @param chainId Target chain ID
     */
    function deployToNetwork(uint256 chainId) external {
        DeploymentConfig memory config = networkConfigs[chainId];
        require(config.chainId != 0, "Network not configured");

        vm.createSelectFork(vm.rpcUrl(config.networkName));
        this.run();
    }

    /**
     * @notice Get deployment configuration for a network
     * @param chainId Chain ID
     * @return config Deployment configuration
     */
    function getNetworkConfig(uint256 chainId) external view returns (DeploymentConfig memory config) {
        return networkConfigs[chainId];
    }
}
