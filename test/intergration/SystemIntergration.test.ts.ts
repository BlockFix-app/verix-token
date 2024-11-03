import { expect } from "chai";
import { ethers } from "hardhat";
import { 
  loadFixture,
  time 
} from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployFullSystemFixture } from "../utils/fixtures";
import { signMetaTx, signRelayRequest } from "../utils/helpers";

describe("Verix System Integration", function () {
  describe("Gas Coverage Flow", function () {
    it("Should handle complete gas coverage with meta-transaction", async function () {
      const { 
        token,
        gasPool,
        relayer,
        operator,
        user1,
        user2
      } = await loadFixture(deployFullSystemFixture);

      // 1. Update user tier
      await gasPool.updateUserTier(user1.address);
      const tier = await gasPool.userTier(user1.address);
      expect(tier).to.equal(2); // Standard tier

      // 2. Prepare token transfer
      const initialBalance = await token.balanceOf(user2.address);
      const transferAmount = ethers.utils.parseEther("100");

      // 3. Create meta-transaction
      const nonce = await token.nonces(user1.address);
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      const signature = await user1._signTypedData(
        {
          name: "Verix Token",
          version: "1",
          chainId: await user1.getChainId(),
          verifyingContract: token.address
        },
        {
          Permit: [
            { name: "owner", type: "address" },
            { name: "spender", type: "address" },
            { name: "value", type: "uint256" },
            { name: "nonce", type: "uint256" },
            { name: "deadline", type: "uint256" }
          ]
        },
        {
          owner: user1.address,
          spender: relayer.address,
          value: transferAmount,
          nonce: nonce,
          deadline: deadline
        }
      );

      // 4. Execute relayed transaction
      await relayer.connect(operator).executeMetaTransaction(
        user1.address,
        token.address,
        transferAmount,
        user2.address,
        deadline,
        signature
      );

      // 5. Verify results
      const finalBalance = await token.balanceOf(user2.address);
      expect(finalBalance).to.equal(initialBalance.add(transferAmount));
    });

    it("Should integrate with governance system", async function () {
      const { 
        token,
        governor,
        timelock,
        gasPool,
        user1
      } = await loadFixture(deployFullSystemFixture);

      // 1. Create proposal to update gas coverage tier
      const description = "Update Standard Tier Gas Coverage";
      const encodedFunction = gasPool.interface.encodeFunctionData(
        "updateTier",
        [2, ethers.utils.parseEther("5000"), 8000, ethers.utils.parseEther("300")]
      );

      await governor.propose(
        [gasPool.address],
        [0],
        [encodedFunction],
        description
      );

      // 2. Advance blocks for voting delay
      await time.increase(2);

      // 3. Cast votes
      const proposalId = await governor.proposalCount();
      await governor.connect(user1).castVote(proposalId, 1);

      // 4. Advance time for voting period
      await time.increase(50400);

      // 5. Queue proposal
      await governor.queue(
        [gasPool.address],
        [0],
        [encodedFunction],
        ethers.utils.id(description)
      );

      // 6. Advance time for timelock
      await time.increase(2 * 24 * 60 * 60);

      // 7. Execute proposal
      await governor.execute(
        [gasPool.address],
        [0],
        [encodedFunction],
        ethers.utils.id(description)
      );

      // 8. Verify tier update
      const tier = await gasPool.tiers(2);
      expect(tier.coveragePercent).to.equal(8000);
    });
  });

  describe("Dividend Distribution Integration", function () {
    it("Should distribute and claim dividends using gas coverage", async function () {
      const {
        token,
        gasPool,
        relayer,
        operator,
        user1,
        admin
      } = await loadFixture(deployFullSystemFixture);

      // 1. Distribute dividends
      await token.connect(admin).distributeDividends({ 
        value: ethers.utils.parseEther("1") 
      });

      // 2. Create claim request with gas coverage
      const nonce = await relayer.getUserNonce(user1.address);
      const gasAmount = ethers.utils.parseEther("0.1");
      const expiryTime = Math.floor(Date.now() / 1000) + 3600;
      
      const claimData = token.interface.encodeFunctionData("claimDividends", []);
      
      const request = {
        user: user1.address,
        gasAmount,
        nonce,
        expiryTime,
        data: claimData
      };

      const signature = await signRelayRequest(user1, request, relayer.address);
      request.signature = signature;

      // 3. Execute covered claim
      await relayer.connect(operator).executeRelay(request);

      // 4. Verify dividend claim
      const unclaimed = await token.unclaimedDividends(user1.address);
      expect(unclaimed).to.equal(0);
    });
  });

  describe("System Stress Tests", function () {
    it("Should handle high volume of concurrent transactions", async function () {
      const { 
        token,
        gasPool,
        relayer,
        operator
      } = await loadFixture(deployFullSystemFixture);

      // Create test users
      const testUsers = await Promise.all(
        Array(20).fill(0).map(async () => {
          const wallet = ethers.Wallet.createRandom().connect(ethers.provider);
          // Fund the wallet
          await operator.sendTransaction({
            to: wallet.address,
            value: ethers.utils.parseEther("1")
          });
          // Transfer some tokens
          await token.transfer(wallet.address, ethers.utils.parseEther("1000"));
          return wallet;
        })
      );

      // Create multiple concurrent requests
      const requests = await Promise.all(
        testUsers.map(async (user) => {
          const nonce = await relayer.getUserNonce(user.address);
          const gasAmount = ethers.utils.parseEther("0.01");
          const expiryTime = Math.floor(Date.now() / 1000) + 3600;
          
          const request = {
            user: user.address,
            gasAmount,
            nonce,
            expiryTime,
            data: "0x"
          };

          const signature = await signRelayRequest(user, request, relayer.address);
          request.signature = signature;
          return request;
        })
      );

      // Process all requests in batches
      const batchSize = 5;
      for (let i = 0; i < requests.length; i += batchSize) {
        const batch = requests.slice(i, i + batchSize);
        await Promise.all(
          batch.map(request =>
            relayer.connect(operator).executeRelay(request)
          )
        );
      }

      // Verify system stability
      const poolBalance = await gasPool.poolBalance();
      expect(poolBalance).to.be.gt(0);
    });
  });
});
