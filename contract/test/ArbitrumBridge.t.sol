// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/ArbitrumBridgeAdapter.sol";
import "../src/ArbitrumWithdrawalManager.sol";

/**
 * @title ArbitrumBridgeTest
 * @dev Comprehensive tests for Arbitrum bridge components
 * @notice Tests bridge adapter and withdrawal manager functionality
 */
contract ArbitrumBridgeTest is Test {
    
    // ============ Contract Instances ============
    
    ArbitrumBridgeAdapter public bridgeAdapter;
    ArbitrumWithdrawalManager public withdrawalManager;
    
    // ============ Mock Addresses ============
    
    address public constant MOCK_ARBITRUM_INBOX = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;
    address public constant MOCK_ARBITRUM_OUTBOX = 0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840;
    
    // ============ Test Accounts ============
    
    address public owner;
    address public user1;
    address public user2;
    address public recipient;
    address public challenger;
    
    // ============ Test Constants ============
    
    uint256 public constant TEST_BRIDGE_AMOUNT = 1 ether;
    uint256 public constant MIN_WITHDRAWAL_AMOUNT = 0.001 ether;
    uint256 public constant MAX_WITHDRAWAL_AMOUNT = 1000 ether;
    uint256 public constant CHALLENGE_PERIOD = 7 days;

    // ============ Setup ============
    
    function setUp() public {
        // Set up test accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        recipient = makeAddr("recipient");
        challenger = makeAddr("challenger");
        
        // Fund accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(challenger, 10 ether);
        
        // Deploy contracts
        vm.startPrank(owner);
        
        bridgeAdapter = new ArbitrumBridgeAdapter(
            owner
        );
        
        withdrawalManager = new ArbitrumWithdrawalManager(
            owner,
            bytes32(uint256(uint160(MOCK_ARBITRUM_OUTBOX)))
        );
        
        vm.stopPrank();
        
        // Mock external dependencies
        _mockArbitrumInfrastructure();
    }
    
    function _mockArbitrumInfrastructure() internal {
        // Mock Arbitrum Inbox createRetryableTicket
        vm.mockCall(
            MOCK_ARBITRUM_INBOX,
            abi.encodeWithSignature("createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)"),
            abi.encode(bytes32(uint256(0x123456789)))
        );
        
        // Mock Arbitrum Outbox executeTransaction
        vm.mockCall(
            MOCK_ARBITRUM_OUTBOX,
            abi.encodeWithSignature("executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)"),
            abi.encode(true)
        );
    }

    // ============ Bridge Adapter Tests ============
    
    function testBridgeETHBasic() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        uint256 gasLimit = 150000;
        uint256 maxGasPrice = 30 gwei;
        
        vm.prank(user1);
        uint256 txId = bridgeAdapter.bridgeETH{value: bridgeAmount}(
            recipient
        );
        
        assertTrue(txId != 0, "Transaction ID should not be zero");
        
        // Check transaction status
        ArbitrumBridgeAdapter.TransactionStatus memory status = bridgeAdapter.getTransactionStatus(bytes32(txId));
        
        assertTrue(status.exists, "Transaction should exist");
        assertFalse(status.completed, "Transaction should not be completed yet");
        assertFalse(status.failed, "Transaction should not be failed");
        assertTrue(status.timestamp > 0, "Timestamp should be set");
    }
    
    function testBridgeETHOptimized() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        
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
        
        vm.prank(user1);
        uint256 txId = bridgeAdapter.bridgeETHWithParams{value: bridgeAmount}(params);
        
        assertTrue(txId != 0, "Optimized bridge should succeed");
        
        // Verify gas statistics are updated
        ArbitrumBridgeAdapter.GasStats memory stats = 
            bridgeAdapter.getUserGasStats(user1);
        
        assertEq(stats.totalTransactions, 1, "Should have 1 transaction recorded");
        assertTrue(stats.averageGasUsed > 0, "Average gas should be recorded");
    }
    
    function testEstimateBridgeCost() public view {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        uint256 gasLimit = 150000;
        uint256 gasPrice = 30 gwei;
        uint256 maxSubmissionCost = 0.01 ether;
        
        uint256 totalCost = 
            bridgeAdapter.estimateBridgeCost(bridgeAmount, gasLimit, gasPrice, maxSubmissionCost);
        
        assertTrue(totalCost > bridgeAmount, "Total cost should include fees");
        assertEq(totalCost, bridgeAmount + maxSubmissionCost + (gasLimit * gasPrice), "Cost calculation should be correct");
    }
    
    function testBridgeAdapterAccessControl() public {
        // Test pause function
        vm.prank(user1);
        vm.expectRevert();
        bridgeAdapter.pause();
        
        vm.prank(owner);
        bridgeAdapter.pause();
        assertTrue(bridgeAdapter.paused(), "Contract should be paused");
        
        // Test bridging while paused
        vm.prank(user1);
        vm.expectRevert();
        bridgeAdapter.bridgeETH{value: TEST_BRIDGE_AMOUNT}(recipient);
        
        // Unpause
        vm.prank(owner);
        bridgeAdapter.unpause();
        assertFalse(bridgeAdapter.paused(), "Contract should be unpaused");
    }
    
    function testInvalidBridgeParameters() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        
        // Test invalid recipient
        vm.prank(user1);
        vm.expectRevert(ArbitrumBridgeAdapter.InvalidRecipient.selector);
        bridgeAdapter.bridgeETH{value: bridgeAmount}(address(0));
        
        // Test invalid amount (too small)
        vm.prank(user1);
        vm.expectRevert(ArbitrumBridgeAdapter.InvalidAmount.selector);
        bridgeAdapter.bridgeETH{value: 0.0001 ether}(recipient);
    }

    // ============ Withdrawal Manager Tests ============
    
    function testInitiateWithdrawal() public {
        uint256 withdrawAmount = TEST_BRIDGE_AMOUNT;
        bytes32[] memory proof = _createMerkleProof();
        
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
        
        assertTrue(withdrawalId != bytes32(0), "Withdrawal ID should not be zero");
        
        // Check withdrawal data
        ArbitrumWithdrawalManager.WithdrawalData memory withdrawal = 
            withdrawalManager.getWithdrawal(withdrawalId);
        
        assertEq(withdrawal.user, user1, "User should match");
        assertEq(withdrawal.recipient, recipient, "Recipient should match");
        assertEq(withdrawal.amount, withdrawAmount - (withdrawAmount * 25 / 10000), "Amount should match (minus fees)");
        assertEq(
            uint256(withdrawal.status),
            uint256(ArbitrumWithdrawalManager.WithdrawalStatus.ChallengePeriod),
            "Status should be ChallengePeriod"
        );
        assertEq(withdrawal.merkleProof.length, proof.length, "Proof length should match");
    }
    
    function testExecuteWithdrawal() public {
        uint256 withdrawAmount = TEST_BRIDGE_AMOUNT;
        bytes32[] memory proof = _createMerkleProof();
        
        ArbitrumWithdrawalManager.WithdrawalRequest memory request = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: withdrawAmount,
                l2TxHash: keccak256("test_tx"),
                merkleProof: proof,
                index: 0
            });
        
        // Step 1: Initiate withdrawal
        vm.prank(user1);
        bytes32 withdrawalId = withdrawalManager.initiateWithdrawal(request);
        
        // Step 2: Wait for challenge period
        vm.warp(block.timestamp + CHALLENGE_PERIOD + 1);
        
        // Step 3: Execute withdrawal
        uint256 initialRecipientBalance = recipient.balance;
        
        vm.prank(user1);
        withdrawalManager.executeWithdrawal(withdrawalId);
        
        // Verify withdrawal executed
        ArbitrumWithdrawalManager.WithdrawalData memory withdrawal = 
            withdrawalManager.getWithdrawal(withdrawalId);
        
        assertEq(
            uint256(withdrawal.status),
            uint256(ArbitrumWithdrawalManager.WithdrawalStatus.Executed),
            "Status should be Executed"
        );
        
        // Verify recipient received funds (minus fees)
        assertTrue(recipient.balance > initialRecipientBalance, "Recipient should receive funds");
    }
    
    function testChallengeWithdrawal() public {
        uint256 withdrawAmount = TEST_BRIDGE_AMOUNT;
        bytes32[] memory proof = _createMerkleProof();
        
        ArbitrumWithdrawalManager.WithdrawalRequest memory request = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: withdrawAmount,
                l2TxHash: keccak256("test_tx"),
                merkleProof: proof,
                index: 0
            });
        
        // Step 1: Initiate withdrawal
        vm.prank(user1);
        bytes32 withdrawalId = withdrawalManager.initiateWithdrawal(request);
        
        // Step 2: Challenge withdrawal
        vm.prank(challenger);
        withdrawalManager.challengeWithdrawal(
            withdrawalId,
            "Invalid proof"
        );
        
        // Verify withdrawal is challenged
        ArbitrumWithdrawalManager.WithdrawalData memory withdrawal = 
            withdrawalManager.getWithdrawal(withdrawalId);
        
        assertEq(
            uint256(withdrawal.status),
            uint256(ArbitrumWithdrawalManager.WithdrawalStatus.Challenged),
            "Status should be Challenged"
        );
        
        // Verify challenge data exists by checking status
        assertTrue(withdrawal.status == ArbitrumWithdrawalManager.WithdrawalStatus.Challenged, "Withdrawal should be marked as challenged");
    }
    
    function testResolveChallenge() public {
        uint256 withdrawAmount = TEST_BRIDGE_AMOUNT;
        bytes32[] memory proof = _createMerkleProof();
        
        ArbitrumWithdrawalManager.WithdrawalRequest memory request = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: withdrawAmount,
                l2TxHash: keccak256("test_tx"),
                merkleProof: proof,
                index: 0
            });
        
        // Step 1: Initiate and challenge withdrawal
        vm.prank(user1);
        bytes32 withdrawalId = withdrawalManager.initiateWithdrawal(request);
        
        vm.prank(challenger);
        withdrawalManager.challengeWithdrawal(
            withdrawalId,
            "Invalid proof"
        );
        
        // Step 2: Resolve challenge (owner decides)
        vm.prank(owner);
        withdrawalManager.resolveChallenge(withdrawalId, true); // Challenge is valid
        
        // Verify challenge resolved
        ArbitrumWithdrawalManager.WithdrawalData memory withdrawal = 
            withdrawalManager.getWithdrawal(withdrawalId);
        
        assertEq(
            uint256(withdrawal.status),
            uint256(ArbitrumWithdrawalManager.WithdrawalStatus.Failed),
            "Status should be Failed"
        );
    }
    
    function testWithdrawalManagerAccessControl() public {
        // Test pause function
        vm.prank(user1);
        vm.expectRevert();
        withdrawalManager.pause();
        
        vm.prank(owner);
        withdrawalManager.pause();
        assertTrue(withdrawalManager.paused(), "Contract should be paused");
        
        // Test withdrawal while paused
        bytes32[] memory proof = _createMerkleProof();
        
        ArbitrumWithdrawalManager.WithdrawalRequest memory request = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: TEST_BRIDGE_AMOUNT,
                l2TxHash: keccak256("test_tx"),
                merkleProof: proof,
                index: 0
            });
        
        vm.prank(user1);
        vm.expectRevert();
        withdrawalManager.initiateWithdrawal(request);
    }
    
    function testInvalidWithdrawalParameters() public {
        bytes32[] memory proof = _createMerkleProof();
        
        // Test invalid recipient
        ArbitrumWithdrawalManager.WithdrawalRequest memory invalidRecipientRequest = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: address(0),
                amount: TEST_BRIDGE_AMOUNT,
                l2TxHash: keccak256("test_tx"),
                merkleProof: proof,
                index: 0
            });
        
        vm.prank(user1);
        vm.expectRevert(ArbitrumWithdrawalManager.InvalidRecipient.selector);
        withdrawalManager.initiateWithdrawal(invalidRecipientRequest);
        
        // Test invalid amount (too small)
        ArbitrumWithdrawalManager.WithdrawalRequest memory invalidAmountRequest = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: 0.0001 ether,
                l2TxHash: keccak256("test_tx"),
                merkleProof: proof,
                index: 0
            });
        
        vm.prank(user1);
        vm.expectRevert(ArbitrumWithdrawalManager.InvalidWithdrawalAmount.selector);
        withdrawalManager.initiateWithdrawal(invalidAmountRequest);
        
        // Test empty proof
        bytes32[] memory emptyProof = new bytes32[](0);
        ArbitrumWithdrawalManager.WithdrawalRequest memory invalidProofRequest = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: TEST_BRIDGE_AMOUNT,
                l2TxHash: keccak256("test_tx"),
                merkleProof: emptyProof,
                index: 0
            });
        
        vm.prank(user1);
        vm.expectRevert(ArbitrumWithdrawalManager.InvalidMerkleProof.selector);
        withdrawalManager.initiateWithdrawal(invalidProofRequest);
    }

    // ============ Gas Optimization Tests ============
    
    function testGasOptimization() public {
        uint256 bridgeAmount = TEST_BRIDGE_AMOUNT;
        
        // Test multiple transactions to see gas optimization in action
        for (uint256 i = 0; i < 5; i++) {
            uint256 gasBefore = gasleft();
            
            vm.prank(user1);
            bridgeAdapter.bridgeETH{value: bridgeAmount}(recipient, 150000, 30 gwei);
            
            uint256 gasUsed = gasBefore - gasleft();
            console.log("Gas used for transaction", i + 1, ":", gasUsed);
        }
        
        // Check gas statistics
        ArbitrumBridgeAdapter.GasStats memory stats = 
            bridgeAdapter.getUserGasStats(user1);
        
        assertEq(stats.totalTransactions, 5, "Should have 5 transactions");
        assertTrue(stats.averageGasUsed > 0, "Should have average gas data");
        assertTrue(stats.totalGasUsed >= stats.averageGasUsed, "Total gas should be >= average");
    }

    // ============ Edge Case Tests ============
    
    function testMaximumWithdrawalAmount() public {
        uint256 maxAmount = MAX_WITHDRAWAL_AMOUNT;
        bytes32[] memory proof = _createMerkleProof();
        
        vm.deal(user1, maxAmount + 1 ether);
        
        ArbitrumWithdrawalManager.WithdrawalRequest memory request = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: maxAmount,
                l2TxHash: keccak256("test_tx"),
                merkleProof: proof,
                index: 0
            });
        
        vm.prank(user1);
        bytes32 withdrawalId = withdrawalManager.initiateWithdrawal(request);
        
        assertTrue(withdrawalId != bytes32(0), "Max withdrawal should succeed");
    }
    
    function testMinimumWithdrawalAmount() public {
        uint256 minAmount = MIN_WITHDRAWAL_AMOUNT;
        bytes32[] memory proof = _createMerkleProof();
        
        ArbitrumWithdrawalManager.WithdrawalRequest memory request = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: minAmount,
                l2TxHash: keccak256("test_tx"),
                merkleProof: proof,
                index: 0
            });
        
        vm.prank(user1);
        bytes32 withdrawalId = withdrawalManager.initiateWithdrawal(request);
        
        assertTrue(withdrawalId != bytes32(0), "Min withdrawal should succeed");
    }
    
    function testConcurrentWithdrawals() public {
        uint256 withdrawAmount = TEST_BRIDGE_AMOUNT;
        bytes32[] memory proof = _createMerkleProof();
        
        ArbitrumWithdrawalManager.WithdrawalRequest memory request1 = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: withdrawAmount,
                l2TxHash: keccak256("test_tx_1"),
                merkleProof: proof,
                index: 0
            });
        
        ArbitrumWithdrawalManager.WithdrawalRequest memory request2 = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: withdrawAmount,
                l2TxHash: keccak256("test_tx_2"),
                merkleProof: proof,
                index: 1
            });
        
        // Multiple users initiate withdrawals
        vm.prank(user1);
        bytes32 withdrawalId1 = withdrawalManager.initiateWithdrawal(request1);
        
        vm.prank(user2);
        bytes32 withdrawalId2 = withdrawalManager.initiateWithdrawal(request2);
        
        assertTrue(withdrawalId1 != withdrawalId2, "Withdrawal IDs should be unique");
        
        // Both should be in challenge period
        ArbitrumWithdrawalManager.WithdrawalData memory withdrawal1 = 
            withdrawalManager.getWithdrawal(withdrawalId1);
        ArbitrumWithdrawalManager.WithdrawalData memory withdrawal2 = 
            withdrawalManager.getWithdrawal(withdrawalId2);
        
        assertEq(
            uint256(withdrawal1.status),
            uint256(ArbitrumWithdrawalManager.WithdrawalStatus.ChallengePeriod),
            "First withdrawal should be in challenge period"
        );
        assertEq(
            uint256(withdrawal2.status),
            uint256(ArbitrumWithdrawalManager.WithdrawalStatus.ChallengePeriod),
            "Second withdrawal should be in challenge period"
        );
    }

    // ============ Emergency Functions Tests ============
    
    function testEmergencyWithdraw() public {
        // Fund the withdrawal manager
        vm.deal(address(withdrawalManager), 10 ether);
        
        uint256 initialOwnerBalance = owner.balance;
        
        vm.prank(owner);
        withdrawalManager.emergencyWithdraw(owner, 5 ether);
        
        assertEq(
            owner.balance,
            initialOwnerBalance + 5 ether,
            "Owner should receive emergency withdrawal"
        );
    }
    
    function testEmergencyWithdrawAccessControl() public {
        vm.deal(address(withdrawalManager), 10 ether);
        
        vm.prank(user1);
        vm.expectRevert();
        withdrawalManager.emergencyWithdraw(user1, 5 ether);
    }

    // ============ Fuzz Tests ============
    
    function testFuzzBridgeAmount(uint256 amount) public {
        // Bound amount to valid range
        amount = bound(amount, 0.001 ether, 100 ether);
        
        vm.deal(user1, amount + 1 ether);
        
        vm.prank(user1);
        uint256 txId = bridgeAdapter.bridgeETH{value: amount}(recipient);
        
        assertTrue(txId != 0, "Bridge should succeed for valid amounts");
    }
    
    function testFuzzWithdrawalAmount(uint256 amount) public {
        // Bound amount to valid range
        amount = bound(amount, MIN_WITHDRAWAL_AMOUNT, 10 ether);
        
        vm.deal(user1, amount + 1 ether);
        bytes32[] memory proof = _createMerkleProof();
        
        ArbitrumWithdrawalManager.WithdrawalRequest memory request = 
            ArbitrumWithdrawalManager.WithdrawalRequest({
                recipient: recipient,
                amount: amount,
                l2TxHash: keccak256("test_tx"),
                merkleProof: proof,
                index: 0
            });
        
        vm.prank(user1);
        bytes32 withdrawalId = withdrawalManager.initiateWithdrawal(request);
        
        assertTrue(withdrawalId != bytes32(0), "Withdrawal should succeed for valid amounts");
    }

    // ============ Helper Functions ============
    
    function _createMerkleProof() internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = keccak256("proof_element_1");
        proof[1] = keccak256("proof_element_2");
        proof[2] = keccak256("proof_element_3");
        return proof;
    }
    
    function _simulateL2Confirmation(bytes32 txId) internal {
        // This would be called by a relayer or automated system
        // For testing, we'll simulate it
        vm.prank(owner);
        // bridgeAdapter.confirmTransaction(txId, 150000);
    }
}