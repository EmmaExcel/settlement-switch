// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ILiFi {
    struct BridgeData {
        bytes32 transactionId;
        string bridge;
        string integrator;
        address referrer;
        address sendingAssetId;
        address receiver;
        uint256 minAmount;
        uint256 destinationChainId;
        bool hasSourceSwaps;
        bool hasDestinationCall;
    }

    struct SwapData {
        address callTo;
        address approveTo;
        address sendingAssetId;
        address receivingAssetId;
        uint256 fromAmount;
        bytes callData;
        bool requiresDeposit;
    }

    function startBridgeTokensViaGenericBridge(
        BridgeData calldata _bridgeData,
        bytes calldata _genericData
    ) external payable;

    function swapAndStartBridgeTokensViaGenericBridge(
        BridgeData calldata _bridgeData,
        SwapData[] calldata _swapData,
        bytes calldata _genericData
    ) external payable;
}

interface IRouterClient {
    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }

    struct EVM2AnyMessage {
        bytes receiver;
        bytes data;
        EVMTokenAmount[] tokenAmounts;
        address feeToken;
        bytes extraArgs;
    }

    function ccipSend(
        uint64 destinationChainSelector,
        EVM2AnyMessage calldata message
    ) external payable returns (bytes32 messageId);

    function getFee(
        uint64 destinationChainSelector,
        EVM2AnyMessage calldata message
    ) external view returns (uint256 fee);
}

interface ILiFiDiamond {
    function getQuote(
        address fromToken,
        address toToken,
        uint256 amount,
        uint256 fromChainId,
        uint256 toChainId
    ) external view returns (uint256 estimatedAmount, uint256 estimatedFee);
}

