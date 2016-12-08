pragma solidity ^0.4.2;

import './ContractEvaluator.sol';
import './Feed.sol';
import './Token.sol';

//// Smart contract that manages and settles contracts
//// - Create contracts using the constructor functions
//// - Register agreements over contract with +register+
//// - Sign agreement with +sign+
//// - Call +evaluate+ (repeatedly) to process contract
//// - To terminate an agreement, all parties must call +kill+
////
//// The contract manager is also a Feed with two observables
//// - sha3("signed", agreementId)
//// - sha3("killed", agreementId)
////
//// The contract manager emits several events that clients may monitor:
//// - event ContractCreated(string description, uint256 contractId)
//// - event AgreementRegistered(uint256 agreementId)
//// - event AgreementSigned(uint256 agreementId)
//// - event AgreementSettled(uint256 agreementId)
//// - event AgreementKilled(uint256 agreementId)
contract ContractManager is ContractEvaluator, Feed  {

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

    uint256 timeDelta; // Size of time steps in seconds; must be synced with feeds
  }

  /// Events
  /// ------

  /// Event for the construction of a new contract
  event ContractCreated(string description, uint256 contractId);

  /// Event for the registration of a new agreement
  event AgreementRegistered(uint256 agreementId);

  /// Event for when an agreement is signed by all parties
  event AgreementSigned(uint256 agreementId);

  /// Event for when the contract in an agreement evaluates to empty
  event AgreementSettled(uint256 agreementId);

  /// Event for when the an agreement is kill-signed by all parties
  event AgreementKilled(uint256 agreementId);

  /// Debugging
  /// ---------

  event LogU(string name, uint val);
  event LogI(string name, int val);
  event LogB(string name, bool val);
  event LogS(string name, bytes8 val);
  event LogA(string name, address val);

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

  /// Data store for feed (keys are sha3 hashes)
  mapping (bytes32 => int256) datastore;

  /// External functions
  /// ------------------

  /// Initializer
  function ContractManager() ContractEvaluator() Feed() {
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
    a.timeDelta = 30;

    // Mapping names to addresses
    a.addressFor[party1Name] = party1Address;
    a.addressFor[party2Name] = party2Address;
    a.addressFor[token1Name] = token1Address;
    a.addressFor[token2Name] = token2Address;
    a.addressFor[feed1Name] = feed1Address;

    // Check (throws if not okay)
    checkContract(idx, contractId);

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
        set(sha3("signed", agreementId), currentTime(a.timeDelta), 1); // Signed observable
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
        set(sha3("killed", agreementId), currentTime(a.timeDelta), 1); // Killed observable
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
    a.currentContract = evaluateContract(agreementId, a.timeDelta, a.currentContract, 1);

    // Check if now settled
    currentContract = contrs[a.currentContract];
    if (currentContract.variant == ContrVariant.Empty) {
      AgreementSettled(agreementId);
    }
  }

  /// Feed functions
  /// --------------

  /// Gets value for key
  function get(bytes32 key, uint time) constant returns (int256 value) {
    return datastore[sha3(key, time)];
  }

  /// Sets new value for event
  function set(bytes32 key, uint time, int256 value) internal {
    datastore[sha3(key, time)] = value;
  }

  /// Checker overrides
  /// -----------------

  /// Called when the checker encounters a name in a contract
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

  /// Evaluator overrides
  /// -------------------

  /// Called when the evaluator encounters an observable
  function handleObservation(uint key, bytes8 name, bytes32 digest, uint time)
  internal returns (int) {
    Agreement a = agreements[key];
    address feedAddress = a.addressFor[name];
    Feed feed = Feed(feedAddress);
    return feed.get(digest, time);
  }

  /// Called when the evaluator encounters a transfer
  function handleTransfer(uint key, bytes8 tokenName, bytes8 from, bytes8 to, int scale)
  internal returns (bool) {
    // Can't transfer negative amounts
    if (scale < 0) throw;

    // Get agreement
    Agreement a = agreements[key];

    // Translate identifiers
    address tokenAddress = a.addressFor[tokenName];
    address fromAddress = a.addressFor[from];
    address toAddress = a.addressFor[to];

    // Transfer
    Token token = Token(tokenAddress);
    bool res = token.transferFrom(fromAddress, toAddress, uint256(scale));

    // Handle result
    if (res) {
      return true;
    } else {
      set(sha3("default", from), currentTime(a.timeDelta), 1); // Default observable
      return false;
    }
  }

  /// Offered contracts
  /// -----------------

  /// Zero-coupon bond
  function zcb(bytes8 issuer, bytes8 holder, bytes8 ccy, int nominal, int price, int maturity)
  returns (uint contractId) {
    contractId = contrAnd(
      contrScale(
        exprConstant(constInteger(price)),
        contrTransfer(
          ccy,
          holder,
          issuer
        )
      ),
      contrAfter(
        constInteger(maturity),
        contrScale(
          exprConstant(constInteger(nominal)),
          contrTransfer(
            ccy,
            issuer,
            holder
          )
        )
      )
    );
    ContractCreated("zcb", contractId);
  }

  /// ccy1(party1 → party2) & strike * ccy2(party2 → party1)
  function fxSpot(bytes8 party1, bytes8 party2, bytes8 ccy1, bytes8 ccy2, int amount, int strike)
  returns (uint contractId) {
    contractId = contrScale(
      exprConstant(constInteger(amount)),
      contrAnd(
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
      )
    );
    ContractCreated("fxSingle", contractId);
  }

  /// t ↑ amount * (ccy1(party1 → party2) & strike * ccy2(party2 → party1))
  function fxForward(bytes8 party1, bytes8 party2, bytes8 ccy1,
    bytes8 ccy2, int t, int amount, int strike)
  returns (uint contractId) {
    contractId = contrAfter(
      constInteger(t),
      fxSpot(party1, party2, ccy1, ccy2, amount, strike)
    );
    ContractCreated("fxForward", contractId);
  }

  ///
  function fxAmericanOption(bytes8 party1, bytes8 party2, bytes8 ccy1, bytes8 ccy2,
    uint n, uint t0, int amount, int strike, bytes8 feed, bytes32 digest)
  returns (uint contractId) {
    uint spot = fxSpot(party1, party2, ccy1, ccy2, amount, strike);
    uint obs = exprEqual(
      exprObservation(feed, exprConstant(constDigest(digest)), exprVariable("t")),
      exprConstant(constInteger(1))
    );
    contractId = contrIfWithin("t", obs, n, t0, spot, contrEmpty());
    ContractCreated("fxAmericanOption", contractId);
  }

}
