// Requires
var childProcess = require('child_process');
var fs = require('fs');
var Web3 = require('web3');

// Instance variables
var _this = this;
var web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));

// Returns the ABI of the given contract (must be in folder +source+)
exports.getAbi = function(name) {
  return JSON.parse(fs.readFileSync('./source/' + name + '.abi', 'utf8'));
}

// Returns the binary code of the given contract (must be in folder +source+)
exports.getCode = function(name) {
  return "0x" + fs.readFileSync('./source/' + name + '.bin', 'utf8');
}

// Object for ContractEngine
exports.ContractEngine = (function() {
  var contract = web3.eth.contract(_this.getAbi('ContractEngine'));
  return contract;
})();

// Object for CurrencyToken
exports.CurrencyToken = (function() {
  var contract = web3.eth.contract(_this.getAbi('CurrencyToken'));
  return contract;
})();

// Object for SimpleFeed
exports.SimpleFeed = (function() {
  var contract = web3.eth.contract(_this.getAbi('SimpleFeed'));
  return contract;
})();

// Launches a token with the given name and creator
exports.launchContractEngine = function(creator, cb) {
  var contract = _this.ContractEngine;
  var code = _this.getCode('ContractEngine');
  var token = contract.new({from: creator, data: code, gas: 10000000}, function(e, contract) {
    if (e)                      { console.log("Error launching engine:" + e); }
    else if (!contract.address) { console.log("Engine waiting to be mined..."); }
    else                        { cb(contract); }
  });
}

// Launches a token with the given name and creator
exports.launchFeed = function(creator, cb) {
  var contract = _this.SimpleFeed;
  var code = _this.getCode('SimpleFeed');
  var token = contract.new({from: creator, data: code, gas: 1000000}, function(e, contract) {
    if (e)                      { console.log("Error launching feed:" + e); }
    else if (!contract.address) { console.log("Feed waiting to be mined..."); }
    else                        { cb(contract); }
  });
}

// Launches a token with the given name and creator
exports.launchToken = function(creator, name, cb) {
  var contract = _this.CurrencyToken;
  var code = _this.getCode('CurrencyToken');
  var token = contract.new(name, {from: creator, data: code, gas: 1000000}, function(e, contract) {
    if (e)                      { console.log("Error launching token:" + e); }
    else if (!contract.address) { console.log("Token waiting to be mined..."); }
    else                        { cb(contract); }
  });
}

// Recompiles the solidity files in ./source/
exports.recompile = function (cb) {
  childProcess.exec('bash ./recompile.sh', function (error, stdout, stderr) {
    cb(error);
  });
};

// Unlocks all accounts on the current chain
exports.unlockAll = function() {
  for (var i = 0; i < web3.eth.accounts.length; i++) {
    web3.personal.unlockAccount(web3.eth.accounts[i], "123456");
  }
}

// Exposes the web3 object
exports.web3 = web3;
