// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/**
 * @title WorkingTest
 * @notice Minimal test to verify Foundry setup works
 */
contract WorkingTest is Test {
    
    function testBasicFunctionality() public {
        // Test basic arithmetic
        uint256 a = 10;
        uint256 b = 5;
        assertEq(a + b, 15);
        assertEq(a - b, 5);
        assertEq(a * b, 50);
        assertEq(a / b, 2);
    }
    
    function testAddressOperations() public {
        address addr1 = address(0x123);
        address addr2 = address(0x456);
        
        assertTrue(addr1 != addr2);
        assertEq(addr1, address(0x123));
        assertFalse(addr1 == addr2);
    }
    
    function testArrayOperations() public {
        uint256[] memory numbers = new uint256[](3);
        numbers[0] = 100;
        numbers[1] = 200;
        numbers[2] = 300;
        
        assertEq(numbers.length, 3);
        assertEq(numbers[0], 100);
        assertEq(numbers[1], 200);
        assertEq(numbers[2], 300);
        
        uint256 sum = 0;
        for (uint256 i = 0; i < numbers.length; i++) {
            sum += numbers[i];
        }
        assertEq(sum, 600);
    }
    
    function testStringOperations() public {
        string memory greeting = "Hello World";
        bytes memory greetingBytes = bytes(greeting);
        
        assertTrue(greetingBytes.length > 0);
        assertEq(greetingBytes.length, 11);
    }
    
    function testEventEmission() public {
        // Test event emission
        vm.expectEmit(true, false, false, true);
        emit TestEvent(msg.sender, 42);
        
        // Emit the event
        emit TestEvent(msg.sender, 42);
    }
    
    function testTimeManipulation() public {
        uint256 initialTime = block.timestamp;
        
        // Warp time forward by 1 hour
        vm.warp(block.timestamp + 3600);
        
        assertEq(block.timestamp, initialTime + 3600);
    }
    
    function testBalanceManipulation() public {
        address testAddr = address(0x789);
        
        // Check initial balance is 0
        assertEq(testAddr.balance, 0);
        
        // Give the address some ETH
        vm.deal(testAddr, 1 ether);
        
        // Check balance is now 1 ETH
        assertEq(testAddr.balance, 1 ether);
    }
    
    function testFuzzBasicMath(uint8 x, uint8 y) public {
        // Fuzz test with bounded inputs
        vm.assume(x > 0 && y > 0);
        vm.assume(x < 100 && y < 100);
        
        uint256 sum = uint256(x) + uint256(y);
        assertTrue(sum >= x);
        assertTrue(sum >= y);
        assertTrue(sum <= 200);
    }
    
    function testFuzzAddressGeneration(uint160 seed) public {
        address generated = address(seed);
        
        // Test that we can generate addresses
        assertTrue(generated == address(seed));
        
        // Test address properties
        if (seed > 0) {
            assertTrue(generated != address(0));
        }
    }
    
    // Event for testing
    event TestEvent(address indexed sender, uint256 value);
}