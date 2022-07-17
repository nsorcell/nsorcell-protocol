import { parseEther } from "ethers/lib/utils"
import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { developmentChains, networkConfig } from "../helper-hardhat.config"
import verify from "../utils/verify"

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const config = networkConfig[network.config.chainId!]

  const args = [
    config.vrfCoordinatorV2,
    config.keyHash,
    config.callbackGasLimit,
    config.randomNumberCount,
    config.subscriptionId,
    config.keepersUpdateInterval,
    parseEther("0.1"),
  ]

  log("----------------------------------------------------")
  log("Deploying Lottery6 and waiting for confirmations...")
  const lottery6 = await deploy("Lottery6", {
    from: deployer,
    args,
    log: true,
    waitConfirmations: 5,
  })
  log(`Lottery6 deployed at ${lottery6.address}`)
  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    await verify(lottery6.address, args)
  }
}
export default deploy
deploy.tags = ["all", "Lottery6", "production"]
