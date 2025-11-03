// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/core/SettlementSwitch.sol";
import "../src/core/RouteCalculator.sol";
import "../src/core/BridgeRegistry.sol";
import "../src/core/FeeManager.sol";

/**
 * @title SimpleDeploy
 * @notice Simplified deployment script for core contracts only
 */
contract SimpleDeploy is Script {
    
    struct DeployedContracts {
        SettlementSwitch settlementSwitch;
        RouteCalculator routeCalculator;
        BridgeRegistry bridgeRegistry;
        FeeManager feeManager;
    }

    function run() external {
        uint256 chainId = block.chainid;
        address admin = vm.envAddress("ADMIN_ADDRESS_TESTNET");
        address treasury = vm.envAddress("TREASURY_ADDRESS_TESTNET");
        
        console.log("Deploying to chain ID:", chainId);
        console.log("Admin:", admin);
        console.log("Treasury:", treasury);

        vm.startBroadcast();

        DeployedContracts memory deployed = _deployCore(admin, treasury);
        
        vm.stopBroadcast();

        _logDeployment(deployed, chainId);
    }

    function _deployCore(address admin, address treasury) internal returns (DeployedContracts memory deployed) {
        console.log("Deploying core contracts...");

        // Deploy RouteCalculator
        deployed.routeCalculator = new RouteCalculator();
        console.log("RouteCalculator deployed at:", address(deployed.routeCalculator));

        // Deploy BridgeRegistry
        deployed.bridgeRegistry = new BridgeRegistry(admin);
        console.log("BridgeRegistry deployed at:", address(deployed.bridgeRegistry));

        // Deploy FeeManager
        deployed.feeManager = new FeeManager(admin, treasury);
        console.log("FeeManager deployed at:", address(deployed.feeManager));

        // Deploy SettlementSwitch
        deployed.settlementSwitch = new SettlementSwitch(
            admin,
            address(deployed.routeCalculator),
            address(deployed.bridgeRegistry),
            payable(address(deployed.feeManager))
        );
        console.log("SettlementSwitch deployed at:", address(deployed.settlementSwitch));

        return deployed;
    }

    function _logDeployment(DeployedContracts memory deployed, uint256 chainId) internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Chain ID:", chainId);
        console.log("RouteCalculator:", address(deployed.routeCalculator));
        console.log("BridgeRegistry:", address(deployed.bridgeRegistry));
        console.log("FeeManager:", address(deployed.feeManager));
        console.log("SettlementSwitch:", address(deployed.settlementSwitch));
        console.log("========================\n");
    }
}