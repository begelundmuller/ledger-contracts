pragma solidity ^0.4.2;

/// Data feed
contract Feed {
  function get(bytes32 key) constant returns (int256 value);
}
