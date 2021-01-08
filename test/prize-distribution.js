const PrizeDistribution = artifacts.require("PrizeDistribution");

contract("PrizeDistribution", accounts => {
  before(async () => {
    this.prizeDistribution = await PrizeDistribution.new(web3.utils.toWei("5"));
  });
  it("should init the PrizeDistribution contract correctly", async () => {
    const commissionRate = await this.prizeDistribution.getCommissionRate.call();
    assert.equal(commissionRate, web3.utils.toWei("5"));
  });
});
