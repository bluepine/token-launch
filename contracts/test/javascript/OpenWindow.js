const assertJump = require('./helpers/assertJump');
const BigNumber = require('bignumber.js');
var OmegaToken = artifacts.require("./tokens/OmegaToken.sol");
var CrowdsaleController = artifacts.require("./CrowdsaleController.sol");
var DutchAuction = artifacts.require("./DutchAuction/DutchAuction.sol");
var OpenWindow = artifacts.require("./OpenWindow/OpenWindow.sol");

contract('OpenWindow',
  function(accounts)
    {
    const totalSupply = 1000000 * 10**18; 
    const price = 1;
    const walletAddress = accounts[1];
    const dutchAuctionAddress = accounts[2];
    const crowdsaleControllerAddress = accounts[0];

    let openWindow;
    let omegaToken;

    before(
      async () =>
      {
        // Create omega token
        omegaToken = await OmegaToken.new(dutchAuctionAddress, walletAddress);
        // Create open window sale
        openWindow = await OpenWindow.new(totalSupply, price, walletAddress, omegaToken.address, {from: crowdsaleControllerAddress});
        await omegaToken.transfer(openWindow.address, totalSupply, {from: dutchAuctionAddress})
      }
    );

    it(
      'Initializes with correct values',
      async () =>
      { 
        let owner = await openWindow.owner();
        let wallet = await openWindow.wallet();
        let actualPrice = await openWindow.price();
        let balance = await omegaToken.balanceOf(openWindow.address);
        let stage = await openWindow.stage();

        assert.equal(owner, accounts[0]);
        assert.equal(wallet, walletAddress);
        assert.equal(actualPrice, price);
        assert.equal(balance, totalSupply);
        assert.equal(stage, 0);
      }
    );

    it(
      'Spender buys tokens in the name of buyer 1',
      async () =>
      { 
        let buyer1 = accounts[4];
        let value1 = 300000 * 10 ** 18;  // 300k Ether
        // Simulates buyer sending money to the crowdsale controller
        web3.eth.sendTransaction({from:buyer1, to:crowdsaleControllerAddress, value: value1})
        let expectedTokensBought = value1 / price;
        let expectedTokenSupply = new BigNumber(totalSupply).sub(expectedTokensBought);


        await openWindow.buy(buyer1, {value: value1});
        let actualTokensBought = await openWindow.tokensBought(buyer1);
        let actualTokenSupply = await openWindow.tokenSupply();

        assert.equal(actualTokensBought, expectedTokensBought);
        assert.equal(actualTokenSupply, expectedTokenSupply.toNumber());
      }
    );

    it(
      'Spender buys tokens in the name of buyer 2',
      async () =>
      { 
        let buyer2 = accounts[5];
        let value2 = 300000 * 10 ** 18;
        // Simulates buyer sending money to the crowdsale controller
        web3.eth.sendTransaction({from:buyer2, to:crowdsaleControllerAddress, value: value2})
        let expectedTokensBought = value2 / price;
        let expectedTokenSupply = new BigNumber(totalSupply).sub(expectedTokensBought * 2);

        await openWindow.buy(buyer2, {value: value2});
        let actualTokensBought = await openWindow.tokensBought(buyer2);
        let actualTokenSupply = await openWindow.tokenSupply();

        assert.equal(actualTokensBought, expectedTokensBought);
        assert.equal(actualTokenSupply, expectedTokenSupply.toNumber());
      }
    );

    it(
      'Spender buys tokens in the name of buyer 3 finishing the sale',
      async () =>
      { 

        let buyer3 = accounts[6];
        let value1 = 300000 * 10 ** 18;
        let value2 = 300000 * 10 ** 18;
        let value3 = 500000 * 10 ** 18;
        let initialBalance3 = web3.eth.getBalance(buyer3);
        // Simulates buyer sending money to the crowdsale controller
        web3.eth.sendTransaction({from:buyer3, to:crowdsaleControllerAddress, value: value3})
        let expectedTokensBought1 = value1/price;
        let expectedTokensBought2 = value2/price;
        let expectedTokensBought = new BigNumber(totalSupply).sub(expectedTokensBought1 ).sub(expectedTokensBought2);
        
        await openWindow.buy(buyer3, {value: value3});
        let actualTokensBought = await openWindow.tokensBought(buyer3);
        let actualTokenSupply = await openWindow.tokenSupply();
        let currentBalance3 = web3.eth.getBalance(buyer3);
        let stage = await openWindow.stage();
        let refundBuyer3 = value3*.2;
        // console.log([currentBalance3, initialBalance3]);

        assert.equal(actualTokensBought, expectedTokensBought.toNumber());
        assert.equal(actualTokenSupply, 0);
        assert.equal(stage, 1);
        //need to fix refund functionality
        // assert.equal(currentBalance3 - value3, initialBalance3 - refundBuyer3);
      }
    );
  }
)
