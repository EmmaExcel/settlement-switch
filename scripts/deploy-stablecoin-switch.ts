import { ethers } from "hardhat";

async function main() {
  // Deploy the StablecoinSwitch contract
  const StablecoinSwitch = await ethers.getContractFactory("StablecoinSwitch");
  const stablecoinSwitch = await StablecoinSwitch.deploy();
  await stablecoinSwitch.waitForDeployment();

  console.log("StablecoinSwitch deployed to:", await stablecoinSwitch.getAddress());


  /*
  await stablecoinSwitch.updateMockRoute(
    42161,    // Arbitrum One chain ID
    50,       // 0.5% fee
    60,       // 1 minute speed
    true      // Active
  );
  
  // Set up bridge adapters after deployment
  // await stablecoinSwitch.setLiFiRouter("0x123...");
  // await stablecoinSwitch.setChainlinkRouter("0x456...");
  */
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
