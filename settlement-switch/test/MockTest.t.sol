// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/**
 * @title MockTest
 * @notice Very simple test to verify basic Solidity functionality
 */
contract MockTest is Test {
    
    function testBasicMath() public {
        uint256 a = 5;
        uint256 b = 3;
        assertEq(a + b, 8);
        assertEq(a * b, 15);
        assertTrue(a > b);
    }
    
    function testAddresses() public {
        address addr1 = address(0x1);
        address addr2 = address(0x2);
        assertTrue(addr1 != addr2);
        assertEq(addr1, address(0x1));
    }
    
    function testArrays() public {
        uint256[] memory arr = new uint256[](3);
        arr[0] = 10;
        arr[1] = 20;
        arr[2] = 30;
        
        assertEq(arr.length, 3);
        assertEq(arr[0], 10);
        assertEq(arr[1], 20);
        assertEq(arr[2], 30);
    }
    
    function testFuzzBasicMath(uint256 x, uint256 y) public {
        vm.assume(x < type(uint128).max);
        vm.assume(y < type(uint128).max);
        
        uint256 sum = x + y;
        assertTrue(sum >= x);
        assertTrue(sum >= y);
    }
}