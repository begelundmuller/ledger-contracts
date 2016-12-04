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
  function get(bytes32 key) constant returns (int256 value) {
    return datastore[key];
  }

  /// Sets new value for event (only callable by owner)
  function set(bytes32 key, int256 value) {
    if (msg.sender != owner) throw;
    datastore[key] = value;
  }

}
