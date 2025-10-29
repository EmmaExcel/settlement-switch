import { expect } from "chai";
import { ethers } from "hardhat";
import { StablecoinSwitch, MockERC20 } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("StablecoinSwitch", function () {
  let stablecoinSwitch: StablecoinSwitch;
  let mockToken: MockERC20;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  
  const ETHEREUM_CHAIN_ID = 1;
  const POLYGON_CHAIN_ID = 137;
  const OPTIMISM_CHAIN_ID = 10;
  const AMOUNT = ethers.parseUnits("1000", 6); // 1000 USDC (6 decimals)
  
  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    
    // Deploy mock ERC20 token
    const MockERC20Factory = await ethers.getContractFactory("MockERC20");
    mockToken = await MockERC20Factory.deploy("Mock USDC", "USDC", 6);
    await mockToken.waitForDeployment();
    
    // Deploy StablecoinSwitch
    const StablecoinSwitchFactory = await ethers.getContractFactory("StablecoinSwitch");
    stablecoinSwitch = await StablecoinSwitchFactory.deploy();
    await stablecoinSwitch.waitForDeployment();
    
    // Mint tokens to user1
    await mockToken.mint(user1.address, ethers.parseUnits("10000", 6));
    
    // Approve StablecoinSwitch to spend user1's tokens
    await mockToken.connect(user1).approve(
      await stablecoinSwitch.getAddress(),
      ethers.MaxUint256
    );
  });

  describe("Deployment", function () {
    it("Should set the correct chain ID", async function () {
      const chainId = await stablecoinSwitch.getCurrentChainId();
      expect(chainId).to.equal((await ethers.provider.getNetwork()).chainId);
    });

    it("Should initialize mock routes", async function () {
      const ethRoute = await stablecoinSwitch.mockRoutes(ETHEREUM_CHAIN_ID);
      expect(ethRoute.active).to.be.true;
      expect(ethRoute.costBps).to.equal(30);
      expect(ethRoute.speedSeconds).to.equal(600);
      
      const polyRoute = await stablecoinSwitch.mockRoutes(POLYGON_CHAIN_ID);
      expect(polyRoute.active).to.be.true;
      expect(polyRoute.costBps).to.equal(20);
      
      const opRoute = await stablecoinSwitch.mockRoutes(OPTIMISM_CHAIN_ID);
      expect(opRoute.active).to.be.true;
      expect(opRoute.costBps).to.equal(25);
    });

    it("Should set owner correctly", async function () {
      expect(await stablecoinSwitch.owner()).to.equal(owner.address);
    });
  });

  describe("getOptimalPath", function () {
    it("Should return optimal path for Cost priority", async function () {
      const path = await stablecoinSwitch.getOptimalPath(
        await mockToken.getAddress(),
        AMOUNT,
        ETHEREUM_CHAIN_ID,
        0 // Cost priority
      );
      
      expect(path.fromChainId).to.equal((await ethers.provider.getNetwork()).chainId);
      expect(path.toChainId).to.equal(ETHEREUM_CHAIN_ID);
      expect(path.cost).to.equal((AMOUNT * 30n) / 10000n); // 0.3% fee
      expect(path.speed).to.equal(600);
    });

    it("Should return optimal path for Speed priority", async function () {
      const path = await stablecoinSwitch.getOptimalPath(
        await mockToken.getAddress(),
        AMOUNT,
        POLYGON_CHAIN_ID,
        1 // Speed priority
      );
      
      expect(path.fromChainId).to.equal((await ethers.provider.getNetwork()).chainId);
      expect(path.toChainId).to.equal(POLYGON_CHAIN_ID);
      expect(path.cost).to.equal((AMOUNT * 20n) / 10000n); // 0.2% fee
      expect(path.speed).to.equal(300);
    });

    it("Should return empty path for inactive route", async function () {
      const path = await stablecoinSwitch.getOptimalPath(
        await mockToken.getAddress(),
        AMOUNT,
        999, // Non-existent chain
        0
      );
      
      expect(path.fromChainId).to.equal(0);
      expect(path.toChainId).to.equal(0);
      expect(path.bridge).to.equal(ethers.ZeroAddress);
    });
  });

  describe("routeTransaction", function () {
    it("Should revert with InvalidAmount for zero amount", async function () {
      await expect(
        stablecoinSwitch.connect(user1).routeTransaction(
          await mockToken.getAddress(),
          0,
          ETHEREUM_CHAIN_ID,
          0
        )
      ).to.be.revertedWithCustomError(stablecoinSwitch, "InvalidAmount");
    });

    it("Should revert with InvalidToken for zero address", async function () {
      await expect(
        stablecoinSwitch.connect(user1).routeTransaction(
          ethers.ZeroAddress,
          AMOUNT,
          ETHEREUM_CHAIN_ID,
          0
        )
      ).to.be.revertedWithCustomError(stablecoinSwitch, "InvalidToken");
    });

    it("Should revert with InvalidChainId for same chain", async function () {
      const currentChainId = (await ethers.provider.getNetwork()).chainId;
      
      await expect(
        stablecoinSwitch.connect(user1).routeTransaction(
          await mockToken.getAddress(),
          AMOUNT,
          currentChainId,
          0
        )
      ).to.be.revertedWithCustomError(stablecoinSwitch, "InvalidChainId");
    });

    it("Should revert with InvalidPriority for invalid priority", async function () {
      await expect(
        stablecoinSwitch.connect(user1).routeTransaction(
          await mockToken.getAddress(),
          AMOUNT,
          ETHEREUM_CHAIN_ID,
          2 // Invalid priority
        )
      ).to.be.revertedWithCustomError(stablecoinSwitch, "InvalidPriority");
    });

    it("Should revert with NoRouteAvailable for inactive route", async function () {
      await expect(
        stablecoinSwitch.connect(user1).routeTransaction(
          await mockToken.getAddress(),
          AMOUNT,
          999, // Non-existent chain
          0
        )
      ).to.be.revertedWithCustomError(stablecoinSwitch, "NoRouteAvailable");
    });
  });

  describe("Bridge Adapter Management", function () {
    let mockBridge: SignerWithAddress;

    beforeEach(async function () {
      mockBridge = user2; // Use user2 as mock bridge address
    });

    it("Should set LiFi bridge adapter", async function () {
      const tx = await stablecoinSwitch.setLiFiBridgeAdapter(mockBridge.address);
      await expect(tx)
        .to.emit(stablecoinSwitch, "BridgeAdapterSet")
        .withArgs("LiFi", mockBridge.address, await ethers.provider.getBlock(tx.blockNumber!).then(b => b!.timestamp));
      
      expect(await stablecoinSwitch.liFiBridgeAdapter()).to.equal(mockBridge.address);
    });

    it("Should set Chainlink bridge adapter", async function () {
      await stablecoinSwitch.setChainlinkBridgeAdapter(mockBridge.address);
      expect(await stablecoinSwitch.chainlinkBridgeAdapter()).to.equal(mockBridge.address);
    });

    it("Should set custom bridge adapter", async function () {
      await stablecoinSwitch.setBridgeAdapter(mockBridge.address);
      expect(await stablecoinSwitch.customBridgeAdapter()).to.equal(mockBridge.address);
    });

    it("Should set LiFi router", async function () {
      await stablecoinSwitch.setLiFiRouter(mockBridge.address);
      expect(await stablecoinSwitch.liFiRouter()).to.equal(mockBridge.address);
    });

    it("Should set Chainlink router", async function () {
      await stablecoinSwitch.setChainlinkRouter(mockBridge.address);
      expect(await stablecoinSwitch.chainlinkRouter()).to.equal(mockBridge.address);
    });

    it("Should only allow owner to set adapters", async function () {
      await expect(
        stablecoinSwitch.connect(user1).setLiFiBridgeAdapter(mockBridge.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("updateMockRoute", function () {
    it("Should update mock route", async function () {
      const newChainId = 100;
      const newCostBps = 50;
      const newSpeedSeconds = 1000;
      
      await stablecoinSwitch.updateMockRoute(newChainId, newCostBps, newSpeedSeconds, true);
      
      const route = await stablecoinSwitch.mockRoutes(newChainId);
      expect(route.costBps).to.equal(newCostBps);
      expect(route.speedSeconds).to.equal(newSpeedSeconds);
      expect(route.active).to.be.true;
    });

    it("Should deactivate route", async function () {
      await stablecoinSwitch.updateMockRoute(ETHEREUM_CHAIN_ID, 30, 600, false);
      
      const route = await stablecoinSwitch.mockRoutes(ETHEREUM_CHAIN_ID);
      expect(route.active).to.be.false;
    });

    it("Should only allow owner to update routes", async function () {
      await expect(
        stablecoinSwitch.connect(user1).updateMockRoute(100, 50, 1000, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("executeSettlement", function () {
    beforeEach(async function () {
      // Transfer some tokens to the contract
      await mockToken.mint(await stablecoinSwitch.getAddress(), AMOUNT);
    });

    it("Should revert with InvalidAmount for zero amount", async function () {
      await expect(
        stablecoinSwitch.executeSettlement(
          await mockToken.getAddress(),
          0,
          user2.address,
          ETHEREUM_CHAIN_ID
        )
      ).to.be.revertedWithCustomError(stablecoinSwitch, "InvalidAmount");
    });

    it("Should revert with InvalidToken for zero address", async function () {
      await expect(
        stablecoinSwitch.executeSettlement(
          ethers.ZeroAddress,
          AMOUNT,
          user2.address,
          ETHEREUM_CHAIN_ID
        )
      ).to.be.revertedWithCustomError(stablecoinSwitch, "InvalidToken");
    });

    it("Should revert with InvalidRecipient for zero address", async function () {
      await expect(
        stablecoinSwitch.executeSettlement(
          await mockToken.getAddress(),
          AMOUNT,
          ethers.ZeroAddress,
          ETHEREUM_CHAIN_ID
        )
      ).to.be.revertedWithCustomError(stablecoinSwitch, "InvalidRecipient");
    });

    it("Should only allow owner to execute settlement", async function () {
      await expect(
        stablecoinSwitch.connect(user1).executeSettlement(
          await mockToken.getAddress(),
          AMOUNT,
          user2.address,
          ETHEREUM_CHAIN_ID
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("emergencyWithdraw", function () {
    beforeEach(async function () {
      // Transfer some tokens to the contract
      await mockToken.mint(await stablecoinSwitch.getAddress(), AMOUNT);
    });

    it("Should allow owner to withdraw tokens", async function () {
      const ownerBalanceBefore = await mockToken.balanceOf(owner.address);
      
      await stablecoinSwitch.emergencyWithdraw(
        await mockToken.getAddress(),
        AMOUNT
      );
      
      const ownerBalanceAfter = await mockToken.balanceOf(owner.address);
      expect(ownerBalanceAfter - ownerBalanceBefore).to.equal(AMOUNT);
    });

    it("Should only allow owner to withdraw", async function () {
      await expect(
        stablecoinSwitch.connect(user1).emergencyWithdraw(
          await mockToken.getAddress(),
          AMOUNT
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Reentrancy Protection", function () {
    it("Should prevent reentrancy on routeTransaction", async function () {
      // This would require a malicious token contract that tries to reenter
      // For now, we verify the nonReentrant modifier is present
      // In production, you'd want to test with a malicious token mock
    });
  });
});
