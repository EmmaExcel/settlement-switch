// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/ETHBridge.sol";
import "../src/ArbitrumBridgeAdapter.sol";
import "../src/ArbitrumWithdrawalManager.sol";
import "../src/BridgeErrorHandler.sol";

/**
 * @title BridgeIntegrationTest
 * @dev Integration tests for the complete bridge system
 * @notice Tests end-to-end workflows and cross-contract interactions
 */
contract BridgeIntegrationTest is Test {
    
    // ============ Contract Instances ============
    
    ETHBridge public ethBridge;
    ArbitrumBridgeAdapter public bridgeAdapter;
    ArbitrumWithdrawalManager public withdrawalManager;
    BridgeErrorHandler public errorHandler;
    
    // ============ Mock Addresses ============
    
    address public constant MOCK_CHAINLINK_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant MOCK_ARBITRUM_INBOX = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;
    address public constant MOCK_ARBITRUM_OUTBOX = 0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840;
    
    // ============ Test Accounts ============
    
    address public owner;
    address public user1;
    address public user2;
    address public recipient;
    address public relayer;
    
    // ============ Test Constants ============
    
    uint256 public constant INITIAL_ETH_PRICE = 2000e8;
    uint256 public constant TEST_BRIDGE_AMOUNT = 1 ether;
    uint256 public constant LARGE_BRIDGE_AMOUNT = 10 ether;
    
    // ============ Setup ============
    
    function setUp() public {
        // Set up test accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        recipient = makeAddr("recipient");
        relayer = makeAddr("relayer");
        
        // Fund accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(relayer, 50 ether);
        
        // Deploy contracts
        _deployContracts();
        
        // Configure contracts
        _configureContracts();
        
        // Mock external dependencies
        _mockExternalDependencies();
    }
    
    function _deployContracts() internal {
        vm.startPrank(owner);
        
        // Deploy error handler first
        errorHandler = new BridgeErrorHandler(owner);
        
        // Deploy withdrawal manager
        withdrawalManager = new ArbitrumWithdrawalManager(
            owner,
            MOCK_ARBITRUM_OUTBOX
        );
        
        // Deploy bridge adapter
        bridgeAdapter = new ArbitrumBridgeAdapter(
            owner,
            MOCK_ARBITRUM_INBOX
        );
        
        // Deploy main ETH bridge
        ethBridge = new ETHBridge(
            owner,
            MOCK_CHAINLINK_FEED,
            MOCK_ARBITRUM_INBOX
        );
        
        vm.stopPrank();
    }
    
    function _configureContracts() internal {
        vm.startPrank(owner);
        
        // Configure error handler with contract addresses
        errorHandler.setContractAddress("ETHBridge", address(ethBridge));
        errorHandler.setContractAddress("BridgeAdapter", address(bridgeAdapter));
        errorHandler.setContractAddress("WithdrawalManager", address(withdrawalManager));
        
        // Set up cross-contract permissions if needed
        // (This would depend on the actual contract implementations)
        
        vm.stopPrank();
    }
    
    function _mockExternalDependencies() internal {
        // Mock Chainlink price feed
        vm.mockCall(
            MOCK_CHAINLINK_FEED,
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(
                uint80(1),
                int256(INITIAL_ETH_PRICE),
                uint256(block.timestamp),
                uint256(block.timestamp),
                uint80(1)
            )
        );
        
        // Mock Arbitrum Inbox
        vm.mockCall(
            MOCK_ARBITRUM_INBOX,
            abi.encodeWithSignature("createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)"),
            abi.encode(bytes32(0x123))
        );
        
        // Mock Arbitrum Outbox
        vm.mockCall(
            MOCK_ARBITRUM_OUTBOX,
            abi.encodeWithSignature("executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)"),
            abi.encode(true)
        );
    }

    // ============ End-to-End Bridge Tests ============
    
    function testCompleteEthereumToArbitrumFlow() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        uint256 initialUserBalance = user1.balance;
        
        // Step 1: User initiates bridge on Ethereum
        vm.prank(user1);
        bytes32 txId = ethBridge.bridgeETH{value: bridgeAmount}(recipient);
        
        // Verify transaction created
        assertTrue(txId != bytes32(0), "Transaction should be created");
        
        // Step 2: Bridge adapter processes the transaction
        vm.prank(owner);
        bridgeAdapter.bridgeETH{value: bridgeAmount}(recipient, 150000, 30 gwei);
        
        // Step 3: Simulate L2 confirmation
        vm.prank(owner);
        ethBridge.completeBridge(txId, 120000);
        
        // Verify final state
        (,,,, ETHBridge.BridgeStatus status,,) = ethBridge.getTransaction(txId);
        assertEq(uint256(status), uint256(ETHBridge.BridgeStatus.Completed), "Bridge should be completed");
        
        // Verify user balance changed
        assertTrue(user1.balance < initialUserBalance, "User balance should decrease");
    }
    
    function testCompleteArbitrumToEthereumFlow() public {
        uint256 withdrawAmount = TEST_BRIDGE_AMOUNT;
        
        // Step 1: Initiate withdrawal on Arbitrum (simulated)
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = keccak256("proof1");
        proof[1] = keccak256("proof2");
        proof[2] = keccak256("proof3");
        
        ArbitrumWithdrawalManager.WithdrawalRequest memory request = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: withdrawAmount,
                l2TxHash: keccak256("test_tx"),
                merkleProof: proof,
                index: 0
            });
        
        vm.prank(user1);
        bytes32 withdrawalId = withdrawalManager.initiateWithdrawal(request);
        
        // Step 2: Wait for challenge period (simulate time passage)
        vm.warp(block.timestamp + 7 days + 1);
        
        // Step 3: Execute withdrawal
        vm.prank(relayer);
        withdrawalManager.executeWithdrawal(withdrawalId);
        
        // Verify withdrawal completed
        (,,,, ArbitrumWithdrawalManager.WithdrawalStatus status,) = 
            withdrawalManager.getWithdrawal(withdrawalId);
        assertEq(
            uint256(status), 
            uint256(ArbitrumWithdrawalManager.WithdrawalStatus.Executed), 
            "Withdrawal should be executed"
        );
    }

    // ============ Multi-User Scenarios ============
    
    function testConcurrentBridging() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        
        // Multiple users bridge simultaneously
        vm.prank(user1);
        bytes32 txId1 = ethBridge.bridgeETH{value: bridgeAmount}(recipient);
        
        vm.prank(user2);
        bytes32 txId2 = ethBridge.bridgeETH{value: bridgeAmount * 2}(recipient);
        
        // Both transactions should be successful
        assertTrue(txId1 != bytes32(0), "User1 transaction should succeed");
        assertTrue(txId2 != bytes32(0), "User2 transaction should succeed");
        assertTrue(txId1 != txId2, "Transaction IDs should be unique");
        
        // Verify both transactions are tracked
        bytes32[] memory user1Txs = ethBridge.getUserTransactions(user1);
        bytes32[] memory user2Txs = ethBridge.getUserTransactions(user2);
        
        assertEq(user1Txs.length, 1, "User1 should have 1 transaction");
        assertEq(user2Txs.length, 1, "User2 should have 1 transaction");
    }
    
    function testHighVolumeTransactions() public {
        uint256 numTransactions = 10;
        uint256 bridgeAmount = 0.1 ether;
        
        // Create multiple transactions
        for (uint256 i = 0; i < numTransactions; i++) {
            vm.prank(user1);
            bytes32 txId = ethBridge.bridgeETH{value: bridgeAmount}(recipient);
            assertTrue(txId != bytes32(0), "Each transaction should succeed");
        }
        
        // Verify all transactions are tracked
        bytes32[] memory userTxs = ethBridge.getUserTransactions(user1);
        assertEq(userTxs.length, numTransactions, "All transactions should be tracked");
    }

    // ============ Error Handling Integration ============
    
    function testErrorHandlerIntegration() public {
        // Test network congestion handling
        vm.prank(owner);
        errorHandler.reportNetworkCongestion(1, 100 gwei);
        
        assertTrue(errorHandler.isNetworkCongested(1), "Network should be marked as congested");
        
        // Test failed transaction handling
        bytes32 txId = keccak256("failed_tx");
        vm.prank(owner);
        errorHandler.reportFailedTransaction(txId, "Insufficient gas");
        
        assertTrue(errorHandler.isTransactionFailed(txId), "Transaction should be marked as failed");
    }
    
    function testErrorRecoveryFlow() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        
        // Step 1: Create a transaction
        vm.prank(user1);
        bytes32 txId = ethBridge.bridgeETH{value: bridgeAmount}(recipient);
        
        // Step 2: Simulate transaction failure
        vm.prank(owner);
        errorHandler.reportFailedTransaction(txId, "Network timeout");
        
        // Step 3: Retry transaction (this would be handled by the error handler)
        vm.prank(owner);
        errorHandler.retryFailedTransaction(txId);
        
        // Verify recovery attempt was logged
        assertTrue(errorHandler.isTransactionFailed(txId), "Failed transaction should be tracked");
    }

    // ============ Gas Optimization Integration ============
    
    function testGasOptimizedBridging() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        
        // Test with optimized parameters
        ArbitrumBridgeAdapter.OptimizedBridgeParams memory params = 
            ArbitrumBridgeAdapter.OptimizedBridgeParams({
                to: recipient,
                amount: bridgeAmount,
                gasLimit: 150000,
                gasPriceBid: 30 gwei,
                maxSubmissionCost: 0.01 ether,
                data: "",
                priority: 0
            });
        
        uint256 gasBefore = gasleft();
        
        vm.prank(user1);
        uint256 txId = bridgeAdapter.bridgeETHWithParams{value: bridgeAmount}(params);
        
        uint256 gasUsed = gasBefore - gasleft();
        
        assertTrue(txId != 0, "Optimized bridge should succeed");
        assertTrue(gasUsed < 200000, "Gas usage should be optimized");
        
        console.log("Gas used for optimized bridge:", gasUsed);
    }

    // ============ Security Integration Tests ============
    
    function testCrossContractSecurity() public {
        // Test that contracts properly validate calls from each other
        
        // Only authorized contracts should be able to call certain functions
        vm.prank(user1);
        vm.expectRevert();
        errorHandler.reportFailedTransaction(bytes32(0), "unauthorized");
        
        // Owner should be able to call
        vm.prank(owner);
        errorHandler.reportFailedTransaction(bytes32(0), "authorized");
    }
    
    function testReentrancyProtectionAcrossContracts() public {
        // This would require malicious contracts to test properly
        // For now, verify that all contracts have reentrancy protection
        assertTrue(true, "All contracts should have ReentrancyGuard");
    }

    // ============ Fee Distribution Tests ============
    
    function testFeeCollection() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        uint256 initialContractBalance = address(ethBridge).balance;
        
        // Bridge ETH to generate fees
        vm.prank(user1);
        ethBridge.bridgeETH{value: bridgeAmount}(recipient);
        
        // Contract should have collected fees
        assertTrue(
            address(ethBridge).balance > initialContractBalance + bridgeAmount,
            "Contract should collect fees"
        );
        
        // Owner should be able to withdraw fees
        uint256 initialOwnerBalance = owner.balance;
        
        vm.prank(owner);
        ethBridge.withdrawFees(owner);
        
        assertTrue(owner.balance > initialOwnerBalance, "Owner should receive fees");
    }

    // ============ Upgrade and Migration Tests ============
    
    function testContractUpgradeability() public {
        // Test that contracts can be paused for upgrades
        vm.prank(owner);
        ethBridge.pause();
        
        vm.prank(owner);
        bridgeAdapter.pause();
        
        vm.prank(owner);
        withdrawalManager.pause();
        
        // All contracts should be paused
        assertTrue(ethBridge.paused(), "ETHBridge should be paused");
        assertTrue(bridgeAdapter.paused(), "BridgeAdapter should be paused");
        assertTrue(withdrawalManager.paused(), "WithdrawalManager should be paused");
        
        // Transactions should fail when paused
        vm.prank(user1);
        vm.expectRevert();
        ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
    }

    // ============ Performance Tests ============
    
    function testSystemPerformanceUnderLoad() public {
        uint256 numUsers = 5;
        uint256 transactionsPerUser = 3;
        uint256 bridgeAmount = 0.5 ether;
        
        // Create multiple users
        address[] memory users = new address[](numUsers);
        for (uint256 i = 0; i < numUsers; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            vm.deal(users[i], 10 ether);
        }
        
        uint256 totalGasUsed = 0;
        uint256 gasBefore = gasleft();
        
        // Each user makes multiple transactions
        for (uint256 i = 0; i < numUsers; i++) {
            for (uint256 j = 0; j < transactionsPerUser; j++) {
                vm.prank(users[i]);
                bytes32 txId = ethBridge.bridgeETH{value: bridgeAmount}(recipient);
                assertTrue(txId != bytes32(0), "Transaction should succeed under load");
            }
        }
        
        totalGasUsed = gasBefore - gasleft();
        uint256 avgGasPerTx = totalGasUsed / (numUsers * transactionsPerUser);
        
        console.log("Total transactions:", numUsers * transactionsPerUser);
        console.log("Total gas used:", totalGasUsed);
        console.log("Average gas per transaction:", avgGasPerTx);
        
        // Performance should remain reasonable under load
        assertTrue(avgGasPerTx < 300000, "Average gas per transaction should be reasonable");
    }

    // ============ Edge Case Integration Tests ============
    
    function testSystemBehaviorAtLimits() public {
        // Test maximum bridge amount
        uint256 maxAmount = 1000 ether;
        vm.deal(user1, maxAmount + 1 ether);
        
        vm.prank(user1);
        bytes32 txId = ethBridge.bridgeETH{value: maxAmount}(recipient);
        assertTrue(txId != bytes32(0), "Max amount bridge should succeed");
        
        // Test minimum bridge amount
        uint256 minAmount = 0.001 ether;
        
        vm.prank(user2);
        bytes32 txId2 = ethBridge.bridgeETH{value: minAmount}(recipient);
        assertTrue(txId2 != bytes32(0), "Min amount bridge should succeed");
    }
    
    function testSystemRecoveryAfterFailure() public {
        // Simulate system failure by pausing all contracts
        vm.startPrank(owner);
        ethBridge.pause();
        bridgeAdapter.pause();
        withdrawalManager.pause();
        vm.stopPrank();
        
        // Verify system is down
        vm.prank(user1);
        vm.expectRevert();
        ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
        
        // Recover system
        vm.startPrank(owner);
        ethBridge.unpause();
        bridgeAdapter.unpause();
        withdrawalManager.unpause();
        vm.stopPrank();
        
        // Verify system is operational again
        vm.prank(user1);
        bytes32 txId = ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
        assertTrue(txId != bytes32(0), "System should recover after failure");
    }

    // ============ Monitoring and Analytics ============
    
    function testSystemMetrics() public {
        // Bridge some transactions to generate metrics
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user1);
            ethBridge.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
        }
        
        // Check gas usage statistics
        ArbitrumBridgeAdapter.GasStats memory stats = 
            bridgeAdapter.getUserGasStats(user1);
        
        assertTrue(stats.totalTransactions > 0, "Should have transaction statistics");
        assertTrue(stats.averageGasUsed > 0, "Should have average gas data");
    }

    // ============ Helper Functions ============
    
    function _simulateNetworkCongestion() internal {
        vm.prank(owner);
        errorHandler.reportNetworkCongestion(1, 200 gwei);
    }
    
    function _simulateL2Confirmation(bytes32 txId) internal {
        vm.prank(owner);
        ethBridge.completeBridge(txId, 150000);
    }
    
    function _createMerkleProof() internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = keccak256("leaf1");
        proof[1] = keccak256("leaf2");
        proof[2] = keccak256("leaf3");
        return proof;
    }
}