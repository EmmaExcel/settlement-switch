// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeAdapter.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FeeManager is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;


    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    
  
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    
    struct FeeStructure {
        uint256 baseFeeRate;        // Base fee rate in basis points
        uint256 minFeeAmount;       // Minimum fee amount in Wei
        uint256 maxFeeAmount;       // Maximum fee amount in Wei
        uint256 congestionMultiplier; // Multiplier for high congestion (basis points)
        bool isActive;              // Whether this fee structure is active
    }


    struct RevenueDistribution {
        address recipient;          // Recipient address
        uint256 percentage;         // Percentage of revenue (basis points)
        bool isActive;              // Whether this distribution is active
    }


    struct DynamicFeeParams {
        uint256 baseGasPrice;       // Base gas price threshold
        uint256 congestionThreshold; // Congestion level threshold (0-100)
        uint256 maxMultiplier;      // Maximum fee multiplier (basis points)
        uint256 adjustmentSpeed;    // How quickly fees adjust (basis points per block)
        uint256 lastUpdateBlock;    // Last block when fees were updated
    }


    struct FeeRecord {
        address token;              // Token address (address(0) for ETH)
        uint256 amount;             // Fee amount collected
        uint256 timestamp;          // Collection timestamp
        address payer;              // Fee payer address
        bytes32 transferId;         // Associated transfer ID
        string feeType;             // Type of fee (bridge, protocol, etc.)
    }

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE_RATE = 1000; // 10% maximum fee rate
    uint256 public constant MAX_CONGESTION_MULTIPLIER = 5000; // 50% maximum congestion multiplier
    uint256 public constant DEFAULT_BASE_FEE = 10; // 0.1% default base fee

    // State variables
    mapping(string => FeeStructure) public feeStructures;
    mapping(uint256 => DynamicFeeParams) public chainFeeParams; // chainId => params
    mapping(address => uint256) public collectedFees; // token => amount
    mapping(address => RevenueDistribution) public revenueDistributors;
    
    address[] public distributorList;
    FeeRecord[] public feeHistory;
    
    address public treasury;
    uint256 public totalFeesCollected;
    uint256 public totalFeesDistributed;
    
    // Fee exemptions
    mapping(address => bool) public feeExemptions;
    mapping(address => uint256) public discountRates; // address => discount rate in basis points

    // Events
    event FeeStructureUpdated(
        string indexed feeType,
        FeeStructure feeStructure
    );
    
    event FeeCollected(
        address indexed token,
        uint256 amount,
        address indexed payer,
        bytes32 indexed transferId,
        string feeType
    );
    
    event RevenueDistributed(
        address indexed recipient,
        address indexed token,
        uint256 amount
    );
    
    event DynamicFeeUpdated(
        uint256 indexed chainId,
        uint256 newMultiplier,
        uint256 congestionLevel
    );
    
    event FeeExemptionGranted(address indexed account, bool exempt);
    event DiscountRateSet(address indexed account, uint256 discountRate);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    // Errors
    error InvalidFeeRate();
    error InvalidRecipient();
    error InvalidDistribution();
    error FeeStructureNotFound();
    error InsufficientFeePayment();
    error DistributionFailed();
    error InvalidCongestionLevel();
    error ExcessiveDiscount();

 
    constructor(address admin, address _treasury) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FEE_MANAGER_ROLE, admin);
        _grantRole(TREASURY_ROLE, admin);
        
        treasury = _treasury;
        
        // Initialize default fee structures
        _initializeDefaultFeeStructures();
    }

 
    function _initializeDefaultFeeStructures() internal {
        // Protocol fee structure
        feeStructures["protocol"] = FeeStructure({
            baseFeeRate: DEFAULT_BASE_FEE,
            minFeeAmount: 0.001 ether,
            maxFeeAmount: 1 ether,
            congestionMultiplier: 2000, // 20% increase during congestion
            isActive: true
        });

        // Bridge fee structure
        feeStructures["bridge"] = FeeStructure({
            baseFeeRate: 5, // 0.05%
            minFeeAmount: 0.0005 ether,
            maxFeeAmount: 0.5 ether,
            congestionMultiplier: 1500, // 15% increase during congestion
            isActive: true
        });

        // Gas fee structure
        feeStructures["gas"] = FeeStructure({
            baseFeeRate: 0, // Gas fees are calculated separately
            minFeeAmount: 0,
            maxFeeAmount: 10 ether,
            congestionMultiplier: 3000, // 30% increase during congestion
            isActive: true
        });
    }

  
    function calculateFee(
        string memory feeType,
        uint256 amount,
        uint256 chainId,
        address payer
    ) external view returns (uint256 feeAmount) {
        FeeStructure memory feeStruct = feeStructures[feeType];
        if (!feeStruct.isActive) return 0;

        // Check fee exemption
        if (feeExemptions[payer]) return 0;

        // Calculate base fee
        feeAmount = (amount * feeStruct.baseFeeRate) / BASIS_POINTS;

        // Apply minimum and maximum limits
        if (feeAmount < feeStruct.minFeeAmount) {
            feeAmount = feeStruct.minFeeAmount;
        }
        if (feeAmount > feeStruct.maxFeeAmount) {
            feeAmount = feeStruct.maxFeeAmount;
        }

        // Apply dynamic fee adjustment based on congestion
        uint256 congestionMultiplier = _getCongestionMultiplier(chainId, feeStruct);
        feeAmount = (feeAmount * congestionMultiplier) / BASIS_POINTS;

        // Apply discount if applicable
        uint256 discount = discountRates[payer];
        if (discount > 0) {
            feeAmount = feeAmount - (feeAmount * discount / BASIS_POINTS);
        }

        return feeAmount;
    }

  
    function collectFee(
        string memory feeType,
        address token,
        uint256 amount,
        address payer,
        bytes32 transferId
    ) external payable nonReentrant onlyRole(FEE_MANAGER_ROLE) {
        if (amount == 0) return;

        // Collect the fee
        if (token == address(0)) {
            // ETH fee
            if (msg.value < amount) revert InsufficientFeePayment();
            
            // Refund excess
            if (msg.value > amount) {
                payable(payer).transfer(msg.value - amount);
            }
        } else {
            // ERC20 token fee
            IERC20(token).safeTransferFrom(payer, address(this), amount);
        }

        // Update collected fees
        collectedFees[token] += amount;
        totalFeesCollected += amount;

        // Record fee collection
        feeHistory.push(FeeRecord({
            token: token,
            amount: amount,
            timestamp: block.timestamp,
            payer: payer,
            transferId: transferId,
            feeType: feeType
        }));

        emit FeeCollected(token, amount, payer, transferId, feeType);
    }


    function distributeFees(address token) external nonReentrant onlyRole(TREASURY_ROLE) {
        uint256 availableAmount = collectedFees[token];
        if (availableAmount == 0) return;

        uint256 totalDistributed = 0;

        // Distribute to configured recipients
        for (uint256 i = 0; i < distributorList.length; i++) {
            address recipient = distributorList[i];
            RevenueDistribution memory distribution = revenueDistributors[recipient];
            
            if (!distribution.isActive) continue;

            uint256 distributionAmount = (availableAmount * distribution.percentage) / BASIS_POINTS;
            
            if (distributionAmount > 0) {
                if (token == address(0)) {
                    // ETH distribution
                    payable(recipient).transfer(distributionAmount);
                } else {
                    // ERC20 token distribution
                    IERC20(token).safeTransfer(recipient, distributionAmount);
                }

                totalDistributed += distributionAmount;
                emit RevenueDistributed(recipient, token, distributionAmount);
            }
        }

        // Send remaining to treasury
        uint256 remainingAmount = availableAmount - totalDistributed;
        if (remainingAmount > 0) {
            if (token == address(0)) {
                payable(treasury).transfer(remainingAmount);
            } else {
                IERC20(token).safeTransfer(treasury, remainingAmount);
            }
            emit RevenueDistributed(treasury, token, remainingAmount);
        }

        // Update state
        collectedFees[token] = 0;
        totalFeesDistributed += availableAmount;
    }

   
    function updateFeeStructure(
        string memory feeType,
        FeeStructure memory feeStructure
    ) external onlyRole(FEE_MANAGER_ROLE) {
        if (feeStructure.baseFeeRate > MAX_FEE_RATE) revert InvalidFeeRate();
        if (feeStructure.congestionMultiplier > MAX_CONGESTION_MULTIPLIER) revert InvalidFeeRate();
        if (feeStructure.minFeeAmount > feeStructure.maxFeeAmount) revert InvalidFeeRate();

        feeStructures[feeType] = feeStructure;
        emit FeeStructureUpdated(feeType, feeStructure);
    }

  
    function setRevenueDistribution(
        address recipient,
        uint256 percentage
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (recipient == address(0)) revert InvalidRecipient();
        if (percentage > BASIS_POINTS) revert InvalidDistribution();

        bool isNewRecipient = !revenueDistributors[recipient].isActive;
        
        revenueDistributors[recipient] = RevenueDistribution({
            recipient: recipient,
            percentage: percentage,
            isActive: percentage > 0
        });

        if (isNewRecipient && percentage > 0) {
            distributorList.push(recipient);
        } else if (!isNewRecipient && percentage == 0) {
            // Remove from distributor list
            for (uint256 i = 0; i < distributorList.length; i++) {
                if (distributorList[i] == recipient) {
                    distributorList[i] = distributorList[distributorList.length - 1];
                    distributorList.pop();
                    break;
                }
            }
        }

        // Validate total distribution doesn't exceed 100%
        _validateTotalDistribution();
    }

    function updateDynamicFeeParams(
        uint256 chainId,
        DynamicFeeParams memory params
    ) external onlyRole(FEE_MANAGER_ROLE) {
        if (params.maxMultiplier > MAX_CONGESTION_MULTIPLIER) revert InvalidFeeRate();
        
        params.lastUpdateBlock = block.number;
        chainFeeParams[chainId] = params;
    }

   
    function updateCongestionLevel(
        uint256 chainId,
        uint256 congestionLevel
    ) external onlyRole(FEE_MANAGER_ROLE) {
        if (congestionLevel > 100) revert InvalidCongestionLevel();

        DynamicFeeParams storage params = chainFeeParams[chainId];
        
        // Calculate new multiplier based on congestion
        uint256 newMultiplier = BASIS_POINTS;
        if (congestionLevel > params.congestionThreshold) {
            uint256 excessCongestion = congestionLevel - params.congestionThreshold;
            uint256 multiplierIncrease = (excessCongestion * params.maxMultiplier) / (100 - params.congestionThreshold);
            newMultiplier = BASIS_POINTS + multiplierIncrease;
        }

        // Apply adjustment speed to smooth out changes
        uint256 blocksSinceUpdate = block.number - params.lastUpdateBlock;
        uint256 maxAdjustment = params.adjustmentSpeed * blocksSinceUpdate;
        
        // Limit adjustment speed
        if (newMultiplier > BASIS_POINTS + maxAdjustment) {
            newMultiplier = BASIS_POINTS + maxAdjustment;
        } else if (newMultiplier < BASIS_POINTS - maxAdjustment) {
            newMultiplier = BASIS_POINTS - maxAdjustment;
        }

        params.lastUpdateBlock = block.number;
        
        emit DynamicFeeUpdated(chainId, newMultiplier, congestionLevel);
    }


    function setFeeExemption(address account, bool exempt) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeExemptions[account] = exempt;
        emit FeeExemptionGranted(account, exempt);
    }

    function setDiscountRate(address account, uint256 discountRate) external onlyRole(FEE_MANAGER_ROLE) {
        if (discountRate > BASIS_POINTS) revert ExcessiveDiscount();
        
        discountRates[account] = discountRate;
        emit DiscountRateSet(account, discountRate);
    }

    function updateTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert InvalidRecipient();
        
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

 
    function _getCongestionMultiplier(
        uint256 chainId,
        FeeStructure memory feeStruct
    ) internal view returns (uint256 multiplier) {
        DynamicFeeParams memory params = chainFeeParams[chainId];
        
        if (params.baseGasPrice == 0) {
            // No dynamic params set, use static multiplier
            return BASIS_POINTS + feeStruct.congestionMultiplier;
        }

        // Use dynamic calculation based on current conditions
        // This is simplified - in production, you'd integrate with gas price oracles
        return BASIS_POINTS + feeStruct.congestionMultiplier;
    }

  
    function _validateTotalDistribution() internal view {
        uint256 totalPercentage = 0;
        
        for (uint256 i = 0; i < distributorList.length; i++) {
            RevenueDistribution memory distribution = revenueDistributors[distributorList[i]];
            if (distribution.isActive) {
                totalPercentage += distribution.percentage;
            }
        }
        
        if (totalPercentage > BASIS_POINTS) revert InvalidDistribution();
    }


    function getFeeHistory(bytes32 transferId) external view returns (FeeRecord[] memory records) {
        uint256 count = 0;
        
        // Count matching records
        for (uint256 i = 0; i < feeHistory.length; i++) {
            if (feeHistory[i].transferId == transferId) {
                count++;
            }
        }
        
        // Create result array
        records = new FeeRecord[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < feeHistory.length; i++) {
            if (feeHistory[i].transferId == transferId) {
                records[index] = feeHistory[i];
                index++;
            }
        }
        
        return records;
    }

    function getCollectedFees(address token) external view returns (uint256 amount) {
        return collectedFees[token];
    }


    function getRevenueDistribution() external view returns (
        address[] memory recipients,
        uint256[] memory percentages
    ) {
        recipients = new address[](distributorList.length);
        percentages = new uint256[](distributorList.length);
        
        for (uint256 i = 0; i < distributorList.length; i++) {
            recipients[i] = distributorList[i];
            percentages[i] = revenueDistributors[distributorList[i]].percentage;
        }
        
        return (recipients, percentages);
    }


    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (recipient == address(0)) revert InvalidRecipient();
        
        if (token == address(0)) {
            payable(recipient).transfer(amount);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }

    receive() external payable {
        // Allow contract to receive ETH for fee payments
    }
}