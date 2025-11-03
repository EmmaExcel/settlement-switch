// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MockPriceFeed is Ownable {
    struct RoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    // Price feed configuration
    uint8 public decimals;
    string public description;
    uint256 public version = 1;
    
    // Current price data
    RoundData public currentRoundData;
    mapping(uint80 => RoundData) public rounds;
    
    // Configurable behavior for testing
    bool public isActive = true;
    bool public shouldRevert = false;
    bool public shouldReturnStaleData = false;
    uint256 public stalenessThreshold = 3600; // 1 hour
    uint256 public priceDeviationBps = 0; // Price deviation in basis points
    
    // Historical data
    uint80 public currentRoundId = 1;
    int256[] public priceHistory;
    uint256 public maxHistoryLength = 100;
    
    // Volatility simulation
    bool public volatilityEnabled = false;
    uint256 public volatilityPercentage = 500; // 5% volatility
    uint256 public lastVolatilityUpdate;
    uint256 public volatilityInterval = 300; // 5 minutes
    
    // Events
    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);
    event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
    event ConfigUpdated(string parameter, uint256 value);

    // Errors
    error PriceFeedInactive();
    error RoundNotComplete();
    error InvalidRoundId();
    error StalePrice();

    constructor(
        uint8 _decimals,
        string memory _description,
        int256 _initialPrice
    ) Ownable(msg.sender) {
        decimals = _decimals;
        description = _description;
        
        // Initialize with current price
        _updatePrice(_initialPrice);
    }

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        if (shouldRevert) revert PriceFeedInactive();
        if (!isActive) revert PriceFeedInactive();
        
        RoundData memory round = currentRoundData;
        
        // Check for stale data
        if (shouldReturnStaleData || (block.timestamp - round.updatedAt > stalenessThreshold)) {
            revert StalePrice();
        }
        
        // Apply price deviation if configured
        int256 deviatedPrice = _applyPriceDeviation(round.answer);
        
        return (
            round.roundId,
            deviatedPrice,
            round.startedAt,
            round.updatedAt,
            round.answeredInRound
        );
    }

    function getRoundData(uint80 _roundId) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        if (shouldRevert) revert PriceFeedInactive();
        if (_roundId > currentRoundId || _roundId == 0) revert InvalidRoundId();
        
        RoundData memory round = rounds[_roundId];
        if (round.updatedAt == 0) revert RoundNotComplete();
        
        return (
            round.roundId,
            round.answer,
            round.startedAt,
            round.updatedAt,
            round.answeredInRound
        );
    }

    function updatePrice(int256 _price) external onlyOwner {
        _updatePrice(_price);
    }

    function _updatePrice(int256 _price) internal {
        // Apply volatility if enabled
        if (volatilityEnabled && block.timestamp >= lastVolatilityUpdate + volatilityInterval) {
            _price = _applyVolatility(_price);
            lastVolatilityUpdate = block.timestamp;
        }
        
        currentRoundId++;
        
        RoundData memory newRound = RoundData({
            roundId: currentRoundId,
            answer: _price,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: currentRoundId
        });
        
        currentRoundData = newRound;
        rounds[currentRoundId] = newRound;
        
        // Update price history
        priceHistory.push(_price);
        if (priceHistory.length > maxHistoryLength) {
            // Remove oldest price (simplified, not gas efficient for production)
            for (uint256 i = 0; i < priceHistory.length - 1; i++) {
                priceHistory[i] = priceHistory[i + 1];
            }
            priceHistory.pop();
        }
        
        emit AnswerUpdated(_price, currentRoundId, block.timestamp);
        emit NewRound(currentRoundId, msg.sender, block.timestamp);
    }

    function _applyPriceDeviation(int256 _basePrice) internal view returns (int256 deviatedPrice) {
        if (priceDeviationBps == 0) return _basePrice;
        
        // Apply random-like deviation based on block properties
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 10000;
        bool isPositive = pseudoRandom % 2 == 0;
        
        uint256 deviation = (uint256(_basePrice) * priceDeviationBps) / 10000;
        
        if (isPositive) {
            return _basePrice + int256(deviation);
        } else {
            return _basePrice - int256(deviation);
        }
    }

    function _applyVolatility(int256 _basePrice) internal view returns (int256 volatilePrice) {
        if (volatilityPercentage == 0) return _basePrice;
        
        // Generate pseudo-random volatility
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(
            block.timestamp, 
            block.prevrandao, 
            _basePrice
        ))) % 10000;
        
        bool isPositive = pseudoRandom % 2 == 0;
        uint256 volatilityAmount = (pseudoRandom % volatilityPercentage);
        
        uint256 priceChange = (uint256(_basePrice) * volatilityAmount) / 10000;
        
        if (isPositive) {
            return _basePrice + int256(priceChange);
        } else {
            return _basePrice - int256(priceChange);
        }
    }

    // Configuration functions

    function setActive(bool _isActive) external onlyOwner {
        isActive = _isActive;
        emit ConfigUpdated("isActive", _isActive ? 1 : 0);
    }

    function setShouldRevert(bool _shouldRevert) external onlyOwner {
        shouldRevert = _shouldRevert;
        emit ConfigUpdated("shouldRevert", _shouldRevert ? 1 : 0);
    }

    function setShouldReturnStaleData(bool _shouldReturnStale) external onlyOwner {
        shouldReturnStaleData = _shouldReturnStale;
        emit ConfigUpdated("shouldReturnStaleData", _shouldReturnStale ? 1 : 0);
    }

    function setStalenessThreshold(uint256 _threshold) external onlyOwner {
        stalenessThreshold = _threshold;
        emit ConfigUpdated("stalenessThreshold", _threshold);
    }

    function setPriceDeviation(uint256 _deviationBps) external onlyOwner {
        require(_deviationBps <= 5000, "Deviation too high"); // Max 50%
        priceDeviationBps = _deviationBps;
        emit ConfigUpdated("priceDeviationBps", _deviationBps);
    }

    function setVolatility(bool _enabled, uint256 _percentage, uint256 _interval) external onlyOwner {
        require(_percentage <= 2000, "Volatility too high"); // Max 20%
        volatilityEnabled = _enabled;
        volatilityPercentage = _percentage;
        volatilityInterval = _interval;
        lastVolatilityUpdate = block.timestamp;
        
        emit ConfigUpdated("volatilityEnabled", _enabled ? 1 : 0);
        emit ConfigUpdated("volatilityPercentage", _percentage);
        emit ConfigUpdated("volatilityInterval", _interval);
    }

    function simulatePriceCrash(uint256 _crashPercentage) external onlyOwner {
        require(_crashPercentage <= 9000, "Crash too severe"); // Max 90%
        
        int256 currentPrice = currentRoundData.answer;
        int256 crashAmount = (currentPrice * int256(_crashPercentage)) / 10000;
        int256 newPrice = currentPrice - crashAmount;
        
        _updatePrice(newPrice);
    }

    function simulatePricePump(uint256 _pumpPercentage) external onlyOwner {
        require(_pumpPercentage <= 5000, "Pump too high"); // Max 50%
        
        int256 currentPrice = currentRoundData.answer;
        int256 pumpAmount = (currentPrice * int256(_pumpPercentage)) / 10000;
        int256 newPrice = currentPrice + pumpAmount;
        
        _updatePrice(newPrice);
    }

    function batchUpdatePrices(int256[] calldata _prices, uint256[] calldata _timestamps) external onlyOwner {
        require(_prices.length == _timestamps.length, "Array length mismatch");
        
        for (uint256 i = 0; i < _prices.length; i++) {
            currentRoundId++;
            
            RoundData memory newRound = RoundData({
                roundId: currentRoundId,
                answer: _prices[i],
                startedAt: _timestamps[i],
                updatedAt: _timestamps[i],
                answeredInRound: currentRoundId
            });
            
            rounds[currentRoundId] = newRound;
            priceHistory.push(_prices[i]);
        }
        
        // Update latest round data to the last entry
        if (_prices.length > 0) {
            currentRoundData = rounds[currentRoundId];
        }
    }

    // View functions

    function getPriceHistory() external view returns (int256[] memory prices) {
        return priceHistory;
    }

    function getPriceStatistics() external view returns (
        int256 min,
        int256 max,
        int256 avg,
        int256 current
    ) {
        if (priceHistory.length == 0) {
            return (0, 0, 0, currentRoundData.answer);
        }
        
        min = priceHistory[0];
        max = priceHistory[0];
        int256 sum = 0;
        
        for (uint256 i = 0; i < priceHistory.length; i++) {
            int256 price = priceHistory[i];
            if (price < min) min = price;
            if (price > max) max = price;
            sum += price;
        }
        
        avg = sum / int256(priceHistory.length);
        current = currentRoundData.answer;
        
        return (min, max, avg, current);
    }

    function checkStaleness() external view returns (bool isStale, uint256 staleness) {
        staleness = block.timestamp - currentRoundData.updatedAt;
        isStale = staleness > stalenessThreshold;
        return (isStale, staleness);
    }

    function getFeedConfig() external view returns (
        uint8 feedDecimals,
        string memory feedDescription,
        uint256 feedVersion,
        bool feedActive,
        uint256 currentRound,
        uint256 historyLength
    ) {
        return (
            decimals,
            description,
            version,
            isActive,
            currentRoundId,
            priceHistory.length
        );
    }

    function simulateNetworkDelay(uint256 _delaySeconds) external onlyOwner {
        // In a real test environment, this would introduce actual delays
        // For now, we just update the timestamp to simulate delayed updates
        currentRoundData.updatedAt = block.timestamp - _delaySeconds;
        rounds[currentRoundId].updatedAt = block.timestamp - _delaySeconds;
    }

    function reset(int256 _initialPrice) external onlyOwner {
        currentRoundId = 0;
        delete priceHistory;
        isActive = true;
        shouldRevert = false;
        shouldReturnStaleData = false;
        priceDeviationBps = 0;
        volatilityEnabled = false;
        
        _updatePrice(_initialPrice);
    }
}