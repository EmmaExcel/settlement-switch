// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/SettlementSwitch.sol";
import "../src/interfaces/IBridgeAdapter.sol";

contract BridgeETHMainnetScript is Script {
    // Chain IDs
    uint256 constant ARBITRUM_ONE = 42161;
    uint256 constant ETHEREUM_MAINNET = 1;

    // ETH address (0x0 represents native ETH)
    address constant ETH_ADDRESS = address(0);

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address settlementSwitchAddr = vm.envAddress("SETTLEMENT_SWITCH_ADDRESS");
        uint256 amountToBridge = vm.envUint("BRIDGE_AMOUNT_WEI");
        uint256 nativeFeeWei = vm.envUint("LZ_NATIVE_FEE_WEI");

        address recipient = vm.envOr({name: "RECIPIENT", defaultValue: address(0)});
        if (recipient == address(0)) {
            recipient = vm.addr(privateKey);
        }

        console.log("Bridging ETH from Arbitrum One to Ethereum Mainnet");
        console.log("SettlementSwitch:", settlementSwitchAddr);
        console.log("Sender:", vm.addr(privateKey));
        console.log("Recipient:", recipient);
        console.log("Amount:", amountToBridge);
        console.log("Native fee (LZ):", nativeFeeWei);

        vm.startBroadcast(privateKey);

        SettlementSwitch settlementSwitch = SettlementSwitch(payable(settlementSwitchAddr));

        // Route preferences
        IBridgeAdapter.RoutePreferences memory prefs = IBridgeAdapter.RoutePreferences({
            mode: IBridgeAdapter.RoutingMode.FASTEST,
            maxSlippageBps: 100, // 1%
            maxFeeWei: nativeFeeWei,
            maxTimeMinutes: 45,
            allowMultiHop: false
        });

        // Supply value = amount + LayerZero native fee
        bytes32 transferId = settlementSwitch.bridgeWithAutoRoute{value: amountToBridge + nativeFeeWei}(
            ETH_ADDRESS,
            ETH_ADDRESS,
            amountToBridge,
            ARBITRUM_ONE,
            ETHEREUM_MAINNET,
            recipient,
            prefs,
            ""
        );

        console.log("Bridge transfer initiated. Transfer ID:", vm.toString(transferId));
        vm.stopBroadcast();
    }
}

