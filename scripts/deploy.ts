import { ethers } from "hardhat";

async function main() {
  const tokenAddress = process.env.USDC_TOKEN_ADDRESS || ethers.ZeroAddress;

  if (!process.env.USDC_TOKEN_ADDRESS) {
    console.warn("USDC_TOKEN_ADDRESS not set. Using zero address; deployment will succeed but interactions will fail.");
  }

  const Vault = await ethers.getContractFactory("LiquidityVault");
  const vault = await Vault.deploy(tokenAddress);
  await vault.waitForDeployment();

  console.log("LiquidityVault deployed to:", await vault.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});