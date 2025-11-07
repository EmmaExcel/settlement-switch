// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/SettlementSwitch.sol";
import "../src/core/BridgeRegistry.sol";
import "../src/core/RouteCalculator.sol";
import "../src/adapters/LayerZeroAdapter.sol";

/// @notice One-time setup script to configure Sepolia testnets for LayerZero/Stargate
/// Enables bridging ETH between Ethereum Sepolia and Arbitrum Sepolia using the deployed
/// SettlementSwitch and LayerZeroAdapter. Assumes contracts are deployed on the source chain
/// you will initiate transfers from (commonly Ethereum Sepolia).
contract SepoliaSetupScript is Script {
    // Testnet Chain IDs
    uint256 constant ETHEREUM_SEPOLIA = 11155111;
    uint256 constant ARBITRUM_SEPOLIA = 421614;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // Deployed contract addresses
        address settlementSwitchAddr = vm.envAddress("SETTLEMENT_SWITCH_ADDR");
        address bridgeRegistryAddr = vm.envAddress("BRIDGE_REGISTRY_ADDR");
        address routeCalculatorAddr = vm.envAddress("ROUTE_CALCULATOR_ADDR");
        address layerZeroAdapterAddr = vm.envAddress("LAYERZERO_ADAPTER_ADDR");

        // LayerZero/Stargate TESTNET configuration (provide official testnet addresses)
        address stargateRouterAddr = vm.envAddress("STARGATE_ROUTER_ADDR");
        address stargateRouterEthAddr = vm.envAddress("STARGATE_ROUTER_ETH_ADDR");
        address lzEndpointAddr = vm.envAddress("LZ_ENDPOINT_ADDR");

        // ETH pool IDs on Stargate for testnet (Sepolia/Arbitrum Sepolia)
        uint256 poolIdEthSepolia = vm.envUint("STARGATE_POOL_ID_ETH_SEPOLIA");
        uint256 poolIdEthArbSepolia = vm.envUint("STARGATE_POOL_ID_ETH_ARB_SEPOLIA");

        vm.startBroadcast(pk);

        console.log("Running Sepolia setup...");
        console.log("SettlementSwitch:", settlementSwitchAddr);
        console.log("BridgeRegistry:", bridgeRegistryAddr);
        console.log("RouteCalculator:", routeCalculatorAddr);
        console.log("LayerZeroAdapter:", layerZeroAdapterAddr);

        SettlementSwitch sswitch = SettlementSwitch(payable(settlementSwitchAddr));
        BridgeRegistry registry = BridgeRegistry(bridgeRegistryAddr);
        RouteCalculator calculator = RouteCalculator(routeCalculatorAddr);
        LayerZeroAdapter lz = LayerZeroAdapter(payable(layerZeroAdapterAddr));

        // 1) Ensure destination chains are marked supported (if not already)
        console.log("Updating SettlementSwitch chain configs for Sepolia testnets...");
        sswitch.updateChainConfig(ETHEREUM_SEPOLIA, "Ethereum Sepolia", true, 50 gwei);
        sswitch.updateChainConfig(ARBITRUM_SEPOLIA, "Arbitrum Sepolia", true, 2 gwei);

        // 2) Register LayerZero adapter with RouteCalculator for route discovery
        console.log("Registering LayerZero with RouteCalculator...");
        calculator.registerAdapter(layerZeroAdapterAddr);

        // 3) Register LayerZero adapter with BridgeRegistry for Sepolia <-> Arbitrum Sepolia
        console.log("Registering LayerZero with BridgeRegistry for Sepolia<->Arbitrum Sepolia...");
        uint256[] memory supportedChains = new uint256[](2);
        supportedChains[0] = ETHEREUM_SEPOLIA;
        supportedChains[1] = ARBITRUM_SEPOLIA;

        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(0); // Native ETH

        registry.registerBridge(layerZeroAdapterAddr, supportedChains, supportedTokens);

        // 4) Ensure LayerZero adapter supports ETH on both chains (liquidity is already initialized)
        // Calling addSupportedToken is idempotent for our adapter; safe to reassert.
        console.log("Asserting ETH support and liquidity on LayerZero adapter...");
        lz.addSupportedToken(address(0), ETHEREUM_SEPOLIA, lz.tokenLiquidity(address(0), ETHEREUM_SEPOLIA));
        lz.addSupportedToken(address(0), ARBITRUM_SEPOLIA, lz.tokenLiquidity(address(0), ARBITRUM_SEPOLIA));

        // 5) Configure LZ endpoint, Stargate routers and ETH pool IDs (testnet)
        console.log("Configuring LayerZero/Stargate testnet endpoints and pool IDs...");
        lz.setLayerZeroEndpoint(lzEndpointAddr);
        lz.setStargateRouter(stargateRouterAddr);
        lz.setStargateRouterETH(stargateRouterEthAddr);
        lz.setPoolId(address(0), ETHEREUM_SEPOLIA, poolIdEthSepolia);
        lz.setPoolId(address(0), ARBITRUM_SEPOLIA, poolIdEthArbSepolia);

        console.log("Sepolia setup completed: ETH bridging enabled via LayerZero (Sepolia <-> Arbitrum Sepolia).");
        vm.stopBroadcast();
    }
}

