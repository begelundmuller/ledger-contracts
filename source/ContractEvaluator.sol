pragma solidity ^0.4.2;

import './ContractChecker.sol';

contract ContractEvaluator is ContractChecker {

  /// Represents a variable assignment
  struct Assignment {
    bytes8 identifier;
    uint expr;
  }

  /// Used during evaluation of contracts (cleared in-between)
  Assignment[] internal evaluationEnv;

  /// Initializer
  function ContractEvaluator() ContractChecker()  {
  }

  /// Implemented by subclass to handle transfer
  /// The transfer will reduce to the empty contract iff return value is true
  function handleTransfer(uint key, bytes8 token, bytes8 from, bytes8 to, int scale)
  internal returns (bool);

  /// Implemented by subclass
  function handleObservation(uint key, bytes8 name, bytes32 digest, uint time) internal returns (int);

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

  function currentTime(uint timeDelta) internal constant returns (uint) {
    uint drop = block.timestamp % timeDelta;
    return block.timestamp - drop;
  }

  /// Evaluation
  /// ----------

  /// Evaluates given contract and returns the ID of the reduced contract
  function evaluateContract(uint key, uint timeDelta, uint contractId, int scale)
  internal returns (uint) {
    // Get contract
    Contr c = contrs[contractId];

    // Proceed by case analysis
    if (c.variant == ContrVariant.Empty) {
      // Cannot reduce the empty contract
    } else if (c.variant == ContrVariant.After) {
      // Reduce if past time
      if (consts[c.const1].integer <= int256(block.timestamp)) {
        return evaluateContract(key, timeDelta, c.contr1, scale);
      }
    } else if (c.variant == ContrVariant.And) {
      return evaluateAndContract(key, timeDelta, contractId, scale);
    } else if (c.variant == ContrVariant.Scale) {
      return evaluateScaleContract(key, timeDelta, contractId, scale);
    } else if (c.variant == ContrVariant.Transfer) {
      // Reduce to empty if handled; else stays the same
      if (handleTransfer(key, c.identifier1, c.identifier2, c.identifier3, scale)) {
        return contrEmpty();
      } else {
        return contractId;
      }
    } else if (c.variant == ContrVariant.IfWithin) {
      return evaluateIfWithinContract(key, timeDelta, contractId, scale);
    }

    // If not handled above, stays unchanged
    return contractId;
  }

  function evaluateAndContract(uint key, uint timeDelta, uint contractId, int scale)
  internal returns (uint) {
    // Get contract
    Contr c = contrs[contractId];

    // Reduce both contrs
    uint outContractId1 = evaluateContract(key, timeDelta, c.contr1, scale);
    uint outContractId2 = evaluateContract(key, timeDelta, c.contr2, scale);
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
  }

  function evaluateScaleContract(uint key, uint timeDelta, uint contractId, int scale)
  internal returns (uint) {
    // Get contract
    Contr c = contrs[contractId];

    // Evaluate expression for scale value
    uint outExprId = evaluateExpression(key, timeDelta, c.expr1);
    Expr outExpr = exprs[outExprId];

    // If scale value doesn't evaluate to constant, cannot proceed
    if (outExpr.variant != ExprVariant.Constant) {
      return contractId;
    }

    // Get scale constant (if scaling by 0, return the empty contract)
    Const k = consts[outExpr.const1];
    if (k.integer == 0) {
      return contrEmpty();
    }

    // Evaluate subcontract with increased scale
    uint outContractId = evaluateContract(key, timeDelta, c.contr1, k.integer * scale);
    Contr outContract = contrs[outContractId];

    // Keep scaling only if not empty
    if (outContract.variant == ContrVariant.Empty) {
      return outContractId;
    } else {
      return contrScale(outExprId, outContractId);
    }
  }

  function evaluateIfWithinContract(uint key, uint timeDelta, uint contractId, int scale)
  internal returns (uint) {
    // Get contract
    Contr c = contrs[contractId];

    // Get n and t0
    int n = consts[c.const1].integer;
    int t0 = consts[c.const2].integer;

    // Evaluate
    bool result = false;
    for (uint i = 0; i < uint(n) && !result; i++) {
      // Calculate time
      int t = t0 + int(i * timeDelta);

      // Proceed only if not in the future
      if (uint(t) <= block.timestamp) {
        // Evaluate lambda
        pushEnv(c.identifier1, exprConstant(constInteger(t)));
        uint exprId = evaluateExpression(key, timeDelta, c.expr1);
        popEnv();

        // If returns a constant, set result to that
        Expr expr = exprs[exprId];
        if (expr.variant == ExprVariant.Constant) {
          Const k = consts[expr.const1];
          if (k.variant == ConstVariant.Boolean) {
            result = result || k.boolean;
          }
        }
      }
    }

    // Done
    if (result) {
      return evaluateContract(key, timeDelta, c.contr1, scale);
    } else if (t0 + n > int(block.timestamp)) {
      return contractId;
    } else {
      return evaluateContract(key, timeDelta, c.contr2, scale);
    }
  }

  /// Evaluates expression and returns the ID of the reduced expression
  function evaluateExpression(uint key, uint timeDelta, uint expressionId)
  internal returns (uint) {
    // Get expression
    Expr e = exprs[expressionId];

    // Proceed by case analysis
    if (e.variant == ExprVariant.Constant) {
    } else if (e.variant == ExprVariant.Variable) {
      return lookupEnv(e.identifier1);
    } else if (e.variant == ExprVariant.Observation) {
      return evaluateExpressionObservation(key, timeDelta, expressionId);
    } else if (e.variant == ExprVariant.Acc) {
      return evaluateExpressionAcc(key, timeDelta, expressionId);
    } else if (e.variant == ExprVariant.Plus
    || e.variant == ExprVariant.Equal
    || e.variant == ExprVariant.LessEqual
    || e.variant == ExprVariant.And) {
      return evaluateExpressionBinaryOp(key, timeDelta, expressionId);
    } else if (e.variant == ExprVariant.Not) {
      return evaluateExpressionUnaryOp(key, timeDelta, expressionId);
    } else if (e.variant == ExprVariant.IfElse) {
      return evaluateExpressionIfElse(key, timeDelta, expressionId);
    }

    // If not handled above, stays unchanged
    return expressionId;
  }

  /// Evaluates an Obs expression
  function evaluateExpressionObservation(uint key, uint timeDelta, uint expressionId)
  internal returns (uint) {
    // Get expression and evaluate sub-expressions
    Expr e = exprs[expressionId];
    Expr e1 = exprs[evaluateExpression(key, timeDelta, e.expr1)];
    Expr e2 = exprs[evaluateExpression(key, timeDelta, e.expr2)];

    // If both don't evaluate to a constant, can't yet do anything
    if (e1.variant != ExprVariant.Constant || e2.variant != ExprVariant.Constant) {
      return expressionId;
    }

    // Get constants
    Const k1 = consts[e1.const1];
    Const k2 = consts[e2.const1];

    // Get value from feed
    int k = handleObservation(key, e.identifier1, k1.digest, uint(k2.integer));
    if (k == 0) {
      return expressionId;
    } else {
      return exprConstant(constInteger(k));
    }
  }

  /// Evaluates an Acc expression
  function evaluateExpressionAcc(uint key, uint timeDelta, uint expressionId)
  internal returns (uint) {
    // Get
    Expr e = exprs[expressionId];

    // Get constants
    int t = consts[e.const1].integer;
    int n = consts[e.const2].integer;

    // Cannot reduce if all times accumulated over are not in the past
    if (t + int(timeDelta) * n < int(block.timestamp)) return expressionId;

    // Accummulate
    uint currentExpr = e.expr2;
    for (uint i = 0; i <= uint(n); i++) {
      pushEnv(e.identifier1, currentExpr);
      pushEnv(e.identifier2, exprConstant(constInteger(t + int(timeDelta * i))));
      currentExpr = evaluateExpression(key, timeDelta, e.expr1);
      popEnv();
      popEnv();
    }

    // Return result of accumulation
    return currentExpr;
  }

  /// Evaluates a unary operation (currently only +not+)
  function evaluateExpressionUnaryOp(uint key, uint timeDelta, uint expressionId)
  internal returns (uint) {
    // Get expr in question
    Expr e = exprs[expressionId];
    uint outExpressionId = evaluateExpression(key, timeDelta, e.expr1);
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
  function evaluateExpressionBinaryOp(uint key, uint timeDelta, uint expressionId)
  internal returns (uint) {
    // Get expr in question
    Expr e = exprs[expressionId];

    // Evaluate each sub expr
    uint exprId1 = evaluateExpression(key, timeDelta, e.expr1);
    uint exprId2 = evaluateExpression(key, timeDelta, e.expr2);
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
  function evaluateExpressionIfElse(uint key, uint timeDelta, uint expressionId)
  internal returns (uint) {
    // Get expr in question
    Expr e = exprs[expressionId];

    // Evaluate conditional
    uint condExprId = evaluateExpression(key, timeDelta, e.expr1);
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
    return evaluateExpression(key, timeDelta, outExprId);
  }

}
