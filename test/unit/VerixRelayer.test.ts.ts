import { expect } from "chai";
import { ethers } from "hardhat";
import { 
  loadFixture,
  time 
} from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { 
  VerixRelayer,
  VerixGasPool,
  VerixGasOracle,
  VerixToken,
  MockV3Aggregator
} from "../../typechain-types";
import { BigNumber } from "ethers";

describe("VerixRelayer", function () {
  // Test fixtures
  async function deployRelayerFixture() {
    const [owner, admin, operator, user1, user2] = await ethers.getSigners();

    // Deploy mock price feeds
    const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
    const maticUsdFeed = await MockV3Aggregator.deploy(8, 100000000); // $1.00
    const gasWeiFeed = await MockV3Aggregator.deploy(8, 50000000000); // 50 Gwei

    // Deploy token
    const Token = await ethers.getContractFactory("VerixToken");
    const token = await Token.deploy();

    // Deploy Oracle
    const Oracle = await ethers.getContractFactory("VerixGasOracle");
    const oracle = await Oracle.deploy(
      maticUsdFeed.address,
      gasWeiFeed.address
    );

    // Deploy Gas Pool
    const GasPool = await ethers.getContractFactory("VerixGasPool");
    const gasPool = await GasPool.deploy(
      token.address,
      oracle.address,
      admin.address
    );

    // Deploy Relayer
    const Relayer = await ethers.getContractFactory("VerixRelayer");
    const relayer = await Relayer.deploy(
      gasPool.address,
      oracle.address,
      ethers.utils.parseEther("1"), // 1 MATIC min balance
      86400 // 24 hour timeout
    );

    // Setup roles and initial state
    await gasPool.grantRole(await gasPool.OPERATOR_ROLE(), operator.address);
    await gasPool.connect(admin).replenishPool({ value: ethers.utils.parseEther("10") });

    // Transfer tokens to test users
    await token.transfer(user1.address, ethers.utils.parseEther("5000")); // Standard tier
    await token.transfer(user2.address, ethers.utils.parseEther("10000")); // Premium tier

    return { 
      token, 
      oracle, 
      gasPool, 
      relayer,
      owner,
      admin,
      operator,
      user1,
      user2,
      maticUsdFeed,
      gasWeiFeed
    };
  }

  describe("Deployment", function () {
    it("Should set the correct initial parameters", async function () {
      const { relayer, gasPool, oracle } = await loadFixture(deployRelayerFixture);

      expect(await relayer.gasPool()).to.equal(gasPool.address);
      expect(await relayer.gasOracle()).to.equal(oracle.address);
      expect(await relayer.minRelayerBalance()).to.equal(ethers.utils.parseEther("1"));
      expect(await relayer.relayerTimeout()).to.equal(86400);
    });

    it("Should revert deployment with invalid parameters", async function () {
      const Relayer = await ethers.getContractFactory("VerixRelayer");
      
      await expect(
        Relayer.deploy(
          ethers.constants.AddressZero,
          ethers.constants.AddressZero,
          ethers.utils.parseEther("1"),
          86400
        )
      ).to.be.revertedWith("Invalid gas pool");
    });
  });

  describe("Relayer Registration", function () {
    it("Should register a new relayer", async function () {
      const { relayer, operator } = await loadFixture(deployRelayerFixture);

      await expect(
        relayer.connect(operator).registerRelayer({
          value: ethers.utils.parseEther("1")
        })
      )
        .to.emit(relayer, "RelayerRegistered")
        .withArgs(operator.address, ethers.utils.parseEther("1"));

      const relayerInfo = await relayer.getRelayerStatus(operator.address);
      expect(relayerInfo.isActive).to.be.true;
      expect(relayerInfo.balance).to.equal(ethers.utils.parseEther("1"));
    });

    it("Should revert registration with insufficient balance", async function () {
      const { relayer, operator } = await loadFixture(deployRelayerFixture);

      await expect(
        relayer.connect(operator).registerRelayer({
          value: ethers.utils.parseEther("0.5")
        })
      ).to.be.revertedWith("Insufficient initial balance");
    });

    it("Should not allow duplicate registration", async function () {
      const { relayer, operator } = await loadFixture(deployRelayerFixture);

      await relayer.connect(operator).registerRelayer({
        value: ethers.utils.parseEther("1")
      });

      await expect(
        relayer.connect(operator).registerRelayer({
          value: ethers.utils.parseEther("1")
        })
      ).to.be.revertedWith("Already registered");
    });
  });

  describe("Relay Execution", function () {
    let relayer: VerixRelayer;
    let operator: SignerWithAddress;
    let user1: SignerWithAddress;

    beforeEach(async function () {
      const fixture = await loadFixture(deployRelayerFixture);
      relayer = fixture.relayer;
      operator = fixture.operator;
      user1 = fixture.user1;

      // Register operator as relayer
      await relayer.connect(operator).registerRelayer({
        value: ethers.utils.parseEther("1")
      });
    });

    async function createRelayRequest(
      user: SignerWithAddress,
      gasAmount: string,
      expiryTime: number,
      data: string = "0x"
    ) {
      const nonce = await relayer.getUserNonce(user.address);
      
      const message = ethers.utils.solidityKeccak256(
        ["address", "uint256", "uint256", "uint256", "bytes", "address"],
        [
          user.address,
          ethers.utils.parseEther(gasAmount),
          nonce,
          expiryTime,
          data,
          relayer.address
        ]
      );

      const signature = await user.signMessage(ethers.utils.arrayify(message));

      return {
        user: user.address,
        gasAmount: ethers.utils.parseEther(gasAmount),
        nonce,
        expiryTime,
        data,
        signature
      };
    }

    it("Should execute valid relay request", async function () {
      const expiryTime = Math.floor(Date.now() / 1000) + 3600;
      const request = await createRelayRequest(user1, "0.1", expiryTime);

      await expect(relayer.connect(operator).executeRelay(request))
        .to.emit(relayer, "RelayExecuted")
        .withArgs(user1.address, operator.address, request.gasAmount, anyValue);

      // Verify state updates
      expect(await relayer.getUserNonce(user1.address)).to.equal(1);
      const relayerInfo = await relayer.getRelayerMetrics(operator.address);
      expect(relayerInfo.successfulRelays).to.equal(1);
    });

    it("Should revert expired requests", async function () {
      const expiryTime = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
      const request = await createRelayRequest(user1, "0.1", expiryTime);

      await expect(
        relayer.connect(operator).executeRelay(request)
      ).to.be.revertedWith("Request expired");
    });

    it("Should revert requests with invalid signature", async function () {
      const expiryTime = Math.floor(Date.now() / 1000) + 3600;
      const request = await createRelayRequest(user1, "0.1", expiryTime);
      request.signature = "0x" + "00".repeat(65); // Invalid signature

      await expect(
        relayer.connect(operator).executeRelay(request)
      ).to.be.revertedWith("Invalid signature");
    });

    it("Should revert requests with invalid nonce", async function () {
      const expiryTime = Math.floor(Date.now() / 1000) + 3600;
      const request = await createRelayRequest(user1, "0.1", expiryTime);
      request.nonce = BigNumber.from(1); // Wrong nonce

      await expect(
        relayer.connect(operator).executeRelay(request)
      ).to.be.revertedWith("Invalid nonce");
    });

    it("Should handle high gas limit requests", async function () {
      const expiryTime = Math.floor(Date.now() / 1000) + 3600;
      const request = await createRelayRequest(user1, "2", expiryTime); // 2 MATIC worth of gas

      await expect(
        relayer.connect(operator).executeRelay(request)
      ).to.be.revertedWith("Gas limit exceeded");
    });
  });

  describe("Relayer Management", function () {
    it("Should allow relayer to withdraw balance", async function () {
      const { relayer, operator } = await loadFixture(deployRelayerFixture);

      // Register and top up relayer
      await relayer.connect(operator).registerRelayer({
        value: ethers.utils.parseEther("2")
      });

      const withdrawAmount = ethers.utils.parseEther("0.5");
      await expect(
        relayer.connect(operator).withdrawRelayerBalance(withdrawAmount)
      )
        .to.emit(relayer, "RelayerBalanceUpdated")
        .to.changeEtherBalance(operator, withdrawAmount);
    });

    it("Should maintain minimum balance requirement", async function () {
      const { relayer, operator } = await loadFixture(deployRelayerFixture);

      await relayer.connect(operator).registerRelayer({
        value: ethers.utils.parseEther("2")
      });

      await expect(
        relayer.connect(operator).withdrawRelayerBalance(ethers.utils.parseEther("1.5"))
      ).to.be.revertedWith("Must maintain min balance");
    });

    it("Should remove inactive relayer", async function () {
      const { relayer, operator, owner } = await loadFixture(deployRelayerFixture);

      await relayer.connect(operator).registerRelayer({
        value: ethers.utils.parseEther("1")
      });

      // Advance time beyond timeout
      await time.increase(86401);

      await expect(
        relayer.connect(owner).removeInactiveRelayer(operator.address)
      )
        .to.emit(relayer, "RelayerRemoved")
        .withArgs(operator.address);

      const relayerInfo = await relayer.getRelayerStatus(operator.address);
      expect(relayerInfo.isActive).to.be.false;
    });
  });

  describe("Performance Tracking", function () {
    it("Should track successful and failed relays", async function () {
      const { relayer, operator, user1 } = await loadFixture(deployRelayerFixture);

      await relayer.connect(operator).registerRelayer({
        value: ethers.utils.parseEther("2")
      });

      // Execute some relays
      const expiryTime = Math.floor(Date.now() / 1000) + 3600;
      const request1 = await createRelayRequest(user1, "0.1", expiryTime);
      const request2 = await createRelayRequest(user1, "0.1", expiryTime, "0x12345678"); // Will fail

      await relayer.connect(operator).executeRelay(request1);
      await relayer.connect(operator).executeRelay(request2);

      const metrics = await relayer.getRelayerMetrics(operator.address);
      expect(metrics.successfulRelays).to.equal(1);
      expect(metrics.failedRelays).to.equal(1);
      expect(metrics.successRate).to.equal(50);
    });
  });

  describe("Emergency Controls", function () {
    it("Should pause and unpause relayer operations", async function () {
      const { relayer, owner, operator } = await loadFixture(deployRelayerFixture);

      await relayer.connect(owner).pause();
      
      await expect(
        relayer.connect(operator).registerRelayer({
          value: ethers.utils.parseEther("1")
        })
      ).to.be.revertedWith("Paused");

      await relayer.connect(owner).unpause();
      
      await expect(
        relayer.connect(operator).registerRelayer({
          value: ethers.utils.parseEther("1")
        })
      ).to.not.be.reverted;
    });
  });
});

// Helper function to sign relay requests
async function signRelayRequest(
  signer: SignerWithAddress,
  request: any,
  relayerAddress: string
): Promise<string> {
  const message = ethers.utils.solidityKeccak256(
    ["address", "uint256", "uint256", "uint256", "bytes", "address"],
    [
      request.user,
      request.gasAmount,
      request.nonce,
      request.expiryTime,
      request.data,
      relayerAddress
    ]
  );

  return signer.signMessage(ethers.utils.arrayify(message));
}
