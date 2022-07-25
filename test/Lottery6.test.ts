import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import { parseEther } from "ethers/lib/utils"
import { deployments, ethers, network } from "hardhat"
import { Lottery6 } from "typechain-types"
import { VRFCoordinatorV2Mock } from "typechain-types/@chainlink/contracts/src/v0.8/mocks"
import { developmentChains } from "../helper-hardhat.config"

describe("Lottery6", function () {
  let deployer: SignerWithAddress,
    lottery6: Lottery6,
    vrfCoordinatorV2Mock: VRFCoordinatorV2Mock

  beforeEach(async () => {
    if (!developmentChains.includes(network.name)) {
      throw "You need to be on a development chain to run tests."
    }

    const accounts = await ethers.getSigners()
    deployer = accounts[0]

    await deployments.fixture("all")

    lottery6 = await ethers.getContract("Lottery6")
    vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
  })

  describe("constructor", () => {})

  describe("enter", () => {
    it("should store the player, entering the lottery", async () => {
      const luckyNumbers = [1, 2, 3, 4, 5, 6]

      await lottery6.enter(luckyNumbers, false, { value: parseEther("0.1") })
      const storedNumbers = await lottery6.getPlayerNumbers(deployer.address)

      expect(JSON.stringify(storedNumbers.map((n) => n.toNumber()))).to.equals(
        JSON.stringify(luckyNumbers)
      )
    })

    it("should do stuff", async () => {
      const luckyNumbers = [1, 2, 3, 4, 5, 6]

      await lottery6.enter(luckyNumbers, false, { value: parseEther("0.1") })

      // jump interval time + 1 seconds ahead
      await network.provider.send("evm_increaseTime", [31])
      await network.provider.request({
        method: "evm_mine",
        params: [],
      })

      const txResponse = await lottery6.performUpkeep("0x")
      const txReceipt = await txResponse.wait(1) // waits 1 block
      const state = await lottery6.getState()

      await vrfCoordinatorV2Mock.fulfillRandomWords(
        txReceipt!.events![1].args!.requestId,
        "[1, 2, 3, 4, 5, 6]"
      )
    })
  })
})
