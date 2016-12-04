pragma solidity ^0.4.2;

import './Feed.sol';

/// Example data provider (in this case, an oracle)
contract InternalFeed is Feed {

  /// Data store (keys are sha3 hashes)
  mapping (bytes32 => int256) datastore;

  /// Initializer
  function InternalFeed() {
  }

  /// Gets value for key
  function get(bytes32 key) constant returns (int256 value) {
    return datastore[key];
  }

  /// Sets new value for event
  function set(bytes32 key, int256 value) internal {
    datastore[key] = value;
  }

}
