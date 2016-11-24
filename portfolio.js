var lib = require('./library.js');

// Configure based on output from +node bootstrap.js+
var addressUSD = "0x5f3b2984a6b015c6125975bef2b547a30da8f0cd";
var addressDKK = "0xa970e4d242e36edf46e0b999156e154ffb3a079c";
var addressGBP = "0xc79ccc291b89aa5aa24f40f5fe7f6d02512eaf0d";
var addressFeed = "0x6b5986b039c3148e46303f2d12d705839093f6ac";

// Intermediate values (populate as executing steps)
var addressEngine = "0xe2b55cde02c98f8550fc0bf25459f06d5bcc0e36";
var contractIds = [6];
var agreementIds = [0];

// Recompile and unlock all accounts
lib.recompile(function(e) {});
lib.unlockAll();

// Accounts
var master = lib.web3.eth.accounts[0];
var party1 = lib.web3.eth.accounts[1];
var party2 = lib.web3.eth.accounts[2];

// Creates the engine
var createEngine = function() {
  lib.launchContractEngine(master, function(engine) {
    console.log("Engine: " + engine.address);
  });
}

// Creates some contracts within the engine
var createPortfolio = function() {
  var engine = lib.ContractEngine.at(addressEngine);
  var t = Math.floor(Date.now() / 1000) + 60*60*24;
  engine.fxForwardContract("X", "Y", "USD", "DKK", t, 10000, 7, { from: master, gas: 10000000 }, function(e, tx) {
    if (e) { console.log(e); return; }
    var events = engine.allEvents("latest", function(err, event) {
      if (event.transactionHash == tx) {
        console.log(event.args.contractId.toString());
        events.stopWatching();
      }
    });
  });
}

// Registers the contracts
var registerPortfolio = function() {
  var engine = lib.ContractEngine.at(addressEngine);
  contractIds.forEach(function(contractId) {
    engine.register(contractId, "X", party1, "Y", party2, "USD", addressUSD, "DKK", addressDKK, "Feed", addressFeed, { from: master, gas: 10000000 }, function(e, tx) {
      if (e) { console.log(e); return; }
      var events = engine.allEvents("latest", function(err, event) {
        if (event.transactionHash == tx) {
          console.log(event.args.agreementId.toString());
          events.stopWatching();
        }
      });
    });
  });
}

// Signs the contracts in the engine
var signPortfolio = function() {
  var engine = lib.ContractEngine.at(addressEngine);
  agreementIds.forEach(function(agreementId) {
    [party1, party2].forEach(function(party) {
      engine.sign(agreementId, { from: party, gas: 10000000 }, function(e, tx) {
        if (e) { console.log(e); return; }
        var events = engine.allEvents("latest", function(err, event) {
          if (event.transactionHash == tx) {
            console.log(event.args.agreementId.toString() + " == " + agreementId + " ==> signed!");
            events.stopWatching();
          }
        });
      });
    });
  });
}

//
var evaluatePortfolio = function() {
  // Call evaluate on contracts, print all transfers that transpire
}

//
var debug = function() {
  var engine = lib.ContractEngine.at(addressEngine);
  console.log(engine.exprs(0));
}

// Do:
// createEngine();
// createPortfolio();
// registerPortfolio();
// signPortfolio();
// evaluatePortfolio()

debug();
