import { ethers } from "hardhat";
import { verifyContract } from "../utils/verification";
import { saveDeploymentAddress } from "../utils/constants";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying Vesting Contract with account:", deployer.address);

  const tokenAddress = process.env.VERIX_TOKEN_ADDRESS;
  if (!tokenAddress) {
    throw new Error("Token address not provided");
  }

  // Deploy Vesting Contract
  const VerixTokenVesting = await ethers.getContractFactory("VerixTokenVesting");
  const vesting = await VerixTokenVesting.deploy(tokenAddress);
  await vesting.deployed();
  console.log("Vesting Contract deployed to:", vesting.address);
  await saveDeploymentAddress('VerixTokenVesting', vesting.address);

  // Verify contract
  if (process.env.VERIFY_CONTRACTS === 'true') {
    await verifyContract(vesting.address, [tokenAddress]);
  }

  // Setup initial vesting schedules if configured
  if (process.env.SETUP_INITIAL_VESTING === 'true') {
    const vestingSchedules = require('../config/vesting-schedules.json');
    for (const schedule of vestingSchedules) {
      await vesting.createVestingSchedule(
        schedule.beneficiary,
        ethers.utils.parseEther(schedule.amount),
        schedule.startTime,
        schedule.cliffDuration,
        schedule.duration,
        schedule.vestingType,
        schedule.revocable
      );
      console.log(`Created vesting schedule for ${schedule.beneficiary}`);
    }
  }

  console.log("Vesting system deployment completed");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
