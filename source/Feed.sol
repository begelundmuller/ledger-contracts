pragma solidity ^0.4.2;

/// Data feed
contract Feed {
  function get(bytes32 key, uint time) constant returns (int256 value);
}
