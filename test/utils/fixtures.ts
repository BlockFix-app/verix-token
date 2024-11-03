import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { 
  VerixToken,
  VerixGasPool,
  VerixGasOracle,
  VerixRelayer,
  VerixGovernor,
  VerixTimelock,
  MockV3Aggregator
} from "../../typechain-types";

export async function deployFullSystemFixture() {
  const [owner, admin, operator, user1, user2] = await ethers.getSigners();

  // Deploy Mock Price Feeds
  const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
  const maticUsdFeed = await MockV3Aggregator.deploy(8, 100000000);
  const gasWeiFeed = await MockV3Aggregator.deploy(8, 50000000000);

  // Deploy Token
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
    ethers.utils.parseEther("1"),
    86400
  );

  // Deploy Governance System
  const Timelock = await ethers.getContractFactory("VerixTimelock");
  const timelock = await Timelock.deploy(
    2 * 24 * 60 * 60,
    [owner.address],
    [owner.address],
    owner.address
  );

  const Governor = await ethers.getContractFactory("VerixGovernor");
  const governor = await Governor.deploy(
    token.address,
    timelock.address,
    1,
    50400,
    ethers.utils.parseEther("100000"),
    5
  );

  // Setup initial state
  await gasPool.grantRole(await gasPool.OPERATOR_ROLE(), operator.address);
  await gasPool.connect(admin).replenishPool({ value: ethers.utils.parseEther("10") });
  
  await token.transfer(user1.address, ethers.utils.parseEther("5000"));
  await token.transfer(user2.address, ethers.utils.parseEther("10000"));

  return { 
    token,
    oracle,
    gasPool,
    relayer,
    timelock,
    governor,
    owner,
    admin,
    operator,
    user1,
    user2,
    maticUsdFeed,
    gasWeiFeed
  };
}

export async function deployMockPriceFeeds() {
  const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
  const maticUsdFeed = await MockV3Aggregator.deploy(8, 100000000); // $1.00
  const gasWeiFeed = await MockV3Aggregator.deploy(8, 50000000000); // 50 Gwei

  return { maticUsdFeed, gasWeiFeed };
}
