import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import { parseEther } from "ethers/lib/utils"
import { deployments, ethers, network } from "hardhat"
import { Lottery6 } from "typechain-types"
import { VRFCoordinatorV2Mock } from "typechain-types/@chainlink/contracts/src/v0.8/mocks"
import { developmentChains, networkConfig } from "../helper-hardhat.config"

describe("Lottery6", function () {
  const config = networkConfig[network.config.chainId!],
    winningNumbers = [1, 9, 16, 24, 25, 41],
    luckyNumbers = [1, 2, 3, 4, 5, 6]

  let accounts: SignerWithAddress[],
    deployer: SignerWithAddress,
    lottery6: Lottery6,
    vrfCoordinatorV2Mock: VRFCoordinatorV2Mock

  beforeEach(async () => {
    if (!developmentChains.includes(network.name)) {
      throw "You need to be on a development chain to run tests."
    }

    accounts = await ethers.getSigners()
    deployer = accounts[0]

    await deployments.fixture("all")

    lottery6 = await ethers.getContract("Lottery6")
    vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")

    await vrfCoordinatorV2Mock.createSubscription()
    await vrfCoordinatorV2Mock.fundSubscription(1, parseEther("1"))
  })

  describe("constructor", () => {})

  describe("enter", () => {
    it("reverts when you don't pay enough", async () => {
      await expect(
        lottery6.enter(luckyNumbers, false)
      ).to.be.revertedWithCustomError(lottery6, "Lottery6__PaymentNotEnough")
    })

    it("should store the player, and the submitted numbers after entering the lottery.", async () => {
      await lottery6.enter(luckyNumbers, false, { value: parseEther("0.1") })
      const storedNumbers = await lottery6.getPlayerNumbers(deployer.address)

      expect(JSON.stringify(storedNumbers.map((n) => n.toNumber()))).to.equals(
        JSON.stringify(luckyNumbers)
      )
    })

    it("emits event on enter", async () => {
      await expect(
        lottery6.enter(luckyNumbers, false, { value: parseEther("0.1") })
      ).to.emit(lottery6, "Lottery6__Enter")
    })

    it("doesn't allow entrance when the lottery is drawing", async () => {
      await lottery6.enter(luckyNumbers, false, { value: parseEther("0.1") })
      await network.provider.send("evm_increaseTime", [
        config.keepersUpdateInterval! + 1,
      ])
      await network.provider.request({ method: "evm_mine", params: [] })
      await lottery6.performUpkeep("0x")

      expect(await lottery6.getState()).to.be.eq("2") // DRAWING

      await expect(
        lottery6.enter(luckyNumbers, false, {
          value: parseEther("0.1"),
        })
      ).to.be.revertedWithCustomError(lottery6, "Lottery6__EntryClosed")
    })
  })

  describe("fulfillRandomWords", () => {
    it("should emit the NoWinners if the numbers are not matching", async () => {
      await lottery6.enter(luckyNumbers, false, {
        value: parseEther("0.1"),
      })

      // jump interval time + 1 seconds ahead
      await network.provider.send("evm_increaseTime", [31])
      await network.provider.request({
        method: "evm_mine",
        params: [],
      })

      const tx = await lottery6.performUpkeep("0x")
      const rc = await tx.wait(1) // waits 1 block

      await vrfCoordinatorV2Mock.fulfillRandomWords(
        rc!.events![1].args!.requestId,
        lottery6.address
      )

      const history = await lottery6.getHistory()

      const [result, winners] = history.flat()

      expect(JSON.stringify(result.map((n) => n.toString()))).to.equal(
        JSON.stringify(winningNumbers.map((n) => n.toString()))
      )
      expect(winners.length).to.equal(0)
    })

    it("should emit the Winners if the numbers are matching", async () => {
      await lottery6.enter(winningNumbers, false, {
        value: parseEther("0.1"),
      })

      // jump interval time + 1 seconds ahead
      await network.provider.send("evm_increaseTime", [31])
      await network.provider.request({
        method: "evm_mine",
        params: [],
      })

      const tx = await lottery6.performUpkeep("0x")
      const rc = await tx.wait(1) // waits 1 block

      await vrfCoordinatorV2Mock.fulfillRandomWords(
        rc!.events![1].args!.requestId,
        lottery6.address
      )

      const history = await lottery6.getHistory()

      const [result, winners] = history.flat()

      expect(JSON.stringify(result.map((n) => n.toString()))).to.equal(
        JSON.stringify(winningNumbers.map((n) => n.toString()))
      )
      expect(winners[0]).to.equal(accounts[0].address)
    })
  })
})
