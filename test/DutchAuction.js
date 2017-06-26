const assertJump = require('./helpers/assertJump');
const nextBlock = require('./helpers/nextBlock');
const timer = require('./helpers/timer');
const BigNumber = require('bignumber.js');

// var MultiSigWallet = artifacts.require("./Wallets/MultiSigWallet.sol");
var DutchAction = artifacts.require("./DutchAuction/DutchAuction.sol");
var OmegaToken = artifacts.require("./Tokens/OmegaToken.sol");
// var CrowdsaleController = artifacts.require("./CrowdsaleController.sol");

contract('DutchAuction', 
  function(accounts) 
    {
    const BLOCKS_PER_DAY = 5760
    const TOTAL_TOKENS = 900000 * 10**18
    const MAX_TOKENS_SOLD = 2000000
    const PREASSIGNED_TOKENS = 1000000 * 10**18
    const WAITING_PERIOD = 60*60*24*7
    const MAX_GAS = 150000  // Kraken gas limit
    const crowdsaleControllerAddress = accounts[2];
    const multiSigWalletAddress = accounts[1];
    const owner = accounts[0];

    let FUNDING_GOAL = 250000 * 10**18
    let PRICE_FACTOR = 4000
    let currentBlock;
    let startBlock;
    let tokenPrice;
    let currentStage;

    let dutchAuction;
    let omegaToken;
    
    before(
      async () =>
      {
        // Create dutchAuction
        dutchAuction = await DutchAction.new(crowdsaleControllerAddress, multiSigWalletAddress, 250000 * 10 ** 18, PRICE_FACTOR);
        // Create Omega token
        omegaToken = await OmegaToken.new(dutchAuction.address, multiSigWalletAddress);
      }
    );

    it(
      'Sets up dutch auction',
      async () =>
      {
        await dutchAuction.setup(omegaToken.address);
      }
    );

    it(
      'Checks initial parameters',
      async () =>
      {
        let ceiling = await dutchAuction.ceiling();
        let priceFactor = await dutchAuction.priceFactor();
        assert.equal(ceiling, FUNDING_GOAL);
        assert.equal(priceFactor, PRICE_FACTOR);
      }
    );

    it(
      'Changes funding goals',
      async () =>
      {
        FUNDING_GOAL = 260000 * 10**18;
        PRICE_FACTOR = 5000;
        await dutchAuction.changeSettings(FUNDING_GOAL, PRICE_FACTOR, {from: multiSigWalletAddress})
        let ceiling = await dutchAuction.ceiling();
        let priceFactor = await dutchAuction.priceFactor();

        assert.equal(ceiling, FUNDING_GOAL);
        assert.equal(priceFactor, PRICE_FACTOR);
      }
    );

    it(
      'Starts dutch auction',
      async () =>
      {
        await dutchAuction.startAuction({from: multiSigWalletAddress});
        startBlock = await dutchAuction.startBlock();
        let currentStage = await dutchAuction.stage();

        currentBlock = web3.eth.blockNumber;
        let startStage = 2;
        assert.equal(startBlock, currentBlock);
        assert.equal(currentStage, startStage);
      }
    );

    it(
      'After auction started, funding goal cannot be changed anymore',
      async () =>
      {
        try { 
          await dutchAuction.changeSettings(FUNDING_GOAL, PRICE_FACTOR, {from: multiSigWalletAddress}) 
        } catch(error) {
          return assertJump(error);
        }
        assert.fail('should have thrown before');
      }
    );

    it(
      'Setups cannot be done twice',
      async () =>
      {
        try { 
          await dutchAuction.setup(omegaToken.address);
        } catch(error) {
          return assertJump(error);
        }
        assert.fail('should have thrown before');
      }
    );

    it(
      'Bidder 1 places a bid in the first block after auction starts',
      async () =>
      {
        let bidder1 = accounts[0];
        let value1 = 100000 * 10 ** 18;  // 100k Ether

        //Checks token start price
        tokenPrice = await dutchAuction.calcTokenPrice();
        currentBlock = web3.eth.blockNumber;
        assert.equal(tokenPrice, PRICE_FACTOR * 10 ** 18 / (currentBlock - startBlock + 7500) + 1)

        await dutchAuction.bid(bidder1, {value: value1})
        let stopPrice = await dutchAuction.calcStopPrice();
        let totalReceived = await dutchAuction.totalReceived();
        tokenPrice = await dutchAuction.calcTokenPrice();
        currentBlock = web3.eth.blockNumber;

        assert.equal(totalReceived, value1);
        assert.equal(stopPrice, new BigNumber(value1).dividedBy(MAX_TOKENS_SOLD).toNumber() + 1);
        // As blocks are mines token price changes
        assert.equal(tokenPrice, PRICE_FACTOR * 10 ** 18 / (currentBlock - startBlock + 7500) + 1);
      }
    );

    it(
      'Spender accidentally defines dutch auction contract as receiver',
      async () =>
      {
        let bidder2 = accounts[2];
        let value2 = 100000 * 10 ** 18;  // 100k Ether
        try {
          await dutchAuction.bid(dutchAuction.address, {value: value2})
        } catch(error) {
          return assertJump(error);
        }
        assert.fail('should have thrown before');
      }
    );

    it(
      'Spender accidentally defines omega token contract as receiver',
      async () =>
      {
        let bidder2 = accounts[2];
        let value2 = 100000 * 10 ** 18;  // 100k Ether
        try {
          await dutchAuction.bid(omegaToken.address, {value: value2});
        } catch(error) {
          return assertJump(error);
        }
        assert.fail('should have thrown before');
      }
    );

    it(
      'Spender places a bid in the name of bidder 2',
      async () =>
      {
        let bidder2 = accounts[2];
        let value1 = 100000 * 10 ** 18;  // 100k Ether
        let value2 = 100000 * 10 ** 18;  // 100k Ether
        
        await dutchAuction.bid(bidder2, {value: value2})
        let stopPrice = await dutchAuction.calcStopPrice();
        let totalReceived = await dutchAuction.totalReceived();
        tokenPrice = await dutchAuction.calcTokenPrice();
        currentBlock = web3.eth.blockNumber;

        assert.equal(totalReceived, value1 + value2);
        assert.equal(stopPrice, new BigNumber(value1 + value2).dividedBy(MAX_TOKENS_SOLD).toNumber() + 1);
        assert.equal(tokenPrice, PRICE_FACTOR * 10 ** 18 / (currentBlock - startBlock + 7500) + 1);
      }
    );

    it(
      'Spender places a bid in the name of bidder 3 finishing the auction',
      async () =>
      {
        let bidder3 = accounts[3];
        let initialBalance3 = web3.eth.getBalance(bidder3);
        let value1 = 100000 * 10 ** 18;  // 100k Ether
        let value2 = 100000 * 10 ** 18;  // 100k Ether
        let value3 = 100000 * 10 ** 18;  // 100k Ether

        await dutchAuction.bid(bidder3, {value: value3})
        let stopPrice = await dutchAuction.calcStopPrice();
        let finalPrice =  await dutchAuction.finalPrice();
        let totalReceived = await dutchAuction.totalReceived();
        tokenPrice = await dutchAuction.calcTokenPrice();
        currentBalance3 = web3.eth.getBalance(bidder3);
        currentBlock = web3.eth.blockNumber;
        currentStage = await dutchAuction.stage();

        refundBidder3 = value3*.6
        // Verifies that bidder3 received a refund
        assert.equal(currentBalance3 - value3, initialBalance3 - refundBidder3);
        assert.equal(stopPrice, new BigNumber(totalReceived).dividedBy(MAX_TOKENS_SOLD).toNumber() + 1);
        // Final price is equal to stop price
        assert.equal(finalPrice, tokenPrice.toNumber());
        assert.equal(web3.eth.getBalance(dutchAuction.address), 0);
        assert.equal(currentStage, 3);
      }
    );

    it(
      'Once auction is over, trading cannot begin for 1 week',
      async () =>
      {
        let bidder3 = accounts[3];
        let days = 6;
        await timer(days);
        try {
          await dutchAuction.claimTokens(accounts[3]);
        } catch(error) {
          return assertJump(error);
        }
        assert.fail('should have thrown before');
      }
    ); 

    it(
      'After 1 week buyers are able claim their tokens and trading begins',
      async () =>
      {
        let finalPrice = await dutchAuction.finalPrice();
        let bidder1 = accounts[0];
        let value1 = 100000 * 10 ** 18;  // 100k Ether;
        let days = 2;
        await timer(days);

        await dutchAuction.claimTokens(bidder1);
        let bidder1Balance = await omegaToken.balanceOf(bidder1);
        currentStage = await dutchAuction.stage();

        assert.equal(bidder1Balance, value1 * 10 ** 18 / finalPrice);
        assert.equal(currentStage, 4);
      }
    );


});