// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {StablecoinSwitch} from "../src/StablecoinSwitch.sol";

/**
 * Configure StablecoinSwitch for Arbitrum Sepolia:
 * - Enables chain support for `421614`
 * - Adds the ArbitrumBridgeAdapter for that chain with name and gas cost
 *
 * Usage:
 *   SWITCH_ADDRESS=0xc16a01431b1d980b0df125df4d8df4633c4d5ba0 \
 *   ADAPTER_ADDRESS=0xYourArbitrumBridgeAdapterOnL1 \
 *   GAS_COST=0 \
 *   forge script contract/script/ConfigureStablecoinSwitch.s.sol:ConfigureStablecoinSwitch \
 *     --rpc-url https://ethereum-sepolia-rpc.publicnode.com \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast
 */
contract ConfigureStablecoinSwitch is Script {
    uint256 constant DEST_CHAIN_ID = 421614; // Arbitrum Sepolia

    function run() external {
        address switchAddr = vm.envAddress("SWITCH_ADDRESS");
        address adapter;
        uint256 gasCost = _getGasCost();

        // ADAPTER_ADDRESS is optional; if not set, we only enable chain support
        try vm.envAddress("ADAPTER_ADDRESS") returns (address a) {
            adapter = a;
        } catch {
            adapter = address(0);
        }

        require(switchAddr != address(0), "SWITCH_ADDRESS missing");

        StablecoinSwitch stablecoinSwitch = StablecoinSwitch(payable(switchAddr));

        console2.log("Configuring StablecoinSwitch:", switchAddr);
        console2.log("Dest Chain:", DEST_CHAIN_ID);
        if (adapter != address(0)) {
            console2.log("Adapter:", adapter);
            console2.log("Gas Cost:", gasCost);
        } else {
            console2.log("No ADAPTER_ADDRESS provided; enabling chain support only");
        }

        vm.startBroadcast();
        // Enable destination chain support
        stablecoinSwitch.setChainSupport(DEST_CHAIN_ID, true);
        // Conditionally add bridge adapter if provided
        if (adapter != address(0)) {
            stablecoinSwitch.addBridgeAdapter(DEST_CHAIN_ID, adapter, "Arbitrum", gasCost);
        }
        vm.stopBroadcast();

        console2.log("Configuration complete.");
    }

    function _getGasCost() internal view returns (uint256) {
        // GAS_COST is optional; defaults to 0
        try vm.envUint("GAS_COST") returns (uint256 v) {
            return v;
        } catch {
            return 0;
        }
    }
}