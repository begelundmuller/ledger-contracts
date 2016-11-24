pragma solidity ^0.4.2;

/// Adapted from ERC20 token standard
contract Token {
  function totalSupply() constant returns (uint256 totalSupply);
  function balanceOf(address _owner) constant returns (uint256 balance);
  function transfer(address to, uint256 value) returns (bool success);
  function transferFrom(address from, address to, uint256 value) returns (bool success);
  function permit(address spender, bool permission);
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
