const assertJump = require('./helpers/assertJump');
var OmegaToken = artifacts.require("./tokens/OmegaToken.sol");

contract('OmegaToken', 
  function(accounts) 
    {
    const TOTAL_TOKENS = 900000 * 10**18
    const MAX_TOKENS_SOLD = 2000000
    const PREASSIGNED_TOKENS = 1000000 * 10**18

    const crowdsaleControllerAddress = accounts[2];
    const multiSigWalletAddress = accounts[1];
    const dutchAuctionAddress = accounts[2];

    let omegaToken;
    
    beforeEach(
      async () =>
      {
        // Create Omega token
        omegaToken = await OmegaToken.new(dutchAuctionAddress, multiSigWalletAddress);
      }
    );

    it(
      'Initializes with correct name, symbol, and token allocations',
      async () =>
      { 
        let name = await omegaToken.name();
        let symbol = await omegaToken.symbol();
        let totalSupply = await omegaToken.totalSupply();
        let omegaMultiSigBalance = await omegaToken.balanceOf(multiSigWalletAddress);
        let dutchAuctionBalance =  await omegaToken.balanceOf(dutchAuctionAddress);
        
        assert.equal(name, "Omega Token");
        assert.equal(symbol, "OM");
        assert.equal(totalSupply, (9000000 * 10**18));
        assert.equal(omegaMultiSigBalance, 7000000 * 10**18);
        assert.equal(dutchAuctionBalance, 2000000 * 10**18);
      }
    );

    it(
      'It reverts if dutch auction address is empty',
      async () =>
      { 
        try {
          await OmegaToken.new(0x0, multiSigWalletAddress);
        } catch(error) {
          return assertJump(error);
        }
        assert.fail('should have thrown before');
      }
    );

    it(
      'It reverts if multisig address is empty',
      async () =>
      { 
        try {
          await OmegaToken.new(dutchAuctionAddress, 0x0);
        } catch(error) {
          return assertJump(error);
        }
        assert.fail('should have thrown before');
      }
    );
});