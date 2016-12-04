pragma solidity ^0.4.2;

import './ContractEvaluator.sol';
import './InternalFeed.sol';
import './Token.sol';

//// Smart contract that manages and settles contracts
//// - Create contracts using the constructor functions
//// - Register agreements over contract with +register+
//// - Sign agreement with +sign+
//// - Call +evaluate+ (repeatedly) to process contract
//// - To terminate an agreement, all parties must call +kill+
////
//// The contract engine is also a Feed with two observables
//// - sha3("signed", agreementId)
//// - sha3("killed", agreementId)
////
//// The contract engine emits several events that clients may monitor:
//// - event ContractCreated(uint256 contractId)
//// - event AgreementRegistered(uint256 agreementId)
//// - event AgreementSigned(uint256 agreementId)
//// - event AgreementSettled(uint256 agreementId)
//// - event AgreementKilled(uint256 agreementId)
contract ContractEngine is ContractEvaluator, InternalFeed  {

  /// Structs
  /// -------

  /// Represents an agreement over a contract
  struct Agreement {
    uint256 initialContract; // As initially constructed
    uint256 currentContract; // Current state (changes on calls to evaluate)

    bytes8[] parties; // All parties present in initialContr (derived)
    mapping(bytes8 => address) addressFor; // identifier in contract => address

    mapping(address => bool) signed;     // Creation signatures
    mapping(address => bool) killSigned; // Kill/termination signatures

    uint256 signedOn; // First time where ∀p <- partiesInContract . signed[p]
    uint256 killedOn; // First time where ∀p <- partiesInContract . killSigned[p]
  }

  /// Events
  /// ------

  /// Event for the construction of a new contract
  event ContractCreated(uint256 contractId);

  /// Event for the registration of a new agreement
  event AgreementRegistered(uint256 agreementId);

  /// Event for when an agreement is signed by all parties
  event AgreementSigned(uint256 agreementId);

  /// Event for when the contract in an agreement evaluates to empty
  event AgreementSettled(uint256 agreementId);

  /// Event for when the an agreement is kill-signed by all parties
  event AgreementKilled(uint256 agreementId);

  /// Debugging
  event LogU(string name, uint val);
  event LogI(string name, int val);
  event LogB(string name, bool val);
  event LogS(string name, bytes8 val);
  event LogA(string name, address val);

  /// Debugging
  /// ---------

  function agreementParties(uint agreementId, uint partyIdx) returns (bytes8) {
    return agreements[agreementId].parties[partyIdx];
  }

  function agreementAddressFor(uint agreementId, bytes8 name) returns (address) {
    return agreements[agreementId].addressFor[name];
  }

  function agreementSigned(uint agreementId, address addr) returns (bool) {
    return agreements[agreementId].signed[addr];
  }

  /// State variables
  /// ---------------

  /// Stores all registered agreements
  Agreement[] public agreements;

  /// External functions
  /// ------------------

  /// Initializer
  function ContractEngine() ContractEvaluator() InternalFeed() {
  }

  /// Register a new agreement
  function register(uint256 contractId,
    bytes8 party1Name, address party1Address,
    bytes8 party2Name, address party2Address,
    bytes8 token1Name, address token1Address,
    bytes8 token2Name, address token2Address,
    bytes8 feed1Name, address feed1Address
  ) returns (uint agreementId) {
    // Add agreement
    uint idx = agreements.length;
    agreements.length++;
    Agreement a = agreements[idx];

    // Initialize
    a.initialContract = contractId;
    a.currentContract = contractId;
    a.signedOn = 0;
    a.killedOn = 0;

    // Mapping names to addresses
    a.addressFor[party1Name] = party1Address;
    a.addressFor[party2Name] = party2Address;
    a.addressFor[token1Name] = token1Address;
    a.addressFor[token2Name] = token2Address;
    a.addressFor[feed1Name] = feed1Address;

    // Check (throws if not okay)
    checkContract(idx, a.currentContract);

    // Done
    AgreementRegistered(idx);
    return idx;
  }

  /// Sign an agreement
  function sign(uint256 agreementId) {
      // Find agreement
      Agreement a = agreements[agreementId];

      // Stop if already signed
      if (a.signedOn > 0) return;

      // Sign
      a.signed[msg.sender] = true;

      // Check if signed by all
      bool signed = true;
      for (uint i = 0; i < a.parties.length; i++) {
        bytes8 partyName = a.parties[i];
        address partyAddress = a.addressFor[partyName];
        signed = signed && a.signed[partyAddress];
      }

      // If signed by all, set signedOn
      if (signed) {
        a.signedOn = block.timestamp;
        set(sha3("signed", agreementId), 1); // Signed observable
        AgreementSigned(agreementId); // Signed event
      }
  }

  /// Sign an agreement
  function kill(uint256 agreementId) {
      // Find agreement
      Agreement a = agreements[agreementId];

      // Stop if already killed
      if (a.killedOn > 0) return;

      // Sign
      a.killSigned[msg.sender] = true;

      // Check if signed by all
      bool signed = true;
      for (uint i = 0; i < a.parties.length; i++) {
        bytes8 partyName = a.parties[i];
        address partyAddress = a.addressFor[partyName];
        signed = signed && a.killSigned[partyAddress];
      }

      // If signed, set killedOn
      if (signed) {
        a.killedOn = block.timestamp;
        set(sha3("killed", agreementId), 1); // Killed observable
        AgreementKilled(agreementId); // Killed event
      }
  }

  /// Processes developments in the agreement's contract since last call
  function evaluate(uint256 agreementId) {
    // Find agreement
    Agreement a = agreements[agreementId];

    // Check signed and not killed
    if (a.signedOn == 0 || a.killedOn != 0) return;

    // Check not empty
    Contr currentContract = contrs[a.currentContract];
    if (currentContract.variant == ContrVariant.Empty) return;

    // Evaluate
    a.currentContract = evaluateContract(agreementId, a.currentContract, 1);

    // Check if now settled
    currentContract = contrs[a.currentContract];
    if (currentContract.variant == ContrVariant.Empty) {
      AgreementSettled(agreementId);
    }
  }

  /// Currently offered contracts
  /// ---------------------------

  /// t ↑ amount * ( ccy1(party1 → party2) & strike * ccy2(party2 → party1) )
  function fxForwardContract(bytes8 party1, bytes8 party2, bytes8 ccy1,
    bytes8 ccy2, int t, int amount, int strike)
  returns (uint contractId) {
    // Create the transfer sub-contr
    uint transfer = contrAnd(
      contrTransfer(
        ccy1,
        party1,
        party2
      ),
      contrScale(
        exprConstant(constInteger(strike)),
        contrTransfer(
          ccy2,
          party2,
          party1
        )
      )
    );

    // Create the forward using transfer
    contractId = contrAfter(
      constInteger(t),
      contrScale(
        exprConstant(constInteger(amount)),
        transfer
      )
    );

    ContractCreated(contractId);
  }

  /// Checking agreements
  /// -------------------

  function checkerEncounteredName(uint key, NameKind kind, bytes8 name) internal {
    // Check name is mapped to an address in the agreement being checked
    Agreement a = agreements[key];
    if (a.addressFor[name] == 0) throw;

    // If it's a party, store the name in the agreement (useful for evaluation)
    if (kind == NameKind.Party) {
      uint idx = a.parties.length;
      a.parties.length++;
      a.parties[idx] = name;
    }
  }

  /// Evaluation helpers
  /// ------------------

  function handleObservation(uint key, bytes8 name, bytes8 label, uint time)
  internal returns (int) {
    Agreement a = agreements[key];
    address feedAddress = a.addressFor[name];
    Feed feed = Feed(feedAddress);
    return feed.get(sha3(label, time));
  }

  function transferTokens(uint agreementId, bytes8 tIdent, bytes8 p1Ident,
  bytes8 p2Ident, int amount) internal {
    // Can't transfer negative amounts
    if (amount < 0) throw;

    // Get agreement
    Agreement a = agreements[agreementId];

    // Translate identifiers
    address tokenAddress = a.addressFor[tIdent];
    address party1Address = a.addressFor[p1Ident];
    address party2Address = a.addressFor[p2Ident];

    // Transfer
    Token token = Token(tokenAddress);
    bool res = token.transferFrom(party1Address, party2Address, uint256(amount));
    if (!res) throw;
  }

  /// Various other helpers

  function max(int a, int b) internal constant returns (int) {
    if (a > b) {
      return a;
    } else {
      return b;
    }
  }

  function min(int a, int b) internal constant returns (int) {
    if (a > b) {
      return b;
    } else {
      return a;
    }
  }

  function specialPlus(int a, int b) internal constant returns (int) {
    if (b == 0) {
      return 0;
    } else {
      return a + b;
    }
  }

}
