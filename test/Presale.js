'use strict';

const assertJump = require('./helpers/assertJump');
var Presale = artifacts.require('./Presale/Presale.sol');

contract('StandardToken', function(accounts) {
  let presale;

  beforeEach(async () => {
    presale = await Presale.new();
  });

  it("should return the correct totalSupply after construction", async function() {
    // let totalSupply = await token.totalSupply();
    // assert.equal(totalSupply, 100);
  })

});