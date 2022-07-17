import { parseEther } from "ethers/lib/utils"
import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { developmentChains } from "../helper-hardhat.config"

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments, network } = hre

  if (developmentChains.includes(network.name)) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId: number = network.config.chainId!

    const args = [parseEther("0.1")]

    log("----------------------------------------------------")
    log("Deploying mocks...")

    log(`XY deployed at ${"--address"}`)
  } else {
    console.log("Not on development chain, mocks are not deployed.")
  }
}
export default deploy
deploy.tags = ["all", "mocks"]
