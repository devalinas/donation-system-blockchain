import { HardhatUserConfig } from 'hardhat/config';
import "@nomicfoundation/hardhat-toolbox";
import dotenv from 'dotenv';
dotenv.config();

const PRIVATE_KEY = process.env.PRIVATE_KEY || "";
const INFURA_API_KEY = process.env.INFURA_KEY || "";
const COINMARKETCAP_KEY = process.env.COINMARKETCAP_KEY || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";

const config : HardhatUserConfig = {

  solidity: {
    version: '0.8.25',
    settings: {
      optimizer: {
        enabled: true, 
        runs: 200
      },
      evmVersion: 'shanghai',
    },
  },
  typechain: {
    outDir: 'typechain-types',
    target: 'ethers-v6',
  },
  // defaultNetwork: "mainnet",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: 'https://ethereum-sepolia.blockpi.network/v1/rpc/public'
      },
      chainId: 11155111,
      allowUnlimitedContractSize: true
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      // accounts: [`0x${PRIVATE_KEY}`],
    },
    sepolia: {
      url: 'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
      chainId: 11155111,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    mainnet: {
      url: 'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
      // accounts: [`0x${PRIVATE_KEY}`],
    },
  },
  mocha: {
    timeout: 200000
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  gasReporter: {
    enabled: true,
    currency: 'USD',
    coinmarketcap: COINMARKETCAP_KEY
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  }
};

export default config;
