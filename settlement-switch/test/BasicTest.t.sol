// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockPriceFeed.sol";

/**
 * @title BasicTest
 * @notice Simple tests to verify basic contract functionality
 */
contract BasicTest is Test {
    MockERC20 public token;
    MockPriceFeed public priceFeed;
    
    address public user = address(0x1);
    
    function setUp() public {
        // Deploy mock contracts
        token = new MockERC20("Test Token", "TEST", 18, 1000000 * 1e18);
        priceFeed = new MockPriceFeed(8, "TEST/USD", 100 * 1e8); // $100
    }
    
    function testTokenBasicFunctionality() public {
        // Test basic token operations
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.decimals(), 18);
        assertTrue(token.totalSupply() > 0);
        
        // Test minting
        uint256 mintAmount = 1000 * 1e18;
        token.mint(user, mintAmount);
        assertEq(token.balanceOf(user), mintAmount);
        
        // Test transfer
        vm.prank(user);
        token.transfer(address(this), 100 * 1e18);
        assertEq(token.balanceOf(address(this)), 100 * 1e18);
        assertEq(token.balanceOf(user), mintAmount - 100 * 1e18);
    }
    
    function testPriceFeedBasicFunctionality() public {
        // Test price feed operations
        assertEq(priceFeed.decimals(), 8);
        
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        
        assertTrue(roundId > 0);
        assertEq(answer, 100 * 1e8);
        assertTrue(updatedAt > 0);
        
        // Test price update
        priceFeed.updatePrice(200 * 1e8);
        (, int256 newAnswer,,,) = priceFeed.latestRoundData();
        assertEq(newAnswer, 200 * 1e8);
    }
    
    function testTokenConfigurableBehavior() public {
        // Test configurable behavior
        assertTrue(token.transfersEnabled());
        assertTrue(token.approvalsEnabled());
        
        // Disable transfers
        token.setTransfersEnabled(false);
        assertFalse(token.transfersEnabled());
        
        // Try transfer (should fail)
        token.mint(user, 1000 * 1e18);
        vm.prank(user);
        vm.expectRevert();
        token.transfer(address(this), 100 * 1e18);
        
        // Re-enable transfers
        token.setTransfersEnabled(true);
        vm.prank(user);
        token.transfer(address(this), 100 * 1e18);
        assertEq(token.balanceOf(address(this)), 100 * 1e18);
    }
    
    function testPriceFeedVolatility() public {
        // Test volatility simulation
        priceFeed.setVolatility(true, 500, 300); // 5% volatility, 5min interval
        
        int256 originalPrice = 100 * 1e8;
        priceFeed.updatePrice(originalPrice);
        
        // Simulate time passage and price update
        vm.warp(block.timestamp + 301);
        priceFeed.updatePrice(originalPrice);
        
        (, int256 newPrice,,,) = priceFeed.latestRoundData();
        // Price should be different due to volatility (within reasonable bounds)
        assertTrue(newPrice != originalPrice);
        assertTrue(newPrice > 90 * 1e8 && newPrice < 110 * 1e8); // Within 10% range
    }
    
    function testFuzzTokenOperations(uint256 amount) public {
        // Bound the amount to reasonable values
        amount = bound(amount, 1, 1000000 * 1e18);
        
        // Test minting and burning
        token.mint(user, amount);
        assertEq(token.balanceOf(user), amount);
        
        token.burn(user, amount);
        assertEq(token.balanceOf(user), 0);
    }
    
    function testFuzzPriceFeedUpdates(int256 price) public {
        // Bound price to reasonable values
        price = int256(bound(uint256(price), 1 * 1e8, 10000 * 1e8)); // $1 to $10,000
        
        priceFeed.updatePrice(price);
        (, int256 answer,,,) = priceFeed.latestRoundData();
        assertEq(answer, price);
    }
}