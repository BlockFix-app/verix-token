import { run } from "hardhat";

export async function verifyContract(
  address: string,
  constructorArguments: any[]
) {
  try {
    await run("verify:verify", {
      address,
      constructorArguments,
    });
    console.log("Contract verified successfully");
  } catch (error) {
    console.error("Verification failed:", error);
  }
}
