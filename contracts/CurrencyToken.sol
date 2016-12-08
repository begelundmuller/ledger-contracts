pragma solidity ^0.4.2;

/// Contract representing a currency
contract CurrencyToken {

  /// Display name (in clients) for token
  string public name;

  /// The entity that can increase the supply of tokens
  address public creator;

  /// The total supply of tokens available
  uint256 public totalSupply;

  /// Balances of tokens
  mapping (address => uint256) public balanceOf;

  /// `Permissions` record people allowed to spend tokens on another party's behalf
  mapping (address => mapping (address => bool)) public permissions;

  /// Event marking that a transfer occured
  event Transfer(address indexed from, address indexed to, uint256 value);

  /// Initializer
  function CurrencyToken(string tokenName) {
    name = tokenName;
    creator = msg.sender;
  }

  /// Endows a beneficiary with tokens (only for token creator)
  function endow(address beneficiary, uint256 value) {
    // Check sender is creator
    if (msg.sender != creator) throw;

    // Endow
    balanceOf[beneficiary] += value;
    totalSupply += value;
  }

  /// Transfers tokens from sender
  function transfer(address to, uint256 value) returns (bool success) {
    // Check has enough tokens
    if (balanceOf[msg.sender] < value) return false;

    // Transfer
    balanceOf[msg.sender] -= value;
    balanceOf[to] += value;

    // Log event (for clients)
    Transfer(msg.sender, to, value);

    // Done
    return true;
  }

  /// Transfers tokens on behalf of another entity
  function transferFrom(address from, address to, uint256 value) returns (bool success) {
    // Check has enough tokens
    if (balanceOf[from] < value) return false;

    // Check permitted
    if (!permissions[from][msg.sender]) return false;

    // Transfer
    balanceOf[from] -= value;
    balanceOf[to] += value;

    // Log event (for clients)
    Transfer(from, to, value);

    // Done
    return true;
  }

  // Allow person to spend money on sender's behalf
  function permit(address spender, bool permission) {
    permissions[msg.sender][spender] = permission;
  }

}
