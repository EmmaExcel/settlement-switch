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
    bytes32 constant SALT = keccak256("SettlementSwitch_v1.0");
    
    function run() external {
        uint256 chainId = block.chainid;
        address admin = vm.envAddress("ADMIN_ADDRESS_TESTNET");
        address treasury = vm.envAddress("TREASURY_ADDRESS_TESTNET");
        
        console.log("Optimized deployment to chain ID:", chainId);

        vm.startBroadcast();

        // Deploy with CREATE2 for gas efficiency
        address routeCalculator = _deployWithCreate2(
            type(RouteCalculator).creationCode,
            SALT
        );
        
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