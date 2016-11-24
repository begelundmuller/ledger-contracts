pragma solidity ^0.4.2;

/// Data feed
contract Feed {
  function get(bytes32 key) constant returns (uint256 value);
  function set(bytes32 key, uint256 value);
}
