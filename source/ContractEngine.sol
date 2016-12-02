pragma solidity ^0.4.2;

import './ContractBuilder.sol';
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
contract ContractEngine is ContractBuilder, InternalFeed  {

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

  /// Represents a variable assignment
  struct Assignment {
    bytes8 identifier;
    uint expr;
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

  /// Used during evaluation of contracts (cleared in-between)
  Assignment[] internal evaluationEnv;

  /// External functions
  /// ------------------

  /// Initializer
  function ContractEngine() ContractBuilder() InternalFeed() {
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
    checkAgreement(idx, a.currentContract);

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
  /// TODO: Type checking
  /// -------------------

  function checkAgreement(uint agreementId, uint contractId) internal {
    Contr c = contrs[contractId];
    Agreement a = agreements[agreementId];

    if (c.variant == ContrVariant.Empty) {
    } else if (c.variant == ContrVariant.After) {
      checkAgreement(agreementId, c.contr1);
    } else if (c.variant == ContrVariant.And) {
      checkAgreement(agreementId, c.contr1);
      checkAgreement(agreementId, c.contr2);
    } else if (c.variant == ContrVariant.Scale) {
      checkExpressionInAgreement(agreementId, c.expr1);
      checkAgreement(agreementId, c.contr1);
    } else if (c.variant == ContrVariant.Transfer) {
      // Check token has an address
      if (a.addressFor[c.identifier1] == 0) throw;
      // Add party identifiers to a.parties
      uint idx = a.parties.length;
      a.parties.length = a.parties.length + 2;
      a.parties[idx] = c.identifier2;
      a.parties[idx + 1] = c.identifier3;
    } else if (c.variant == ContrVariant.IfWithin) {
      checkExpressionInAgreement(agreementId, c.expr1);
      checkAgreement(agreementId, c.contr1);
      checkAgreement(agreementId, c.contr2);
    }
  }

  function checkExpressionInAgreement(uint agreementId, uint expressionId) internal {
    Expr e = exprs[expressionId];
    Agreement a = agreements[agreementId];

    if (e.variant == ExprVariant.Constant) {
    } else if (e.variant == ExprVariant.Variable) {
    } else if (e.variant == ExprVariant.Observation) {
      // Check feed has an address
      if (a.addressFor[e.identifier1] == 0) throw;
      checkExpressionInAgreement(agreementId, e.expr1);
      checkExpressionInAgreement(agreementId, e.expr2);
    } else if (e.variant == ExprVariant.Acc) {
      checkExpressionInAgreement(agreementId, e.expr1);
      checkExpressionInAgreement(agreementId, e.expr2);
    } else if (e.variant == ExprVariant.Plus) {
      checkExpressionInAgreement(agreementId, e.expr1);
      checkExpressionInAgreement(agreementId, e.expr2);
    } else if (e.variant == ExprVariant.Equal) {
      checkExpressionInAgreement(agreementId, e.expr1);
      checkExpressionInAgreement(agreementId, e.expr2);
    } else if (e.variant == ExprVariant.LessEqual) {
      checkExpressionInAgreement(agreementId, e.expr1);
      checkExpressionInAgreement(agreementId, e.expr2);
    } else if (e.variant == ExprVariant.And) {
      checkExpressionInAgreement(agreementId, e.expr1);
      checkExpressionInAgreement(agreementId, e.expr2);
    } else if (e.variant == ExprVariant.Not) {
      checkExpressionInAgreement(agreementId, e.expr1);
    }
  }

  /// Evaluating contracts
  /// --------------------

  /// Evaluates given contract and returns the ID of the reduced contract
  /// If encounters a transfer, executes transfer and returns empty
  function evaluateContract(uint agreementId, uint contractId, int scale)
  internal returns (uint) {
    Contr c = contrs[contractId];
    if (c.variant == ContrVariant.Empty) { // Nothing to do
      return contractId;
    } else if (c.variant == ContrVariant.After) { // Reduce if past time
      Const k = consts[c.const1];
      if (k.integer <= int256(block.timestamp)) {
        return evaluateContract(agreementId, c.contr1, scale);
      } else {
        return contractId;
      }
    } else if (c.variant == ContrVariant.And) { // Reduce both contrs
      uint outContractId1 = evaluateContract(agreementId, c.contr1, scale);
      uint outContractId2 = evaluateContract(agreementId, c.contr2, scale);
      Contr outContract1 = contrs[outContractId1];
      Contr outContract2 = contrs[outContractId2];
      // If either is empty, no longer need for And
      if (outContract1.variant == ContrVariant.Empty) {
        return outContractId2;
      } else if (outContract2.variant == ContrVariant.Empty) {
        return outContractId1;
      } else {
        return contrAnd(outContractId1, outContractId2);
      }
    } else if (c.variant == ContrVariant.Scale) {
      // Return empty if scale is 0
      k = consts[c.const1];
      if (k.integer == 0) {
        return contrEmpty();
      }
      // Evaluate subcontract with increased scale
      uint outContractId = evaluateContract(agreementId, c.contr1, k.integer * scale);
      Contr outContract = contrs[outContractId];
      // Keep scaling only if not empty
      if (outContract.variant == ContrVariant.Empty) {
        return outContractId;
      } else {
        return contrScale(c.const1, outContractId);
      }
    } else if (c.variant == ContrVariant.Transfer) {
      transferTokens(agreementId, c.identifier1, c.identifier2, c.identifier3, scale);
      return contrEmpty();
    } else if (c.variant == ContrVariant.IfWithin) {
      return evaluateIfWithinContract(agreementId, contractId, scale);
    }
  }

  function evaluateIfWithinContract(uint agreementId, uint contractId, int scale)
  internal returns (uint) {
    // Contr
    Contr c = contrs[contractId];

    // Get n and t0
    int n = consts[c.const1].integer;
    int t0 = consts[c.const2].integer;

    // Evaluate
    bool result = false;
    for (uint i = 0; i < uint(n); i++) {
      int t = t0 + int(i);
      if (uint(t) <= block.timestamp) {
        pushEnv(c.identifier1, exprConstant(constInteger(t)));
        uint exprId = evaluateExpression(agreementId, c.expr1);
        popEnv();
        Expr expr = exprs[exprId];
        if (consts[expr.const1].boolean) {
          result = true;
        }
      }
    }

    // Done
    if (result) {
      return evaluateContract(agreementId, c.contr1, scale);
    } else if (t0 + n > int(block.timestamp)) {
      return contractId;
    } else {
      return evaluateContract(agreementId, c.contr2, scale);
    }
  }

  /// Evaluates expression and returns the ID of the reduced expression
  function evaluateExpression(uint agreementId, uint expressionId)
  internal returns (uint) {
    Expr e = exprs[expressionId];
    if (e.variant == ExprVariant.Constant) {
      Const k = consts[e.const1];
      if (k.variant == ConstVariant.Label && k.label == "this") {
        return constInteger(int(agreementId));
      } else {
        return expressionId;
      }
    } else if (e.variant == ExprVariant.Variable) {
      return lookupEnv(e.identifier1);
    } else if (e.variant == ExprVariant.Observation) {
      return evaluateExpressionObservation(agreementId, expressionId);
    } else if (e.variant == ExprVariant.Acc) {
      return evaluateExpressionAcc(agreementId, expressionId);
    } else if (e.variant == ExprVariant.Plus
    || e.variant == ExprVariant.Equal
    || e.variant == ExprVariant.LessEqual
    || e.variant == ExprVariant.And) {
      return evaluateExpressionBinaryOp(agreementId, expressionId);
    } else if (e.variant == ExprVariant.Not) {
      return evaluateExpressionUnaryOp(agreementId, expressionId);
    }
    return expressionId; // Couldn't evaluate (shouldn't happen...)
  }

  /// Evaluates an Obs expression
  function evaluateExpressionObservation(uint agreementId, uint expressionId)
  internal returns (uint) {
    // Get
    Agreement a = agreements[agreementId];
    Expr e = exprs[expressionId];

    // Evaluate sub-expressions
    Expr e1 = exprs[evaluateExpression(agreementId, e.expr1)];
    Expr e2 = exprs[evaluateExpression(agreementId, e.expr2)];

    // If both don't evaluate to a constant, can't yet do anything
    if (e1.variant != ExprVariant.Constant || e2.variant != ExprVariant.Constant) {
      return expressionId;
    }

    // Get constants
    Const k1 = consts[e1.const1];
    Const k2 = consts[e2.const1];

    // Get value from feed
    address feedAddress = a.addressFor[e.identifier1];
    Feed feed = Feed(feedAddress);
    return feed.get(sha3(k1.label, k2.integer));
  }

  /// Evaluates an Acc expression
  function evaluateExpressionAcc(uint agreementId, uint expressionId)
  internal returns (uint) {
    // Get
    Agreement a = agreements[agreementId];
    Expr e = exprs[expressionId];

    // Get constants
    int t = consts[e.const1].integer;
    int d = consts[e.const2].integer;
    int n = consts[e.const3].integer;

    // If all times accumulated over are in the past
    if (t + d * n < int(block.timestamp)) return expressionId;

    // Accummulate
    uint currentExpr = e.expr2;
    for (uint i = 0; i <= uint(n); i++) {
      pushEnv(e.identifier1, currentExpr);
      pushEnv(e.identifier2, exprConstant(constInteger(t + d * int(i))));
      currentExpr = evaluateExpression(agreementId, e.expr1);
      popEnv();
      popEnv();
    }

    // Return result of accumulation
    return currentExpr;
  }

  /// Evaluates a unary operation (currently only +not+)
  function evaluateExpressionUnaryOp(uint agreementId, uint expressionId)
  internal returns (uint) {
    // Get expr in question
    Expr e = exprs[expressionId];
    uint outExpressionId = evaluateExpression(agreementId, e.expr1);
    Expr outExpression = exprs[outExpressionId];

    // If not constant, can't evaluate yet
    if (outExpression.variant != ExprVariant.Constant) {
      return expressionId;
    }

    // Get constants
    Const k1 = consts[outExpression.const1];

    // Handle cases by type
    if (k1.variant == ConstVariant.Boolean) {
      if (e.variant == ExprVariant.Not) {
        return constBoolean(!k1.boolean);
      }
    }

    // Couldn't reduce, return same (shouldn't happen)
    return expressionId;
  }

  /// Evaluates a binary operation
  function evaluateExpressionBinaryOp(uint agreementId, uint expressionId)
  internal returns (uint) {
    // Get expr in questio
    Expr e = exprs[expressionId];

    // Evaluate each sub expr
    uint exprId1 = evaluateExpression(agreementId, e.expr1);
    uint exprId2 = evaluateExpression(agreementId, e.expr2);
    Expr expr1 = exprs[exprId1];
    Expr expr2 = exprs[exprId2];

    // If both not constant, can't evaluate yet
    if (expr1.variant != ExprVariant.Constant
    || expr2.variant != ExprVariant.Constant) {
      return expressionId;
    }

    // Get constants
    Const k1 = consts[expr1.const1];
    Const k2 = consts[expr2.const1];

    // Handle cases by type
    if (k1.variant == ConstVariant.Integer && k2.variant == ConstVariant.Integer) {
      if (e.variant == ExprVariant.Plus) {
        return constInteger(k1.integer + k2.integer);
      } else if (e.variant == ExprVariant.Equal) {
        return constBoolean(k1.integer == k2.integer);
      } else if (e.variant == ExprVariant.LessEqual) {
        return constBoolean(k1.integer <= k2.integer);
      }
    } else if (k1.variant == ConstVariant.Boolean && k2.variant == ConstVariant.Boolean) {
      if (e.variant == ExprVariant.Equal) {
        return constBoolean(k1.boolean == k2.boolean);
      } else if (e.variant == ExprVariant.And) {
        return constBoolean(k1.boolean && k2.boolean);
      }
    }

    // Couldn't reduce, return same (indicates type error)
    return expressionId;
  }

  /// Evaluation helpers
  /// ------------------

  function transferTokens(uint agreementId, bytes8 tIdent, bytes8 p1Ident,
  bytes8 p2Ident, int amount) internal {
    // Can't transfer negative amounts
    if (amount < 0) throw;

    // Get agreement
    Agreement a = agreements[agreementId];

    // Translate identifiers
    Token token = Token(a.addressFor[tIdent]);
    address party1Address = a.addressFor[p1Ident];
    address party2Address = a.addressFor[p2Ident];

    // Transfer
    bool res = token.transferFrom(party1Address, party2Address, uint256(amount));
    if (!res) throw;
  }

  function pushEnv(bytes8 identifier, uint exprId) internal {
    uint idx = evaluationEnv.length;
    evaluationEnv.length++;
    evaluationEnv[idx] = Assignment({
      identifier: identifier,
      expr: exprId
    });
  }

  function popEnv() internal {
    uint idx = evaluationEnv.length - 1;
    delete evaluationEnv[idx];
    evaluationEnv.length--;
  }

  function lookupEnv(bytes8 identifier) internal returns (uint) {
    for (uint i = evaluationEnv.length - 1; i >= 0; i--) {
      if (evaluationEnv[i].identifier == identifier) {
        return evaluationEnv[i].expr;
      }
    }
    return 0;
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
