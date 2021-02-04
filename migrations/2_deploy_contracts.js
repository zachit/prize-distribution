const PrizeDistribution = artifacts.require("./PrizeDistribution.sol");

module.exports = async function(deployer, network, accounts) {
  const prizeDistribution = await PrizeDistribution.new(50, 50);
  console.log("PrizeDistribution ->", await prizeDistribution.address);
}
