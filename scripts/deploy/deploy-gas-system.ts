import { ethers } from "hardhat";
import { verifyContract } from "../utils/verification";
import { saveDeploymentAddress } from "../utils/constants";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying Gas System with account:", deployer.address);

  // Get token address
  const tokenAddress = process.env.VERIX_TOKEN_ADDRESS;
  if (!tokenAddress) {
    throw new Error("Token address not provided");
  }

  // Deploy price feeds (for testnet only)
  let maticUsdFeed, gasWeiFeed;
  if (process.env.NETWORK === "localhost" || process.env.NETWORK === "hardhat") {
    const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
    maticUsdFeed = await MockPriceFeed.deploy(8, 100000000);
    gasWeiFeed = await MockPriceFeed.deploy(8, 50000000000);
    await maticUsdFeed.deployed();
    await gasWeiFeed.deployed();
  } else {
    maticUsdFeed = { address: process.env.MATIC_USD_FEED };
    gasWeiFeed = { address: process.env.GAS_WEI_FEED };
  }

  // Deploy Oracle
  const VerixGasOracle = await ethers.getContractFactory("VerixGasOracle");
  const oracle = await VerixGasOracle.deploy(
    maticUsdFeed.address,
    gasWeiFeed.address
  );
  await oracle.deployed();
  console.log("VerixGasOracle deployed to:", oracle.address);
  await saveDeploymentAddress('VerixGasOracle', oracle.address);

  // Deploy Gas Pool
  const VerixGasPool = await ethers.getContractFactory("VerixGasPool");
  const gasPool = await VerixGasPool.deploy(
    tokenAddress,
    oracle.address,
    process.env.ADMIN_ADDRESS || deployer.address
  );
  await gasPool.deployed();
  console.log("VerixGasPool deployed to:", gasPool.address);
  await saveDeploymentAddress('VerixGasPool', gasPool.address);

  // Deploy Relayer
  const VerixRelayer = await ethers.getContractFactory("VerixRelayer");
  const relayer = await VerixRelayer.deploy(
    gasPool.address,
    oracle.address,
    ethers.utils.parseEther("1"),
    86400
  );
  await relayer.deployed();
  console.log("VerixRelayer deployed to:", relayer.address);
  await saveDeploymentAddress('VerixRelayer', relayer.address);

  // Verify contracts
  if (process.env.VERIFY_CONTRACTS === 'true') {
    await verifyContract(oracle.address, [maticUsdFeed.address, gasWeiFeed.address]);
    await verifyContract(gasPool.address, [
      tokenAddress, 
      oracle.address, 
      process.env.ADMIN_ADDRESS || deployer.address
    ]);
    await verifyContract(relayer.address, [
      gasPool.address,
      oracle.address,
      ethers.utils.parseEther("1"),
      86400
    ]);
  }

  // Setup initial pool funding
  if (process.env.INITIAL_POOL_FUNDING) {
    await gasPool.replenishPool({
      value: ethers.utils.parseEther(process.env.INITIAL_POOL_FUNDING)
    });
    console.log(`Pool funded with ${process.env.INITIAL_POOL_FUNDING} MATIC`);
  }

  console.log("Gas System deployment completed");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
