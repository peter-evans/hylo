import Foundation

import ArgumentParser
import Driver
import Eval

/// The compiler's command parser.
struct ValCommand: ParsableCommand {

  /// The home path for Val's runtime and standard library.
  static var home = URL(fileURLWithPath: "/opt/local/lib/val")

  @Argument(help: "The input file(s).", transform: URL.init(fileURLWithPath:))
  var input: [URL]

  @Option(help: "The location Val's runtime environment.", transform: URL.init(fileURLWithPath:))
  var home = ValCommand.home

  @Flag(help: "Parse and type-check input file(s) and dump AST(s).")
  var dumpAST = false

  func run() throws {
    // Create a new driver.
    let driver = Driver()
    driver.context.diagnosticConsumer = Terminal(sourceManager: driver.context.sourceManager)

    // Load the standard library.
    try driver.loadStdLib(path: home.appendingPathComponent("StdLib"))

    // Load the given input files as a module.
    if !input.isEmpty {
      // Parse the module.
      let decl = try driver.parse(moduleName: "main", moduleFiles: input)

      // Type check the module.
      guard driver.typeCheck(moduleDecl: decl) else { return }

      // Dump the module, if requested.
      if dumpAST {
        driver.dump()
        return
      }

      // Lower the module to VIL code.
      let main = try driver.lower(moduleDecl: decl)
      main.dump()

      // Interpret the module.
      var interpreter = Interpreter(context: driver.context)
      try interpreter.load(module: driver.lower(moduleDecl: driver.context.stdlib!))
      try interpreter.load(module: main)
      try interpreter.start()
    }
  }

}

ValCommand.main()
