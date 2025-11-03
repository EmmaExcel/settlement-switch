// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/core/SettlementSwitch.sol";
import "../src/core/RouteCalculator.sol";
import "../src/core/BridgeRegistry.sol";
import "../src/core/FeeManager.sol";
import "../src/mocks/MockBridgeAdapter.sol";
import "../src/mocks/MockERC20.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract SimpleSettlementTest is Test {
    SettlementSwitch public settlementSwitch;
    RouteCalculator public routeCalculator;
    BridgeRegistry public bridgeRegistry;
    FeeManager public feeManager;
    MockBridgeAdapter public mockBridge;
    MockERC20 public mockUSDC;

    address public admin = address(0x1);
    address public user = address(0x2);
    address public treasury = address(0x4);

    uint256 public constant SEPOLIA = 11155111;
    uint256 public constant MUMBAI = 80001;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy tokens
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6, 1000000 * 1e6);

        // Deploy core contracts
        routeCalculator = new RouteCalculator();
        bridgeRegistry = new BridgeRegistry(admin);
        feeManager = new FeeManager(admin, treasury);

        settlementSwitch = new SettlementSwitch(
            admin,
            address(routeCalculator),
            address(bridgeRegistry),
            payable(address(feeManager))
        );

        // Deploy ONE simple bridge
        mockBridge = new MockBridgeAdapter("Test Bridge", 0.001 ether, 5, 300);

        // Register with RouteCalculator
        routeCalculator.registerAdapter(address(mockBridge));

        // Register with BridgeRegistry (simplified - only 1 chain, 1 token)
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = SEPOLIA;

        address[] memory tokens = new address[](1);
        tokens[0] = address(mockUSDC);

        bridgeRegistry.registerBridge(address(mockBridge), chainIds, tokens);

        // Register with SettlementSwitch
        settlementSwitch.registerBridgeAdapter(address(mockBridge), true);

        // Setup user balance
        mockUSDC.mint(user, 10000 * 1e6); // 10k USDC

        vm.stopPrank();
        vm.deal(user, 10 ether);
    }

    function test_BasicRouteCalculation() public {
        vm.startPrank(user);

        // Simple route calculation test
        uint256 amount = 1000 * 1e6; // 1000 USDC
        
        // This should work without gas issues
        address[] memory adapters = routeCalculator.getRegisteredAdapters();
        assertEq(adapters.length, 1);
        assertEq(adapters[0], address(mockBridge));

        vm.stopPrank();
    }

    function test_Route1000USDCSepoliaToMumbai_Cheapest() public {
        vm.startPrank(user);

        uint256 amount = 1000 * 1e6; // 1000 USDC

        // Add supported route to mock bridge
        mockBridge.addSupportedRoute(SEPOLIA, address(mockUSDC), 100000 * 1e6);
        mockBridge.addSupportedRoute(MUMBAI, address(mockUSDC), 100000 * 1e6);

        // Create route preferences
        IBridgeAdapter.RoutePreferences memory preferences = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,    // 1%
            maxFeeWei: 1 ether,     // Max 1 ETH fee
            maxTimeMinutes: 60,     // 1 hour
            allowMultiHop: false    // Single hop only
        });

        // Try to find optimal route
        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC), // tokenIn
            address(mockUSDC), // tokenOut
            amount,
            SEPOLIA,           // srcChainId
            MUMBAI,            // dstChainId
            preferences
        );

        // Should find our mock bridge
        assertEq(route.adapter, address(mockBridge));
        assertGt(route.metrics.totalCostWei, 0);
        assertGt(route.metrics.estimatedTimeMinutes, 0);

        vm.stopPrank();
    }
}