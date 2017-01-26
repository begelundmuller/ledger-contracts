pragma solidity ^0.4.2;

import './ContractChecker.sol';

contract ContractEngine is ContractChecker {

  /// Represents a variable assignment
  struct Assignment {
    bytes8 identifier;
    uint expr;
  }

  /// Used during evaluation of contracts (cleared in-between)
  Assignment[] internal evaluationEnv;

  /// Initializer
  function ContractEngine() ContractChecker()  {
  }

  /// Implemented by subclass to handle transfer
  /// The transfer will reduce to the empty contract iff return value is true
  function handleTransfer(uint key, bytes8 token, bytes8 from, bytes8 to, int scale)
  internal returns (bool);

  /// Implemented by subclass
  function handleObservation(uint key, bytes8 name, bytes32 digest, uint time) internal returns (int);

  /// Implemented by subclass
  /// Use to get time delta of contract
  function timeDelta(uint key) internal returns (uint td);

  /// Env helpers
  /// -----------

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

  /// Time helpers
  /// ------------

  function currentTime(uint key) internal constant returns (uint) {
    uint td = timeDelta(key);
    uint drop = block.timestamp % td;
    return block.timestamp - drop;
  }

  /// Evaluation
  /// ----------

  /// Evaluates given contract and returns the ID of the reduced contract
  function evaluateContract(uint key, uint now, uint contractId, int scale)
  internal returns (uint) {
    // Get contract
    Contr c = contrs[contractId];

    // Proceed by case analysis
    if (c.variant == ContrVariant.Zero) {
      // Cannot reduce the empty contract
    } else if (c.variant == ContrVariant.Translate) {
      // Specialise
      uint translateTimeExprIdx = evaluateExpression(key, now, c.expr1);
      Expr translateTimeExpr = exprs[translateTimeExprIdx];
      if (translateTimeExpr.variant == ExprVariant.Constant) {
        uint translateTo = uint(consts[translateTimeExpr.const1].integer) + now;
        c.variant = ContrVariant.TranslateSpecialized;
        c.const1 = constInteger(int(translateTo));
        c.expr1 = 0;
        return evaluateContract(key, now, contractId, scale);
      }
    } else if (c.variant == ContrVariant.TranslateSpecialized) {
      // Reduce if past time
      translateTo = uint(consts[c.const1].integer);
      if (translateTo <= now) {
        uint tmpContractId = evaluateContract(key, translateTo, c.contr1, scale);
        return evaluateContract(key, now, tmpContractId, scale);
      }
    } else if (c.variant == ContrVariant.Both) {
      return evaluateBothContract(key, now, contractId, scale);
    } else if (c.variant == ContrVariant.Scale) {
      return evaluateScaleContract(key, now, contractId, scale);
    } else if (c.variant == ContrVariant.Transfer) {
      // Reduce to empty if handled; else stays the same
      if (handleTransfer(key, c.identifier1, c.identifier2, c.identifier3, scale)) {
        return contrZero();
      } else {
        return contractId;
      }
    } else if (c.variant == ContrVariant.IfWithin) {
      c.const1 = constInteger(int(now));
      c.expr2 = evaluateExpression(key, now, c.expr2);
      c.expr3 = evaluateExpression(key, now, c.expr3);
      c.variant = ContrVariant.IfWithinSpecialized;
      return evaluateContract(key, now, contractId, scale);
    } else if (c.variant == ContrVariant.IfWithinSpecialized) {
      return evaluateIfWithinSpecializedContract(key, now, contractId, scale);
    }

    // If not handled above, stays unchanged
    return contractId;
  }

  function evaluateBothContract(uint key, uint now, uint contractId, int scale)
  internal returns (uint) {
    // Get contract
    Contr c = contrs[contractId];

    // Reduce both contrs
    uint outContractId1 = evaluateContract(key, now, c.contr1, scale);
    uint outContractId2 = evaluateContract(key, now, c.contr2, scale);
    Contr outContract1 = contrs[outContractId1];
    Contr outContract2 = contrs[outContractId2];

    // If either is empty, no longer need for Both
    if (outContract1.variant == ContrVariant.Zero) {
      return outContractId2;
    } else if (outContract2.variant == ContrVariant.Zero) {
      return outContractId1;
    } else {
      return contrBoth(outContractId1, outContractId2);
    }
  }

  function evaluateScaleContract(uint key, uint now, uint contractId, int scale)
  internal returns (uint) {
    // Get contract
    Contr c = contrs[contractId];

    // Evaluate expression for scale value
    uint outExprId = evaluateExpression(key, now, c.expr1);
    Expr outExpr = exprs[outExprId];

    // If scale value doesn't evaluate to constant, cannot proceed
    if (outExpr.variant != ExprVariant.Constant) {
      return contractId;
    }

    // Get scale constant (if scaling by 0, return the empty contract)
    Const k = consts[outExpr.const1];
    if (k.integer == 0) {
      return contrZero();
    }

    // Evaluate subcontract with increased scale
    uint outContractId = evaluateContract(key, now, c.contr1, k.integer * scale);
    Contr outContract = contrs[outContractId];

    // Keep scaling only if not empty
    if (outContract.variant == ContrVariant.Zero) {
      return outContractId;
    } else {
      return contrScale(outExprId, outContractId);
    }
  }

  function evaluateIfWithinSpecializedContract(uint key, uint ct, uint contractId, int scale)
  internal returns (uint) {
    // Get contract
    Contr c = contrs[contractId];

    // Get end of now (set to absolute timestamps when specialised)
    Expr endExpr = exprs[evaluateExpression(key, ct, c.expr2)];
    Expr nowExpr = exprs[evaluateExpression(key, ct, c.expr3)];
    int end = consts[endExpr.const1].integer + consts[c.const1].integer;
    int now = consts[nowExpr.const1].integer;

    // Split into two functions because of stack size limitations
    return evaluateIfWithinSpecializedContractPrime(key, ct, contractId, scale, end, now);
  }

  function evaluateIfWithinSpecializedContractPrime(uint key, uint ct, uint contractId, int scale, int end, int now)
  internal returns (uint) {
    // Get contract
    Contr c = contrs[contractId];

    // When to stop loop©
    int minEndCt = 0;
    if (int(ct) <= end) {
      minEndCt = int(ct);
    } else {
      minEndCt = end;
    }

    // Evaluate
    bool result = false;
    for (uint i = 0; now <= minEndCt && !result; i++) {
      // Evaluate expression for now
      Expr expr = exprs[evaluateExpression(key, uint(now), c.expr1)];

      // If returns a constant, set result to that
      if (expr.variant == ExprVariant.Constant) {
        Const k = consts[expr.const1];
        if (k.variant == ConstVariant.Boolean) {
          result = result || k.boolean;
        }
      }

      // Update now
      now = now + int(timeDelta(key));
    }

    // Done
    if (result) {
      // TODO: Replace occurences in c.contr1 with of c.identifier1 with exprConstant(constInteger(int(now) - consts[c.const1].integer)
      uint tmpContractId = evaluateContract(key, uint(now), c.contr1, scale);
      return evaluateContract(key, ct, tmpContractId, scale);
    } else if (now >= end) {
      // TODO: Replace occurences in c.contr2 with of c.identifier1 with exprConstant(constInteger(int(end) - consts[c.const1].integer)
      tmpContractId = evaluateContract(key, uint(end), c.contr2, scale);
      return evaluateContract(key, ct, tmpContractId, scale);
    } else {
      c.expr3 = exprConstant(constInteger(now));
      return contractId;
    }
  }

  /// Evaluates expression and returns the ID of the reduced expression
  function evaluateExpression(uint key, uint now, uint expressionId)
  internal returns (uint) {
    // Get expression
    Expr e = exprs[expressionId];

    // Proceed by case analysis
    if (e.variant == ExprVariant.Now) {
      return exprConstant(constInteger(int(now)));
    } else if (e.variant == ExprVariant.Constant) {
    } else if (e.variant == ExprVariant.Variable) {
      return lookupEnv(e.identifier1);
    } else if (e.variant == ExprVariant.Observation) {
      return evaluateExpressionObservation(key, now, expressionId);
    } else if (e.variant == ExprVariant.Foldt) {
      return evaluateExpressionFoldt(key, now, expressionId);
    } else if (e.variant == ExprVariant.Plus
    || e.variant == ExprVariant.Equal
    || e.variant == ExprVariant.LessEqual
    || e.variant == ExprVariant.And) {
      return evaluateExpressionBinaryOp(key, now, expressionId);
    } else if (e.variant == ExprVariant.Not) {
      return evaluateExpressionUnaryOp(key, now, expressionId);
    } else if (e.variant == ExprVariant.IfElse) {
      return evaluateExpressionIfElse(key, now, expressionId);
    }

    // If not handled above, stays unchanged
    return expressionId;
  }

  /// Evaluates an Obs expression
  function evaluateExpressionObservation(uint key, uint now, uint expressionId)
  internal returns (uint) {
    // Get expression and evaluate time sub-expression
    Expr e = exprs[expressionId];
    Expr e1 = exprs[evaluateExpression(key, now, e.expr1)];

    // If both don't evaluate to a constant, can't do anything
    if (e1.variant != ExprVariant.Constant) {
      return expressionId;
    }

    // Get constants
    Const digestConst = consts[e.const1];
    Const timeConst = consts[e1.const1];

    // Get value from feed
    int k = handleObservation(key, e.identifier1, digestConst.digest, uint(timeConst.integer));
    if (k == 0) {
      return expressionId;
    } else {
      return exprConstant(constInteger(k));
    }
  }

  /// Evaluates an Foldt expression
  function evaluateExpressionFoldt(uint key, uint now, uint expressionId)
  internal returns (uint) {
    // Get
    Expr e = exprs[expressionId];

    // Get constants
    Expr tExpr = exprs[evaluateExpression(key, now, e.expr3)];
    if (tExpr.variant != ExprVariant.Constant) {
      return expressionId;
    }
    int timeAgo = consts[tExpr.const1].integer;
    int foldDelta = consts[e.const1].integer;

    // Accummulate
    uint currentExpr = e.expr2;
    uint currentNow = now - uint(timeAgo);
    for (uint i = 0; currentNow <= now; i++) {
      pushEnv(e.identifier1, currentExpr);
      currentExpr = evaluateExpression(key, currentNow, e.expr1);
      popEnv();
      currentNow = currentNow + uint(foldDelta);
    }

    // Return result of accumulation
    return currentExpr;
  }

  /// Evaluates a unary operation (currently only +not+)
  function evaluateExpressionUnaryOp(uint key, uint now, uint expressionId)
  internal returns (uint) {
    // Get expr in question
    Expr e = exprs[expressionId];
    uint outExpressionId = evaluateExpression(key, now, e.expr1);
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
        return exprConstant(constBoolean(!k1.boolean));
      }
    }

    // Couldn't reduce, return same (shouldn't happen)
    return expressionId;
  }

  /// Evaluates a binary operation
  function evaluateExpressionBinaryOp(uint key, uint now, uint expressionId)
  internal returns (uint) {
    // Get expr in question
    Expr e = exprs[expressionId];

    // Evaluate each sub expr
    uint exprId1 = evaluateExpression(key, now, e.expr1);
    uint exprId2 = evaluateExpression(key, now, e.expr2);
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
        return exprConstant(constInteger(k1.integer + k2.integer));
      } else if (e.variant == ExprVariant.Equal) {
        return exprConstant(constBoolean(k1.integer == k2.integer));
      } else if (e.variant == ExprVariant.LessEqual) {
        return exprConstant(constBoolean(k1.integer <= k2.integer));
      }
    } else if (k1.variant == ConstVariant.Boolean && k2.variant == ConstVariant.Boolean) {
      if (e.variant == ExprVariant.Equal) {
        return exprConstant(constBoolean(k1.boolean == k2.boolean));
      } else if (e.variant == ExprVariant.And) {
        return exprConstant(constBoolean(k1.boolean && k2.boolean));
      }
    }

    // Couldn't reduce, return same (indicates type error)
    return expressionId;
  }

  /// Evaluates an if-else
  function evaluateExpressionIfElse(uint key, uint now, uint expressionId)
  internal returns (uint) {
    // Get expr in question
    Expr e = exprs[expressionId];

    // Evaluate conditional
    uint condExprId = evaluateExpression(key, now, e.expr1);
    Expr condExpr = exprs[condExprId];

    // If not constant, can't evaluate yet
    if (condExpr.variant != ExprVariant.Constant) {
      return expressionId;
    }

    // Get constant (will be boolean)
    Const condConst = consts[condExpr.const1];

    // Handle cases by type
    uint outExprId;
    if (condConst.boolean) {
      outExprId = e.expr2;
    } else {
      outExprId = e.expr3;
    }

    // Return evaluated expression ID
    return evaluateExpression(key, now, outExprId);
  }

}
