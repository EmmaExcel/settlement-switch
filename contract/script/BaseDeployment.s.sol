// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title BaseDeployment
 * @dev Base contract for deployment scripts with common functionality
 */
abstract contract BaseDeployment is Script {
    // Common deployment configuration
    struct DeploymentConfig {
        address deployer;
        uint256 chainId;
        bool isTestnet;
        string networkName;
    }
    
    DeploymentConfig public config;
    
    // Events
    event ContractDeployed(string name, address addr, uint256 chainId);
    event DeploymentCompleted(uint256 chainId, uint256 gasUsed);
    
    modifier onlyValidChain() {
        require(block.chainid > 0, "Invalid chain ID");
        _;
    }
    
    function setUp() public virtual {
        config.deployer = msg.sender;
        config.chainId = block.chainid;
        config.isTestnet = _isTestnet(config.chainId);
        config.networkName = _getNetworkName(config.chainId);
        
        console.log("Setting up deployment on", config.networkName);
        console.log("Chain ID:", config.chainId);
        console.log("Deployer:", config.deployer);
    }
    
    function run() public virtual;
    
    function _isTestnet(uint256 chainId) internal pure returns (bool) {
        return chainId == 11155111 || // Sepolia
               chainId == 421614 ||   // Arbitrum Sepolia
               chainId == 5 ||        // Goerli (deprecated)
               chainId == 80001;      // Mumbai
    }
    
    function _getNetworkName(uint256 chainId) internal pure virtual returns (string memory) {
        if (chainId == 1) return "Ethereum Mainnet";
        if (chainId == 11155111) return "Sepolia";
        if (chainId == 42161) return "Arbitrum One";
        if (chainId == 421614) return "Arbitrum Sepolia";
        if (chainId == 137) return "Polygon";
        if (chainId == 80001) return "Mumbai";
        return "Unknown Network";
    }
    
    function _logDeployment(string memory name, address addr) internal {
        console.log(string(abi.encodePacked("Deployed ", name, " at:")), addr);
        emit ContractDeployed(name, addr, config.chainId);
    }
    
    function _verifyContract(address contractAddr, bytes memory constructorArgs) internal {
        if (!config.isTestnet) {
            console.log("Contract verification needed for mainnet deployment");
            console.log("Address:", contractAddr);
            // Note: Actual verification would be done via forge verify command
        }
    }
}