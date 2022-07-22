import { HOUR } from "./utils/constants"

export interface networkConfigItem {
  name?: string
  subscriptionId?: string
  keyHash?: string
  keepersUpdateInterval?: string
  raffleEntranceFee?: string
  callbackGasLimit?: string
  vrfCoordinatorV2?: string
  randomNumberCount?: number
}

export interface networkConfigInfo {
  [key: number]: networkConfigItem
}

export const networkConfig: networkConfigInfo = {
  31337: {
    name: "localhost",
    subscriptionId: "8527",
    keyHash:
      "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc", // 30 gwei
    keepersUpdateInterval: (HOUR / 2).toString(),
    raffleEntranceFee: "100000000000000000", // 0.1 ETH
    callbackGasLimit: "1000000", // 500,000 gas
    vrfCoordinatorV2: "0x6168499c0cFfCaCD319c818142124B7A15E857ab",
    randomNumberCount: 50,
  },
  4: {
    name: "rinkeby",
    subscriptionId: "8527",
    keyHash:
      "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc", // 30 gwei
    keepersUpdateInterval: (HOUR / 2).toString(),
    raffleEntranceFee: "100000000000000000", // 0.1 ETH
    callbackGasLimit: "500000", // 500,000 gas
    vrfCoordinatorV2: "0x6168499c0cFfCaCD319c818142124B7A15E857ab",
    randomNumberCount: 15,
  },
  1: {
    name: "mainnet",
    keepersUpdateInterval: "30",
  },
}

export const developmentChains = ["hardhat", "localhost"]
