const HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "trip gadget cruise pill egg volume amateur air refuse amazing helmet menu";

module.exports = {
  networks: {
    development: {
      provider: function () {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/");
      },
      host: "127.0.0.1",
      port: 8545,
      network_id: '*',
      accounts: 100,
      defaultEtherBalance: 500,
      gas: 10000000
    }
  },
  compilers: {
    solc: {
      version: "^0.4.25"
    }
  }
};