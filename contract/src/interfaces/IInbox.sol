// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IInbox
 * @notice Arbitrum Inbox interface for L1 to L2 messaging
 */
interface IInbox {
    /**
     * @notice Create a retryable ticket for L1 to L2 messaging
     * @param to L2 contract address to call
     * @param l2CallValue ETH value to send to L2
     * @param maxSubmissionCost Maximum cost for submitting the transaction
     * @param excessFeeRefundAddress Address to refund excess fees
     * @param callValueRefundAddress Address to refund call value
     * @param gasLimit Gas limit for L2 execution
     * @param maxFeePerGas Maximum fee per gas for L2 execution
     * @param data Calldata for L2 contract call
     * @return Ticket ID for the retryable ticket
     */
    function createRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256);
}