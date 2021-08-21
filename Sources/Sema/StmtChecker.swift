import AST
import Basic

/// The type checker for Val's statements.
struct StmtChecker: StmtVisitor {

  typealias StmtResult = Bool

  /// The declaration space in which the visited statements reside.
  var useSite: DeclSpace

  /// The binding policy to adopt for substituting free type variables.
  let freeVarBindingPolicy: FreeTypeVarBindingPolicy

  /// The return statements that have been visited by the checker.
  var retStmts: [RetStmt] = []

  mutating func visit(_ node: BraceStmt) -> Bool {
    let oldUseSite = useSite
    useSite = node
    defer { useSite = oldUseSite }

    var isWellTyped = true
    for i in 0 ..< node.stmts.count {
      switch node.stmts[i] {
      case let decl as Decl:
        isWellTyped = TypeChecker.check(decl: decl) && isWellTyped

      case let stmt as Stmt:
        isWellTyped = stmt.accept(&self) && isWellTyped

      case var expr as Expr:
        TypeChecker.check(expr: &expr, useSite: node, freeVarBindingPolicy: freeVarBindingPolicy)
        node.stmts[i] = expr
        isWellTyped = !expr.type.hasErrors && isWellTyped

      default:
        fatalError("unexpected node")
      }
    }
    return isWellTyped
  }

  mutating func visit(_ node: RetStmt) -> Bool {
    retStmts.append(node)

    // Use the return type of the function as the fixed type of the returned value.
    let funDecl = node.funDecl ?< fatalError("return statement outside of a function")
    assert(funDecl.state >= .realized)
    let funType = funDecl.type as! FunType
    var fixedRetType = funType.retType

    if fixedRetType.hasTypeParams {
      if let env = funDecl.prepareGenericEnv() {
        (fixedRetType, _) = env.contextualize(fixedRetType, from: useSite)
      } else {
        fixedRetType = funType.context.errorType
      }
    }

    // Type check the returned value.
    if var value = node.value {
      // Type check the returned expression.
      TypeChecker.check(expr: &value, fixedType: fixedRetType, useSite: useSite)
      node.value = value
      return !value.type.hasErrors
    } else {
      return true
    }
//    if (fixedRetType != context.unitType) && !(funDecl is CtorDecl) {
//      // Complain that non-unit function should return a value.
//      context.report(.missingReturnValue(range: node.range))
//    }
  }

  func visit(_ node: MatchCaseStmt) -> Bool {
    fatalError("unreachable")
  }

}
