pragma solidity ^0.4.2;

import './Feed.sol';

/// Example data provider (in this case, an oracle)
contract SimpleFeed is Feed {

  /// Creator of contract (only entity that can provide new data)
  address owner;

  /// Data store (keys are sha3 hashes)
  mapping (bytes32 => int256) datastore;

  /// Initializer
  function SimpleFeed() {
    owner = msg.sender;
  }

  /// Gets value for key
  function get(bytes32 key, uint time) constant returns (int256 value) {
    return datastore[sha3(key, time)];
  }

  /// Sets new value for event (only callable by owner)
  function set(bytes32 key, uint time, int256 value) {
    if (msg.sender != owner) throw;
    datastore[sha3(key, time)] = value;
  }

}
