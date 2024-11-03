import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeploymentAddress } from "../scripts/utils/constants";

task("verify-all", "Verifies all deployed contracts")
  .setAction(async (_, hre: HardhatRuntimeEnvironment) => {
    const network = hre.network.name;
    console.log(`Verifying contracts on ${network}...`);

    try {
      // Get deployed addresses
      const tokenAddress = await getDeploymentAddress("VerixToken");
      const oracleAddress = await getDeploymentAddress("VerixGasOracle");
      const gasPoolAddress = await getDeploymentAddress("VerixGasPool");
      const relayerAddress = await getDeploymentAddress("VerixRelayer");
      const timelockAddress = await getDeploymentAddress("VerixTimelock");
      const governorAddress = await getDeploymentAddress("VerixGovernor");
      const vestingAddress = await getDeploymentAddress("VerixTokenVesting");

      // Get price feed addresses
      const maticUsdFeed = process.env.MATIC_USD_FEED;
      const gasWeiFeed = process.env.GAS_WEI_FEED;

      console.log("\nVerifying VerixToken...");
      await hre.run("verify:verify", {
        address: tokenAddress,
        constructorArguments: []
      });

      console.log("\nVerifying VerixGasOracle...");
      await hre.run("verify:verify", {
        address: oracleAddress,
        constructorArguments: [maticUsdFeed, gasWeiFeed]
      });

      console.log("\nVerifying VerixGasPool...");
      await hre.run("verify:verify", {
        address: gasPoolAddress,
        constructorArguments: [
          tokenAddress,
          oracleAddress,
          process.env.ADMIN_ADDRESS
        ]
      });

      console.log("\nVerifying VerixRelayer...");
      await hre.run("verify:verify", {
        address: relayerAddress,
        constructorArguments: [
          gasPoolAddress,
          oracleAddress,
          hre.ethers.utils.parseEther("1"), // minRelayerBalance
          86400 // relayerTimeout
        ]
      });

      console.log("\nVerifying VerixTimelock...");
      await hre.run("verify:verify", {
        address: timelockAddress,
        constructorArguments: [
          172800, // 2 days delay
          [process.env.ADMIN_ADDRESS], // proposers
          [process.env.ADMIN_ADDRESS], // executors
          process.env.ADMIN_ADDRESS // admin
        ]
      });

      console.log("\nVerifying VerixGovernor...");
      await hre.run("verify:verify", {
        address: governorAddress,
        constructorArguments: [
          tokenAddress,
          timelockAddress,
          1, // voting delay
          50400, // voting period
          hre.ethers.utils.parseEther("100000"), // proposal threshold
          5 // quorum percentage
        ]
      });

      console.log("\nVerifying VerixTokenVesting...");
      await hre.run("verify:verify", {
        address: vestingAddress,
        constructorArguments: [tokenAddress]
      });

      console.log("\nAll contracts verified successfully!");
    } catch (error) {
      console.error("Error during verification:", error);
      process.exit(1);
    }
  });

task("verify-contract", "Verifies a specific contract")
  .addParam("contract", "Contract name to verify")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const network = hre.network.name;
    console.log(`Verifying ${taskArgs.contract} on ${network}...`);

    try {
      const contractAddress = await getDeploymentAddress(taskArgs.contract);
      const constructorArgs = await getConstructorArguments(taskArgs.contract, hre);

      await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: constructorArgs
      });

      console.log(`${taskArgs.contract} verified successfully!`);
    } catch (error) {
      console.error("Error during verification:", error);
      process.exit(1);
    }
  });

async function getConstructorArguments(contractName: string, hre: HardhatRuntimeEnvironment) {
  const tokenAddress = await getDeploymentAddress("VerixToken");
  const oracleAddress = await getDeploymentAddress("VerixGasOracle");
  const gasPoolAddress = await getDeploymentAddress("VerixGasPool");
  const timelockAddress = await getDeploymentAddress("VerixTimelock");

  switch (contractName) {
    case "VerixToken":
      return [];

    case "VerixGasOracle":
      return [process.env.MATIC_USD_FEED, process.env.GAS_WEI_FEED];

    case "VerixGasPool":
      return [tokenAddress, oracleAddress, process.env.ADMIN_ADDRESS];

    case "VerixRelayer":
      return [
        gasPoolAddress,
        oracleAddress,
        hre.ethers.utils.parseEther("1"),
        86400
      ];

    case "VerixTimelock":
      return [
        172800,
        [process.env.ADMIN_ADDRESS],
        [process.env.ADMIN_ADDRESS],
        process.env.ADMIN_ADDRESS
      ];

    case "VerixGovernor":
      return [
        tokenAddress,
        timelockAddress,
        1,
        50400,
        hre.ethers.utils.parseEther("100000"),
        5
      ];

    case "VerixTokenVesting":
      return [tokenAddress];

    default:
      throw new Error(`Unknown contract: ${contractName}`);
  }
}

// Task to verify proxy contracts
task("verify-proxy", "Verifies a proxy contract and its implementation")
  .addParam("proxy", "Proxy contract address")
  .addParam("implementation", "Implementation contract address")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    console.log("Verifying proxy contract...");
    
    try {
      // Verify proxy contract
      await hre.run("verify:verify", {
        address: taskArgs.proxy,
        constructorArguments: []
      });

      // Verify implementation contract
      await hre.run("verify:verify", {
        address: taskArgs.implementation,
        constructorArguments: []
      });

      console.log("Proxy and implementation verified successfully!");
    } catch (error) {
      console.error("Error during proxy verification:", error);
      process.exit(1);
    }
  });

// Task to verify all contracts on a specific network
task("verify-network", "Verifies all contracts on a specific network")
  .addParam("network", "Network to verify contracts on")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    if (hre.network.name !== taskArgs.network) {
      console.error(`Please run this task on ${taskArgs.network} network`);
      process.exit(1);
    }

    await hre.run("verify-all");
  });
