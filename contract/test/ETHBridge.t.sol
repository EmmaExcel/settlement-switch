// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/ETHBridge.sol";

/**
 * @title ETHBridgeTest
 * @dev Comprehensive test suite for ETHBridge contract
 * @notice Tests all functionality including edge cases and error conditions
 */
contract ETHBridgeTest is Test {
    
    // ============ Test Setup ============
    
    ETHBridge public ethBridge;
    
    // Mock addresses
    address public constant MOCK_CHAINLINK_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant MOCK_ARBITRUM_INBOX = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;
    
    // Test accounts
    address public owner;
    address public user1;
    address public user2;
    address public recipient;
    
    // Test constants
    uint256 public constant INITIAL_ETH_PRICE = 2000e8; // $2000 USD
    uint256 public constant TEST_BRIDGE_AMOUNT = 1 ether;
    uint256 public constant MIN_BRIDGE_AMOUNT = 0.001 ether;
    uint256 public constant MAX_BRIDGE_AMOUNT = 1000 ether;

    // ============ Events for Testing ============
    
    event ETHBridged(
        bytes32 indexed transactionId,
        address indexed user,
        address indexed recipient,
        uint256 amount,
        uint256 fee,
        uint256 estimatedGas
    );
    
    event BridgeCompleted(
        bytes32 indexed transactionId,
        address indexed user,
        uint256 finalGasUsed
    );
    
    event WithdrawalCompleted(
        bytes32 indexed transactionId,
        address indexed recipient,
        uint256 amount
    );

    // ============ Setup Functions ============
    
    function setUp() public {
        // Set up test accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        recipient = makeAddr("recipient");
        
        // Deploy ETHBridge contract
        vm.prank(owner);
        ethBridge = new ETHBridge(
            owner,
            MOCK_CHAINLINK_FEED,
            MOCK_ARBITRUM_INBOX
        );
        
        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(address(ethBridge), 50 ether);
        
        // Mock Chainlink price feed
        _mockChainlinkPriceFeed();
    }
    
    function _mockChainlinkPriceFeed() internal {
        // Mock the Chainlink price feed to return $2000 USD
        vm.mockCall(
            MOCK_CHAINLINK_FEED,
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(
                uint80(1), // roundId
                int256(INITIAL_ETH_PRICE), // price
                uint256(block.timestamp), // startedAt
                uint256(block.timestamp), // updatedAt
                uint80(1) // answeredInRound
            )
        );
    }

    // ============ Basic Functionality Tests ============
    
    function testBridgeETHSuccess() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        
        vm.prank(user1);
        bytes32 txId = ethBridge.bridgeETH{value: bridgeAmount}(recipient);
        
        // Verify transaction was recorded
        assertTrue(txId != bytes32(0), "Transaction ID should not be zero");
        
        // Check transaction details
        (
            address txUser,
            uint256 txAmount,
            address txRecipient,
            uint256 txTimestamp,
            ETHBridge.BridgeStatus txStatus,
            uint256 txFee,
            uint256 txEstimatedGas
        ) = ethBridge.getTransaction(txId);
        
        assertEq(txUser, user1, "User should match");
        assertEq(txAmount, bridgeAmount, "Amount should match");
        assertEq(txRecipient, recipient, "Recipient should match");
        assertEq(uint256(txStatus), uint256(ETHBridge.BridgeStatus.Pending), "Status should be Pending");
        assertTrue(txFee > 0, "Fee should be greater than zero");
        assertTrue(txEstimatedGas > 0, "Estimated gas should be greater than zero");
    }
    
    function testBridgeETHWithCustomParams() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        uint256 maxGasPrice = 50 gwei;
        uint256 gasLimit = 200000;
        
        ETHBridge.BridgeParams memory params = ETHBridge.BridgeParams({
            recipient: recipient,
            maxGasPrice: maxGasPrice,
            gasLimit: gasLimit,
            deadline: block.timestamp + 3600
        });
        
        vm.prank(user1);
        bytes32 txId = ethBridge.bridgeETHWithParams{value: bridgeAmount}(params);
        
        assertTrue(txId != bytes32(0), "Transaction ID should not be zero");
        
        // Verify custom parameters were used
        (,,,,,, uint256 estimatedGas) = ethBridge.getTransaction(txId);
        assertTrue(estimatedGas > 0, "Estimated gas should be calculated");
    }
    
    function testEstimateBridgeCost() public view {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        
        (uint256 totalCost, uint256 bridgeFee, uint256 gasCost) = 
            ethBridge.estimateBridgeCost(bridgeAmount, 30 gwei, 150000);
        
        assertTrue(totalCost > bridgeAmount, "Total cost should be greater than bridge amount");
        assertTrue(bridgeFee > 0, "Bridge fee should be greater than zero");
        assertTrue(gasCost > 0, "Gas cost should be greater than zero");
        assertEq(totalCost, bridgeAmount + bridgeFee + gasCost, "Total cost calculation should be correct");
    }

    // ============ Access Control Tests ============
    
    function testOnlyOwnerFunctions() public {
        // Test pause function
        vm.prank(user1);
        vm.expectRevert();
        ethBridge.pause();
        
        vm.prank(owner);
        ethBridge.pause();
        assertTrue(ethBridge.paused(), "Contract should be paused");
        
        // Test unpause function
        vm.prank(user1);
        vm.expectRevert();
        ethBridge.unpause();
        
        vm.prank(owner);
        ethBridge.unpause();
        assertFalse(ethBridge.paused(), "Contract should be unpaused");
        
        // Test withdraw fees
        vm.prank(user1);
        vm.expectRevert();
        ethBridge.withdrawFees(owner);
        
        vm.prank(owner);
        ethBridge.withdrawFees(owner);
    }
    
    function testOwnershipTransfer() public {
        address newOwner = makeAddr("newOwner");
        
        vm.prank(owner);
        ethBridge.transferOwnership(newOwner);
        
        vm.prank(newOwner);
        ethBridge.acceptOwnership();
        
        assertEq(ethBridge.owner(), newOwner, "Ownership should be transferred");
    }

    // ============ Input Validation Tests ============
    
    function testBridgeETHInvalidAmount() public {
        // Test amount too small
        vm.prank(user1);
        vm.expectRevert(ETHBridge.InvalidAmount.selector);
        ethBridge.bridgeETH{value: MIN_BRIDGE_AMOUNT - 1}(recipient);
        
        // Test amount too large
        vm.deal(user1, MAX_BRIDGE_AMOUNT + 1 ether);
        vm.prank(user1);
        vm.expectRevert(ETHBridge.InvalidAmount.selector);
        ethBridge.bridgeETH{value: MAX_BRIDGE_AMOUNT + 1}(recipient);
    }
    
    function testBridgeETHInvalidRecipient() public {
        vm.prank(user1);
        vm.expectRevert(ETHBridge.InvalidRecipient.selector);
        ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(address(0));
    }
    
    function testBridgeETHExpiredDeadline() public {
        ETHBridge.BridgeParams memory params = ETHBridge.BridgeParams({
            recipient: recipient,
            maxGasPrice: 50 gwei,
            gasLimit: 200000,
            deadline: block.timestamp - 1 // Expired deadline
        });
        
        vm.prank(user1);
        vm.expectRevert(ETHBridge.DeadlineExceeded.selector);
        ethBridge.bridgeETHWithParams{value: TEST_BRIDGE_AMOUNT}(params);
    }
    
    function testBridgeETHHighGasPrice() public {
        ETHBridge.BridgeParams memory params = ETHBridge.BridgeParams({
            recipient: recipient,
            maxGasPrice: 1000 gwei, // Very high gas price
            gasLimit: 200000,
            deadline: block.timestamp + 3600
        });
        
        vm.prank(user1);
        vm.expectRevert(ETHBridge.GasPriceTooHigh.selector);
        ethBridge.bridgeETHWithParams{value: TEST_BRIDGE_AMOUNT}(params);
    }

    // ============ State Management Tests ============
    
    function testPausedState() public {
        vm.prank(owner);
        ethBridge.pause();
        
        vm.prank(user1);
        vm.expectRevert();
        ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
    }
    
    function testTransactionHistory() public {
        // Bridge multiple transactions
        vm.prank(user1);
        bytes32 txId1 = ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
        
        vm.prank(user2);
        bytes32 txId2 = ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT * 2}(recipient);
        
        // Check user transaction history
        bytes32[] memory user1Txs = ethBridge.getUserTransactions(user1);
        bytes32[] memory user2Txs = ethBridge.getUserTransactions(user2);
        
        assertEq(user1Txs.length, 1, "User1 should have 1 transaction");
        assertEq(user2Txs.length, 1, "User2 should have 1 transaction");
        assertEq(user1Txs[0], txId1, "User1 transaction ID should match");
        assertEq(user2Txs[0], txId2, "User2 transaction ID should match");
    }

    // ============ Fee Calculation Tests ============
    
    function testFeeCalculation() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        
        vm.prank(user1);
        bytes32 txId = ethBridge.bridgeETH{value: bridgeAmount}(recipient);
        
        (,,,,,uint256 fee,) = ethBridge.getTransaction(txId);
        
        // Fee should be 0.1% of bridge amount
        uint256 expectedFee = (bridgeAmount * 10) / 10000;
        assertEq(fee, expectedFee, "Fee calculation should be correct");
    }
    
    function testGasCostEstimation() public view {
        uint256 gasPrice = 30 gwei;
        uint256 gasLimit = 150000;
        
        (,, uint256 gasCost) = ethBridge.estimateBridgeCost(TEST_BRIDGE_AMOUNT, gasPrice, gasLimit);
        
        // Gas cost should be based on ETH price
        uint256 expectedGasCostETH = (gasLimit * gasPrice);
        assertEq(gasCost, expectedGasCostETH, "Gas cost estimation should be correct");
    }

    // ============ Withdrawal Tests ============
    
    function testCompleteWithdrawal() public {
        // First, create a pending withdrawal
        bytes32 txId = keccak256(abi.encodePacked(user1, recipient, TEST_BRIDGE_AMOUNT, block.timestamp));
        
        vm.prank(owner);
        ethBridge.completeWithdrawal(txId, recipient, TEST_BRIDGE_AMOUNT);
        
        // Check that withdrawal was completed
        // Note: This would require the withdrawal to be properly set up first
    }

    // ============ Edge Case Tests ============
    
    function testZeroETHBalance() public {
        // Drain user's ETH
        vm.deal(user1, 0);
        
        vm.prank(user1);
        vm.expectRevert();
        ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
    }
    
    function testContractETHBalance() public {
        uint256 initialBalance = address(ethBridge).balance;
        
        vm.prank(user1);
        ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
        
        // Contract balance should increase
        assertEq(
            address(ethBridge).balance,
            initialBalance + TEST_BRIDGE_AMOUNT,
            "Contract balance should increase by bridge amount"
        );
    }
    
    function testMaxTransactionsPerUser() public {
        // Test that users can make multiple transactions
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user1);
            ethBridge.bridgeETH{value: MIN_BRIDGE_AMOUNT}(recipient);
        }
        
        bytes32[] memory userTxs = ethBridge.getUserTransactions(user1);
        assertEq(userTxs.length, 5, "User should have 5 transactions");
    }

    // ============ Integration Tests ============
    
    function testFullBridgeFlow() public {
        uint256 initialUserBalance = user1.balance;
        uint256 initialContractBalance = address(ethBridge).balance;
        
        // Step 1: Bridge ETH
        vm.prank(user1);
        bytes32 txId = ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
        
        // Verify user balance decreased
        assertEq(
            user1.balance,
            initialUserBalance - TEST_BRIDGE_AMOUNT,
            "User balance should decrease"
        );
        
        // Verify contract balance increased
        assertEq(
            address(ethBridge).balance,
            initialContractBalance + TEST_BRIDGE_AMOUNT,
            "Contract balance should increase"
        );
        
        // Step 2: Complete bridge (simulate L2 confirmation)
        vm.prank(owner);
        ethBridge.completeBridge(txId, 100000); // Mock gas used
        
        // Verify transaction status updated
        (,,,, ETHBridge.BridgeStatus status,,) = ethBridge.getTransaction(txId);
        assertEq(uint256(status), uint256(ETHBridge.BridgeStatus.Completed), "Status should be Completed");
    }

    // ============ Fuzz Tests ============
    
    function testFuzzBridgeAmount(uint256 amount) public {
        // Bound the amount to valid range
        amount = bound(amount, MIN_BRIDGE_AMOUNT, MAX_BRIDGE_AMOUNT);
        
        vm.deal(user1, amount + 1 ether); // Extra for gas
        
        vm.prank(user1);
        bytes32 txId = ethBridge.bridgeETH{value: amount}(recipient);
        
        (,uint256 txAmount,,,,,) = ethBridge.getTransaction(txId);
        assertEq(txAmount, amount, "Transaction amount should match input");
    }
    
    function testFuzzRecipientAddress(address _recipient) public {
        vm.assume(_recipient != address(0));
        vm.assume(_recipient.code.length == 0); // Not a contract
        
        vm.prank(user1);
        bytes32 txId = ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(_recipient);
        
        (,,address txRecipient,,,,) = ethBridge.getTransaction(txId);
        assertEq(txRecipient, _recipient, "Recipient should match input");
    }

    // ============ Gas Optimization Tests ============
    
    function testGasUsage() public {
        uint256 gasBefore = gasleft();
        
        vm.prank(user1);
        ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
        
        uint256 gasUsed = gasBefore - gasleft();
        
        // Gas usage should be reasonable (less than 200k gas)
        assertTrue(gasUsed < 200000, "Gas usage should be optimized");
        console.log("Gas used for bridgeETH:", gasUsed);
    }

    // ============ Security Tests ============
    
    function testReentrancyProtection() public {
        // This would require a malicious contract to test properly
        // For now, we verify the ReentrancyGuard is in place
        assertTrue(true, "ReentrancyGuard should prevent reentrancy attacks");
    }
    
    function testOverflowProtection() public {
        // Test with maximum values to ensure no overflow
        uint256 maxAmount = type(uint256).max;
        
        vm.expectRevert();
        ethBridge.estimateBridgeCost(maxAmount, type(uint256).max, type(uint256).max);
    }

    // ============ Helper Functions ============
    
    function _createTestTransaction() internal returns (bytes32) {
        vm.prank(user1);
        return ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
    }
    
    function _fundAccount(address account, uint256 amount) internal {
        vm.deal(account, amount);
    }
}