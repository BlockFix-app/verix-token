import { ethers, upgrades } from "hardhat";
import { verifyContract } from "../utils/verification";
import { saveDeploymentAddress } from "../utils/constants";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying governance contracts with account:", deployer.address);

    // Deploy AccessControl
    const VerixAccessControl = await ethers.getContractFactory("VerixAccessControl");
    const accessControl = await VerixAccessControl.deploy(deployer.address);
    await accessControl.deployed();
    console.log("VerixAccessControl deployed to:", accessControl.address);

    // Save deployment address
    await saveDeploymentAddress('VerixAccessControl', accessControl.address);

    // Deploy Timelock
    const minDelay = 24 * 60 * 60; // 1 day
    const proposers = [deployer.address];
    const executors = [deployer.address];

    const VerixTimelock = await ethers.getContractFactory("VerixTimelock");
    const timelock = await VerixTimelock.deploy(
        minDelay,
        proposers,
        executors,
        deployer.address
    );
    await timelock.deployed();
    console.log("VerixTimelock deployed to:", timelock.address);

    // Save deployment address
    await saveDeploymentAddress('VerixTimelock', timelock.address);

    // Setup initial roles
    const SYSTEM_ADMIN_ROLE = await accessControl.SYSTEM_ADMIN_ROLE();
    const GOVERNANCE_MANAGER_ROLE = await accessControl.GOVERNANCE_MANAGER_ROLE();

    // Grant roles to timelock contract
    await accessControl.grantRole(GOVERNANCE_MANAGER_ROLE, timelock.address);

    // Transfer admin role to timelock
    await accessControl.initiateRoleTransfer(SYSTEM_ADMIN_ROLE, timelock.address);
    console.log("Initiated role transfer to timelock contract");

    // Verify contracts if on a network that supports it
    if (process.env.VERIFY_CONTRACTS === 'true') {
        await verifyContract(accessControl.address, [deployer.address]);
        await verifyContract(timelock.address, [
            minDelay,
            proposers,
            executors,
            deployer.address
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
