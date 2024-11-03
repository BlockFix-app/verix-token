import { ethers, upgrades } from "hardhat";
import { verifyContract } from "../utils/verification";
import { saveDeploymentAddress } from "../utils/constants";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Deploy Token
  const VerixToken = await ethers.getContractFactory("VerixToken");
  const token = await VerixToken.deploy();
  await token.deployed();
  console.log("VerixToken deployed to:", token.address);

  // Save deployment address
  await saveDeploymentAddress('VerixToken', token.address);

  // Verify contract
  if (process.env.VERIFY_CONTRACTS === 'true') {
    await verifyContract(token.address, []);
  }

  // Setup initial roles
  const ADMIN_ROLE = await token.DEFAULT_ADMIN_ROLE();
  const DIVIDEND_MANAGER_ROLE = await token.DIVIDEND_MANAGER_ROLE();
  const GOVERNANCE_MANAGER_ROLE = await token.GOVERNANCE_MANAGER_ROLE();

  // Grant roles
  await token.grantRole(ADMIN_ROLE, process.env.ADMIN_ADDRESS || deployer.address);
  await token.grantRole(DIVIDEND_MANAGER_ROLE, process.env.DIVIDEND_MANAGER || deployer.address);
  await token.grantRole(GOVERNANCE_MANAGER_ROLE, process.env.GOVERNANCE_MANAGER || deployer.address);

  console.log("Initial roles configured");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
