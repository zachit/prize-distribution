const PrizeDistribution = artifacts.require("PrizeDistribution");

contract("PrizeDistribution", accounts => {

  const BigNumber = web3.utils.BN;

  before(async () => {
    this.prizeDistribution = await PrizeDistribution.new(web3.utils.toWei("5"));
  });

  it("should init the PrizeDistribution contract correctly",
    async () => {
      const commissionRate = await this.prizeDistribution.getCommissionRate.call();
      assert.equal(commissionRate, web3.utils.toWei("5"));
    }
  );

  it("should create a new competition",
    async() => {
      const blockNumber = await web3.eth.getBlockNumber();
      await this.prizeDistribution.createCompetition(
        "Vega Trading Competition",
        "GBP/USD Feb 21",
        web3.utils.toWei("0.1"),
        new BigNumber(66),
        new BigNumber(blockNumber),
        new BigNumber(blockNumber + 10),
        new BigNumber(45),
        new BigNumber(30),
        new BigNumber(15),
        new BigNumber(7),
        new BigNumber(3)
      );
      const competition = await this.prizeDistribution.getCompetition.call(0);
      assert.equal(competition[0], "Vega Trading Competition");
      assert.equal(competition[1], accounts[0]);
      assert.equal(competition[2], "GBP/USD Feb 21");
      assert.equal(competition[3].toNumber(), 0);
      assert.equal(competition[4].toNumber(), 66);
      assert.equal(web3.utils.fromWei(competition[5]), 0.1);
      assert.equal(competition[6].toNumber(), blockNumber);
      assert.equal(competition[7].toNumber(), blockNumber + 10);
      assert.equal(competition[8], false);
      assert.equal(competition[9], false);
    }
  );

  it("should not create competition with invalid prize distribution",
    async () => {
      const blockNumber = await web3.eth.getBlockNumber();
      try {
        await this.prizeDistribution.createCompetition(
          "Vega Trading Competition",
          "GBP/USD Feb 21",
          web3.utils.toWei("0.1"),
          new BigNumber(66),
          new BigNumber(blockNumber),
          new BigNumber(blockNumber + 10),
          new BigNumber(45),
          new BigNumber(30),
          new BigNumber(15),
          new BigNumber(7),
          new BigNumber(4)
        );
      } catch(e) {
        assert.equal(e.reason, "The prize distribution must total 100%.");
      }
    }
  );
});
