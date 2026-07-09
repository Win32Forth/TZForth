//
//  TestTZForth.swift
//
//  Standalone tester for the TZForth engine (based on Leif Bruder public-domain lbForth / LBForth model).
//
//  How to run (note: multi-file swift script needs concatenation on current Swift):
//
//      cd /path/to/TZForth
//      cat TZForth/TZForth.swift TZForth/TZForthTests.swift TZForth/TestTZForth.swift > /tmp/combined.swift
//      swift /tmp/combined.swift
//
//      # For automated tests (\\ block comments, \S, FLOAD behavior):
//      FTEST=1 swift /tmp/combined.swift
//
//  Note: The ANS validation test logic (runANSValidation + test sources) was split to
//  TZForthTests.swift (as extension) to keep the main engine file smaller; it is included
//  above so that the standalone REPL supports the ANS-VALIDATE word too.
//  The FTEST harness here remains self-contained (dupe of early test logic for standalone).
//  See TZForth.swift (originally LBForth.swift) and TZForthTests.swift for credits.
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

//
// Public Domain Statement
//
// This software is released into the public domain.
// 
// TZForth is free and unencumbered software dedicated to the public domain.
// 
// The standalone tester (TestTZForth.swift, originally TestLBForth.swift) and
// the embedded validation logic are part of the TZForth project.
// Internally we respect and preserve the Leif Bruder 2014 public-domain lbForth
// model origins for the engine and test techniques.
// See engine header for the gist link.
//
// See TZForth.swift for full credit and the original model link.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
//

import Foundation

// MARK: - Tester

let forth = TZForth()

// Capture all output from the Forth engine
forth.onOutput = { text in
    print(text, terminator: "")
}

print("=== Test TZForth (Leif Bruder 2014 public domain lbForth model) ===")
print("Architecture: low-ID primitives + threaded colon definitions")
print("Type normal Forth.  Use 'bye' or Ctrl-D to exit.\n")
print("Useful for testing:  1 2 + .   : foo 42 ;   foo .   etc.\n")

