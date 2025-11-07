// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/SettlementSwitch.sol";
import "../src/core/BridgeRegistry.sol";
import "../src/core/RouteCalculator.sol";
import "../src/adapters/LayerZeroAdapter.sol";

/// @notice One-time setup script to make an Arbitrum One deployment usable for
/// bridging from Arbitrum One to other chains (e.g., Ethereum mainnet) without
/// deploying contracts on destination chains.
///
/// It performs:
/// - Marks Ethereum Mainnet as supported on `SettlementSwitch` with sane gas caps
/// - Registers the LayerZero adapter with `RouteCalculator` and `BridgeRegistry`
/// - Adds ETH support and initial liquidity for Arbitrum One and Ethereum on LayerZero adapter
contract ArbitrumOneSetupScript is Script {
    // Chain IDs
    uint256 constant ETHEREUM_MAINNET = 1;
    uint256 constant ARBITRUM_ONE = 42161;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // Required addresses passed via environment variables
        address settlementSwitchAddr = vm.envAddress("SETTLEMENT_SWITCH_ADDR");
        address bridgeRegistryAddr = vm.envAddress("BRIDGE_REGISTRY_ADDR");
        address routeCalculatorAddr = vm.envAddress("ROUTE_CALCULATOR_ADDR");
        address layerZeroAdapterAddr = vm.envAddress("LAYERZERO_ADAPTER_ADDR");

        // Production LayerZero/Stargate configuration
        address stargateRouterAddr = vm.envAddress("STARGATE_ROUTER_ADDR");
        address stargateRouterEthAddr = vm.envAddress("STARGATE_ROUTER_ETH_ADDR");
        address lzEndpointAddr = vm.envAddress("LZ_ENDPOINT_ADDR");
        uint256 poolIdEthArbitrum = vm.envUint("STARGATE_POOL_ID_ETH_ARBITRUM");
        uint256 poolIdEthEthereum = vm.envUint("STARGATE_POOL_ID_ETH_ETHEREUM");

        vm.startBroadcast(pk);

        console.log("Running Arbitrum One setup...");
        console.log("SettlementSwitch:", settlementSwitchAddr);
        console.log("BridgeRegistry:", bridgeRegistryAddr);
        console.log("RouteCalculator:", routeCalculatorAddr);
        console.log("LayerZeroAdapter:", layerZeroAdapterAddr);

        SettlementSwitch sswitch = SettlementSwitch(payable(settlementSwitchAddr));
        BridgeRegistry registry = BridgeRegistry(bridgeRegistryAddr);
        RouteCalculator calculator = RouteCalculator(routeCalculatorAddr);
        LayerZeroAdapter lz = LayerZeroAdapter(payable(layerZeroAdapterAddr));

        // 1) Enable destination chain(s) on SettlementSwitch
        // Set reasonable max gas price caps for routing decisions
        console.log("Updating SettlementSwitch chain configs...");
        sswitch.updateChainConfig(ARBITRUM_ONE, "Arbitrum One", true, 2 gwei);
        sswitch.updateChainConfig(ETHEREUM_MAINNET, "Ethereum Mainnet", true, 100 gwei);

        // 2) Register LayerZero adapter with RouteCalculator (for route discovery)
        console.log("Registering LayerZero with RouteCalculator...");
        calculator.registerAdapter(layerZeroAdapterAddr);

        // 3) Register LayerZero adapter with BridgeRegistry for Arbitrum<->Ethereum
        console.log("Registering LayerZero with BridgeRegistry for ARB<->ETH...");
        uint256[] memory supportedChains = new uint256[](2);
        supportedChains[0] = ARBITRUM_ONE;
        supportedChains[1] = ETHEREUM_MAINNET;

        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(0); // Native ETH

        registry.registerBridge(layerZeroAdapterAddr, supportedChains, supportedTokens);

        // 4) Ensure LayerZero adapter supports ETH on both chains with initial liquidity
        console.log("Adding ETH support and initial liquidity on LayerZero adapter...");
        lz.addSupportedToken(address(0), ARBITRUM_ONE, 500 ether);
        lz.addSupportedToken(address(0), ETHEREUM_MAINNET, 500 ether);

        // 5) Configure real LayerZero/Stargate endpoints and pool IDs
        console.log("Configuring LayerZero/Stargate endpoints and pool IDs...");
        lz.setLayerZeroEndpoint(lzEndpointAddr);
        lz.setStargateRouter(stargateRouterAddr);
        lz.setStargateRouterETH(stargateRouterEthAddr);
        lz.setPoolId(address(0), ARBITRUM_ONE, poolIdEthArbitrum);
        lz.setPoolId(address(0), ETHEREUM_MAINNET, poolIdEthEthereum);

        console.log("Arbitrum One setup completed: ARB -> ETH bridging enabled via LayerZero.");
        vm.stopBroadcast();
    }
}
