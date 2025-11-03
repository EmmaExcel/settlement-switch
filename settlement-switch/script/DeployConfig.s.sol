// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title DeployConfig
 * @notice Configuration management for multi-chain deployments
 * @dev Centralizes network-specific addresses and settings
 */
contract DeployConfig is Script {
    /// @notice Network configuration structure
    struct NetworkConfig {
        string name;
        uint256 chainId;
        string rpcUrl;
        address deployer;
        address admin;
        address treasury;
        address emergencyAdmin;
        TokenConfig[] tokens;
        PriceFeedConfig[] priceFeeds;
        BridgeConfig[] bridges;
        GasConfig gasConfig;
        bool isTestnet;
    }

    /// @notice Token configuration
    struct TokenConfig {
        string name;
        string symbol;
        address tokenAddress;
        uint8 decimals;
        bool isNative;
        uint256 initialLiquidity;
    }

    /// @notice Price feed configuration
    struct PriceFeedConfig {
        string pair;
        address feedAddress;
        uint8 decimals;
        uint256 heartbeat;
        bool isActive;
    }

    /// @notice Bridge configuration
    struct BridgeConfig {
        string name;
        address adapterAddress;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 dailyLimit;
        bool isEnabled;
        uint256[] supportedChains;
    }

    /// @notice Gas configuration
    struct GasConfig {
        uint256 maxGasPrice;
        uint256 maxPriorityFee;
        uint256 gasLimit;
        uint256 confirmations;
    }

    // Network configurations
    mapping(uint256 => NetworkConfig) public networkConfigs;
    mapping(string => uint256) public networkNameToChainId;

    // Constants
    uint256 public constant ETHEREUM_MAINNET = 1;
    uint256 public constant ETHEREUM_SEPOLIA = 11155111;
    uint256 public constant ARBITRUM_ONE = 42161;
    uint256 public constant ARBITRUM_SEPOLIA = 421614;
    uint256 public constant POLYGON_MAINNET = 137;
    uint256 public constant POLYGON_MUMBAI = 80001;

    constructor() {
        _initializeConfigs();
    }

    /**
     * @notice Initialize all network configurations
     */
    function _initializeConfigs() internal {
        _initializeSepoliaConfig();
        _initializeArbitrumSepoliaConfig();
        _initializeMumbaiConfig();
        _initializeMainnetConfigs();
    }

    /**
     * @notice Initialize Ethereum Sepolia configuration
     */
    function _initializeSepoliaConfig() internal {
        TokenConfig[] memory tokens = new TokenConfig[](4);
        tokens[0] = TokenConfig({
            name: "Ethereum",
            symbol: "ETH",
            tokenAddress: address(0),
            decimals: 18,
            isNative: true,
            initialLiquidity: 1000 ether
        });
        tokens[1] = TokenConfig({
            name: "USD Coin",
            symbol: "USDC",
            tokenAddress: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8, // Sepolia USDC (example)
            decimals: 6,
            isNative: false,
            initialLiquidity: 1000000 * 1e6
        });
        tokens[2] = TokenConfig({
            name: "Wrapped Ether",
            symbol: "WETH",
            tokenAddress: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14, // Sepolia WETH (example)
            decimals: 18,
            isNative: false,
            initialLiquidity: 1000 ether
        });
        tokens[3] = TokenConfig({
            name: "Dai Stablecoin",
            symbol: "DAI",
            tokenAddress: 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6, // Sepolia DAI (example)
            decimals: 18,
            isNative: false,
            initialLiquidity: 1000000 ether
        });

        PriceFeedConfig[] memory priceFeeds = new PriceFeedConfig[](4);
        priceFeeds[0] = PriceFeedConfig({
            pair: "ETH/USD",
            feedAddress: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // Sepolia ETH/USD
            decimals: 8,
            heartbeat: 3600,
            isActive: true
        });
        priceFeeds[1] = PriceFeedConfig({
            pair: "USDC/USD",
            feedAddress: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E, // Sepolia USDC/USD (example)
            decimals: 8,
            heartbeat: 86400,
            isActive: true
        });
        priceFeeds[2] = PriceFeedConfig({
            pair: "DAI/USD",
            feedAddress: 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19, // Sepolia DAI/USD (example)
            decimals: 8,
            heartbeat: 3600,
            isActive: true
        });
        priceFeeds[3] = PriceFeedConfig({
            pair: "GAS/GWEI",
            feedAddress: 0x48731cF7e84dc94C5f84577882c14Be11a5B7456, // Sepolia Gas Price (example)
            decimals: 0,
            heartbeat: 300,
            isActive: true
        });

        BridgeConfig[] memory bridges = new BridgeConfig[](6);
        uint256[] memory supportedChains = new uint256[](3);
        supportedChains[0] = ETHEREUM_SEPOLIA;
        supportedChains[1] = ARBITRUM_SEPOLIA;
        supportedChains[2] = POLYGON_MUMBAI;

        bridges[0] = BridgeConfig({
            name: "LayerZero",
            adapterAddress: address(0), // Will be set during deployment
            minAmount: 1 * 1e6, // 1 USDC
            maxAmount: 100000 * 1e6, // 100k USDC
            dailyLimit: 1000000 * 1e6, // 1M USDC
            isEnabled: true,
            supportedChains: supportedChains
        });

        bridges[1] = BridgeConfig({
            name: "Hop Protocol",
            adapterAddress: address(0),
            minAmount: 1 * 1e6,
            maxAmount: 50000 * 1e6,
            dailyLimit: 500000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        bridges[2] = BridgeConfig({
            name: "Polygon Bridge",
            adapterAddress: address(0),
            minAmount: 10 * 1e6,
            maxAmount: 1000000 * 1e6,
            dailyLimit: 10000000 * 1e6,
            isEnabled: true,
            supportedChains: _getPolygonSupportedChains()
        });

        bridges[3] = BridgeConfig({
            name: "Arbitrum Bridge",
            adapterAddress: address(0),
            minAmount: 1 * 1e6,
            maxAmount: 5000000 * 1e6,
            dailyLimit: 50000000 * 1e6,
            isEnabled: true,
            supportedChains: _getArbitrumSupportedChains()
        });

        bridges[4] = BridgeConfig({
            name: "Across",
            adapterAddress: address(0),
            minAmount: 10 * 1e6,
            maxAmount: 10000000 * 1e6,
            dailyLimit: 100000000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        bridges[5] = BridgeConfig({
            name: "Connext",
            adapterAddress: address(0),
            minAmount: 1 * 1e6,
            maxAmount: 1000000 * 1e6,
            dailyLimit: 10000000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        networkConfigs[ETHEREUM_SEPOLIA] = NetworkConfig({
            name: "Ethereum Sepolia",
            chainId: ETHEREUM_SEPOLIA,
            rpcUrl: "https://sepolia.infura.io/v3/YOUR_INFURA_KEY",
            deployer: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6, // Replace with actual deployer
            admin: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6, // Replace with actual admin
            treasury: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6, // Replace with actual treasury
            emergencyAdmin: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6, // Replace with actual emergency admin
            tokens: tokens,
            priceFeeds: priceFeeds,
            bridges: bridges,
            gasConfig: GasConfig({
                maxGasPrice: 50 gwei,
                maxPriorityFee: 2 gwei,
                gasLimit: 500000,
                confirmations: 1
            }),
            isTestnet: true
        });

        networkNameToChainId["sepolia"] = ETHEREUM_SEPOLIA;
        networkNameToChainId["ethereum-sepolia"] = ETHEREUM_SEPOLIA;
    }

    /**
     * @notice Initialize Arbitrum Sepolia configuration
     */
    function _initializeArbitrumSepoliaConfig() internal {
        TokenConfig[] memory tokens = new TokenConfig[](3);
        tokens[0] = TokenConfig({
            name: "Ethereum",
            symbol: "ETH",
            tokenAddress: address(0),
            decimals: 18,
            isNative: true,
            initialLiquidity: 1000 ether
        });
        tokens[1] = TokenConfig({
            name: "USD Coin",
            symbol: "USDC",
            tokenAddress: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d, // Arbitrum Sepolia USDC (example)
            decimals: 6,
            isNative: false,
            initialLiquidity: 1000000 * 1e6
        });
        tokens[2] = TokenConfig({
            name: "Wrapped Ether",
            symbol: "WETH",
            tokenAddress: 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73, // Arbitrum Sepolia WETH (example)
            decimals: 18,
            isNative: false,
            initialLiquidity: 1000 ether
        });

        PriceFeedConfig[] memory priceFeeds = new PriceFeedConfig[](2);
        priceFeeds[0] = PriceFeedConfig({
            pair: "ETH/USD",
            feedAddress: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165, // Arbitrum Sepolia ETH/USD (example)
            decimals: 8,
            heartbeat: 3600,
            isActive: true
        });
        priceFeeds[1] = PriceFeedConfig({
            pair: "USDC/USD",
            feedAddress: 0x0153002d20B96532C639313c2d54c3dA09109309, // Arbitrum Sepolia USDC/USD (example)
            decimals: 8,
            heartbeat: 86400,
            isActive: true
        });

        uint256[] memory supportedChains = new uint256[](3);
        supportedChains[0] = ETHEREUM_SEPOLIA;
        supportedChains[1] = ARBITRUM_SEPOLIA;
        supportedChains[2] = POLYGON_MUMBAI;

        BridgeConfig[] memory bridges = new BridgeConfig[](4);
        bridges[0] = BridgeConfig({
            name: "LayerZero",
            adapterAddress: address(0),
            minAmount: 1 * 1e6,
            maxAmount: 100000 * 1e6,
            dailyLimit: 1000000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        bridges[1] = BridgeConfig({
            name: "Hop Protocol",
            adapterAddress: address(0),
            minAmount: 1 * 1e6,
            maxAmount: 50000 * 1e6,
            dailyLimit: 500000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        bridges[2] = BridgeConfig({
            name: "Across",
            adapterAddress: address(0),
            minAmount: 10 * 1e6,
            maxAmount: 10000000 * 1e6,
            dailyLimit: 100000000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        bridges[3] = BridgeConfig({
            name: "Connext",
            adapterAddress: address(0),
            minAmount: 1 * 1e6,
            maxAmount: 1000000 * 1e6,
            dailyLimit: 10000000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        networkConfigs[ARBITRUM_SEPOLIA] = NetworkConfig({
            name: "Arbitrum Sepolia",
            chainId: ARBITRUM_SEPOLIA,
            rpcUrl: "https://arbitrum-sepolia.infura.io/v3/YOUR_INFURA_KEY",
            deployer: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            admin: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            treasury: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            emergencyAdmin: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            tokens: tokens,
            priceFeeds: priceFeeds,
            bridges: bridges,
            gasConfig: GasConfig({
                maxGasPrice: 1 gwei,
                maxPriorityFee: 0.01 gwei,
                gasLimit: 2000000,
                confirmations: 1
            }),
            isTestnet: true
        });

        networkNameToChainId["arbitrum-sepolia"] = ARBITRUM_SEPOLIA;
    }

    /**
     * @notice Initialize Polygon Mumbai configuration
     */
    function _initializeMumbaiConfig() internal {
        TokenConfig[] memory tokens = new TokenConfig[](4);
        tokens[0] = TokenConfig({
            name: "Matic",
            symbol: "MATIC",
            tokenAddress: address(0),
            decimals: 18,
            isNative: true,
            initialLiquidity: 100000 ether
        });
        tokens[1] = TokenConfig({
            name: "USD Coin",
            symbol: "USDC",
            tokenAddress: 0x0FA8781a83E46826621b3BC094Ea2A0212e71B23, // Mumbai USDC (example)
            decimals: 6,
            isNative: false,
            initialLiquidity: 1000000 * 1e6
        });
        tokens[2] = TokenConfig({
            name: "Wrapped Ether",
            symbol: "WETH",
            tokenAddress: 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa, // Mumbai WETH (example)
            decimals: 18,
            isNative: false,
            initialLiquidity: 1000 ether
        });
        tokens[3] = TokenConfig({
            name: "Wrapped Matic",
            symbol: "WMATIC",
            tokenAddress: 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889, // Mumbai WMATIC (example)
            decimals: 18,
            isNative: false,
            initialLiquidity: 100000 ether
        });

        PriceFeedConfig[] memory priceFeeds = new PriceFeedConfig[](3);
        priceFeeds[0] = PriceFeedConfig({
            pair: "MATIC/USD",
            feedAddress: 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada, // Mumbai MATIC/USD
            decimals: 8,
            heartbeat: 3600,
            isActive: true
        });
        priceFeeds[1] = PriceFeedConfig({
            pair: "ETH/USD",
            feedAddress: 0x0715A7794a1dc8e42615F059dD6e406A6594651A, // Mumbai ETH/USD (example)
            decimals: 8,
            heartbeat: 3600,
            isActive: true
        });
        priceFeeds[2] = PriceFeedConfig({
            pair: "USDC/USD",
            feedAddress: 0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0, // Mumbai USDC/USD (example)
            decimals: 8,
            heartbeat: 86400,
            isActive: true
        });

        uint256[] memory supportedChains = new uint256[](3);
        supportedChains[0] = ETHEREUM_SEPOLIA;
        supportedChains[1] = ARBITRUM_SEPOLIA;
        supportedChains[2] = POLYGON_MUMBAI;

        BridgeConfig[] memory bridges = new BridgeConfig[](4);
        bridges[0] = BridgeConfig({
            name: "LayerZero",
            adapterAddress: address(0),
            minAmount: 1 * 1e6,
            maxAmount: 100000 * 1e6,
            dailyLimit: 1000000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        bridges[1] = BridgeConfig({
            name: "Hop Protocol",
            adapterAddress: address(0),
            minAmount: 1 * 1e6,
            maxAmount: 50000 * 1e6,
            dailyLimit: 500000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        bridges[2] = BridgeConfig({
            name: "Across",
            adapterAddress: address(0),
            minAmount: 10 * 1e6,
            maxAmount: 10000000 * 1e6,
            dailyLimit: 100000000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        bridges[3] = BridgeConfig({
            name: "Connext",
            adapterAddress: address(0),
            minAmount: 1 * 1e6,
            maxAmount: 1000000 * 1e6,
            dailyLimit: 10000000 * 1e6,
            isEnabled: true,
            supportedChains: supportedChains
        });

        networkConfigs[POLYGON_MUMBAI] = NetworkConfig({
            name: "Polygon Mumbai",
            chainId: POLYGON_MUMBAI,
            rpcUrl: "https://polygon-mumbai.infura.io/v3/YOUR_INFURA_KEY",
            deployer: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            admin: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            treasury: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            emergencyAdmin: 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6,
            tokens: tokens,
            priceFeeds: priceFeeds,
            bridges: bridges,
            gasConfig: GasConfig({
                maxGasPrice: 30 gwei,
                maxPriorityFee: 1 gwei,
                gasLimit: 1000000,
                confirmations: 2
            }),
            isTestnet: true
        });

        networkNameToChainId["mumbai"] = POLYGON_MUMBAI;
        networkNameToChainId["polygon-mumbai"] = POLYGON_MUMBAI;
    }

    /**
     * @notice Initialize mainnet configurations (commented for safety)
     */
    function _initializeMainnetConfigs() internal {
        // Mainnet configurations would go here
        // Commented out for safety during development
        
        /*
        // Ethereum Mainnet
        networkConfigs[ETHEREUM_MAINNET] = NetworkConfig({
            name: "Ethereum Mainnet",
            chainId: ETHEREUM_MAINNET,
            rpcUrl: "https://mainnet.infura.io/v3/YOUR_INFURA_KEY",
            deployer: 0x0000000000000000000000000000000000000000, // SET ACTUAL DEPLOYER
            admin: 0x0000000000000000000000000000000000000000, // SET ACTUAL ADMIN
            treasury: 0x0000000000000000000000000000000000000000, // SET ACTUAL TREASURY
            emergencyAdmin: 0x0000000000000000000000000000000000000000, // SET ACTUAL EMERGENCY ADMIN
            tokens: _getMainnetTokens(),
            priceFeeds: _getMainnetPriceFeeds(),
            bridges: _getMainnetBridges(),
            gasConfig: GasConfig({
                maxGasPrice: 100 gwei,
                maxPriorityFee: 5 gwei,
                gasLimit: 500000,
                confirmations: 3
            }),
            isTestnet: false
        });
        */
    }

    /**
     * @notice Get Polygon supported chains
     * @return chains Array of chain IDs
     */
    function _getPolygonSupportedChains() internal pure returns (uint256[] memory chains) {
        chains = new uint256[](2);
        chains[0] = ETHEREUM_SEPOLIA;
        chains[1] = POLYGON_MUMBAI;
        return chains;
    }

    /**
     * @notice Get Arbitrum supported chains
     * @return chains Array of chain IDs
     */
    function _getArbitrumSupportedChains() internal pure returns (uint256[] memory chains) {
        chains = new uint256[](2);
        chains[0] = ETHEREUM_SEPOLIA;
        chains[1] = ARBITRUM_SEPOLIA;
        return chains;
    }

    // ============ Public Functions ============

    /**
     * @notice Get network configuration by chain ID
     * @param chainId Chain ID
     * @return config Network configuration
     */
    function getNetworkConfig(uint256 chainId) external view returns (NetworkConfig memory config) {
        return networkConfigs[chainId];
    }

    /**
     * @notice Get network configuration by name
     * @param networkName Network name
     * @return config Network configuration
     */
    function getNetworkConfigByName(string memory networkName) external view returns (NetworkConfig memory config) {
        uint256 chainId = networkNameToChainId[networkName];
        require(chainId != 0, "Network not found");
        return networkConfigs[chainId];
    }

    /**
     * @notice Get token configuration for a network
     * @param chainId Chain ID
     * @param tokenSymbol Token symbol
     * @return token Token configuration
     */
    function getTokenConfig(uint256 chainId, string memory tokenSymbol) external view returns (TokenConfig memory token) {
        NetworkConfig memory config = networkConfigs[chainId];
        
        for (uint256 i = 0; i < config.tokens.length; i++) {
            if (keccak256(bytes(config.tokens[i].symbol)) == keccak256(bytes(tokenSymbol))) {
                return config.tokens[i];
            }
        }
        
        revert("Token not found");
    }

    /**
     * @notice Get price feed configuration for a network
     * @param chainId Chain ID
     * @param pair Price pair (e.g., "ETH/USD")
     * @return priceFeed Price feed configuration
     */
    function getPriceFeedConfig(uint256 chainId, string memory pair) external view returns (PriceFeedConfig memory priceFeed) {
        NetworkConfig memory config = networkConfigs[chainId];
        
        for (uint256 i = 0; i < config.priceFeeds.length; i++) {
            if (keccak256(bytes(config.priceFeeds[i].pair)) == keccak256(bytes(pair))) {
                return config.priceFeeds[i];
            }
        }
        
        revert("Price feed not found");
    }

    /**
     * @notice Get bridge configuration for a network
     * @param chainId Chain ID
     * @param bridgeName Bridge name
     * @return bridge Bridge configuration
     */
    function getBridgeConfig(uint256 chainId, string memory bridgeName) external view returns (BridgeConfig memory bridge) {
        NetworkConfig memory config = networkConfigs[chainId];
        
        for (uint256 i = 0; i < config.bridges.length; i++) {
            if (keccak256(bytes(config.bridges[i].name)) == keccak256(bytes(bridgeName))) {
                return config.bridges[i];
            }
        }
        
        revert("Bridge not found");
    }

    /**
     * @notice Check if network is supported
     * @param chainId Chain ID
     * @return supported True if network is supported
     */
    function isNetworkSupported(uint256 chainId) external view returns (bool supported) {
        return networkConfigs[chainId].chainId != 0;
    }

    /**
     * @notice Get all supported chain IDs
     * @return chainIds Array of supported chain IDs
     */
    function getSupportedChainIds() external view returns (uint256[] memory chainIds) {
        chainIds = new uint256[](3); // Adjust size as needed
        chainIds[0] = ETHEREUM_SEPOLIA;
        chainIds[1] = ARBITRUM_SEPOLIA;
        chainIds[2] = POLYGON_MUMBAI;
        return chainIds;
    }

    /**
     * @notice Get deployment addresses for a network
     * @param chainId Chain ID
     * @return admin Admin address
     * @return treasury Treasury address  
     * @return emergencyAdmin Emergency admin address
     * @return deployer Deployer address
     */
    function getDeploymentAddresses(uint256 chainId) external view returns (
        address admin,
        address treasury,
        address emergencyAdmin,
        address deployer
    ) {
        NetworkConfig memory config = networkConfigs[chainId];
        return (config.admin, config.treasury, config.emergencyAdmin, config.deployer);
    }

    /**
     * @notice Update network configuration (admin only)
     * @param chainId Chain ID
     * @param config New network configuration
     */
    function updateNetworkConfig(uint256 chainId, NetworkConfig memory config) external {
        // In a real deployment, this would have access control
        networkConfigs[chainId] = config;
    }

    /**
     * @notice Get gas configuration for a network
     * @param chainId Chain ID
     * @return gasConfig Gas configuration
     */
    function getGasConfig(uint256 chainId) external view returns (GasConfig memory gasConfig) {
        return networkConfigs[chainId].gasConfig;
    }
}