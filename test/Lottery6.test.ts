import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import { deployments, ethers, network } from "hardhat"
import { Lottery6 } from "typechain-types"
import { developmentChains } from "../helper-hardhat.config"

describe("Lottery6", function () {
  let deployer: SignerWithAddress, lottery6: Lottery6
  beforeEach(async () => {
    if (!developmentChains.includes(network.name)) {
      throw "You need to be on a development chain to run tests."
    }

    const accounts = await ethers.getSigners()
    deployer = accounts[0]

    await deployments.fixture(["all"])

    lottery6 = await ethers.getContract("Lottery6")
  })

  describe("constructor", () => {})

  describe("enter", () => {
    it("should store the player, entering the lottery", async () => {
      const luckyNumbers = [1, 2, 3, 4, 5, 6]

      await lottery6.enter(luckyNumbers)
      const storedNumbers = await lottery6.getPlayerNumbers(deployer.address)

      expect(storedNumbers).to.eq(storedNumbers)
    })
  })
})
