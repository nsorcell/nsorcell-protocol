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
    threeHits = [1, 9, 16, 4, 5, 6],
    fourHits = [1, 9, 16, 24, 5, 6],
    fiveHits = [1, 9, 16, 24, 25, 6]

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
        lottery6.enter(threeHits, false)
      ).to.be.revertedWithCustomError(lottery6, "Lottery6__PaymentNotEnough")
    })

    it("should store the player, and the submitted numbers after entering the lottery.", async () => {
      await lottery6.enter(threeHits, false, { value: parseEther("0.1") })
      const storedNumbers = await lottery6.getPlayerNumbers(deployer.address)

      expect(JSON.stringify(storedNumbers.map((n) => n.toNumber()))).to.equals(
        JSON.stringify(threeHits)
      )
    })

    it("emits event on enter", async () => {
      await expect(
        lottery6.enter(threeHits, false, { value: parseEther("0.1") })
      ).to.emit(lottery6, "Lottery6__Enter")
    })

    it("doesn't allow entrance when the lottery is drawing", async () => {
      await lottery6.enter(threeHits, false, { value: parseEther("0.1") })
      await network.provider.send("evm_increaseTime", [
        config.keepersUpdateInterval! + 1,
      ])
      await network.provider.request({ method: "evm_mine", params: [] })
      await lottery6.performUpkeep("0x")

      expect(await lottery6.getState()).to.be.eq("2") // DRAWING

      await expect(
        lottery6.enter(fourHits, false, {
          value: parseEther("0.1"),
        })
      ).to.be.revertedWithCustomError(lottery6, "Lottery6__EntryClosed")
    })
  })

  describe("fulfillRandomWords", () => {
    it("On no 6Hits: History should contain winners in the appropriate index, players should be kept", async () => {
      // 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
      await lottery6.enter(threeHits, false, {
        value: parseEther("0.1"),
      })

      // 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
      await lottery6.connect(accounts[1]).enter(fiveHits, false, {
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

      const [, results] = (await lottery6.getHistory()).flat()

      expect(results[3]).to.contain(accounts[0].address)
      expect(results[5]).to.contain(accounts[1].address)

      const players = await lottery6.getPlayers()

      expect(players).to.contain(accounts[0].address, accounts[1].address)
    })

    it("On 6Hits: History should contain winners in the appropriate index, players should be emptied", async () => {
      // 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
      await lottery6.connect(accounts[1]).enter(threeHits, false, {
        value: parseEther("1000"),
      })

      // 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
      await lottery6.connect(accounts[2]).enter(fiveHits, false, {
        value: parseEther("0.1"),
      })

      // 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
      await lottery6.connect(accounts[3]).enter(winningNumbers, false, {
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

      const tx2 = await vrfCoordinatorV2Mock.fulfillRandomWords(
        rc!.events![1].args!.requestId,
        lottery6.address
      )
      const [, results] = (await lottery6.getHistory()).flat()

      expect(results[3]).to.contain(accounts[1].address)
      expect(results[5]).to.contain(accounts[2].address)
      expect(results[6]).to.contain(accounts[3].address)

      const [balance1, balance2, balance3] = await Promise.all([
        accounts[1].getBalance(),
        accounts[2].getBalance(),
        accounts[3].getBalance(),
      ])

      expect(balance1).to.be.within(parseEther("9045"), parseEther("9055"))
      expect(balance2).to.be.within(parseEther("10195"), parseEther("10205"))
      expect(balance3).to.be.within(parseEther("10645"), parseEther("10655"))

      const players = await lottery6.getPlayers()

      expect(players).to.be.empty
    })
  })
})
