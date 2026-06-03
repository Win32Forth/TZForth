//
//  TestLBForth.swift
//
//  Standalone tester for the LBForth engine (Leif Bruder public-domain model).
//
//  How to run (note: multi-file swift script needs concatenation on current Swift):
//
//      cd /path/to/TZForth
//      cat TZForth/LBForth.swift TestLBForth.swift > /tmp/combined.swift
//      swift /tmp/combined.swift
//
//      # For automated tests (\\ block comments, \S, FLOAD behavior):
//      FTEST=1 swift /tmp/combined.swift
//
//  This completely bypasses Xcode so you can test the actual Forth engine
//  while we sort out the Xcode 26.5 build service crashes.
//
//  The engine uses the classic lbForth trick:
//  - Primitives get very small integer IDs (0, 1, 2, ...).
//  - Colon definitions mostly contain these small IDs in their threaded code.
//  - The inner interpreter dispatches small IDs via a table; larger values
//    are treated as addresses of other threaded code (colon definitions).
//

import Foundation

// MARK: - Tester

let forth = LBForth()

// Capture all output from the Forth engine
forth.onOutput = { text in
    print(text, terminator: "")
}

print("=== Test LBForth (Leif Bruder 2014 public domain model) ===")
print("Architecture: low-ID primitives + threaded colon definitions")
print("Type normal Forth.  Use 'bye' or Ctrl-D to exit.\n")
print("Useful for testing:  1 2 + .   : foo 42 ;   foo .   etc.\n")

