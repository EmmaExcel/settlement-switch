// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/core/SettlementSwitch.sol";
import "../src/core/RouteCalculator.sol";
import "../src/core/BridgeRegistry.sol";
import "../src/core/FeeManager.sol";

/**
 * @title OptimizedDeploy
 * @notice Gas-optimized deployment script with CREATE2 for deterministic addresses
 */
contract OptimizedDeploy is Script {
    
    // Use CREATE2 salt for deterministic addresses
    bytes32 constant SALT = keccak256("SettlementSwitch_v1.1");
    
    function run() external {
        uint256 chainId = block.chainid;
        address admin;
        address treasury;

        // Use mainnet admin/treasury when deploying to Arbitrum One
        if (chainId == 42161) {
            admin = vm.envAddress("ADMIN_ADDRESS_MAINNET");
            treasury = vm.envAddress("TREASURY_ADDRESS_MAINNET");
        } else {
            admin = vm.envAddress("ADMIN_ADDRESS_TESTNET");
            treasury = vm.envAddress("TREASURY_ADDRESS_TESTNET");
        }
        
        console.log("Optimized deployment to chain ID:", chainId);

        // Broadcast using the configured PRIVATE_KEY to avoid Foundry default sender
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Deploy RouteCalculator with direct deployment so owner = EOA
        RouteCalculator rc = new RouteCalculator();
        address routeCalculator = address(rc);
        
        address bridgeRegistry = _deployWithCreate2(
            abi.encodePacked(
                type(BridgeRegistry).creationCode,
                abi.encode(admin)
            ),
            SALT
        );
        
        address feeManager = _deployWithCreate2(
            abi.encodePacked(
                type(FeeManager).creationCode,
                abi.encode(admin, treasury)
            ),
            SALT
        );
        
        address settlementSwitch = _deployWithCreate2(
            abi.encodePacked(
                type(SettlementSwitch).creationCode,
                abi.encode(admin, routeCalculator, bridgeRegistry, feeManager)
            ),
            SALT
        );
        
        vm.stopBroadcast();

        // Log deployment
        console.log("RouteCalculator:", routeCalculator);
        console.log("BridgeRegistry:", bridgeRegistry);
        console.log("FeeManager:", feeManager);
        console.log("SettlementSwitch:", settlementSwitch);
    }

    function _deployWithCreate2(bytes memory bytecode, bytes32 salt) internal returns (address) {
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(deployed != address(0), "CREATE2 deployment failed");
        return deployed;
    }
}
