var lib = require('./library.js');

// Configure based on output from +node bootstrap.js+
var addressUSD = "0x5f3b2984a6b015c6125975bef2b547a30da8f0cd";
var addressDKK = "0xa970e4d242e36edf46e0b999156e154ffb3a079c";
var addressGBP = "0xc79ccc291b89aa5aa24f40f5fe7f6d02512eaf0d";
var addressFeed = "0x6b5986b039c3148e46303f2d12d705839093f6ac";

// Intermediate values (populate as executing steps)
var addressEngine = "0x856359d58565f41808a7fe66148dba3d987dae14";
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
  var t = Math.floor(Date.now() / 1000) + 60; // *60*24
  engine.fxForwardContract("X", "Y", "USD", "DKK", t, 10000, 7, { from: master, gas: 10000000 }, function(e, tx) {
    if (e) { console.log(e); return; }
    var events = engine.allEvents("latest", function(err, event) {
      if (event.transactionHash == tx) {
        console.log(event.args.contractId.toString());
        events.stopWatching();
        // registerPortfolio();
      }
    });
  });
}

// Registers the contracts
var registerPortfolio = function() {
  var engine = lib.ContractEngine.at(addressEngine);
  contractIds.forEach(function(contractId) {
    engine.register(contractId, "X", party1, "Y", party2, "USD", addressUSD, "DKK", addressDKK, "Feed", addressFeed, { from: master, gas: 10000000 }, function(e, tx) {
      console.log(tx);
      if (e) { console.log(e); return; }
      var events = engine.allEvents("latest", function(err, event) {
        if (event.transactionHash == tx) {
          console.log(event.args.agreementId.toString());
          // console.log(event);
          events.stopWatching();
        }
      });
    });
  });
}

// Signs the contracts in the engine
var permitEngine = function(party) {
  var engine = lib.ContractEngine.at(addressEngine);
  var usd = lib.CurrencyToken.at(addressUSD);
  var dkk = lib.CurrencyToken.at(addressDKK);
  var gbp = lib.CurrencyToken.at(addressDKK);
  [usd, dkk, gbp].forEach(function(ccy) {
    ccy.permit(addressEngine, true, { from: party1, gas: 10000000 }, function(e, tx) {
      if (e) { console.log(e); return; }
    });
    ccy.permit(addressEngine, true, { from: party2, gas: 10000000 }, function(e, tx) {
      if (e) { console.log(e); return; }
    });
  });
}

// Signs the contracts in the engine
var signPortfolio = function(party) {
  var engine = lib.ContractEngine.at(addressEngine);
  agreementIds.forEach(function(agreementId) {
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
}

// Signs the contracts in the engine
var killPortfolio = function(party) {
  var engine = lib.ContractEngine.at(addressEngine);
  agreementIds.forEach(function(agreementId) {
    engine.kill(agreementId, { from: party, gas: 10000000 }, function(e, tx) {
      if (e) { console.log(e); return; }
      var events = engine.allEvents("latest", function(err, event) {
        if (event.transactionHash == tx) {
          console.log(event.args.agreementId.toString() + " == " + agreementId + " ==> killed!");
          events.stopWatching();
        }
      });
    });
  });
}

//
var evaluatePortfolio = function() {
  var engine = lib.ContractEngine.at(addressEngine);
  agreementIds.forEach(function(agreementId) {
    engine.evaluate(agreementId, { from: party1, gas: 10000000 }, function(e, tx) {
      console.log("Transaction: " + tx);
      if (e) { console.log(e); return; }
      var events1 = engine.allEvents("latest", function(err, event) {
        if (event.transactionHash == tx) {
          console.log(event);
          events1.stopWatching();
        }
      });
      var usd = lib.CurrencyToken.at(addressUSD);
      var events2 = usd.allEvents("latest", function(err, event) {
        if (event.transactionHash == tx) {
          console.log(event);
          events2.stopWatching();
        }
      });
    });
  });


  // Call evaluate on contracts, print all transfers that transpire
}

//
var debug = function() {
  // var engine = lib.ContractEngine.at(addressEngine);
  var usd = lib.CurrencyToken.at(addressUSD);
  var dkk = lib.CurrencyToken.at(addressDKK);
  // console.log(usd.balanceOf(party1));
  // console.log(usd.balanceOf(party2));
  // console.log(dkk.balanceOf(party1));
  // console.log(dkk.balanceOf(party2));
  // console.log(engine.agreements(1));
  // console.log(engine.contrs(13));

  // Check permitted

  // Create tokens
  // console.log(usd.balanceOf(party1) + "< 5");
  // console.log(usd.permissions(party1, party1) + "< 5");
  // usd.transferFrom(party1, party2, 5, { from: party1, value: 0, gas: 1000000 }, function(e, tx) {
  //   console.log(tx);
  //   var events = usd.allEvents("latest", function(err, event) {
  //     if (event.transactionHash == tx) {
  //       console.log(event);
  //     }
  //   });
  // });

    var events = usd.allEvents({fromBlock:1810, toBlock:"latest"}, function(err, event) {
      console.log(event);
    });

}

// Do:
// createEngine();
// permitEngine();
// createPortfolio();
// registerPortfolio();
// signPortfolio(party1);
// signPortfolio(party2);
// killPortfolio(party1);
// killPortfolio(party2);
// evaluatePortfolio();

debug();
//

// var status = debug.traceTransaction
 // status.structLogs
