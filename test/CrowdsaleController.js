const assertJump = require('./helpers/assertJump');
var OmegaToken = artifacts.require("./tokens/OmegaToken.sol");
var CrowdsaleController = artifacts.require("./CrowdsaleController.sol");
var DutchAuction = artifacts.require("./DutchAuction/DutchAuction.sol");

contract('CrowdsaleController', 
  function(accounts) 
    {
    const TOTAL_TOKENS = 900000 * 10**18
    const MAX_TOKENS_SOLD = 2000000
    const PREASSIGNED_TOKENS = 1000000 * 10**18

    const multiSigWalletAddress = accounts[1];
    const crowdsaleControllerAddress = accounts[2];

    let FUNDING_GOAL = 250000 * 10**18
    let PRICE_FACTOR = 4000

    let crowdsaleController;
    let dutchAuction;
    let omegaToken;
    
    before(
      async () =>
      {
        // Create Omega token
        dutchAuction = await DutchAuction.new(multiSigWalletAddress, 250000 * 10 ** 18, PRICE_FACTOR);
        crowdsaleController = await CrowdsaleController.new(multiSigWalletAddress, dutchAuction.address);
      }
    );

    it(
      'Initializes with correct values',
      async () =>
      { 
        let owner = await crowdsaleController.owner();
        let omegaMultiSig = await crowdsaleController.omegaMultiSig();
        let actualDutchAuction = await crowdsaleController.dutchAuction();
        let stage = await crowdsaleController.stage();

        assert.equal(owner, accounts[0]);
        assert.equal(omegaMultiSig, multiSigWalletAddress);
        assert.equal(actualDutchAuction, dutchAuction.address)
        assert.equal(stage, 0);
      }
    );

    it(
      "Cannot be initialized with an empy multisig wallet",
      async () =>
      {
        try {
          await await CrowdsaleController.new(0x0, dutchAuction.address);;
        } catch(error) {
          return assertJump(error);
        }
        assert.fail('should have thrown before');
      }
    );

    it(
      "Cannot be initialized with an empty dutch auction",
      async () =>
      {
        try {
          await CrowdsaleController.new(multiSigWalletAddress, 0x0);;
        } catch(error) {
          return assertJump(error);
        }
        assert.fail('should have thrown before');
      }
    );

    //add in test to check fo refund
    // it(
    //   "Refunds value sent to it without a function call",
    //   async () =>
    //   {
    //     await crowdsaleController.
    //   }
    // );
    // it(
    //   "Refunds value sent to it without a function call",
    //   async () =>
    //   {
    //     await crowdsaleController.
    //   }
    // );
});