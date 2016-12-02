pragma solidity ^0.4.2;

import './Feed.sol';

/// Example data provider (in this case, an oracle)
contract InternalFeed is Feed {

  /// Data store (keys are sha3 hashes)
  mapping (bytes32 => uint256) datastore;

  /// Initializer
  function InternalFeed() {
  }

  /// Gets value for key
  function get(bytes32 key) constant returns (uint256 value) {
    return datastore[key];
  }

  /// Sets new value for event
  function set(bytes32 key, uint256 value) internal {
    datastore[key] = value;
  }

}
