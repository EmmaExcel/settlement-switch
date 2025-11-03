// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/FeeManager.sol";

contract GrantFeeManagerRole is Script {
    // Contract addresses
    address payable constant FEE_MANAGER = payable(0x4D4f731416Ad43523441887ee49Ccd8bea78ac5f);
    address constant SETTLEMENT_SWITCH = 0x9a87668fADc9AD2D67698708E7c827Ff1D66435B;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Granting FEE_MANAGER_ROLE to Settlement Switch...");
        console.log("FeeManager:", FEE_MANAGER);
        console.log("Settlement Switch:", SETTLEMENT_SWITCH);
        
        vm.startBroadcast(deployerPrivateKey);
        
        FeeManager feeManager = FeeManager(FEE_MANAGER);
        
        // Grant FEE_MANAGER_ROLE to Settlement Switch
        bytes32 feeManagerRole = feeManager.FEE_MANAGER_ROLE();
        console.log("FEE_MANAGER_ROLE:", vm.toString(feeManagerRole));
        
        feeManager.grantRole(feeManagerRole, SETTLEMENT_SWITCH);
        
        console.log("FEE_MANAGER_ROLE granted successfully!");
        
        // Verify the role was granted
        bool hasRole = feeManager.hasRole(feeManagerRole, SETTLEMENT_SWITCH);
        console.log("Settlement Switch has FEE_MANAGER_ROLE:", hasRole);
        
        vm.stopBroadcast();
    }
}