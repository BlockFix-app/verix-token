import { ethers } from "hardhat";
import { verifyContract } from "../utils/verification";
import { saveDeploymentAddress } from "../utils/constants";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying Governance System with account:", deployer.address);

  const tokenAddress = process.env.VERIX_TOKEN_ADDRESS;
  if (!tokenAddress) {
    throw new Error("Token address not provided");
  }

  // Deploy Timelock
  console.log("\nDeploying Timelock Controller...");
  const VerixTimelock = await ethers.getContractFactory("VerixTimelock");
  const timelock = await VerixTimelock.deploy(
    2 * 24 * 60 * 60, // 2 day delay
    [deployer.address], // Proposers
    [deployer.address], // Executors
    deployer.address // Admin
  );
  await timelock.deployed();
  console.log("Timelock deployed to:", timelock.address);
  await saveDeploymentAddress('VerixTimelock', timelock.address);

  // Deploy Governor
  console.log("\nDeploying Governor...");
  const VerixGovernor = await ethers.getContractFactory("VerixGovernor");
  const governor = await VerixGovernor.deploy(
    tokenAddress,
    timelock.address,
    1, // 1 block voting delay
    50400, // ~1 week voting period
    ethers.utils.parseEther("100000"), // 100k tokens for proposal threshold
    5 // 5% quorum
  );
  await governor.deployed();
  console.log("Governor deployed to:", governor.address);
  await saveDeploymentAddress('VerixGovernor', governor.address);

  // Verify contracts
  if (process.env.VERIFY_CONTRACTS === 'true') {
    await verifyContract(timelock.address, [
      2 * 24 * 60 * 60,
      [deployer.address],
      [deployer.address],
      deployer.address
    ]);

    await verifyContract(governor.address, [
      tokenAddress,
      timelock.address,
      1,
      50400,
      ethers.utils.parseEther("100000"),
      5
    ]);
  }

  console.log("Governance system deployment completed");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
