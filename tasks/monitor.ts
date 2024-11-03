import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeploymentAddress } from "../scripts/utils/constants";

task("monitor-system", "Monitors the Verix system status")
  .setAction(async (_, hre: HardhatRuntimeEnvironment) => {
    try {
      // Get contract instances
      const gasPool = await hre.ethers.getContractAt(
        "VerixGasPool",
        await getDeploymentAddress("VerixGasPool")
      );

      const oracle = await hre.ethers.getContractAt(
        "VerixGasOracle",
        await getDeploymentAddress("VerixGasOracle")
      );

      const relayer = await hre.ethers.getContractAt(
        "VerixRelayer",
        await getDeploymentAddress("VerixRelayer")
      );

      // Check pool balance
      const poolBalance = await gasPool.poolBalance();
      const minimumBalance = await gasPool.minimumPoolBalance();
      
      console.log("\nGas Pool Status:");
      console.log(`Pool Balance: ${hre.ethers.utils.formatEther(poolBalance)} MATIC`);
      console.log(`Minimum Required: ${hre.ethers.utils.formatEther(minimumBalance)} MATIC`);

      // Check oracle prices
      const prices = await oracle.getLatestPrices();
      console.log("\nPrice Oracle Status:");
      console.log(`MATIC/USD Price: $${hre.ethers.utils.formatUnits(prices.latestMaticPrice, 8)}`);
      console.log(`Gas Price: ${hre.ethers.utils.formatUnits(prices.latestGasPrice, 9)} Gwei`);
      console.log(`Last Update: ${new Date(prices.updateTime.toNumber() * 1000).toLocaleString()}`);

      // Check relayer status
      const relayerCount = await relayer.totalRelayers();
      console.log("\nRelayer Network Status:");
      console.log(`Total Relayers: ${relayerCount}`);
      
      // Alert on low balance
      if (poolBalance.lt(minimumBalance)) {
        console.error("\n⚠️ WARNING: Gas pool balance below minimum threshold!");
      }

      // Alert on stale prices
      if (await oracle.needsUpdate()) {
        console.error("\n⚠️ WARNING: Oracle prices need updating!");
      }

    } catch (error) {
      console.error("Error monitoring system:", error);
      process.exit(1);
    }
  });

task("monitor-relayers", "Monitors relayer performance")
  .setAction(async (_, hre: HardhatRuntimeEnvironment) => {
    try {
      const relayer = await hre.ethers.getContractAt(
        "VerixRelayer",
        await getDeploymentAddress("VerixRelayer")
      );

      // Get active relayers
      const filter = relayer.filters.RelayerRegistered();
      const events = await relayer.queryFilter(filter);
      
      console.log("\nRelayer Performance Metrics:");
      for (const event of events) {
        const address = event.args?.relayer;
        const metrics = await relayer.getRelayerMetrics(address);
        const status = await relayer.getRelayerStatus(address);

        console.log(`\nRelayer ${address}:`);
        console.log(`Status: ${status.isActive ? 'Active' : 'Inactive'}`);
        console.log(`Balance: ${hre.ethers.utils.formatEther(status.balance)} MATIC`);
        console.log(`Success Rate: ${metrics.successRate}%`);
        console.log(`Total Transactions: ${metrics.successfulRelays.add(metrics.failedRelays)}`);
        console.log(`Last Activity: ${new Date(status.lastActivityTime.toNumber() * 1000).toLocaleString()}`);
      }

    } catch (error) {
      console.error("Error monitoring relayers:", error);
      process.exit(1);
    }
  });
