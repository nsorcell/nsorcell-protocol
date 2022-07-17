import "@nomicfoundation/hardhat-toolbox"
import { HardhatUserConfig } from "hardhat/config"

const config: HardhatUserConfig = {
  paths: {
    root: "..",
    sources: "../contracts",
  },
  typechain: {
    outDir: "./package/src",
    target: "ethers-v5",
  },
}

export default config