// MARK: - Automated tests for \\ block comments and \S (run with: FTEST=1 swift ... TestLBForth.swift)
if ProcessInfo.processInfo.environment["FTEST"] == "1" {
    print("=== Running automated FTEST for \\\\ block comments and \\\\S stop ===")
    var collected = ""
    _ = forth.onOutput
    forth.onOutput = { text in
        collected += text
        print(text, terminator: "") // echo for log visibility
    }
    func resetTest() {
        // Use resetRuntimeState (not the full resetToSafeState) so that words defined
        // by prior loadFile/feedLine in this test step survive for the "exec . " verification
        // steps that follow (which intentionally reset only to get clean collected output
        // and stacks, without nuking the dictionary under test).
        forth.resetRuntimeState()
        collected = ""
    }

    let fm = FileManager.default
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
    let suffix = UUID().uuidString.prefix(8)
    let fblock = tmp.appendingPathComponent("testblock_\(suffix).fth")
    let fstop = tmp.appendingPathComponent("teststop_\(suffix).fth")
    let fecho = tmp.appendingPathComponent("testecho_\(suffix).fth")
    let fdebug = tmp.appendingPathComponent("testdebug_\(suffix).fth")
    let fdotq = tmp.appendingPathComponent("testdotq_\(suffix).fth")

    // Note: in Swift literals, \\\\ produces two backslash chars in the string (for the \\ word in Forth source)
    let blockSrc = """
\\ normal line comment
: load1 11 ;
\\\\ block comment start (spans lines)
: noskip1 22 ;
spanning line without closer yet
{ : after1 33 ;  \\ closer, text after { runs
: load2 44 ;
"""
    let stopSrc = """
: pre 55 ;
: pre2 77 ;
\\\\ block comment protects the \\S below from stopping the load
\\S
: ignored 88 ;
{ : post2 99 ;
\\S
: post 66 ;
"""
    let echoSrc = """
FILE-ECHO ON
: echopre 42 ;
\\S
: echopost 99 ;
"""
    let debugSrc = """
DEBUG-ON
: dbg1 123 ;
DEBUG-OFF
: dbg2 456 ;
: dbg3 789 ;
"""
    let dotqSrc = """
: hello ." Hello from dot quote" ;
hello
.(  -- above should have printed without leading space )
: bad ." test " FOO  ;   \\ will error on FOO (after .") while compiling
: afterbad 999 ;
"""

    do {
        try blockSrc.write(to: fblock, atomically: true, encoding: .utf8)
        try stopSrc.write(to: fstop, atomically: true, encoding: .utf8)
        try echoSrc.write(to: fecho, atomically: true, encoding: .utf8)
        try debugSrc.write(to: fdebug, atomically: true, encoding: .utf8)
        try dotqSrc.write(to: fdotq, atomically: true, encoding: .utf8)
    } catch {
        print("TEST write fail: \(error)")
        exit(1)
    }

    // === Test 1: block comments during FLOAD ===
    resetTest()
    forth.loadFile(fblock)
    let hasLoad1 = forth.debugFind("LOAD1")
    let hasNo1 = forth.debugFind("NOSKIP1")
    let hasAfter1 = forth.debugFind("AFTER1")
    let hasLoad2 = forth.debugFind("LOAD2")
    print("TEST1 block: load1=\(hasLoad1) noskip1=\(hasNo1) after1=\(hasAfter1) load2=\(hasLoad2)")

    resetTest()
    forth.feedLine("load1 .")
    let saw11 = collected.contains("11")
    print("TEST1 exec load1: saw11=\(saw11) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))")

    resetTest()
    forth.feedLine("after1 .")
    let saw33 = collected.contains("33")
    print("TEST1 exec after1: saw33=\(saw33) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))")

    // === Test 2: \S stops load (but \\ block protects inner \S) ===
    resetTest()
    forth.loadFile(fstop)
    let hasPre = forth.debugFind("PRE")
    let hasPost = forth.debugFind("POST")
    let hasPre2 = forth.debugFind("PRE2")
    let hasIgn = forth.debugFind("IGNORED")
    let hasPost2 = forth.debugFind("POST2")
    print("TEST2 stop: pre=\(hasPre) pre2=\(hasPre2) ign=\(hasIgn) post2=\(hasPost2) post=\(hasPost)")

    // === Test 2b: FILE-ECHO ON inside loaded file takes effect (lines shown), \S aborts rest,
    // and after \S load the REPL is not stuck (inSlash etc cleaned; can still define/use words).
    // Also exercises named FLOAD path (resolve sets pending, "host" shim performs the load).
    resetTest()
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    // Simulate "fload <name>" typed: engine sets pending, we do the host-side work (chdir + load)
    // just like the REPL shim in non-FTEST mode. This covers the "FLOAD filename" in cwd case.
    forth.feedLine("fload \(fecho.lastPathComponent)")
    if let u = forth.pendingLoadURL {
        let p = u.deletingLastPathComponent()
        _ = fm.changeCurrentDirectoryPath(p.path)
        forth.logicalCurrentDirectory = p.path
        forth.pendingLoadURL = nil
        forth.loadFile(u)
    }
    let hasEchoPre = forth.debugFind("ECHOPRE")
    let hasEchoPost = forth.debugFind("ECHOPOST")
    print("TEST2b echo+slash: echopre=\(hasEchoPre) echopost=\(hasEchoPost)")
    let sawEchoSrc = collected.contains("FILE-ECHO ON") || collected.contains("echopre")
    let sawPostSrc = collected.contains("echopost")
    print("TEST2b echo output: saw pre-src=\(sawEchoSrc) saw post-src=\(sawPostSrc)")
    // After the load that hit \S, REPL must still work (no leftover inSlashSlashComment etc).
    resetTest()
    forth.feedLine("123 constant postslashok")
    let hasPostSlash = forth.debugFind("POSTSLASHOK")
    print("TEST2b post-slash repl: postslashok=\(hasPostSlash)")
    collected = ""
    forth.feedLine("postslashok .")
    let saw123 = collected.contains("123")
    print("TEST2b post-slash exec: saw123=\(saw123) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))")

    // === Test 2c: DEBUG-ON / DEBUG-OFF inside a loaded file should take effect immediately
    // for subsequent lines in *that* file (live flag change during the load loop's feedLine calls).
    // We expect [DEBUG] dumps only for lines between DEBUG-ON and DEBUG-OFF.
    resetTest()
    forth.feedLine("FILE-ECHO OFF")  // ensure no pollution from prior tests' FILE-ECHO ON
    collected = ""
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    forth.feedLine("fload \(fdebug.lastPathComponent)")
    if let u = forth.pendingLoadURL {
        let p = u.deletingLastPathComponent()
        _ = fm.changeCurrentDirectoryPath(p.path)
        forth.logicalCurrentDirectory = p.path
        forth.pendingLoadURL = nil
        forth.loadFile(u)
    }
    let hasDbg1 = forth.debugFind("DBG1")
    let hasDbg2 = forth.debugFind("DBG2")
    let hasDbg3 = forth.debugFind("DBG3")
    print("TEST2c debug: dbg1=\(hasDbg1) dbg2=\(hasDbg2) dbg3=\(hasDbg3)")
    let sawDbgOn = collected.contains("[DEBUG]")
    // After DEBUG-OFF in the file, further lines in same load should not produce more [DEBUG]
    // (we check overall; a more precise count isn't needed for this).
    print("TEST2c debug output: saw any [DEBUG]=\(sawDbgOn)  (expect true, since dbg1/dbg2 lines should have dumped)")
    // Make sure debug flag is left off after the file's DEBUG-OFF (or at least REPL after load is clean).
    // resetTest will turn it off anyway, but check a post-load interactive has no debug unless we turn on.
    resetTest()
    collected = ""
    forth.feedLine("1 2 + .")
    let sawDbgInRepl = collected.contains("[DEBUG]")
    print("TEST2c post-debug repl: sawDbgInRepl=\(sawDbgInRepl) (expect false) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))")

    // === Test 2d: ." (dot quote) implementation, interpret and compile.
    // Also verifies that compile error (unknown word inside :) during load aborts the
    // rest of the file (no words after the error are defined), and leaves REPL in
    // interpreting state (not stuck compiling).
    resetTest()
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    forth.feedLine("fload \(fdotq.lastPathComponent)")
    if let u = forth.pendingLoadURL {
        let p = u.deletingLastPathComponent()
        _ = fm.changeCurrentDirectoryPath(p.path)
        forth.logicalCurrentDirectory = p.path
        forth.pendingLoadURL = nil
        forth.loadFile(u)
    }
    let hasHello = forth.debugFind("HELLO")
    let hasAfterBad = forth.debugFind("AFTERBAD")
    print("TEST2d dotq: hello=\(hasHello) afterbad=\(hasAfterBad) (expect hello true, afterbad false -- abort on error)")
    let sawHelloOut = collected.contains("Hello from dot quote")
    print("TEST2d dotq output: saw hello text=\(sawHelloOut)")
    // Check state after load (which hit compile err on bad : ) is interpreting, not left compiling.
    // Do a simple feed and see if OK and not compiling debug.
    resetTest()
    collected = ""
    forth.feedLine("42 .")
    let saw42 = collected.contains("42")
    let stillCompiling = collected.contains("state=compiling")
    print("TEST2d post-err repl: saw42=\(saw42) stillCompiling=\(stillCompiling) (expect no) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))")

    // === Test 2e: WORD basic functionality (delimited parse from input stream)
    resetTest()
    collected = ""
    // feed a line where "TEST" is the text after "32 WORD", WORD with BL will parse "TEST" as the delimited content
    forth.feedLine("32 WORD TEST COUNT TYPE")
    let sawTest = collected.contains("TEST")
    print("TEST2e WORD: sawTest=\(sawTest) (expect true) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))")

    // === Test 2f: how to test interpret vs compile STATE ===
    // Use DEBUG-ON so each feedLine emits "[DEBUG] state=... " after the line.
    // To observe "compiling", split the definition across multiple feedLine calls
    // (as noted in recoverFromError docs: use per-line DEBUG to watch state while def is open).
    // After ; state returns to interpreting. [ ] can switch mid-definition.
    resetTest()
    forth.feedLine("DEBUG-ON")
    collected = ""
    forth.feedLine(": state-test 123")  // open def, no ; yet -> should show compiling in debug after this feed
    let sawCompilingDuringDef = collected.contains("state=compiling")
    print("TEST2f after open : line (no ;): sawCompilingDuringDef=\(sawCompilingDuringDef) (expect true)")
    collected = ""
    forth.feedLine(";")  // close it
    let sawInterpretingAfterClose = collected.contains("state=interpreting")
    print("TEST2f after ; : sawInterpretingAfterClose=\(sawInterpretingAfterClose) (expect true)")
    collected = ""
    forth.feedLine("state-test .")
    let sawInterpretingExec = collected.contains("state=interpreting")
    print("TEST2f after exec: sawInterpretingExec=\(sawInterpretingExec) (expect true) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))")
    // Test [ inside a def to temporarily interpret
    resetTest()
    forth.feedLine("DEBUG-ON")
    collected = ""
    forth.feedLine(": state-test2 [ 42 ]")  // [ switches to interp for the 42, even inside :
    // Note: the debug for the *whole* line shows final STATE after ], which is compiling.
    // But the fact that 42 was pushed (see later debug stack) shows [ temporarily set interp for "42".
    // Main observable: open def line without ; shows compiling in its post-line DEBUG.
    collected = ""
    forth.feedLine(";")
    let sawFinalInterp = collected.contains("state=interpreting")
    let sawStuckCompile = collected.contains("state=compiling")
    print("TEST2f after ; for [ test: sawFinalInterp=\(sawFinalInterp) sawStuckCompile=\(sawStuckCompile) (expect interp true, stuck false)")
    // Also, the interpreted 42 should be on stack after the def line (before ; closed it)
    // In the previous debug it showed stack with 42.

    // === Test 3: console REPL \\ spanning lines until { ===
    resetTest()
    forth.feedLine("\\\\ console block start")
    forth.feedLine(": noskipc 123 ;")
    forth.feedLine("42 constant noskipc2")
    forth.feedLine(" { : afterc 456 ;  99 constant afterc2 ")
    let hasNoC = forth.debugFind("NOSKIPC")
    let hasNoC2 = forth.debugFind("NOSKIPC2")
    let hasAfterC = forth.debugFind("AFTERC")
    let hasAfterC2 = forth.debugFind("AFTERC2")
    print("TEST3 console-block: noskipc=\(hasNoC) noskipc2=\(hasNoC2) afterc=\(hasAfterC) afterc2=\(hasAfterC2)")

    resetTest()
    forth.feedLine("afterc .")
    let saw456 = collected.contains("456")
    print("TEST3 exec afterc: saw456=\(saw456)")

    // === Test 4: console \S does nothing (code after on line still runs) ===
    resetTest()
    forth.feedLine("\\S : stillc 789 ;  7 constant stillc2")
    let hasStillC = forth.debugFind("STILLC")
    let hasStillC2 = forth.debugFind("STILLC2")
    print("TEST4 console-s: stillc=\(hasStillC) stillc2=\(hasStillC2)")

    // === Test 5: nested colon calls (CUBE calls SQUARE) must not cause return stack overflow,
    // and execution after FLOAD or errors must leave engine clean for subsequent defs/execs.
    resetTest()
    forth.feedLine(": square dup * ;")
    forth.feedLine(": cube dup square * ;")
    forth.feedLine("3 square .")
    let saw9 = collected.contains("9")
    collected = ""
    forth.feedLine("4 cube .")
    let saw64 = collected.contains("64")
    let stillNoOverflow = !collected.contains("overflow")
    print("TEST5 nested: square9=\(saw9) cube64=\(saw64) no-overflow=\(stillNoOverflow)")

    // Also exec after previous (simulates "after FLOAD")
    collected = ""
    forth.feedLine(": squar dup * ;")
    forth.feedLine("3 squar .")
    let saw9b = collected.contains("9")
    print("TEST5 post: squar9=\(saw9b)")

    // Test that STATE (and similar HERE/BASE/LATEST/SP) now return the *address* (not the dereferenced value)
    // as documented in the help and standard Forth (so "STATE @" works to fetch the 0/1, "STATE ." would show 16)
    resetTest()
    collected = ""
    forth.feedLine("STATE")
    // after feed, if debug off, no output, but to inspect: use the fact we can check stack via debug or define test
    forth.feedLine("DEBUG-ON")
    collected = ""
    forth.feedLine("STATE 16 = .")
    let stateReturnsAddr = collected.contains(" -1") || collected.contains("-1")
    print("TEST state-word: STATE 16 = => \(stateReturnsAddr) (expect true: now returns addr 16, not the state value)")
    collected = ""
    forth.feedLine("STATE @ .")
    let stateFetch = collected.contains("0 ")
    print("TEST STATE @: STATE @ . => \(stateFetch) (expect prints 0 after reset) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))")

    // cleanup
    try? fm.removeItem(at: fblock)
    try? fm.removeItem(at: fstop)

    print("=== FTEST complete ===")
    exit(0)
}

