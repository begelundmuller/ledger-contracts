pragma solidity ^0.4.2;

contract ContractBuilder {

  /// Constructor structs
  /// -------------------

  /// Constants
  enum ConstVariant {
    Boolean,
    Integer,
    Label
  }

  struct Const {
    ConstVariant variant;
    int integer;
    bool boolean;
    bytes8 label;
  }

  /// Expressions
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

  struct Expr {
    ExprVariant variant;
    bytes8 identifier1;
    bytes8 identifier2;
    uint const1;
    uint const2;
    uint const3;
    uint expr1;
    uint expr2;
  }

  /// Contracts
  enum ContrVariant {
    Empty,
    After,
    And,
    Scale,
    Transfer,
    IfWithin
  }

  struct Contr {
    ContrVariant variant;
    bytes8 identifier1;
    bytes8 identifier2;
    bytes8 identifier3;
    uint const1;
    uint const2;
    uint expr1;
    uint contr1;
    uint contr2;
  }

  /// State
  /// -----

  /// Storage for constructions
  Const[] public consts;
  Expr[]  public exprs;
  Contr[] public contrs;

  /// Initializer
  function ContractBuilder() {
    consts.length++;
    exprs.length++;
    contrs.length++;
  }

  /// Constant constructors
  /// ---------------------

  /// Const for a boolean
  function constBoolean(bool b) internal returns (uint) {
    uint idx = nextConst();
    consts[idx] = Const({
      variant: ConstVariant.Boolean,
      boolean: b,
      integer: 0,
      label: ""
    });
return idx;
    return idx;
  }

  /// Const for an integer
  function constInteger(int i) internal returns (uint) {
    uint idx = nextConst();
    consts[idx] = Const({
      variant: ConstVariant.Integer,
      boolean: false,
      integer: i,
      label: ""
    });
    return idx;
  }

  /// Const for a label
  function constLabel(bytes8 l) internal returns (uint) {
    uint idx = nextConst();
    consts[idx] = Const({
      variant: ConstVariant.Label,
      boolean: false,
      integer: 0,
      label: l
    });
    return idx;
  }

  /// Expression constructors
  /// -----------------------

  /// Expr for a const
  function exprConstant(uint k) internal returns (uint) {
    uint idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Constant,
      identifier1: "",
      identifier2: "",
      const1: k,
      const2: 0,
      const3: 0,
      expr1: 0,
      expr2: 0
    });
    return idx;
  }

  /// Expr for a variable
  function exprVariable(bytes8 x) internal returns (uint) {
    uint idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Variable,
      identifier1: x,
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: 0,
      expr2: 0
    });
    return idx;
  }

  /// Expr for an observation
  function exprObservation(bytes8 feed, uint e1)
  internal returns (uint) {
    uint idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Observation,
      identifier1: feed,
      identifier2: 0,
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e1,
      expr2: 0
    });
    return idx;
  }

  /// Expr for an accumulation
  function exprAcc(bytes8 i1, bytes8 i2, uint e1, uint e2, uint k1,
  uint k2, uint k3) internal returns (uint) {
    uint idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Acc,
      identifier1: i1,
      identifier2: i2,
      const1: k1,
      const2: k2,
      const3: k3,
      expr1: e1,
      expr2: e2
    });
    return idx;
  }

  /// Expr for addition
  function exprPlus(uint e1, uint e2)
  internal returns (uint) {
    uint idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Plus,
      identifier1: "",
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e1,
      expr2: e2
    });
    return idx;
  }

  /// Expr for checking equality
  function exprEqual(uint e1, uint e2)
  internal returns (uint) {
    uint idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Equal,
      identifier1: "",
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e1,
      expr2: e2
    });
    return idx;
  }

  /// Expr for <=
  function exprLessEqual(uint e1, uint e2)
  internal returns (uint) {
    uint idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.LessEqual,
      identifier1: "",
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e1,
      expr2: e2
    });
    return idx;
  }

  /// Expr for logical and
  function exprAnd(uint e1, uint e2) internal returns (uint) {
    uint idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.And,
      identifier1: "",
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e1,
      expr2: e2
    });
    return idx;
  }

  /// Expr for logical not
  function exprNot(uint e) internal returns (uint) {
    uint idx = nextExpr();
    exprs[idx] = Expr({
      variant: ExprVariant.Not,
      identifier1: "",
      identifier2: "",
      const1: 0,
      const2: 0,
      const3: 0,
      expr1: e,
      expr2: 0
    });
    return idx;
  }

  /// Contract constructors
  /// ---------------------

  /// Ø
  function contrEmpty() internal returns (uint) {
    uint idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.Empty,
      identifier1: "",
      identifier2: "",
      identifier3: "",
      const1: 0,
      const2: 0,
      expr1: 0,
      contr1: 0,
      contr2: 0
    });
    return idx;
  }

  /// k ↑ c
  function contrAfter(uint k, uint c)
  internal returns (uint) {
    uint idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.After,
      identifier1: "",
      identifier2: "",
      identifier3: "",
      const1: k,
      const2: 0,
      expr1: 0,
      contr1: c,
      contr2: 0
    });
    return idx;
  }

  /// c1 & c2
  function contrAnd(uint c1, uint c2) internal returns (uint) {
    uint idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.And,
      identifier1: "",
      identifier2: "",
      identifier3: "",
      const1: 0,
      const2: 0,
      expr1: 0,
      contr1: c1,
      contr2: c2
    });
    return idx;
  }

  /// e × c
  function contrScale(uint e, uint c) internal returns (uint) {
    uint idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.Scale,
      identifier1: "",
      identifier2: "",
      identifier3: "",
      const1: 0,
      const2: 0,
      expr1: e,
      contr1: c,
      contr2: 0
    });
    return idx;
  }

  /// a(p → q)
  function contrTransfer(bytes8 a, bytes8 p, bytes8 q)
  internal returns (uint) {
    uint idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.Transfer,
      identifier1: a,
      identifier2: p,
      identifier3: q,
      const1: 0,
      const2: 0,
      expr1: 0,
      contr1: 0,
      contr2: 0
    });
    return idx;
  }

  // if \t . e within n of t0 then c1 else c2
  function contrIfWithin(bytes8 t, uint e, uint n, uint t0, uint c1, uint c2)
  internal returns (uint) {
    uint idx = nextContr();
    contrs[idx] = Contr({
      variant: ContrVariant.IfWithin,
      identifier1: t,
      identifier2: "",
      identifier3: "",
      const1: n,
      const2: t0,
      expr1: e,
      contr1: c1,
      contr2: c2
    });
    return idx;
  }

  /// Constructor helpers
  /// -------------------

  function nextConst() internal returns (uint) {
    uint idx = consts.length;
    consts.length++;
    return idx;
  }

  function nextExpr() internal returns (uint) {
    uint idx = exprs.length;
    exprs.length++;
    return idx;
  }

  function nextContr() internal returns (uint) {
    uint idx = contrs.length;
    contrs.length++;
    return idx;
  }

}
