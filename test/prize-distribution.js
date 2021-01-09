const PrizeDistribution = artifacts.require("PrizeDistribution");
const _ = require("lodash");

contract("PrizeDistribution", accounts => {

  const BigNumber = web3.utils.BN;

  const createCompetition = async (
    blockNumber,
    approvalRate,
    distribution1,
    distribution2,
    distribution3,
    distribution4,
    distribution5,
    startBlock,
    endBlock
  ) => {
    await this.prizeDistribution.createCompetition(
      "Vega Trading Competition",
      "GBP/USD Feb 21",
      web3.utils.toWei("0.1"),
      approvalRate || approvalRate == 0 ? new BigNumber(approvalRate) : new BigNumber(66),
      startBlock ? new BigNumber(startBlock) : new BigNumber(blockNumber + 5),
      endBlock ? new BigNumber(endBlock) : new BigNumber(blockNumber + 10),
      [
        distribution1 ? new BigNumber(distribution1) : new BigNumber(45),
        distribution2 ? new BigNumber(distribution2) : new BigNumber(30),
        distribution3 ? new BigNumber(distribution3) : new BigNumber(15),
        distribution4 ? new BigNumber(distribution4) : new BigNumber(7),
        distribution5 ? new BigNumber(distribution5) : new BigNumber(3)
      ]
    );
  };

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
      await createCompetition(blockNumber);
      const competition = await this.prizeDistribution.getCompetition.call(0);
      assert.equal(competition[0], "Vega Trading Competition");
      assert.equal(competition[1], accounts[0]);
      assert.equal(competition[2], "GBP/USD Feb 21");
      assert.equal(competition[3].toNumber(), 0);
      assert.equal(competition[4].toNumber(), 66);
      assert.equal(web3.utils.fromWei(competition[5]), 0.1);
      assert.equal(competition[6].toNumber(), blockNumber + 5);
      assert.equal(competition[7].toNumber(), blockNumber + 10);
      assert.equal(competition[8], false);
      assert.equal(competition[9], false);
    }
  );

  it("should not create competition with invalid prize distribution",
    async () => {
      try {
        const blockNumber = await web3.eth.getBlockNumber();
        await createCompetition(blockNumber, null, null, null, null, null, 4);
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The prize distribution must total 100%."), true);
      }
    }
  );

  it("should not create competition with approval rate of zero",
    async () => {
      try {
        const blockNumber = await web3.eth.getBlockNumber();
        await createCompetition(blockNumber, 0, null, null, null, null, null);
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The distribution approval rate must be greater than zero."), true);
      }
    }
  );

  it("should not create competition with approval rate over 100",
    async () => {
      try {
        const blockNumber = await web3.eth.getBlockNumber();
        await createCompetition(blockNumber, 101, null, null, null, null, null);
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The distribution approval rate must be less than or equal to 100."), true);
      }
    }
  );

  it("should not create competition with start block in the past",
    async () => {
      try {
        const blockNumber = await web3.eth.getBlockNumber();
        await createCompetition(blockNumber, null, null, null, null, null, null, blockNumber - 1);
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The start block must be after the current block."), true);
      }
    }
  );

  it("should not create competition with end block before start block",
    async () => {
      try {
        const blockNumber = await web3.eth.getBlockNumber();
        await createCompetition(blockNumber, null, null, null, null, null, null, blockNumber + 5, blockNumber + 3);
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The end block must be after the start block."), true);
      }
    }
  );

  it("should fail to get an invalid competition by ID",
    async () => {
      try {
        await this.prizeDistribution.getCompetition(999);
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The competition does not exist."), true);
      }
    }
  );

  it("should get competition count",
    async () => {
      const count = await this.prizeDistribution.getCompetitionCount();
      assert.equal(count.toNumber(), 1);
    }
  );

  it("should fail to cancel non-existent competition",
    async () => {
      try {
        await this.prizeDistribution.cancelCompetition(999);
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The competition does not exist."), true);
      }
    }
  );

  it("should fail to cancel competition when not owner",
    async () => {
      try {
        await this.prizeDistribution.cancelCompetition(0, {
          from: accounts[1]
        });
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "Only the owner of a competition can cancel it."), true);
      }
    }
  );

  it("should fail to cancel competition when already started",
    async () => {
      try {
        await this.prizeDistribution.cancelCompetition(0, {
          from: accounts[0]
        });
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "You cannot cancel the competition because it has already started."), true);
      }
    }
  );

  it("should cancel competition when owner",
    async () => {
      const blockNumber = await web3.eth.getBlockNumber();
      createCompetition(blockNumber);
      await this.prizeDistribution.cancelCompetition(1, {
        from: accounts[0]
      });
      const competition = await this.prizeDistribution.getCompetition.call(1);
      assert.equal(competition[9], true);
    }
  );

  it("should fail to cancel competition when already canceled",
    async () => {
      try {
        await this.prizeDistribution.cancelCompetition(1, {
          from: accounts[0]
        });
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The competition has already been canceled."), true);
      }
    }
  );

  it("should allow player to enter competition",
    async() => {
      const blockNumber = await web3.eth.getBlockNumber();
      await createCompetition(blockNumber);
      await this.prizeDistribution.enterCompetition(2, {
        from: accounts[0],
        value: web3.utils.toWei("0.1")
      });
      const competition = await this.prizeDistribution.getCompetition.call(2);
      assert.equal(competition[3].toNumber(), 1);
      assert.equal(0.1, web3.utils.fromWei(
        await web3.eth.getBalance(this.prizeDistribution.address)
      ));
    }
  );

  it("should not allow player to enter competition more than once",
    async() => {
      try {
        await this.prizeDistribution.enterCompetition(2, {
          from: accounts[0],
          value: web3.utils.toWei("0.1")
        });
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "You have already entered this competition."), true);
      }
    }
  );

  it("should not allow player to enter competition with incorrect fee",
    async() => {
      try {
        await this.prizeDistribution.enterCompetition(2, {
          from: accounts[1],
          value: web3.utils.toWei("0.099")
        });
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "You must deposit the exact entry fee in Ether."), true);
      }
    }
  );

  it("should not allow player to enter non-existent competition",
    async() => {
      try {
        await this.prizeDistribution.enterCompetition(999, {
          from: accounts[1],
          value: web3.utils.toWei("0.1")
        });
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The competition does not exist."), true);
      }
    }
  );

  it("should not allow player to enter canceled competition",
    async() => {
      try {
        await this.prizeDistribution.enterCompetition(1, {
          from: accounts[1],
          value: web3.utils.toWei("0.1")
        });
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "This competition has been canceled."), true);
      }
    }
  );

  it("should not allow player to enter started competition",
    async() => {
      try {
        await this.prizeDistribution.enterCompetition(0, {
          from: accounts[1],
          value: web3.utils.toWei("0.1")
        });
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "This competition has already started."), true);
      }
    }
  );

  it("should return fee when competition is canceled",
    async() => {
      const blockNumber = await web3.eth.getBlockNumber();
      await createCompetition(blockNumber);
      await this.prizeDistribution.enterCompetition(3, {
        from: accounts[0],
        value: web3.utils.toWei("0.1")
      });
      assert.equal(0.2, web3.utils.fromWei(
        await web3.eth.getBalance(this.prizeDistribution.address)
      ));
      await this.prizeDistribution.cancelCompetition(3, {
        from: accounts[0]
      });
      await this.prizeDistribution.returnEntryFee(3, accounts[0]);
      assert.equal(0.1, web3.utils.fromWei(
        await web3.eth.getBalance(this.prizeDistribution.address)
      ));
    }
  );

  it("should not return fee when competition doesn't exist",
    async() => {
      try {
        await this.prizeDistribution.returnEntryFee(999, accounts[0]);
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The competition does not exist."), true);
      }
    }
  );

  it("should not return fee when already returned to player",
    async() => {
      try {
        await this.prizeDistribution.returnEntryFee(3, accounts[0]);
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "There is nothing to return to this player."), true);
      }
    }
  );

  it("should not return fee when competition is not canceled",
    async() => {
      try {
        await this.prizeDistribution.returnEntryFee(2, accounts[0]);
        assert.fail();
      } catch(e) {
        assert.equal(_.includes(JSON.stringify(e),
          "The competition has not been canceled."), true);
      }
    }
  );
});