// Simple REPL
while let line = readLine() {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if trimmed.lowercased() == "bye" {
        print("Goodbye.")
        break
    }
    
    // Send the line to the engine (empty lines are fed too so the engine prints "OK"
    // for "nothing to do", matching the console behavior).
    forth.feedLine(line)

    if forth.fileLoadRequested {
        print(" [FLOAD dialog requested — not available in CLI tester. Use: FLOAD path/to/file.fth ]")
        forth.fileLoadRequested = false
    }
    if forth.fileEditRequested {
        print(" [EDIT dialog requested — not available in CLI tester. Use: EDIT path/to/file.fth  (will chdir + simulate open)]")
        forth.fileEditRequested = false
    }
    if let u = forth.pendingEditURL {
        // Mirror the app's EDIT auto-.fth fallback for the simulation/print (parent dir is the same).
        var target = u
        let leaf = u.lastPathComponent
        if !leaf.contains(".") {
            let alt = u.deletingLastPathComponent().appendingPathComponent(leaf + ".fth")
            if !FileManager.default.fileExists(atPath: u.path) && FileManager.default.fileExists(atPath: alt.path) {
                target = alt
            }
        }
        print(" [EDIT would open in editor + chdir to: \(target.deletingLastPathComponent().path) (file: \(target.lastPathComponent)) ]")
        // simulate the host side effect for cwd (so CHDIR etc follow in tester)
        let p = target.deletingLastPathComponent()
        _ = FileManager.default.changeCurrentDirectoryPath(p.path)
        forth.logicalCurrentDirectory = p.path
        forth.pendingEditURL = nil
    }
    if let u = forth.pendingLoadURL {
        print(" [FLOAD: \(u.lastPathComponent) (from \(u.deletingLastPathComponent().path)) ]")
        // In CLI tester (runs outside sandbox), actually perform the load so that
        // "fload path/to/foo.fth" works in the REPL. Also chdir + update logical to simulate host.
        let p = u.deletingLastPathComponent()
        _ = FileManager.default.changeCurrentDirectoryPath(p.path)
        forth.logicalCurrentDirectory = p.path
        forth.pendingLoadURL = nil
        forth.loadFile(u)
    }

    // Support blocking KEY in the standalone tester: if the previous feed
    // left a KEY waiting, read additional lines and supply the first char
    // of each as key input until the KEY is satisfied.
    while forth.waitingForKey {
        guard let keyLine = readLine() else { break }
        if let first = keyLine.first {
            forth.provideKey(Int(first.asciiValue ?? 0))
        } else {
            forth.provideKey(32) // space for empty line
        }
    }
    
    // After every line, show the current data stack (very helpful while developing)
    let stack = forth.stackAsString
    if !stack.isEmpty {
        print("  [ \(stack)]")
    } else {
        print("  [ ]")
    }
}

print("\n=== Session ended ===")