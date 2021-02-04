const HDWalletProvider = require("truffle-hdwallet-provider");
const fs = require('fs');
const mnemonic = fs.readFileSync(".secret").toString().trim();
const infura = fs.readFileSync(".infura").toString().trim();

module.exports = {
  networks: {
    ropsten: {
      provider: function() {
        return new HDWalletProvider(mnemonic,
          "https://ropsten.infura.io/v3/" + infura)
      },
      network_id: 3,
      gas: 4000000
    }
  },
  plugins: ["solidity-coverage"]
};