// MARK: - Automated tests for \\ block comments and \S (run with: FTEST=1 swift ... TestTZForth.swift)
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
    let fline = tmp.appendingPathComponent("testline_\(suffix).txt")
    let finc = tmp.appendingPathComponent("testinc_\(suffix).fth")
    let fwr = tmp.appendingPathComponent("testwr_\(suffix).txt")

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
        try blockSrc.write(to: fblock, atomically: true, encoding: String.Encoding.utf8)
        try stopSrc.write(to: fstop, atomically: true, encoding: String.Encoding.utf8)
        try echoSrc.write(to: fecho, atomically: true, encoding: String.Encoding.utf8)
        try debugSrc.write(to: fdebug, atomically: true, encoding: String.Encoding.utf8)
        try dotqSrc.write(to: fdotq, atomically: true, encoding: String.Encoding.utf8)
        try "alpha\nbeta\n".write(to: fline, atomically: true, encoding: String.Encoding.utf8)
        try ": fincw 42 ;\n".write(to: finc, atomically: true, encoding: String.Encoding.utf8)
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

    // === Test 6: Expanded ANS Forth 2012 Core word set tests ===
    // Additional coverage for many current dictionary words using documented stack effects
    // and behaviors from the 2012 ANS Forth Standard (primarily 6.1 Core Word Set and
    // some Core Extensions). Each test uses feedLine + output/stack inspection.
    // We deliberately avoid destructive global side-effects where possible or recover via resetTest.
    print("=== Starting expanded ANS 2012 Core word tests ===")
    forth.feedLine("VARIABLE t6mem 256 ALLOT")   // safe cell + extra buffer space for memory tests (MOVE/FILL use offsets to avoid low system-var addrs)
    var ansPassed = 0
    var ansTotal = 0
    func ansTest(_ desc: String, _ line: String, _ expectedSubstring: String) {
        resetTest()
        forth.feedLine(line)
        ansTotal += 1
        let out = collected.trimmingCharacters(in: .whitespacesAndNewlines)
        if out.contains(expectedSubstring) {
            ansPassed += 1
            print("TEST6 \(desc): pass")
        } else {
            print("TEST6 \(desc): FAIL got '\(out)' (expected contain '\(expectedSubstring)')")
        }
    }

    // Arithmetic (6.1.0120 + etc.)
    ansTest("+", "3 4 + .", "7")
    ansTest("-", "10 3 - .", "7")
    ansTest("*", "6 7 * .", "42")
    ansTest("/MOD", "10 3 /MOD . .", "3 1")  // quot rem (top=quot per impl+standard)
    ansTest("/", "10 3 / .", "3")
    ansTest("*/MOD", "10 3 4 */MOD . .", "7 2")  // 30 /4 =7 rem 2 , . . gives quot rem
    ansTest("*/", "7 2 3 */ .", "4")
    ansTest("*/", "-7 2 3 */ .", "-4")
    ansTest("2*", "21 2* .", "42")
    ansTest("2*", "4000 2* .", "8000")
    ansTest("2/", "42 2/ .", "21")
    ansTest("2/", "4000 2/ .", "2000")
    ansTest("M*", "1000 1000 M* . .", "0 1000000")
    ansTest("FM/MOD", "10 0 3 FM/MOD . .", "3 1")
    ansTest("SM/REM", "10 0 3 SM/REM . .", "3 1")
    ansTest("U<", "1 2 U< .", "-1")
    ansTest("U>", "2 1 U> .  1 2 U> .", "-1 0")
    ansTest("UM*", "100 100 UM* . .", "0 10000")
    ansTest("UM/MOD", "0 100 10 UM/MOD . .", "10 0")
    ansTest("MOD", "10 3 MOD .", "1")
    ansTest("1+", "41 1+ .", "42")
    ansTest("1-", "43 1- .", "42")
    ansTest("ABS", "-5 ABS .", "5")
    ansTest("NEGATE", "5 NEGATE .", "-5")
    ansTest("MIN", "3 7 MIN .", "3")
    ansTest("MAX", "3 7 MAX .", "7")

    // Logic & shifts (6.1.0720 etc.)
    ansTest("AND", "5 3 AND .", "1")
    ansTest("OR", "5 3 OR .", "7")
    ansTest("XOR", "5 3 XOR .", "6")
    ansTest("INVERT", "0 INVERT .", "-1")  // all bits (in 2's complement sense for cell)
    ansTest("LSHIFT", "1 3 LSHIFT .", "8")
    ansTest("RSHIFT", "8 2 RSHIFT .", "2")

    // Comparisons (6.1.0270 etc.)
    ansTest("=", "5 5 = .", "-1")
    ansTest("=", "5 6 = .", "0")
    ansTest("<", "3 5 < .", "-1")
    ansTest(">", "5 3 > .", "-1")
    ansTest("<>", "5 5 <> .  5 6 <> .", "0 -1")
    ansTest("0=", "0 0= .", "-1")
    ansTest("0=", "1 0= .", "0")
    ansTest("0<", "-1 0< .", "-1")
    ansTest("0>", "1 0> .", "-1")
    ansTest("WITHIN", "5 1 10 WITHIN .", "-1")
    ansTest("WITHIN", "0 1 10 WITHIN .", "0")

    // Stack manip (6.1.0630 etc. + extensions)
    ansTest("DUP", "42 DUP . .", "42 42")
    ansTest("DROP", "1 2 DROP .", "1")
    ansTest("SWAP", "1 2 SWAP . .", "1 2")
    ansTest("OVER", "1 2 OVER . . .", "1 2 1")
    ansTest("?DUP", "0 ?DUP .", "0")
    ansTest("?DUP", "5 ?DUP . .", "5 5")
    ansTest("ROT", "1 2 3 ROT . . .", "1 3 2")
    ansTest("NIP", "1 2 NIP .", "2")
    ansTest("TUCK", "1 2 TUCK . . .", "2 1 2")
    ansTest("PICK", "10 20 30 1 PICK .", "20")  // 0=top, 1=next
    ansTest("ROLL", "10 20 30 1 ROLL . . .", "20 30 10")

    // Return stack (6.1.0580 etc.)
    ansTest(">R R>", "42 >R R> .", "42")
    ansTest("R@", "99 >R R@ R> DROP .", "99")
    ansTest("2>R 2R>", "1 2 2>R 2R> . .", "2 1")
    ansTest("2DROP", "1 2 3 4 2DROP . .", "2 1")
    ansTest("2DUP", "1 2 2DUP . . . .", "2 1 2 1")
    ansTest("2OVER", "1 2 3 4 2OVER . . . .", "2 1 4 3")
    ansTest("2SWAP", "1 2 3 4 2SWAP . . . .", "2 1 4 3")

    // Memory (6.1.0650 etc.)
    // Use t6mem (defined early) to avoid corrupting the live DP_ADDR / HERE value
    ansTest("! @", "123 t6mem ! t6mem @ .", "123")
    ansTest("C! C@", "65 t6mem C! t6mem C@ .", "65")
    ansTest("+!", "0 t6mem ! 5 t6mem +! t6mem @ .", "5")
    ansTest("FILL", "t6mem 3 65 FILL t6mem C@ .", "65")
    ansTest("MOVE", "t6mem 8 + 3 66 FILL t6mem 16 + 3 0 FILL t6mem 8 + t6mem 16 + 3 MOVE t6mem 16 + C@ .", "66")
    ansTest(",", "42 , 43 .", "43")
    // ALLOT tested indirectly via , behavior

    // Constants / literals / base
    ansTest("TRUE", "TRUE .", "-1")
    ansTest("FALSE", "FALSE .", "0")
    ansTest("BL", "BL .", "32")
    ansTest("HEX DECIMAL", "HEX 10 . DECIMAL 16 .", "10 16")
    ansTest("BASE", "10 BASE ! 42 .", "42")

    // I/O basics (already some coverage, add U. SPACES)
    ansTest("U.", "123 U.", "123")
    ansTest("SPACES", "3 SPACES 42 .", "42")  // hard to count spaces but no crash + output

    // Pictured numeric output (core)
    ansTest("<# #S #>", "123 S>D <# #S #> TYPE", "123")
    ansTest("SIGN", "0 0 0 <# SIGN #S #> TYPE", "0")

    // S" / C"
    ansTest("S\"", "S\" HELLO\" TYPE", "HELLO")
    ansTest("C\"", "C\" HELLO\" COUNT TYPE", "HELLO")
    ansTest("C\" compile", ": tcq C\" world\" COUNT TYPE ; tcq", "world")
    ansTest("C\" EVALUATE", ": tcqe C\" 42 .\" ; tcqe COUNT EVALUATE", "42")

    // Control structures (via temp definitions; some coverage in 2d/2f)
    ansTest("IF ELSE THEN", ": t6if 5 0= IF 99 ELSE 88 THEN ; t6if .", "88")
    ansTest("BEGIN UNTIL", ": t6until 0 BEGIN 1+ DUP 3 > UNTIL ; t6until .", "4")
    ansTest("DO LOOP I", ": t6do 0 3 0 DO I + LOOP ; t6do .", "3")  // 0+1+2
    ansTest("?DO +LOOP UNLOOP LEAVE", ": t6dop 0 5 0 ?DO 1+ LOOP ; t6dop .", "5")
    ansTest("J", ": t6j 0 2 0 DO 0 2 0 DO J + LOOP LOOP ; t6j .", "2")  // 0+0 +1+1 =2
    ansTest("RECURSE", ": t6rec 1- DUP 0= IF DROP 99 ELSE RECURSE THEN ; 5 t6rec .", "99")
    ansTest("EXECUTE", "3 4 ' + EXECUTE .", "7")

    // Dictionary / introspection (current words)
    ansTest(">HEADER >NFA ID.", "VARIABLE t6v ' t6v >NFA COUNT TYPE", "t6v")  // name printed
    ansTest("ID.", "' t6v ID.", "t6v")
    ansTest("HERE (value) DP", "HERE DP @ = .", "-1")  // they should match per current impl
    ansTest("LATEST", "LATEST @ 0= 0= .", "-1")  // at least non-zero after bootstrap
    ansTest("DEPTH", "1 2 3 DEPTH .", "3")
    ansTest("[']", ": t6p ['] DUP ; ' DUP t6p = .", "-1")

    // TYPE COUNT WORD (more coverage)
    ansTest("COUNT TYPE via WORD", "32 WORD HELLO COUNT TYPE", "HELLO")

    // 2@ 2! etc. (use safe non-HERE to avoid prior side effects on DP)
    ansTest("ARSHIFT", "-8 1 ARSHIFT .", "-4")

    // New batch: >IN >NUMBER ABORT ABORT" ACCEPT ENVIRONMENT? EVALUATE FIND
    ansTest(">IN", ": t6in 0 >IN ! >IN @ ; t6in .", "0")
    ansTest(">NUMBER", "0 0 S\" 123\" >NUMBER 2DROP DROP .", "123")
    ansTest("EVALUATE", "S\" 3 4 +\" EVALUATE .", "7")
    ansTest("FIND", "32 WORD DUP FIND SWAP DROP 0= 0= .", "-1")
    ansTest("FIND not", "32 WORD NOPE FIND 0= .", "-1")
    ansTest("ACCEPT basic", "HERE 0 ACCEPT .", "0")
    ansTest("ABORT\" no", "0 ABORT\" oops\" 42 .", "42")

    // Check a few more that should be present and not crash
    ansTest("CLS (no crash)", "CLS 42 .", "42")
    ansTest("SPACES (no crash)", "2 SPACES 99 .", "99")

    // New Core (QUIT SOURCE PARSE PAD POSTPONE [COMPILE] + SP!/RSP! + improved ENV)
    ansTest("SOURCE", "SOURCE DROP 0= .", "0")
    ansTest("PAD", "PAD 0= 0= .", "-1")
    ansTest("PARSE", "32 PARSE  2DROP 42 .", "42")
    ansTest("QUIT (no crash)", "42 . QUIT", "42")
    ansTest("SP! RSP!", "1 2 3  1 SP! DEPTH .", "0")
    ansTest("ENVIRONMENT?", "S\" CORE\" ENVIRONMENT? .", "-1")
    ansTest("[COMPILE]", ": t6c [COMPILE] + ; 3 4 t6c .", "7")
    // POSTPONE test: use an immediate word; with POSTPONE the imm action happens at runtime of tpo, not during its definition
    ansTest("POSTPONE", "VARIABLE tpv 0 tpv ! : timp 99 tpv ! ; IMMEDIATE : tpo POSTPONE timp 42 ; tpv @ . tpo tpv @ .", "0 99")

    // Core Ext batch: VALUE IS CASE OF ENDOF ENDCASE 0<> <> U> COMPILE, ERASE DEFER DEFER! DEFER@
    ansTest("0<>", "0 0<> .  5 0<> .", "0 -1")
    ansTest("ERASE", "HERE 5 ERASE HERE C@ HERE 4 + C@ . .", "0 0")
    ansTest("COMPILE,", ": [c+] ['] + COMPILE, ; IMMEDIATE : tcm [c+] ; 10 20 tcm .", "30")
    ansTest("VALUE IS", "123 VALUE v1 v1 .  456 IS v1 v1 .", "123 456")
    ansTest("TO", "100 VALUE tv1  200 TO tv1  tv1 .", "200")
    ansTest(".R", "-5 8 .R", "-5")
    ansTest("PARSE-NAME", "S\" : tpn PARSE-NAME TYPE ; tpn   hello\" EVALUATE", "hello")
    ansTest("HOLDS", "123 S>D <# #S S\" Num: \" HOLDS #> TYPE", "Num: 123")
    ansTest("BUFFER:", "64 BUFFER: tb1 tb1 99 OVER C! C@ .", "99")
    ansTest("UNUSED", "UNUSED 1000 > .", "-1")
    ansTest(".FREE", "UNUSED 1000 > .FREE 42 .", "42")
    ansTest("DEFER IS DEFER@ DEFER!", "DEFER d1 : a1 777 ; ' a1 IS d1 d1 . : a2 888 ; ' a2 ' d1 DEFER! d1 .", "777 888")
    ansTest("CASE OF ENDOF ENDCASE", " ' CASE  ' OF  ' ENDOF  ' ENDCASE  DROP DROP DROP DROP 42 .", "42")

    // Vocabularies: words defined in a custom vocab must not leak into FORTH.
    ansTest("VOCAB isolate FORTH", "VOCABULARY FOO FOO DEFINITIONS 123 CONSTANT baz FORTH DEFINITIONS baz .", "? baz")
    ansTest("VOCAB define FORTH", "VOCABULARY FOO FOO DEFINITIONS 123 CONSTANT baz FORTH DEFINITIONS 456 .", "456")
    ansTest("VOCAB lookup FOO", "VOCABULARY FOO FOO DEFINITIONS 123 CONSTANT baz FORTH DEFINITIONS FOO baz .", "123")
    ansTest("ORDER compilation", "VOCABULARY FOO FOO DEFINITIONS ORDER", "Compilation wordlist: FOO")
    ansTest("WORDS filter", "WORDS CONSTANT", "CONSTANT")
    ansTest("ALSO ONLY ORDER", "ONLY ALSO FORTH ORDER", "Search order: FORTH FORTH")
    ansTest("ALSO search", "ONLY ALSO FORTH 1 2 + .", "3")

    // Core Ext Tier 2: :NONAME ACTION-OF MARKER SAVE-INPUT RESTORE-INPUT SOURCE-ID S\" REFILL
    ansTest(":NONAME", "VARIABLE t7n1 :NONAME 1234 ; t7n1 ! t7n1 @ EXECUTE .", "1234")
    ansTest("ACTION-OF", "DEFER t7d : t7a1 42 ; ' t7a1 IS t7d ' t7d ACTION-OF EXECUTE .", "42")
    ansTest("MARKER", "MARKER t7m1 : t7w1 11 ; : t7w2 22 ; t7m1 t7w1 .", "? t7w1")
    ansTest("SOURCE-ID terminal", "SOURCE-ID .", "-1")
    ansTest("REFILL", "REFILL 0= .", "-1")
    ansTest("SAVE-INPUT RESTORE-INPUT", "SAVE-INPUT S\" 222 .\" EVALUATE RESTORE-INPUT 0= . 333 .", "0 333")
    ansTest("S\\\"", ": t7sq S\\\" hello\" TYPE ; t7sq", "hello")
    ansTest("S\\\" escapes", ": t7sq2 S\\\" a\\\\b\" TYPE ; t7sq2", "a\\b")

    // File-Access (ANS word set 11)
    let flinePath = fline.path
    let fincPath = finc.path
    let fwrPath = fwr.path
    ansTest("R/O OPEN-FILE", "S\" \(flinePath)\" R/O OPEN-FILE 0= .", "-1")
    ansTest("FILE-SIZE", "S\" \(flinePath)\" R/O OPEN-FILE DROP FILE-SIZE DROP DROP .", "11")
    ansTest("READ-LINE", "S\" \(flinePath)\" R/O OPEN-FILE DROP PAD 1+ SWAP 80 SWAP READ-LINE DROP DROP PAD 1+ SWAP TYPE CLOSE-FILE DROP", "alpha")
    ansTest("INCLUDED", "S\" \(fincPath)\" INCLUDED fincw .", "42")
    ansTest("ENVIRONMENT? FILE", "S\" FILE\" ENVIRONMENT? .", "-1")
    ansTest("CREATE-FILE", "S\" \(fwrPath)\" W/O CREATE-FILE 0= SWAP CLOSE-FILE DROP .", "-1")
    forth.feedLine("VARIABLE t8wf")
    forth.feedLine(": t8wv S\" \(fwrPath)\" W/O CREATE-FILE DROP t8wf ! S\" hi\" t8wf @ WRITE-LINE DROP t8wf @ CLOSE-FILE DROP 1 ;")
    ansTest("WRITE-LINE", "t8wv .", "1")
    ansTest("WRITE-LINE size", "S\" \(fwrPath)\" R/O OPEN-FILE DROP FILE-SIZE DROP DROP .", "3")
    ansTest("READ written file", "S\" \(fwrPath)\" R/O OPEN-FILE DROP PAD 1+ SWAP 80 SWAP READ-LINE DROP DROP PAD 1+ SWAP TYPE CLOSE-FILE DROP", "hi")

    print("TEST6 ANS core summary: \(ansPassed)/\(ansTotal) passed")
    if ansPassed != ansTotal {
        print("WARNING: some ANS 2012 core tests failed — review against standard stack effects.")
    }

    // cleanup
    try? fm.removeItem(at: fblock)
    try? fm.removeItem(at: fstop)
    try? fm.removeItem(at: fline)
    try? fm.removeItem(at: finc)
    try? fm.removeItem(at: fwr)

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
