import { expect } from "chai";
import { ethers } from "hardhat";
import { 
  loadFixture,
  time 
} from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { 
  VerixToken,
  VerixGasPool,
  VerixGasOracle,
  VerixRelayer,
  VerixMetaTransaction
} from "../../typechain-types";

describe("Verix Gas System", function () {
  async function deployGasSystemFixture() {
    const [owner, admin, operator, user1, user2] = await ethers.getSigners();

    // Deploy Token
    const VerixToken = await ethers.getContractFactory("VerixToken");
    const token = await VerixToken.deploy();

    // Deploy Oracle with mock price feeds
    const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
    const maticUsdFeed = await MockPriceFeed.deploy(8, 100000000); // $1.00 MATIC/USD
    const gasWeiFeed = await MockPriceFeed.deploy(8, 50000000000); // 50 Gwei

    const VerixGasOracle = await ethers.getContractFactory("VerixGasOracle");
    const oracle = await VerixGasOracle.deploy(
      maticUsdFeed.address,
      gasWeiFeed.address
    );

    // Deploy Gas Pool
    const VerixGasPool = await ethers.getContractFactory("VerixGasPool");
    const gasPool = await VerixGasPool.deploy(
      token.address,
      oracle.address,
      admin.address
    );

    // Deploy Relayer
    const VerixRelayer = await ethers.getContractFactory("VerixRelayer");
    const relayer = await VerixRelayer.deploy(
      gasPool.address,
      oracle.address,
      ethers.utils.parseEther("1"), // 1 MATIC min balance
      86400 // 24 hour timeout
    );

    // Deploy Meta Transaction Handler
    const VerixMetaTransaction = await ethers.getContractFactory("VerixMetaTransaction");
    const metaTx = await VerixMetaTransaction.deploy();

    // Setup roles and initial state
    await gasPool.grantRole(await gasPool.OPERATOR_ROLE(), operator.address);
    await gasPool.connect(admin).replenishPool({ value: ethers.utils.parseEther("10") });

    // Transfer some tokens to test users
    await token.transfer(user1.address, ethers.utils.parseEther("5000")); // Standard tier
    await token.transfer(user2.address, ethers.utils.parseEther("10000")); // Premium tier

    return { 
      token, 
      oracle, 
      gasPool, 
      relayer, 
      metaTx,
      owner, 
      admin, 
      operator, 
      user1, 
      user2 
    };
  }

  describe("Gas Oracle", function () {
    it("Should update prices correctly", async function () {
      const { oracle } = await loadFixture(deployGasSystemFixture);
      await oracle.updatePrices();
      
      const gasPrice = await oracle.gasPrice();
      const maticPrice = await oracle.maticUsdPrice();
      
      expect(gasPrice).to.be.gt(0);
      expect(maticPrice).to.be.gt(0);
    });

    it("Should calculate gas costs accurately", async function () {
      const { oracle } = await loadFixture(deployGasSystemFixture);
      const gasAmount = 100000; // 100k gas
      
      const cost = await oracle.calculateGasCost(gasAmount);
      expect(cost).to.be.gt(0);
    });
  });

  describe("Gas Pool", function () {
    it("Should update user tiers correctly", async function () {
      const { gasPool, user1, user2 } = await loadFixture(deployGasSystemFixture);
      
      await gasPool.updateUserTier(user1.address);
      await gasPool.updateUserTier(user2.address);

      const tier1 = await gasPool.userTier(user1.address);
      const tier2 = await gasPool.userTier(user2.address);

      expect(tier1).to.equal(2); // Standard tier
      expect(tier2).to.equal(3); // Premium tier
    });

    it("Should cover gas fees according to tier", async function () {
      const { gasPool, operator, user1, user2 } = await loadFixture(deployGasSystemFixture);
      const gasAmount = ethers.utils.parseEther("0.1"); // 0.1 MATIC worth of gas

      await gasPool.connect(operator).coverGasFee(user1.address, gasAmount);
      await gasPool.connect(operator).coverGasFee(user2.address, gasAmount);

      const usage1 = await gasPool.userGasUsage(user1.address);
      const usage2 = await gasPool.userGasUsage(user2.address);

      expect(usage1.totalLifetimeUsed).to.be.lt(gasAmount); // 75% coverage
      expect(usage2.totalLifetimeUsed).to.equal(gasAmount); // 100% coverage
    });

    it("Should enforce daily gas limits", async function () {
      const { gasPool, operator, user1 } = await loadFixture(deployGasSystemFixture);
      const tier = await gasPool.userTier(user1.address);
      const { maxDailyGas } = await gasPool.tiers(tier);

      // Try to use more than daily limit
      await expect(
        gasPool.connect(operator).coverGasFee(user1.address, maxDailyGas.add(1))
      ).to.be.revertedWith("Daily gas limit exceeded");
    });
  });

  describe("Relayer", function () {
    it("Should register new relayer", async function () {
      const { relayer, operator } = await loadFixture(deployGasSystemFixture);
      
      await relayer.connect(operator).registerRelayer({
        value: ethers.utils.parseEther("1")
      });

      const relayerInfo = await relayer.getRelayerStatus(operator.address);
      expect(relayerInfo.isActive).to.be.true;
    });

    it("Should execute relay requests", async function () {
      const { relayer, gasPool, operator, user1 } = await loadFixture(deployGasSystemFixture);
      
      // Register relayer
      await relayer.connect(operator).registerRelayer({
        value: ethers.utils.parseEther("1")
      });

      // Create relay request
      const request = {
        user: user1.address,
        gasAmount: ethers.utils.parseEther("0.1"),
        nonce: 0,
        expiryTime: Math.floor(Date.now() / 1000) + 3600,
        signature: "0x" // Would need actual signature in production
      };

      // Execute relay
      await expect(
        relayer.connect(operator).executeRelay(request)
      ).to.emit(relayer, "RelayExecuted");
    });
  });

  describe("Meta Transactions", function () {
    it("Should execute meta transactions", async function () {
      const { metaTx, token, user1, user2 } = await loadFixture(deployGasSystemFixture);
      
      // Create transfer function signature
      const transferData = token.interface.encodeFunctionData("transfer", [
        user2.address,
        ethers.utils.parseEther("1")
      ]);

      // Create and sign meta transaction
      const nonce = await metaTx.getNonce(user1.address);
      const { v, r, s } = await getMetaTxSignature(
        user1,
        nonce,
        transferData,
        metaTx.address
      );

      await expect(
        metaTx.executeMetaTransaction(
          user1.address,
          transferData,
          r,
          s,
          v
        )
      ).to.emit(metaTx, "MetaTransactionExecuted");
    });
  });

  describe("Integration Tests", function () {
    it("Should handle complete gas coverage flow", async function () {
      const { 
        token,
        gasPool,
        relayer,
        operator,
        user1
      } = await loadFixture(deployGasSystemFixture);

      // Update user tier
      await gasPool.updateUserTier(user1.address);

      // Register relayer
      await relayer.connect(operator).registerRelayer({
        value: ethers.utils.parseEther("1")
      });

      // Create and execute relay request
      const request = {
        user: user1.address,
        gasAmount: ethers.utils.parseEther("0.1"),
        nonce: 0,
        expiryTime: Math.floor(Date.now() / 1000) + 3600,
        signature: "0x" // Would need actual signature in production
      };

      await expect(
        relayer.connect(operator).executeRelay(request)
      ).to.emit(relayer, "RelayExecuted")
        .and.to.emit(gasPool, "GasCovered");
    });
  });
});

// Helper function to generate meta transaction signature
async function getMetaTxSignature(
  signer: SignerWithAddress,
  nonce: BigNumber,
  functionData: string,
  verifyingContract: string
): Promise<{ v: number; r: string; s: string }> {
  const domain = {
    name: "Verix Protocol",
    version: "1",
    chainId: await signer.getChainId(),
    verifyingContract
  };

  const types = {
    MetaTransaction: [
      { name: "nonce", type: "uint256" },
      { name: "from", type: "address" },
      { name: "functionSignature", type: "bytes" }
    ]
  };

  const value = {
    nonce: nonce,
    from: signer.address,
    functionSignature: functionData
  };

  const signature = await signer._signTypedData(domain, types, value);
  return ethers.utils.splitSignature(signature);
}
