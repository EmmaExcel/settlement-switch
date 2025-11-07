// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IStargateRouter.sol";

interface IStargateRouterETH {
    function swapETH(
        uint16 _dstChainId,
        address _refundAddress,
        bytes calldata _toAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        IStargateRouter.LzTxObj calldata _lzTxParams
    ) external payable;
}

