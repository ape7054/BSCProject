require('dotenv').config();
const HDWalletProvider = require('@truffle/hdwallet-provider');

// 创建.env文件并添加以下变量
// MNEMONIC=您的助记词
// BSC_API_KEY=您的BSC API密钥

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*"
    },
    bscTestnet: {
      provider: () => new HDWalletProvider(
        process.env.MNEMONIC,
        `https://data-seed-prebsc-1-s1.binance.org:8545`
      ),
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    bsc: {
      provider: () => new HDWalletProvider(
        process.env.MNEMONIC,
        `https://bsc-dataseed1.binance.org`
      ),
      network_id: 56,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    }
  },
  compilers: {
    solc: {
      version: "0.8.19",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    bscscan: process.env.BSC_API_KEY
  }
};