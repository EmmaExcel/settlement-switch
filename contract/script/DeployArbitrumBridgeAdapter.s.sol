// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {ArbitrumBridgeAdapter} from "../src/ArbitrumBridgeAdapter.sol";

/**
 * @title DeployArbitrumBridgeAdapter
 * @dev Minimal script to deploy ArbitrumBridgeAdapter on Ethereum Sepolia (L1)
 * @notice Uses the CLI `--private-key` for broadcasting; constructor owner is `msg.sender`
 *
 * Usage:
 *   forge script contract/script/DeployArbitrumBridgeAdapter.s.sol:DeployArbitrumBridgeAdapter \
 *     --rpc-url https://ethereum-sepolia-rpc.publicnode.com \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast
 */
contract DeployArbitrumBridgeAdapter is Script {
    function run() external {
        console2.log("Deploying ArbitrumBridgeAdapter...");

        vm.startBroadcast();
        address owner = msg.sender;
        ArbitrumBridgeAdapter adapter = new ArbitrumBridgeAdapter(owner);
        vm.stopBroadcast();

        console2.log("ArbitrumBridgeAdapter deployed at:", address(adapter));
        console2.log("Owner:", owner);
    }
}