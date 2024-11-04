import * as hardhat from "hardhat";
import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "./tasks/deploy";

const config: HardhatUserConfig = {
  solidity: "0.8.4",
  networks: {
    // Add network configurations here
  },
};

export default config;
