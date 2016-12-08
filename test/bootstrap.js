var lib = require('./library.js');

// Accounts
var master = lib.web3.eth.accounts[0];
var party1 = lib.web3.eth.accounts[1];
var party2 = lib.web3.eth.accounts[2];

// Recompile and unlock all accounts
lib.recompile(function(e) {});
lib.unlockAll();

// Returns a function that prints the endowment of +token+ to +party+
var printResult = function(token, party) {
  return function() {
    var name = token.name.call();
    var val = token.balanceOf.call(party);
    console.log("Endowment of " + name + " " + val + " granted to " + party);
  };
};

// Create tokens
["USD", "DKK", "GBP"].forEach(function(ccy) {
  lib.launchToken(master, ccy, function(token) {
    // Print token address
    console.log(ccy + ": " + token.address);
    // Endow parties with tokens
    token.endow(party1, 9999999, { from: master, value: 0, gas: 1000000 });
    token.endow(party2, 9999999, { from: master, value: 0, gas: 1000000 });
    // Print results (allow time for sufficient mining to occur)
    setTimeout(printResult(token, party1), 60000);
    setTimeout(printResult(token, party2), 60000);
  });
});

// Create feed
lib.launchFeed(master, function(feed) {
  // Print token address
  console.log("Feed: " + feed.address);
  // Add value to feed
  var blockNum = lib.web3.eth.blockNumber;
  var minedOn = lib.web3.eth.getBlock(blockNum).timestamp;
  feed.set(lib.web3.sha3("launchedOn"), minedOn, { from: master, value: 0, gas: 1000000 });
  // Print results (allow time for sufficient mining to occur)
  setTimeout(function() {
    var launchedOn = feed.get.call(lib.web3.sha3("launchedOn"));
    console.log("Feed launched on: " + launchedOn);
  }, 60000);
});

// For testing:
// lib.web3.personal.unlockAccount(master, "123456");
// var token = lib.CurrencyToken.at("0xc5be00480f5bd3d38e665d4ae347116b31ca1685");
// console.log(token.balanceOf.call(party1).toString());
