import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("deploy-all", "Deploys all contracts")
  .setAction(async (_, hre: HardhatRuntimeEnvironment) => {
    console.log("Deploying all contracts...");

    try {
      // Deploy token
      await hre.run("run", { 
        script: "scripts/deploy/001_deploy_token.ts"
      });

      // Deploy gas system
      await hre.run("run", {
        script: "scripts/deploy/002_deploy_gas_system.ts"
      });

      // Deploy governance
      await hre.run("run", {
        script: "scripts/deploy/003_deploy_governance.ts"
      });

      // Deploy vesting
      await hre.run("run", {
        script: "scripts/deploy/004_deploy_vesting.ts"
      });

      console.log("All contracts deployed successfully!");
    } catch (error) {
      console.error("Error during deployment:", error);
      process.exit(1);
    }
  });

task("deploy-contract", "Deploys a specific contract")
  .addParam("contract", "Contract name to deploy")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    console.log(`Deploying ${taskArgs.contract}...`);

    try {
      const scriptPath = getDeploymentScript(taskArgs.contract);
      await hre.run("run", { script: scriptPath });
      console.log(`${taskArgs.contract} deployed successfully!`);
    } catch (error) {
      console.error("Error during deployment:", error);
      process.exit(1);
    }
  });

function getDeploymentScript(contractName: string): string {
  switch (contractName) {
    case "VerixToken":
      return "scripts/deploy/001_deploy_token.ts";
    case "GasSystem":
      return "scripts/deploy/002_deploy_gas_system.ts";
    case "Governance":
      return "scripts/deploy/003_deploy_governance.ts";
    case "Vesting":
      return "scripts/deploy/004_deploy_vesting.ts";
    default:
      throw new Error(`Unknown contract: ${contractName}`);
  }
}

task("upgrade", "Upgrades a contract implementation")
  .addParam("contract", "Contract name to upgrade")
  .addParam("proxy", "Proxy contract address")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    console.log(`Upgrading ${taskArgs.contract}...`);

    try {
      const Contract = await hre.ethers.getContractFactory(taskArgs.contract);
      const upgraded = await hre.upgrades.upgradeProxy(taskArgs.proxy, Contract);
      await upgraded.deployed();

      console.log(`${taskArgs.contract} upgraded successfully!`);
      console.log("New implementation address:", upgraded.address);
    } catch (error) {
      console.error("Error during upgrade:", error);
      process.exit(1);
    }
  });
