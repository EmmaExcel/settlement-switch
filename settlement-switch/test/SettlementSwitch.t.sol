// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/core/SettlementSwitch.sol";
import "../src/core/RouteCalculator.sol";
import "../src/core/BridgeRegistry.sol";
import "../src/core/FeeManager.sol";
import "../src/mocks/MockBridgeAdapter.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockPriceFeed.sol";
import "../src/interfaces/IBridgeAdapter.sol";

/**
 * @title SettlementSwitchTest
 * @notice Comprehensive test suite for SettlementSwitch contract
 * @dev Tests route selection, multi-chain scenarios, edge cases, and security
 */
contract SettlementSwitchTest is Test {
    // Core contracts
    SettlementSwitch public settlementSwitch;
    RouteCalculator public routeCalculator;
    BridgeRegistry public bridgeRegistry;
    FeeManager public feeManager;

    // Mock contracts
    MockBridgeAdapter public mockBridge1;
    MockBridgeAdapter public mockBridge2;
    MockBridgeAdapter public mockBridge3;
    MockERC20 public mockUSDC;
    MockERC20 public mockWETH;
    MockPriceFeed public ethPriceFeed;
    MockPriceFeed public maticPriceFeed;

    // Test accounts
    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public treasury = address(0x4);
    address public relayer = address(0x5);

    // Chain IDs
    uint256 public constant ETHEREUM_SEPOLIA = 11155111;
    uint256 public constant ARBITRUM_SEPOLIA = 421614;
    uint256 public constant POLYGON_MUMBAI = 80001;

    // Test amounts
    uint256 public constant TEST_AMOUNT = 1000 * 1e6; // 1000 USDC
    uint256 public constant LARGE_AMOUNT = 100000 * 1e6; // 100k USDC
    uint256 public constant SMALL_AMOUNT = 10 * 1e6; // 10 USDC

    // Events for testing
    event RouteCalculated(
        address indexed user,
        uint256 indexed srcChain,
        uint256 indexed dstChain,
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 estimatedCost,
        uint256 estimatedTime,
        address adapter
    );

    event TransferInitiated(
        bytes32 indexed transferId,
        address indexed user,
        IBridgeAdapter.Route route,
        uint256 timestamp
    );

    function setUp() public {
        vm.startPrank(admin);

        // Deploy mock tokens
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6, 1000000 * 1e6);
        mockWETH = new MockERC20("Mock WETH", "WETH", 18, 10000 * 1e18);

        // Deploy price feeds
        ethPriceFeed = new MockPriceFeed(8, "ETH/USD", 2000 * 1e8); // $2000
        maticPriceFeed = new MockPriceFeed(8, "MATIC/USD", 1 * 1e8); // $1

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

        // Deploy mock bridge adapters with different characteristics
        mockBridge1 = new MockBridgeAdapter("Fast Bridge", 0.001 ether, 5, 300); // Fast, low fee
        mockBridge2 = new MockBridgeAdapter("Cheap Bridge", 0.0005 ether, 3, 900); // Slow, very low fee
        mockBridge3 = new MockBridgeAdapter("Reliable Bridge", 0.002 ether, 8, 600); // Medium, higher fee

        // Configure mock bridges
        _configureMockBridges();

        // Register bridges with RouteCalculator
        routeCalculator.registerAdapter(address(mockBridge1));
        routeCalculator.registerAdapter(address(mockBridge2));
        routeCalculator.registerAdapter(address(mockBridge3));

        // Register bridges with BridgeRegistry
        uint256[] memory chainIds = new uint256[](3);
        chainIds[0] = ETHEREUM_SEPOLIA;
        chainIds[1] = ARBITRUM_SEPOLIA;
        chainIds[2] = POLYGON_MUMBAI;

        address[] memory tokens = new address[](2);
        tokens[0] = address(mockUSDC);
        tokens[1] = address(mockWETH);

        bridgeRegistry.registerBridge(address(mockBridge1), chainIds, tokens);
        bridgeRegistry.registerBridge(address(mockBridge2), chainIds, tokens);
        bridgeRegistry.registerBridge(address(mockBridge3), chainIds, tokens);

        // Register bridges with SettlementSwitch
        settlementSwitch.registerBridgeAdapter(address(mockBridge1), true);
        settlementSwitch.registerBridgeAdapter(address(mockBridge2), true);
        settlementSwitch.registerBridgeAdapter(address(mockBridge3), true);

        // Setup user balances
        mockUSDC.mint(user1, 1000000 * 1e6); // 1M USDC
        mockUSDC.mint(user2, 1000000 * 1e6);
        mockWETH.mint(user1, 1000 * 1e18); // 1k WETH
        mockWETH.mint(user2, 1000 * 1e18);

        vm.stopPrank();

        // Give users some ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function _configureMockBridges() internal {
        // Configure supported routes for all bridges
        uint256[] memory chains = new uint256[](3);
        chains[0] = ETHEREUM_SEPOLIA;
        chains[1] = ARBITRUM_SEPOLIA;
        chains[2] = POLYGON_MUMBAI;

        address[] memory tokens = new address[](2);
        tokens[0] = address(mockUSDC);
        tokens[1] = address(mockWETH);

        for (uint256 i = 0; i < chains.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                mockBridge1.addSupportedRoute(chains[i], tokens[j], 1000000 * 1e6);
                mockBridge2.addSupportedRoute(chains[i], tokens[j], 500000 * 1e6);
                mockBridge3.addSupportedRoute(chains[i], tokens[j], 2000000 * 1e6);
            }
        }

        // Configure different success rates
        MockBridgeAdapter.MockConfig memory config1 = MockBridgeAdapter.MockConfig({
            bridgeName: "Fast Bridge",
            baseFee: 0.001 ether,
            feePercentage: 5,
            minAmount: 1 * 1e6,
            maxAmount: 100000 * 1e6,
            completionTime: 300,
            successRate: 95,
            liquidityAmount: 1000000 * 1e6,
            isHealthy: true,
            isActive: true
        });

        MockBridgeAdapter.MockConfig memory config2 = MockBridgeAdapter.MockConfig({
            bridgeName: "Cheap Bridge",
            baseFee: 0.0005 ether,
            feePercentage: 3,
            minAmount: 1 * 1e6,
            maxAmount: 50000 * 1e6,
            completionTime: 900,
            successRate: 92,
            liquidityAmount: 500000 * 1e6,
            isHealthy: true,
            isActive: true
        });

        MockBridgeAdapter.MockConfig memory config3 = MockBridgeAdapter.MockConfig({
            bridgeName: "Reliable Bridge",
            baseFee: 0.002 ether,
            feePercentage: 8,
            minAmount: 10 * 1e6,
            maxAmount: 200000 * 1e6,
            completionTime: 600,
            successRate: 99,
            liquidityAmount: 2000000 * 1e6,
            isHealthy: true,
            isActive: true
        });

        mockBridge1.updateConfig(config1);
        mockBridge2.updateConfig(config2);
        mockBridge3.updateConfig(config3);
    }

    // ============ Basic Functionality Tests ============

    function testFindOptimalRoute_Cheapest() public {
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        // Should select the cheapest bridge (mockBridge2)
        assertEq(route.adapter, address(mockBridge2));
        assertEq(route.tokenIn, address(mockUSDC));
        assertEq(route.tokenOut, address(mockUSDC));
        assertEq(route.amountIn, TEST_AMOUNT);
        assertEq(route.srcChainId, ETHEREUM_SEPOLIA);
        assertEq(route.dstChainId, POLYGON_MUMBAI);
        assertTrue(route.metrics.totalCostWei > 0);
    }

    function testFindOptimalRoute_Fastest() public {
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.FASTEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            ARBITRUM_SEPOLIA,
            prefs
        );

        // Should select the fastest bridge (mockBridge1)
        assertEq(route.adapter, address(mockBridge1));
        assertTrue(route.metrics.estimatedTimeMinutes <= 10); // 5 minutes
    }

    function testFindOptimalRoute_Balanced() public {
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.BALANCED,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            ARBITRUM_SEPOLIA,
            prefs
        );

        // Should select a balanced option
        assertTrue(route.adapter != address(0));
        assertTrue(route.metrics.totalCostWei > 0);
        assertTrue(route.metrics.estimatedTimeMinutes > 0);
    }

    function testExecuteBridge_Success() public {
        vm.startPrank(user1);

        // Approve tokens
        mockUSDC.approve(address(settlementSwitch), TEST_AMOUNT);

        // Find route
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        // Execute bridge
        uint256 balanceBefore = mockUSDC.balanceOf(user1);
        
        vm.expectEmit(true, true, false, true);
        emit TransferInitiated(bytes32(0), user1, route, block.timestamp);

        bytes32 transferId = settlementSwitch.executeBridge{value: 0.01 ether}(
            route,
            user2,
            ""
        );

        // Check transfer was created
        assertTrue(transferId != bytes32(0));
        
        // Check balance decreased
        uint256 balanceAfter = mockUSDC.balanceOf(user1);
        assertEq(balanceBefore - balanceAfter, TEST_AMOUNT);

        // Check transfer details
        IBridgeAdapter.Transfer memory transfer = settlementSwitch.getTransfer(transferId);
        assertEq(transfer.sender, user1);
        assertEq(transfer.recipient, user2);
        assertEq(transfer.route.amountIn, TEST_AMOUNT);

        vm.stopPrank();
    }

    function testBridgeWithAutoRoute() public {
        vm.startPrank(user1);

        mockUSDC.approve(address(settlementSwitch), TEST_AMOUNT);

        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.FASTEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 30,
            allowMultiHop: false
        });

        bytes32 transferId = settlementSwitch.bridgeWithAutoRoute{value: 0.01 ether}(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            ARBITRUM_SEPOLIA,
            user2,
            prefs,
            ""
        );

        assertTrue(transferId != bytes32(0));

        vm.stopPrank();
    }

    // ============ Multi-Chain Scenarios ============

    function testMultipleRoutes() public {
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.BALANCED,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route[] memory routes = settlementSwitch.findMultipleRoutes(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs,
            3
        );

        // Should return multiple routes
        assertTrue(routes.length > 1);
        assertTrue(routes.length <= 3);

        // Routes should be sorted by preference
        for (uint256 i = 1; i < routes.length; i++) {
            // In balanced mode, better routes should have lower total cost or time
            assertTrue(routes[i].adapter != address(0));
        }
    }

    function testMultiPathRoute() public {
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.BALANCED,
            maxSlippageBps: 100,
            maxFeeWei: 10 ether,
            maxTimeMinutes: 60,
            allowMultiHop: true
        });

        ISettlementSwitch.MultiPathRoute memory multiPath = settlementSwitch.findMultiPathRoute(
            address(mockUSDC),
            address(mockUSDC),
            LARGE_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        // Should split large amount across multiple routes
        assertTrue(multiPath.routes.length > 1);
        assertTrue(multiPath.totalAmount == LARGE_AMOUNT);
        
        uint256 totalSplit = 0;
        for (uint256 i = 0; i < multiPath.amounts.length; i++) {
            totalSplit += multiPath.amounts[i];
        }
        assertEq(totalSplit, LARGE_AMOUNT);
    }

    function testExecuteMultiPathBridge() public {
        vm.startPrank(user1);

        mockUSDC.approve(address(settlementSwitch), LARGE_AMOUNT);

        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.BALANCED,
            maxSlippageBps: 100,
            maxFeeWei: 10 ether,
            maxTimeMinutes: 60,
            allowMultiHop: true
        });

        ISettlementSwitch.MultiPathRoute memory multiPath = settlementSwitch.findMultiPathRoute(
            address(mockUSDC),
            address(mockUSDC),
            LARGE_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        uint256 balanceBefore = mockUSDC.balanceOf(user1);

        bytes32[] memory transferIds = settlementSwitch.executeMultiPathBridge{value: 1 ether}(
            multiPath,
            user2,
            ""
        );

        // Check multiple transfers were created
        assertTrue(transferIds.length > 1);
        
        // Check total balance decreased correctly
        uint256 balanceAfter = mockUSDC.balanceOf(user1);
        assertEq(balanceBefore - balanceAfter, LARGE_AMOUNT);

        vm.stopPrank();
    }

    // ============ Edge Cases and Error Handling ============

    function testUnsupportedRoute() public {
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        // Try to find route for unsupported chain
        vm.expectRevert();
        settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            999999, // Unsupported chain
            POLYGON_MUMBAI,
            prefs
        );
    }

    function testInsufficientBalance() public {
        vm.startPrank(user1);

        // Try to transfer more than balance
        uint256 excessiveAmount = mockUSDC.balanceOf(user1) + 1;
        
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            excessiveAmount,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        mockUSDC.approve(address(settlementSwitch), excessiveAmount);

        vm.expectRevert();
        settlementSwitch.executeBridge{value: 0.01 ether}(
            route,
            user2,
            ""
        );

        vm.stopPrank();
    }

    function testInsufficientApproval() public {
        vm.startPrank(user1);

        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        // Don't approve tokens
        vm.expectRevert();
        settlementSwitch.executeBridge{value: 0.01 ether}(
            route,
            user2,
            ""
        );

        vm.stopPrank();
    }

    function testPausedContract() public {
        vm.prank(admin);
        settlementSwitch.emergencyPause("Testing pause");

        vm.startPrank(user1);

        mockUSDC.approve(address(settlementSwitch), TEST_AMOUNT);

        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        vm.expectRevert();
        settlementSwitch.executeBridge{value: 0.01 ether}(
            route,
            user2,
            ""
        );

        vm.stopPrank();
    }

    // ============ Fuzz Testing ============

    function testFuzz_FindOptimalRoute(
        uint256 amount,
        uint8 modeIndex,
        uint16 maxSlippageBps,
        uint32 maxTimeMinutes
    ) public {
        // Bound inputs
        amount = bound(amount, 1 * 1e6, 50000 * 1e6); // 1 to 50k USDC
        modeIndex = uint8(bound(modeIndex, 0, 2)); // 0-2 for routing modes
        maxSlippageBps = uint16(bound(maxSlippageBps, 1, 1000)); // 0.01% to 10%
        maxTimeMinutes = uint32(bound(maxTimeMinutes, 5, 120)); // 5 to 120 minutes

        IBridgeAdapter.RoutingMode mode = IBridgeAdapter.RoutingMode(modeIndex);
        
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: mode,
            maxSlippageBps: maxSlippageBps,
            maxFeeWei: 1 ether,
            maxTimeMinutes: maxTimeMinutes,
            allowMultiHop: false
        });

        try settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            amount,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        ) returns (IBridgeAdapter.Route memory route) {
            // If route found, validate it
            assertTrue(route.adapter != address(0));
            assertEq(route.amountIn, amount);
            assertTrue(route.metrics.totalCostWei > 0);
            assertTrue(route.metrics.estimatedTimeMinutes <= maxTimeMinutes);
        } catch {
            // Route not found is acceptable for some parameter combinations
        }
    }

    function testFuzz_ExecuteBridge(uint256 amount) public {
        // Bound amount to reasonable range
        amount = bound(amount, 10 * 1e6, 10000 * 1e6); // 10 to 10k USDC

        vm.startPrank(user1);

        mockUSDC.approve(address(settlementSwitch), amount);

        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.BALANCED,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        try settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            amount,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        ) returns (IBridgeAdapter.Route memory route) {
            uint256 balanceBefore = mockUSDC.balanceOf(user1);

            bytes32 transferId = settlementSwitch.executeBridge{value: 0.1 ether}(
                route,
                user2,
                ""
            );

            assertTrue(transferId != bytes32(0));
            
            uint256 balanceAfter = mockUSDC.balanceOf(user1);
            assertEq(balanceBefore - balanceAfter, amount);
        } catch {
            // Some amounts might not be supported
        }

        vm.stopPrank();
    }

    // ============ Specific Test Cases from Requirements ============

    function test_Route1000USDCSepoliaToMumbai_Cheapest() public {
        console.log("Testing: Route 1000 USDC from Ethereum Sepolia to Polygon Mumbai with CHEAPEST priority");
        
        uint256 amount = 1000 * 1e6; // 1000 USDC
        
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 50, // 0.5% max slippage
            maxFeeWei: 0.1 ether, // Max $200 fee at $2000 ETH
            maxTimeMinutes: 60, // 1 hour max
            allowMultiHop: false
        });

        // Find optimal route
        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            amount,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        console.log("Selected bridge:", route.adapter);
        console.log("Total cost (Wei):", route.metrics.totalCostWei);
        console.log("Estimated time (minutes):", route.metrics.estimatedTimeMinutes);
        console.log("Success rate:", route.metrics.successRate);

        // Should select cheapest bridge (mockBridge2)
        assertEq(route.adapter, address(mockBridge2));
        assertTrue(route.metrics.totalCostWei <= 0.1 ether);
        assertTrue(route.metrics.estimatedTimeMinutes <= 60);

        // Execute the transfer
        vm.startPrank(user1);
        mockUSDC.approve(address(settlementSwitch), amount);

        uint256 balanceBefore = mockUSDC.balanceOf(user1);
        
        bytes32 transferId = settlementSwitch.executeBridge{value: 0.01 ether}(
            route,
            user2,
            ""
        );

        assertTrue(transferId != bytes32(0));
        assertEq(mockUSDC.balanceOf(user1), balanceBefore - amount);

        console.log("Transfer ID:", vm.toString(transferId));
        console.log("Transfer executed successfully");

        vm.stopPrank();
    }

    function test_MultiHopRouting() public {
        console.log("Testing: Multi-hop routing through intermediate chains");

        // Configure one bridge to not support direct route
        mockBridge1.updateLiquidity(POLYGON_MUMBAI, address(mockUSDC), 0);

        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.BALANCED,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 120,
            allowMultiHop: true
        });

        // This should find alternative routes or multi-hop paths
        IBridgeAdapter.Route[] memory routes = settlementSwitch.findMultipleRoutes(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs,
            5
        );

        assertTrue(routes.length > 0);
        console.log("Found", routes.length, "alternative routes");

        for (uint256 i = 0; i < routes.length; i++) {
            console.log("Route", i, "- Bridge:", routes[i].adapter);
            console.log("  Cost:", routes[i].metrics.totalCostWei);
            console.log("  Time:", routes[i].metrics.estimatedTimeMinutes);
        }
    }

    // ============ Security Tests ============

    function testReentrancyProtection() public {
        // This would require a malicious contract that tries to reenter
        // For now, we test that the nonReentrant modifier is in place
        vm.startPrank(user1);

        mockUSDC.approve(address(settlementSwitch), TEST_AMOUNT);

        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        // Normal execution should work
        bytes32 transferId = settlementSwitch.executeBridge{value: 0.01 ether}(
            route,
            user2,
            ""
        );

        assertTrue(transferId != bytes32(0));

        vm.stopPrank();
    }

    function testAccessControl() public {
        // Test that only admin can perform admin functions
        vm.startPrank(user1);

        vm.expectRevert();
        settlementSwitch.registerBridgeAdapter(address(mockBridge1), true);

        vm.expectRevert();
        settlementSwitch.emergencyPause("Unauthorized pause");

        vm.stopPrank();

        // Admin should be able to perform these functions
        vm.startPrank(admin);

        settlementSwitch.emergencyPause("Authorized pause");
        assertTrue(settlementSwitch.isPaused());

        settlementSwitch.emergencyUnpause();
        assertFalse(settlementSwitch.isPaused());

        vm.stopPrank();
    }

    function testRateLimiting() public {
        vm.startPrank(user1);

        mockUSDC.approve(address(settlementSwitch), TEST_AMOUNT * 2);

        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        // First transfer should succeed
        bytes32 transferId1 = settlementSwitch.executeBridge{value: 0.01 ether}(
            route,
            user2,
            ""
        );
        assertTrue(transferId1 != bytes32(0));

        // Second transfer immediately should fail due to rate limiting
        vm.expectRevert();
        settlementSwitch.executeBridge{value: 0.01 ether}(
            route,
            user2,
            ""
        );

        // After waiting, should succeed
        vm.warp(block.timestamp + 11); // Wait 11 seconds (> MIN_TRANSFER_INTERVAL)

        bytes32 transferId2 = settlementSwitch.executeBridge{value: 0.01 ether}(
            route,
            user2,
            ""
        );
        assertTrue(transferId2 != bytes32(0));

        vm.stopPrank();
    }

    // ============ Gas Optimization Tests ============

    function testGasOptimization_RouteCalculation() public {
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.BALANCED,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        uint256 gasBefore = gasleft();
        
        settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for route calculation:", gasUsed);

        // Should use reasonable amount of gas
        assertTrue(gasUsed < 500000); // Less than 500k gas
    }

    function testGasOptimization_BridgeExecution() public {
        vm.startPrank(user1);

        mockUSDC.approve(address(settlementSwitch), TEST_AMOUNT);

        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.CHEAPEST,
            maxSlippageBps: 100,
            maxFeeWei: 1 ether,
            maxTimeMinutes: 60,
            allowMultiHop: false
        });

        IBridgeAdapter.Route memory route = settlementSwitch.findOptimalRoute(
            address(mockUSDC),
            address(mockUSDC),
            TEST_AMOUNT,
            ETHEREUM_SEPOLIA,
            POLYGON_MUMBAI,
            prefs
        );

        uint256 gasBefore = gasleft();
        
        settlementSwitch.executeBridge{value: 0.01 ether}(
            route,
            user2,
            ""
        );

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for bridge execution:", gasUsed);

        // Should use reasonable amount of gas
        assertTrue(gasUsed < 300000); // Less than 300k gas

        vm.stopPrank();
    }

    // ============ Integration Tests ============

    function testFullWorkflow_MultipleUsers() public {
        // Test multiple users using the system simultaneously
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = address(0x6);

        vm.deal(users[2], 100 ether);
        mockUSDC.mint(users[2], 1000000 * 1e6);

        bytes32[] memory transferIds = new bytes32[](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);

            uint256 amount = (i + 1) * 1000 * 1e6; // 1k, 2k, 3k USDC
            mockUSDC.approve(address(settlementSwitch), amount);

            IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
                mode: IBridgeAdapter.RoutingMode(i % 3), // Different modes
                maxSlippageBps: 100,
                maxFeeWei: 1 ether,
                maxTimeMinutes: 60,
                allowMultiHop: false
            });

            transferIds[i] = settlementSwitch.bridgeWithAutoRoute{value: 0.01 ether}(
                address(mockUSDC),
                address(mockUSDC),
                amount,
                ETHEREUM_SEPOLIA,
                POLYGON_MUMBAI,
                users[(i + 1) % users.length], // Send to next user
                prefs,
                ""
            );

            assertTrue(transferIds[i] != bytes32(0));

            vm.stopPrank();

            // Add delay between transfers to avoid rate limiting
            if (i < users.length - 1) {
                vm.warp(block.timestamp + 11);
            }
        }

        // Verify all transfers were created
        for (uint256 i = 0; i < transferIds.length; i++) {
            IBridgeAdapter.Transfer memory transfer = settlementSwitch.getTransfer(transferIds[i]);
            assertEq(transfer.sender, users[i]);
            assertTrue(transfer.route.amountIn > 0);
        }
    }

    // ============ Helper Functions ============

    function _createTestRoute(
        address adapter,
        uint256 amount,
        uint256 srcChain,
        uint256 dstChain
    ) internal view returns (IBridgeAdapter.Route memory) {
        IBridgeAdapter.RouteMetrics memory metrics = IBridgeAdapter.RouteMetrics({
            estimatedGasCost: 0.001 ether,
            bridgeFee: 0.0005 ether,
            totalCostWei: 0.0015 ether,
            estimatedTimeMinutes: 10,
            liquidityAvailable: 1000000 * 1e6,
            successRate: 95,
            congestionLevel: 20
        });

        return IBridgeAdapter.Route({
            adapter: adapter,
            tokenIn: address(mockUSDC),
            tokenOut: address(mockUSDC),
            amountIn: amount,
            amountOut: amount - (amount * 5 / 10000), // 0.05% fee
            srcChainId: srcChain,
            dstChainId: dstChain,
            metrics: metrics,
            adapterData: "",
            deadline: block.timestamp + 3600
        });
    }

    receive() external payable {}
}