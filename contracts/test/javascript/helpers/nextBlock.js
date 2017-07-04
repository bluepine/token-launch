// timer for tests specific to testrpc
module.exports = () => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0', 
      method: 'evm_mine',
      id: new Date().getTime() // Id of the request; anything works, really
    }, function(err) {
      if (err) return reject(err);
      resolve();
    });
  // setTimeout(() => resolve(), s * 1000 + 600) // 600ms breathing room for testrpc to sync
  });
};
