const assertJump = require('./helpers/assertJump');
var OmegaToken = artifacts.require("./tokens/OmegaToken.sol");
var CrowdsaleController = artifacts.require("./CrowdsaleController.sol");

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
        crowdsaleController = await CrowdsaleController.new(multiSigWalletAddress);
        dutchAuction = await DutchAction.new(crowdsaleController.address, multiSigWalletAddress, 250000 * 10 ** 18, PRICE_FACTOR);
        // omegaToken = await OmegaToken.new(dutchAuctionAddress, multiSigWalletAddress);
      }
    );

    it(
      'Initializes with correct name, symbol, and token allocations',
      async () =>
      { 
        crowdsaleController.setup();
      }
    );
});