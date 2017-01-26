pragma solidity ^0.4.2;

contract Feed {
  function get(bytes32 key, uint time) constant returns (int256 value);
}

/// Feed representing decisions
contract DecisionFeed is Feed {
  /// Data store (keys are sha3 hashes)
  mapping (bytes32 => int256) datastore;

  /// Gets value for key
  /// Lookup-keys must be a hash +sha3(party, ident)+ where +party+
  /// is the address of the deciding party and +ident+ is a label
  /// identifying the decision.
  function get(bytes32 key, uint time) constant returns (int256 value) {
    return datastore[sha3(key, time)];
  }

  /// Sets new value for event
  /// Events set are automatically tied to the sender's address
  function set(bytes32 key, uint time, int256 value) {
    datastore[sha3(sha3(msg.sender, key), time)] = value;
  }
}
