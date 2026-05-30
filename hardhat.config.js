import { defineConfig } from "hardhat/config";
import hardhatEthers from "@nomicfoundation/hardhat-ethers";

const DEPLOYER_KEY = process.env.DEPLOYER_PRIVATE_KEY || "0x" + "0".repeat(64);

export default defineConfig({
  plugins: [hardhatEthers],
  solidity: "0.8.24",
  networks: {
    linea_sepolia: {
      type: "http",
      url: process.env.LINEA_SEPOLIA_RPC || "https://rpc.sepolia.linea.build",
      accounts: [DEPLOYER_KEY],
      chainId: 59141,
    },
  },
});
