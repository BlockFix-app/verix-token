import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";

export async function mineBlocks(count: number) {
  for (let i = 0; i < count; i++) {
    await ethers.provider.send("evm_mine", []);
  }
}

export async function timeTravel(seconds: number) {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  await ethers.provider.send("evm_mine", []);
}

export async function signMetaTx(
  signer: SignerWithAddress,
  nonce: BigNumber,
  functionData: string,
  verifyingContract: string
) {
  const domain = {
    name: "Verix Protocol",
    version: "1",
    chainId: await signer.getChainId(),
    verifyingContract
  };

  const types = {
    MetaTransaction: [
      { name: "nonce", type: "uint256" },
      { name: "from", type: "address" },
      { name: "functionSignature", type: "bytes" }
    ]
  };

  const value = {
    nonce,
    from: signer.address,
    functionSignature: functionData
  };

  return signer._signTypedData(domain, types, value);
}

export async function signRelayRequest(
  signer: SignerWithAddress,
  request: any,
  relayerAddress: string
) {
  const message = ethers.utils.solidityKeccak256(
    ["address", "uint256", "uint256", "uint256", "bytes", "address"],
    [
      request.user,
      request.gasAmount,
      request.nonce,
      request.expiryTime,
      request.data,
      relayerAddress
    ]
  );

  return signer.signMessage(ethers.utils.arrayify(message));
}

export async function createProposal(
  governor: any,
  targets: string[],
  values: number[],
  calldatas: string[],
  description: string
) {
  const tx = await governor.propose(
    targets,
    values,
    calldatas,
    description
  );
  const receipt = await tx.wait();
  const event = receipt.events?.find(e => e.event === "ProposalCreated");
  return event?.args?.proposalId;
}

export function encodeParameters(types: string[], values: any[]) {
  const abi = new ethers.utils.AbiCoder();
  return abi.encode(types, values);
}
