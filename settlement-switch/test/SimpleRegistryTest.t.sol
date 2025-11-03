// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/core/BridgeRegistry.sol";
import "../src/mocks/MockBridgeAdapter.sol";

contract SimpleRegistryTest is Test {
    BridgeRegistry public registry;
    MockBridgeAdapter public mockBridge;
    address public admin = address(0x1);

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy registry
        registry = new BridgeRegistry(admin);
        
        // Deploy simple mock bridge
        mockBridge = new MockBridgeAdapter("Test Bridge", 0.001 ether, 5, 300);
        
        vm.stopPrank();
    }

    function test_SimpleBridgeRegistration() public {
        vm.startPrank(admin);
        
        // Simple registration with minimal data
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 11155111; // Sepolia
        
        address[] memory tokens = new address[](1);
        tokens[0] = address(0x123); // Mock token
        
        // This should work without gas issues
        registry.registerBridge(address(mockBridge), chainIds, tokens);
        
        vm.stopPrank();
    }
}