contract StablecoinSwitch is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    enum Priority {
        Cost,
        Speed
    }

    struct OptimalPath {
        uint256 fromChainId;
        uint256 toChainId;
        uint256 estimatedCost;
        uint256 estimatedTime;
        address bridge;
        string bridgeName;
    }

    struct ChainConfig {
        uint64 chainlinkSelector;
        bool supported;
        uint256 avgBlockTime;
    }

    struct BridgeConfig {
        address adapter;
        uint256 avgSettlementTime;
        uint256 baseFeeBps;
        bool active;
    }

    address public liFiDiamond;
    address public chainlinkRouter;

    mapping(uint256 => ChainConfig) public chainConfigs;
    mapping(string => BridgeConfig) public bridgeConfigs;

    uint256 public immutable currentChainId;
    uint256 public slippageBps = 100;
    uint256 public constant MAX_SLIPPAGE_BPS = 500;

    event TransactionRouted(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 toChainId,
        Priority priority,
        OptimalPath route,
        uint256 timestamp
    );

    event SettlementExecuted(
        address indexed token,
        uint256 amount,
        address indexed recipient,
        uint256 toChainId,
        string bridge,
        bytes32 txId,
        uint256 timestamp
    );

    event BridgeConfigured(
        string indexed bridgeName,
        address adapter,
        uint256 avgTime,
        uint256 baseFee
    );

    event ChainConfigured(
        uint256 indexed chainId,
        uint64 chainlinkSelector,
        uint256 avgBlockTime
    );

    event LiFiBridgeFailed(
        address indexed token,
        uint256 amount,
        address indexed recipient,
        string reason
    );

    event FallbackToChainlink(
        address indexed token,
        uint256 amount,
        address indexed recipient,
        uint256 toChainId
    );

    error InvalidAmount();
    error InvalidChainId();
    error InvalidToken();
    error InvalidPriority();
    error InvalidRecipient();
    error NoRouteAvailable();
    error InsufficientBalance();
    error TransferFailed();
    error BridgeNotConfigured();
    error BridgeFailed(string reason);
    error ChainNotSupported();
    error SlippageTooHigh();
    error InsufficientFee();

    constructor(address _liFiDiamond, address _chainlinkRouter) {
        currentChainId = block.chainid;
        liFiDiamond = _liFiDiamond;
        chainlinkRouter = _chainlinkRouter;

        _initializeChains();
        _initializeBridges();
    }

    function _initializeChains() internal {
        chainConfigs[1] = ChainConfig(5009297550715157269, true, 12);
        chainConfigs[42161] = ChainConfig(4949039107694359620, true, 1);
        chainConfigs[10] = ChainConfig(3734403246176062136, true, 2);
        chainConfigs[137] = ChainConfig(4051577828743386545, true, 2);
        chainConfigs[56] = ChainConfig(11344663589394136015, true, 3);
        chainConfigs[43114] = ChainConfig(6433500567565415381, true, 2);
        chainConfigs[8453] = ChainConfig(15971525489660198786, true, 2);
    }

    function _initializeBridges() internal {
        bridgeConfigs["lifi"] = BridgeConfig(address(0), 300, 10, true);
        bridgeConfigs["chainlink"] = BridgeConfig(address(0), 1200, 30, true);
        bridgeConfigs["stargate"] = BridgeConfig(address(0), 600, 15, false);
        bridgeConfigs["across"] = BridgeConfig(address(0), 180, 8, false);
    }

    function routeTransaction(
        address token,
        uint256 amount,
        uint256 toChainId,
        uint8 priority
    ) external payable nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (token == address(0)) revert InvalidToken();
        if (toChainId == currentChainId) revert InvalidChainId();
        if (priority > 1) revert InvalidPriority();
        if (!chainConfigs[toChainId].supported) revert ChainNotSupported();

        OptimalPath memory path = getOptimalPath(
            token,
            amount,
            toChainId,
            Priority(priority)
        );

        if (path.bridge == address(0)) revert NoRouteAvailable();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit TransactionRouted(
            msg.sender,
            token,
            amount,
            toChainId,
            Priority(priority),
            path,
            block.timestamp
        );

        _executeSettlementWithFallback(token, amount, msg.sender, toChainId);
    }

    function getOptimalPath(
        address token,
        uint256 amount,
        uint256 toChainId,
        Priority priority
    ) public view returns (OptimalPath memory) {
        if (!chainConfigs[toChainId].supported) {
            return OptimalPath(0, 0, 0, 0, address(0), "");
        }

        BridgeConfig memory lifiConfig = bridgeConfigs["lifi"];
        BridgeConfig memory chainlinkConfig = bridgeConfigs["chainlink"];

        uint256 lifiCost = _estimateLiFiCost(token, amount, toChainId);
        uint256 chainlinkCost = _estimateChainlinkCost(
            token,
            amount,
            toChainId
        );

        bool useLiFi;
        if (priority == Priority.Speed) {
            useLiFi =
                lifiConfig.active &&
                lifiConfig.avgSettlementTime <=
                chainlinkConfig.avgSettlementTime;
        } else {
            useLiFi = lifiConfig.active && lifiCost <= chainlinkCost;
        }

        if (useLiFi && lifiConfig.active) {
            return
                OptimalPath({
                    fromChainId: currentChainId,
                    toChainId: toChainId,
                    estimatedCost: lifiCost,
                    estimatedTime: lifiConfig.avgSettlementTime,
                    bridge: liFiDiamond,
                    bridgeName: "lifi"
                });
        } else if (chainlinkConfig.active) {
            return
                OptimalPath({
                    fromChainId: currentChainId,
                    toChainId: toChainId,
                    estimatedCost: chainlinkCost,
                    estimatedTime: chainlinkConfig.avgSettlementTime,
                    bridge: chainlinkRouter,
                    bridgeName: "chainlink"
                });
        }

        return OptimalPath(0, 0, 0, 0, address(0), "");
    }

    function _estimateLiFiCost(
        address token,
        uint256 amount,
        uint256 toChainId
    ) internal view returns (uint256) {
        BridgeConfig memory config = bridgeConfigs["lifi"];
        if (!config.active || liFiDiamond == address(0)) {
            return type(uint256).max;
        }

        uint256 baseFee = (amount * config.baseFeeBps) / 10000;
        return baseFee;
    }

    function _estimateChainlinkCost(
        address token,
        uint256 amount,
        uint256 toChainId
    ) internal view returns (uint256) {
        BridgeConfig memory config = bridgeConfigs["chainlink"];
        if (!config.active || chainlinkRouter == address(0)) {
            return type(uint256).max;
        }

        ChainConfig memory destChain = chainConfigs[toChainId];
        if (!destChain.supported) {
            return type(uint256).max;
        }

        try
            this._getChainlinkFee(
                token,
                amount,
                destChain.chainlinkSelector,
                msg.sender
            )
        returns (uint256 fee) {
            return fee;
        } catch {
            uint256 baseFee = (amount * config.baseFeeBps) / 10000;
            return baseFee;
        }
    }

    function _getChainlinkFee(
        address token,
        uint256 amount,
        uint64 destSelector,
        address recipient
    ) external view returns (uint256) {
        require(msg.sender == address(this), "Internal only");

        IRouterClient.EVMTokenAmount[]
            memory tokenAmounts = new IRouterClient.EVMTokenAmount[](1);
        tokenAmounts[0] = IRouterClient.EVMTokenAmount({
            token: token,
            amount: amount
        });

        IRouterClient.EVM2AnyMessage memory message = IRouterClient
            .EVM2AnyMessage({
                receiver: abi.encode(recipient),
                data: "",
                tokenAmounts: tokenAmounts,
                feeToken: address(0),
                extraArgs: _buildCCIPExtraArgs()
            });

        return IRouterClient(chainlinkRouter).getFee(destSelector, message);
    }

    function _executeSettlementWithFallback(
        address token,
        uint256 amount,
        address recipient,
        uint256 toChainId
    ) internal {
        bool lifiSuccess = false;
        bytes32 txId;

        if (liFiDiamond != address(0) && bridgeConfigs["lifi"].active) {
            try
                this._executeLiFiBridge(token, amount, recipient, toChainId)
            returns (bytes32 id) {
                lifiSuccess = true;
                txId = id;
                emit SettlementExecuted(
                    token,
                    amount,
                    recipient,
                    toChainId,
                    "lifi",
                    txId,
                    block.timestamp
                );
            } catch Error(string memory reason) {
                emit LiFiBridgeFailed(token, amount, recipient, reason);
            } catch {
                emit LiFiBridgeFailed(
                    token,
                    amount,
                    recipient,
                    "Unknown error"
                );
            }
        }

        if (!lifiSuccess) {
            if (
                chainlinkRouter == address(0) ||
                !bridgeConfigs["chainlink"].active
            ) {
                revert BridgeNotConfigured();
            }

            emit FallbackToChainlink(token, amount, recipient, toChainId);
            txId = _executeChainlinkBridge(token, amount, recipient, toChainId);

            emit SettlementExecuted(
                token,
                amount,
                recipient,
                toChainId,
                "chainlink",
                txId,
                block.timestamp
            );
        }
    }

    function _executeLiFiBridge(
        address token,
        uint256 amount,
        address recipient,
        uint256 toChainId
    ) external returns (bytes32) {
        require(msg.sender == address(this), "Internal only");
        if (liFiDiamond == address(0)) revert BridgeNotConfigured();

        IERC20(token).safeApprove(liFiDiamond, amount);

        bytes32 txId = keccak256(
            abi.encodePacked(recipient, amount, block.timestamp, currentChainId)
        );

        ILiFi.BridgeData memory bridgeData = ILiFi.BridgeData({
            transactionId: txId,
            bridge: "stargate",
            integrator: "StablecoinSwitch",
            referrer: address(0),
            sendingAssetId: token,
            receiver: recipient,
            minAmount: amount - ((amount * slippageBps) / 10000),
            destinationChainId: toChainId,
            hasSourceSwaps: false,
            hasDestinationCall: false
        });

        ILiFi(liFiDiamond).startBridgeTokensViaGenericBridge(bridgeData, "");

        return txId;
    }

    function _executeChainlinkBridge(
        address token,
        uint256 amount,
        address recipient,
        uint256 toChainId
    ) internal returns (bytes32) {
        if (chainlinkRouter == address(0)) revert BridgeNotConfigured();

        ChainConfig memory destChain = chainConfigs[toChainId];
        if (!destChain.supported) revert ChainNotSupported();

        IERC20(token).safeApprove(chainlinkRouter, amount);

        IRouterClient.EVMTokenAmount[]
            memory tokenAmounts = new IRouterClient.EVMTokenAmount[](1);
        tokenAmounts[0] = IRouterClient.EVMTokenAmount({
            token: token,
            amount: amount
        });

        IRouterClient.EVM2AnyMessage memory message = IRouterClient
            .EVM2AnyMessage({
                receiver: abi.encode(recipient),
                data: "",
                tokenAmounts: tokenAmounts,
                feeToken: address(0),
                extraArgs: _buildCCIPExtraArgs()
            });

        uint256 fee = IRouterClient(chainlinkRouter).getFee(
            destChain.chainlinkSelector,
            message
        );
        if (msg.value < fee) revert InsufficientFee();

        bytes32 messageId = IRouterClient(chainlinkRouter).ccipSend{value: fee}(
            destChain.chainlinkSelector,
            message
        );

        if (msg.value > fee) {
            payable(msg.sender).transfer(msg.value - fee);
        }

        return messageId;
    }

    function _buildCCIPExtraArgs() internal pure returns (bytes memory) {
        return abi.encodeWithSignature("_buildCCIPExtraArgs(uint256)", 200000);
    }

    function configureChain(
        uint256 chainId,
        uint64 chainlinkSelector,
        uint256 avgBlockTime,
        bool supported
    ) external onlyOwner {
        chainConfigs[chainId] = ChainConfig({
            chainlinkSelector: chainlinkSelector,
            supported: supported,
            avgBlockTime: avgBlockTime
        });

        emit ChainConfigured(chainId, chainlinkSelector, avgBlockTime);
    }

    function configureBridge(
        string calldata bridgeName,
        address adapter,
        uint256 avgSettlementTime,
        uint256 baseFeeBps,
        bool active
    ) external onlyOwner {
        bridgeConfigs[bridgeName] = BridgeConfig({
            adapter: adapter,
            avgSettlementTime: avgSettlementTime,
            baseFeeBps: baseFeeBps,
            active: active
        });

        emit BridgeConfigured(
            bridgeName,
            adapter,
            avgSettlementTime,
            baseFeeBps
        );
    }

    function setLiFiDiamond(address _liFiDiamond) external onlyOwner {
        liFiDiamond = _liFiDiamond;
    }

    function setChainlinkRouter(address _chainlinkRouter) external onlyOwner {
        chainlinkRouter = _chainlinkRouter;
    }

    function setSlippage(uint256 _slippageBps) external onlyOwner {
        if (_slippageBps > MAX_SLIPPAGE_BPS) revert SlippageTooHigh();
        slippageBps = _slippageBps;
    }

    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    function emergencyWithdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
