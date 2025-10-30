// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockPriceFeed
 * @notice Mock implementation of Chainlink AggregatorV3Interface for testing
 */
contract MockPriceFeed is AggregatorV3Interface {
    uint8 private _decimals;
    int256 private _latestAnswer;
    uint256 private _latestTimestamp;
    uint80 private _latestRoundId;
    
    constructor(uint8 decimals_) {
        _decimals = decimals_;
        _latestTimestamp = block.timestamp;
        _latestRoundId = 1;
    }
    
    function updateAnswer(int256 answer) external {
        _latestAnswer = answer;
        _latestTimestamp = block.timestamp;
        _latestRoundId++;
    }
    
    function decimals() external view override returns (uint8) {
        return _decimals;
    }
    
    function description() external pure override returns (string memory) {
        return "Mock Price Feed";
    }
    
    function version() external pure override returns (uint256) {
        return 1;
    }
    
    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _latestAnswer, _latestTimestamp, _latestTimestamp, _roundId);
    }
    
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_latestRoundId, _latestAnswer, _latestTimestamp, _latestTimestamp, _latestRoundId);
    }
}