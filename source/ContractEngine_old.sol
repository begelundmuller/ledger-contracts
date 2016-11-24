pragma solidity ^0.4.2;

import './SimpleFeed.sol';
import './Token.sol';


//// Smart contract that manages and settles contracts
//// - Create contracts using the constructor functions
//// - Register new contracts with +register+
//// - Sign contracts with +sign+
//// - Call +evaluate+ (repeatedly) to process contract
//// - Sign death of contract with +kill+
//// The contract engine is also a feed with two observables
//// - sha3("signed", contractId)
//// - sha3("killed", contractId)
contract ContractEngine is SimpleFeed {

  /// Represents a registered contract
  struct Contract {
    uint256 initialContr;
    uint256 currentContr;

    Assignment[] currentEnv;

    bytes8[] partiesInContract;
    bytes8[] tokensInContract;
    bytes8[] feedsInContract;

    mapping(bytes8 => address) parties;
    mapping(bytes8 => address) tokens;
    mapping(bytes8 => address) feeds;

    mapping(address => bool) signed;
    mapping(address => bool) killSigned;

    uint256 signedOn;
    uint256 killedOn;
  }

  /// Represents a variable assignment
  struct Assignment {
    bytes8 identifier;
    uint expr;
  }

  /// Stores all registered contracts
  Contract[] contracts;

  /// Used for constructing contracts
  Const[] consts;
  Expr[] exprs;
  Contr[] contrs;

  /// Event indicating the creation of a new contract
  event Created(uint256 contrId);
  event Registered(uint256 contractId);

  /// Initializer
  function ContractEngine() SimpleFeed() {
    consts.length++;
    exprs.length++;
    contrs.length++;
  }

  /// Register a new contract
  function register(uint256 contr,
    bytes8[] partyNames, address[] partyAddrs,
    bytes8[] tokenNames, address[] tokenAddrs,
    bytes8[] feedNames, address[] feedAddrs
  ) returns (uint contractId) {
    // Add contract
    uint idx = contracts.length;
    contracts.length++;
    Contract c = contracts[idx];

    // Initialize
    c.initialContr = contr;
    c.currentContr = contr;
    c.signedOn = 0;
    c.killedOn = 0;

    // Make sure input data is aligned
    if (partyNames.length != partyAddrs.length
        || tokenNames.length != tokenAddrs.length
        || feedNames.length != feedAddrs.length) {
      throw;
    }

    // Add parties to contract
    for (uint i = 0; i < partyNames.length; i++) {
      c.parties[partyNames[i]] = partyAddrs[i];
    }

    // Add tokens to contract
    for (uint j = 0; j < tokenNames.length; j++) {
      c.tokens[tokenNames[j]] = tokenAddrs[j];
    }

    // Add feeds to contract
    for (uint k = 0; k < feedNames.length; k++) {
      c.feeds[feedNames[k]] = feedAddrs[k];
    }

    // Find and add all parties/tokens/feeds in contract
    findPartiesInContr(contr, c.partiesInContract);
    findTokensInContr(contr, c.tokensInContract);
    findFeedsInContr(contr, c.feedsInContract);

    // Check all parties are in contract
    checkParties(c);
    checkTokens(c);
    checkFeeds(c);

    // Event
    Registered(idx);

    // Done
    return idx;
  }

  /// Sign a contract,
  function sign(uint256 contractId) {
      // Find contract
      Contract c = contracts[contractId];

      // Stop if contract has already been signed
      if (c.signedOn > 0) return;

      // Sign
      c.signed[msg.sender] = true;

      // Check if signed by all
      bool signed = true;
      for (uint i = 0; i < c.partiesInContract.length; i++) {
        address party = c.parties[c.partiesInContract[i]];
        signed = signed && c.signed[party];
      }

      // If signed by, set signedOn
      if (signed) {
        c.signedOn = block.timestamp;
        set(sha3("signed", contractId), 1); // Signed observable
      }
  }

  /// Sign a contract,
  function kill(uint256 contractId) {
      // Find contract
      Contract c = contracts[contractId];

      // Stop if contract has already been signed
      if (c.killedOn > 0) return;

      // Sign
      c.killSigned[msg.sender] = true;

      // Check if signed by all
      bool signed = true;
      for (uint i = 0; i < c.partiesInContract.length; i++) {
        address party = c.parties[c.partiesInContract[i]];
        signed = signed && c.killSigned[party];
      }

      // If signed by, set signedOn
      if (signed) {
        c.killedOn = block.timestamp;
        set(sha3("killed", contractId), 1); // Contract signed observable
      }
  }

  /// Processes developments in the contract since last call to +evaluate+
  function evaluate(uint256 contractId) {
    // Find contract
    Contract c = contracts[contractId];

    // Check signed and not killed
    if (c.signedOn == 0 || c.killedOn != 0) {
      return;
    }

    // Evaluate
    c.currentContr = evaluateContr(contractId, c.currentContr, 1);
  }

  /// Sample contracts

  // t ↑ amount * ( ccy1(party1 → party2) & strike * ccy2(party2 → party1) )
  function contrFxForward(bytes8 party1, bytes8 party2, bytes8 ccy1,
    bytes8 ccy2, int t, int amount, int strike)
  returns (uint result) {
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
    result = contrAfter(
      constInteger(t),
      contrScale(
        exprConstant(constInteger(amount)),
        transfer
      )
    );

    Created(result);
  }


  /// Functions for checking contracts

  function findPartiesInContr(uint contrId, bytes8[] storage acc) internal {
    Contr c = contrs[contrId];

    if (c.variant == ContrVariant.Empty) {
    } else if (c.variant == ContrVariant.After) {
      findPartiesInContr(c.contr1, acc);
    } else if (c.variant == ContrVariant.And) {
      findPartiesInContr(c.contr1, acc);
      findPartiesInContr(c.contr2, acc);
    } else if (c.variant == ContrVariant.Scale) {
      findPartiesInContr(c.contr1, acc);
    } else if (c.variant == ContrVariant.Transfer) {
      uint idx = acc.length;
      acc.length = acc.length + 2;
      acc[idx] = c.identifier2;
      acc[idx + 1] = c.identifier3;
    } else if (c.variant == ContrVariant.IfBefore) {
      findPartiesInContr(c.contr1, acc);
      findPartiesInContr(c.contr2, acc);
    }
  }

  function findTokensInContr(uint contrId, bytes8[] storage acc) internal {
    Contr c = contrs[contrId];

    if (c.variant == ContrVariant.Empty) {
    } else if (c.variant == ContrVariant.After) {
      findTokensInContr(c.contr1, acc);
    } else if (c.variant == ContrVariant.And) {
      findTokensInContr(c.contr1, acc);
      findTokensInContr(c.contr2, acc);
    } else if (c.variant == ContrVariant.Scale) {
      findTokensInContr(c.contr1, acc);
    } else if (c.variant == ContrVariant.Transfer) {
      uint idx = acc.length;
      acc.length++;
      acc[idx] = c.identifier1;
    } else if (c.variant == ContrVariant.IfBefore) {
      findTokensInContr(c.contr1, acc);
      findTokensInContr(c.contr2, acc);
    }
  }

  function findFeedsInContr(uint contrId, bytes8[] storage acc) internal {
    Contr c = contrs[contrId];

    if (c.variant == ContrVariant.Empty) {
    } else if (c.variant == ContrVariant.After) {
      findFeedsInContr(c.contr1, acc);
    } else if (c.variant == ContrVariant.And) {
      findFeedsInContr(c.contr1, acc);
      findFeedsInContr(c.contr2, acc);
    } else if (c.variant == ContrVariant.Scale) {
      findFeedsInExpr(c.expr1, acc);
      findFeedsInContr(c.contr1, acc);
    } else if (c.variant == ContrVariant.Transfer) {
    } else if (c.variant == ContrVariant.IfBefore) {
      findFeedsInExpr(c.expr1, acc);
      findFeedsInContr(c.contr1, acc);
      findFeedsInContr(c.contr2, acc);
    }
  }

  function findFeedsInExpr(uint exprId, bytes8[] storage acc) internal {
    Expr e = exprs[exprId];

    if (e.variant == ExprVariant.Constant) {
    } else if (e.variant == ExprVariant.Variable) {
    } else if (e.variant == ExprVariant.Observation) {
      uint idx = acc.length;
      acc.length++;
      acc[idx] = e.identifier1;
    } else if (e.variant == ExprVariant.Acc) {
      findFeedsInExpr(e.expr1, acc);
      findFeedsInExpr(e.expr2, acc);
    } else if (e.variant == ExprVariant.Plus) {
      findFeedsInExpr(e.expr1, acc);
      findFeedsInExpr(e.expr2, acc);
    } else if (e.variant == ExprVariant.Equal) {
      findFeedsInExpr(e.expr1, acc);
      findFeedsInExpr(e.expr2, acc);
    } else if (e.variant == ExprVariant.LessEqual) {
      findFeedsInExpr(e.expr1, acc);
      findFeedsInExpr(e.expr2, acc);
    } else if (e.variant == ExprVariant.And) {
      findFeedsInExpr(e.expr1, acc);
      findFeedsInExpr(e.expr2, acc);
    } else if (e.variant == ExprVariant.Not) {
      findFeedsInExpr(e.expr1, acc);
    }
  }

  function checkParties(Contract storage c) internal constant {
    for (uint i = 0; i < c.partiesInContract.length; i++) {
      if (c.parties[c.partiesInContract[i]] == 0) {
        throw;
      }
    }
  }

  function checkTokens(Contract storage c) internal constant {
    for (uint i = 0; i < c.tokensInContract.length; i++) {
      if (c.tokens[c.tokensInContract[i]] == 0) {
        throw;
      }
    }
  }

  function checkFeeds(Contract storage c) internal constant {
    for (uint i = 0; i < c.feedsInContract.length; i++) {
      if (c.feeds[c.feedsInContract[i]] == 0) {
        throw;
      }
    }
  }

  /// Functions for evaluating contracts

  function evaluateContr(uint ctx, uint inCtrIdx, int scale)
  internal returns (uint) {
    Contr c = contrs[inCtrIdx];

    if (c.variant == ContrVariant.Empty) {
      // Nothing to do
      return inCtrIdx;
    } else if (c.variant == ContrVariant.After) {
      // If time has passed, reduce to subcontr
      Const k = consts[c.const1];
      if (k.integer <= int256(block.timestamp)) {
        return evaluateContr(ctx, c.contr1, scale);
      } else {
        return inCtrIdx;
      }
    } else if (c.variant == ContrVariant.And) {
      // Reduce both contrs
      uint outCtrIdx1 = evaluateContr(ctx, c.contr1, scale);
      uint outCtrIdx2 = evaluateContr(ctx, c.contr2, scale);
      Contr outCtr1 = contrs[outCtrIdx1];
      Contr outCtr2 = contrs[outCtrIdx2];

      // If either is empty, no longer need for And
      if (outCtr1.variant == ContrVariant.Empty) {
        return outCtrIdx2;
      } else if (outCtr2.variant == ContrVariant.Empty) {
        return outCtrIdx1;
      } else {
        return contrAnd(outCtrIdx1, outCtrIdx2);
      }
    } else if (c.variant == ContrVariant.Scale) {
      // Evaluate subcontr with magnified scale
      // Return empty if scale is 0 OR subcontr evaluates to empty
      // TODO: Expression evaluation
      k = consts[c.const1];
      if (k.integer == 0) {
        return contrEmpty();
      }

      uint outCtrIdx = evaluateContr(ctx, c.contr1, k.integer * scale);
      Contr outCtr = contrs[outCtrIdx];

      if (outCtr.variant == ContrVariant.Empty) {
        return outCtrIdx;
      } else {
        return contrScale(c.const1, outCtrIdx);
      }
    } else if (c.variant == ContrVariant.Transfer) {
      transferTokens(ctx, c.identifier1, c.identifier2, c.identifier3, scale);
      return contrEmpty();
    } else if (c.variant == ContrVariant.IfBefore) {
      // TODO: Exression evaluation
      evaluateExpr(ctx, c.expr1);
    }
  }

  function evaluateExpr(uint contractId, uint inExprIdx)
  internal returns (uint) {
    Contract c = contracts[contractId];
    Expr e = exprs[inExprIdx];

    if (e.variant == ExprVariant.Constant) {
      Const k = consts[e.const1];
      if (k.variant == ConstVariant.Label && k.label == "this") {
        return constInteger(int(contractId));
      } else {
        return inExprIdx;
      }
    } else if (e.variant == ExprVariant.Variable) {
      return lookup(c.currentEnv, e.identifier1);
    } else if (e.variant == ExprVariant.Observation) {
      return evaluateExprObservation(contractId, inExprIdx);
    } else if (e.variant == ExprVariant.Acc) {
      return evaluateExprAcc(contractId, inExprIdx);
    } else if (e.variant == ExprVariant.Plus
    || e.variant == ExprVariant.Equal
    || e.variant == ExprVariant.LessEqual
    || e.variant == ExprVariant.And) {
      return evaluateExprBinaryOp(contractId, inExprIdx);
    } else if (e.variant == ExprVariant.Not) {
      return evaluateExprUnaryOp(contractId, inExprIdx);
    }

    // Couldn't evaluate (type error)
    return inExprIdx;
  }

  function evaluateExprObservation(uint contractId, uint inExprIdx)
  internal returns (uint) {
    Contract c = contracts[contractId];
    Expr e = exprs[inExprIdx];

    Expr e1 = exprs[evaluateExpr(contractId, e.expr1)];
    Expr e2 = exprs[evaluateExpr(contractId, e.expr2)];

    if (e1.variant != ExprVariant.Constant || e2.variant != ExprVariant.Constant) {
      return inExprIdx;
    }

    Const k1 = consts[e1.const1];
    Const k2 = consts[e2.const1];

    Feed f = Feed(c.feeds[e.identifier1]);
    return f.get(sha3(k1.label, k2.integer));
  }

  function evaluateExprAcc(uint contractId, uint inExprIdx)
  internal returns (uint) {
    Contract c = contracts[contractId];
    Expr e = exprs[inExprIdx];

    int t = consts[e.const1].integer;
    int d = consts[e.const2].integer;
    int n = consts[e.const2].integer;

    if (t + d * n < int(block.timestamp)) return inExprIdx;

    uint currentExpr = e.expr2;
    for (uint i = 0; i <= uint(n); i++) {
      pushAssignment(contractId, e.identifier1, currentExpr);
      pushAssignment(contractId, e.identifier2, exprConstant(constInteger(t + d * int(i))));
      currentExpr = evaluateExpr(contractId, e.expr1);
      popAssignment(contractId);
      popAssignment(contractId);
    }

    return currentExpr;
  }

  function evaluateExprUnaryOp(uint contractId, uint inExprIdx)
  internal returns (uint) {
    // Get expr in questio
    Expr e = exprs[inExprIdx];
    uint exprIdx1 = evaluateExpr(contractId, e.expr1);
    Expr expr1 = exprs[exprIdx1];

    // If not constant, can't evaluate
    if (expr1.variant != ExprVariant.Constant) {
      return inExprIdx;
    }

    // Get constants
    Const k1 = consts[expr1.const1];

    // Handle cases by type
    if (k1.variant == ConstVariant.Boolean) {
      if (e.variant == ExprVariant.Not) {
        return constBoolean(!k1.boolean);
      }
    }

    // Couldn't reduce, return same (indicates type error)
    return inExprIdx;
  }

  function evaluateExprBinaryOp(uint contractId, uint inExprIdx)
  internal returns (uint) {
    // Get expr in questio
    Expr e = exprs[inExprIdx];

    // Evaluate each sub expr
    uint exprIdx1 = evaluateExpr(contractId, e.expr1);
    uint exprIdx2 = evaluateExpr(contractId, e.expr2);
    Expr expr1 = exprs[exprIdx1];
    Expr expr2 = exprs[exprIdx2];

    // If both not constant, can't evaluate
    if (expr1.variant != ExprVariant.Constant
    || expr2.variant != ExprVariant.Constant) {
      return inExprIdx;
    }

    // Get constants
    Const k1 = consts[expr1.const1];
    Const k2 = consts[expr2.const2];

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
    return inExprIdx;
  }

  /// Evaluation helpers

  function transferTokens(uint ctx, bytes8 tIdent, bytes8 p1Ident, bytes8 p2Ident,
  int amount) internal {
    // Can't transfer negative amounts
    if (amount < 0) throw;

    // Get contract
    Contract c = contracts[ctx];

    // Translate identifiers
    Token t = Token(c.tokens[tIdent]);
    address p1 = c.parties[p1Ident];
    address p2 = c.parties[p2Ident];

    // Transfer
    bool res = t.transferFrom(p1, p2, uint256(amount));
    if (!res) throw;
  }

  function pushAssignment(uint contractId, bytes8 identifier, uint exprId) internal {
    Contract c = contracts[contractId];
    uint idx = c.currentEnv.length;
    c.currentEnv.length++;
    c.currentEnv[idx] = Assignment({
      identifier: identifier,
      expr: exprId
    });
  }

  function popAssignment(uint contractId) internal {
    Contract c = contracts[contractId];
    uint idx = c.currentEnv.length - 1;
    delete c.currentEnv[idx];
    c.currentEnv.length--;
  }

  function lookup(Assignment[] env, bytes8 identifier) internal returns (uint) {
    for (uint i = env.length - 1; i >= 0; i--) {
      if (env[i].identifier == identifier) {
        return env[i].expr;
      }
    }
    return 0;
  }

  /// Const constructors

  function constBoolean(bool b) internal returns (uint idx) {
    idx = nextConst();
    consts[idx] = Const({
      variant: ConstVariant.Boolean,
      boolean: b,
      integer: 0,
      label: ""
    });
  }

  function constInteger(int i) internal returns (uint idx) {
    idx = nextConst();
    consts[idx] = Const({
      variant: ConstVariant.Integer,
      boolean: false,
      integer: i,
      label: ""
    });
  }

  function constLabel(bytes8 l) internal returns (uint idx) {
    idx = nextConst();
    consts[idx] = Const({
      variant: ConstVariant.Label,
      boolean: false,
      integer: 0,
      label: l
    });
  }

  /// Expression constructors

  function exprConstant(uint k) internal returns (uint idx) {
    idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Constant,
      identifier1: "",
      identifier2: "",
      const1: k,
      const2: 0,
      const3: 0,
      expr1: 0,
      expr2: 0,
      expr3: 0
    });
  }

  function exprVariable(bytes8 x) internal returns (uint idx) {
    idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Variable,
      identifier1: x,
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: 0,
      expr2: 0,
      expr3: 0
    });
  }

  function exprObservation(bytes8 feed, uint e1, uint e2, uint e3)
  internal returns (uint idx) {
    idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Observation,
      identifier1: feed,
      identifier2: 0,
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e1,
      expr2: e2,
      expr3: e3
    });
  }

  function exprAcc(uint c1, uint c2, uint c3, bytes8 i1, bytes8 i2,
  uint e1, uint e2) internal returns (uint idx) {
    idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Acc,
      identifier1: i1,
      identifier2: i2,
      const1: c1,
      const2: c2,
      const3: c3,
      expr1: e1,
      expr2: e2,
      expr3: 0,
    });
  }

  function exprPlus(uint e1, uint e2)
  internal returns (uint idx) {
    idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Plus,
      identifier1: "",
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e1,
      expr2: e2,
      expr3: 0
    });
  }

  function exprEqual(uint e1, uint e2)
  internal returns (uint idx) {
    idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Equal,
      identifier1: "",
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e1,
      expr2: e2,
      expr3: 0
    });
  }

  function exprLessEqual(uint e1, uint e2)
  internal returns (uint idx) {
    idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.LessEqual,
      identifier1: "",
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e1,
      expr2: e2,
      expr3: 0
    });
  }

  function exprAnd(uint e1, uint e2) internal returns (uint idx) {
    idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.And,
      identifier1: "",
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e1,
      expr2: e2,
      expr3: 0
    });
  }

  function exprNot(uint e) internal returns (uint idx) {
    idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Not,
      identifier1: "",
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e,
      expr2: 0,
      expr3: 0
    });
  }

  /// Contr constructors

  function contrEmpty() internal returns (uint idx) {
    idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.Empty,
      identifier1: "",
      identifier2: "",
      identifier3: "",
      const1: 0,
      expr1: 0,
      contr1: 0,
      contr2: 0
    });
  }

  function contrAfter(uint k, uint c)
  internal returns (uint idx) {
    idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.After,
      identifier1: "",
      identifier2: "",
      identifier3: "",
      const1: k,
      expr1: 0,
      contr1: c,
      contr2: 0
    });
  }

  function contrAnd(uint c1, uint c2) internal returns (uint idx) {
    idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.And,
      identifier1: "",
      identifier2: "",
      identifier3: "",
      const1: 0,
      expr1: 0,
      contr1: c1,
      contr2: c2
    });
  }

  function contrScale(uint e, uint c) internal returns (uint idx) {
    idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.Scale,
      identifier1: "",
      identifier2: "",
      identifier3: "",
      const1: 0,
      expr1: e,
      contr1: c,
      contr2: 0
    });
  }

  function contrTransfer(bytes8 a, bytes8 p, bytes8 q)
  internal returns (uint idx) {
    idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.Transfer,
      identifier1: a,
      identifier2: p,
      identifier3: q,
      const1: 0,
      expr1: 0,
      contr1: 0,
      contr2: 0
    });
  }

  function contrIfBefore(uint e, uint k, uint c1, uint c2)
  internal returns (uint idx) {
    idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.IfBefore,
      identifier1: "",
      identifier2: "",
      identifier3: "",
      const1: k,
      expr1: e,
      contr1: c1,
      contr2: c2
    });
  }

  /// Language structs (consts, expressions, contrs)

  struct Const {
    ConstVariant variant;
    int integer;
    bool boolean;
    bytes8 label;
  }
  enum ConstVariant {
    Boolean,
    Integer,
    Label
  }

  struct Expr {
    ExprVariant variant;
    bytes8 identifier1;
    bytes8 identifier2;
    uint const1;
    uint const2;
    uint const3;
    uint expr1;
    uint expr2;
    uint expr3;
  }
  enum ExprVariant {
    Constant,
    Variable,
    Observation,
    Acc,
    Plus,
    Equal,
    LessEqual,
    And,
    Not
  }

  struct Contr {
    ContrVariant variant;
    bytes8 identifier1;
    bytes8 identifier2;
    bytes8 identifier3;
    uint const1;
    uint expr1;
    uint contr1;
    uint contr2;
  }
  enum ContrVariant {
    Empty,
    After,
    And,
    Scale,
    Transfer,
    IfBefore
  }

  /// Language helpers

  function nextConst() returns (uint) {
    uint idx = consts.length;
    consts.length++;
    return idx;
  }

  function nextExpr() returns (uint) {
    uint idx = exprs.length;
    exprs.length++;
    return idx;
  }

  function nextContr() returns (uint) {
    uint idx = contrs.length;
    contrs.length++;
    return idx;
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
