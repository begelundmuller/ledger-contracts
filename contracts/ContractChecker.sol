pragma solidity ^0.4.2;

import './ContractBuilder.sol';

contract ContractChecker is ContractBuilder {

  enum NameKind {
    Feed,
    Party,
    Token
  }

  function ContractChecker() ContractBuilder()  {
  }

  function checkerEncounteredName(uint key, NameKind kind, bytes8 name) internal;

  function checkContract(uint key, uint contractId) internal {
    Contr c = contrs[contractId];
    if (c.variant == ContrVariant.Zero) {
    } else if (c.variant == ContrVariant.Translate) {
      checkContract(key, c.contr1);
    } else if (c.variant == ContrVariant.Both) {
      checkContract(key, c.contr1);
      checkContract(key, c.contr2);
    } else if (c.variant == ContrVariant.Scale) {
      checkExpression(key, c.expr1);
      checkContract(key, c.contr1);
    } else if (c.variant == ContrVariant.Transfer) {
      checkerEncounteredName(key, NameKind.Token, c.identifier1);
      checkerEncounteredName(key, NameKind.Party, c.identifier2);
      checkerEncounteredName(key, NameKind.Party, c.identifier3);
    } else if (c.variant == ContrVariant.IfWithin) {
      checkExpression(key, c.expr1);
      checkContract(key, c.contr1);
      checkContract(key, c.contr2);
    }
  }

  function checkExpression(uint key, uint expressionId) internal {
    Expr e = exprs[expressionId];
    if (e.variant == ExprVariant.Now) {
    } else if (e.variant == ExprVariant.Constant) {
    } else if (e.variant == ExprVariant.Variable) {
    } else if (e.variant == ExprVariant.Observation) {
      checkerEncounteredName(key, NameKind.Feed, e.identifier1);
      checkExpression(key, e.expr1);
      checkExpression(key, e.expr2);
    } else if (e.variant == ExprVariant.Foldt) {
      checkExpression(key, e.expr1);
      checkExpression(key, e.expr2);
    } else if (e.variant == ExprVariant.Plus) {
      checkExpression(key, e.expr1);
      checkExpression(key, e.expr2);
    } else if (e.variant == ExprVariant.Equal) {
      checkExpression(key, e.expr1);
      checkExpression(key, e.expr2);
    } else if (e.variant == ExprVariant.LessEqual) {
      checkExpression(key, e.expr1);
      checkExpression(key, e.expr2);
    } else if (e.variant == ExprVariant.And) {
      checkExpression(key, e.expr1);
      checkExpression(key, e.expr2);
    } else if (e.variant == ExprVariant.Not) {
      checkExpression(key, e.expr1);
    } else if (e.variant == ExprVariant.IfElse) {
      checkExpression(key, e.expr1);
      checkExpression(key, e.expr2);
      checkExpression(key, e.expr3);
    }
  }

}
