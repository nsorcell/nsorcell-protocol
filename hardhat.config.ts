import "@nomicfoundation/hardhat-toolbox"
import "dotenv/config"
import "hardhat-deploy"
import { HardhatUserConfig } from "hardhat/config"

const PRIVATE_KEY = process.env.PRIVATE_KEY

// Ethereum
const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL ?? ""
const RINKEBY_RPC_URL = process.env.RINKEBY_RPC_URL ?? ""

// Polygon
const POLYGON_MAINNET_RPC_URL = process.env.POLYGON_MAINNET_RPC_URL ?? ""
const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL ?? ""

// Services
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY ?? ""
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY ?? ""

const config: HardhatUserConfig = {
  paths: {
    sources: "./contracts",
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      // // If you want to do some forking, uncomment this
      // forking: {
      //   url: MAINNET_RPC_URL
      // }
      chainId: 31337,
    },
    localhost: {
      chainId: 31337,
    },
    rinkeby: {
      url: RINKEBY_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      saveDeployments: true,
      chainId: 4,
    },
    mainnet: {
      url: MAINNET_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      saveDeployments: true,
      chainId: 1,
    },
    polygon: {
      url: POLYGON_MAINNET_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      saveDeployments: true,
      chainId: 137,
    },
    mumbai: {
      url: MUMBAI_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      saveDeployments: true,
      chainId: 80001,
    },
  },
  etherscan: {
    // npx hardhat verify --network <NETWORK> <CONTRACT_ADDRESS> <CONSTRUCTOR_PARAMETERS>
    apiKey: {
      mainnet: ETHERSCAN_API_KEY,
      rinkeby: ETHERSCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY,
      mumbai: POLYGONSCAN_API_KEY,
    },
  },
  gasReporter: {
    enabled: false,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
    // coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.9",
      },
    ],
  },
  mocha: {
    timeout: 200000, // 200 seconds max for running tests
  },
}

export default config
