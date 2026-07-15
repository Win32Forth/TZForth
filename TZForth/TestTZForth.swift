//
//  TestTZForth.swift
//
//  Standalone tester for the TZForth engine (based on Leif Bruder public-domain lbForth / LBForth model).
//
//  How to run (note: multi-file swift script needs concatenation on current Swift):
//
//      cd /path/to/TZForth
//      cat TZForth/TZForth.swift TZForth/TZForthSettings.swift TZForth/TZForthBlock.swift TZForth/TZForthXChar.swift TZForth/TZForthAssembler.swift TZForth/TZForthFloat.swift TZForth/TZForthTests.swift TZForth/TestTZForth.swift > /tmp/combined.swift
//      swift /tmp/combined.swift
//
//      # For automated tests (\\ block comments, \S, FLOAD behavior + 398 ANS spot-checks):
//      FTEST=1 swift /tmp/combined.swift
//
//      # For John Hayes / forth2012-test-suite (incl. Block; 0 T{ failures target):
//      HAYES=1 swift /tmp/combined.swift
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

let forth = TZForth(settings: TZForthSettings.load())

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
    forth.onPerformNamedLoad = { url in
        forth.loadFile(url)
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
    let freq1 = tmp.appendingPathComponent("required-helper1_\(suffix).fth")
    let freq2 = tmp.appendingPathComponent("required-helper2_\(suffix).fth")
    let freq3 = tmp.appendingPathComponent("required-helper3_\(suffix).fth")
    let freq4 = tmp.appendingPathComponent("required-helper4_\(suffix).fth")
    let fbad = tmp.appendingPathComponent("load-bad_\(suffix).fth")

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
        try "1+\n".write(to: freq1, atomically: true, encoding: String.Encoding.utf8)
        try "1+\n".write(to: freq2, atomically: true, encoding: String.Encoding.utf8)
        try "1+\n".write(to: freq3, atomically: true, encoding: String.Encoding.utf8)
        try "\n".write(to: freq4, atomically: true, encoding: String.Encoding.utf8)
        try "nosuch-tzforth-loaderr-xyz\n999 .\n".write(to: fbad, atomically: true, encoding: String.Encoding.utf8)
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

    // === Test 2b-repl: \\S from console stops remainder of a multi-line submit (paste) ===
    resetTest()
    forth.clearReplBatchStop()
    let replBatch = [": prebatch 11 ;", "\\S", ": postbatch 22 ;"]
    for (i, ln) in replBatch.enumerated() {
        forth.feedLine(ln)
        if forth.replBatchStopRequested { break }
        if i == replBatch.count - 1 { /* ran all */ }
    }
    let hasPreBatch = forth.debugFind("PREBATCH")
    let hasPostBatch = forth.debugFind("POSTBATCH")
    print("TEST2b-repl: prebatch=\(hasPreBatch) postbatch=\(hasPostBatch) (expect true false)")

    // === Test 2b-fload-tail: \S stops file but same-line console tokens still run (FLOAD f HERE .) ===
    resetTest()
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    let fTailSlash = tmp.appendingPathComponent("testslash-tail_\(suffix).fth")
    try! """
: beforestop 11 ;
\\s
: never 22 ;
""".write(to: fTailSlash, atomically: true, encoding: String.Encoding.utf8)
    collected = ""
    forth.feedLine("fload \(fTailSlash.lastPathComponent) 123 .")
    let hasBeforeStop = forth.debugFind("BEFORESTOP")
    let hasNeverStop = forth.debugFind("NEVER")
    let saw123Tail = collected.contains("123")
    print("TEST2b-fload-tail: before=\(hasBeforeStop) never=\(hasNeverStop) saw123=\(saw123Tail) (expect true false true)")

    // === Test 2b-nested-back: outer file continues after inner \\S; console tail runs ===
    resetTest()
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    let fInnerBack = tmp.appendingPathComponent("tz-inner-back_\(suffix).fth")
    let fOuterBack = tmp.appendingPathComponent("tz-outer-back_\(suffix).fth")
    try! """
: innermark 77 ;
\\s
: innernever 88 ;
""".write(to: fInnerBack, atomically: true, encoding: String.Encoding.utf8)
    try! """
FILE-ECHO ON
.( inside= ) 111 .
fload \(fInnerBack.lastPathComponent)
.( after-inner= ) 222 .
\\s
.( never= ) 333 .
""".write(to: fOuterBack, atomically: true, encoding: String.Encoding.utf8)
    collected = ""
    forth.feedLine("fload \(fOuterBack.lastPathComponent) 999 .")
    let hasInnerNever = forth.debugFind("INNERNEVER")
    let hasOuterNever = forth.debugFind("OUTERNEVER")
    let sawInside = collected.contains("inside=")
    let sawAfterInner = collected.contains("after-inner=")
    let sawNever = collected.contains("never=")
    let saw999 = collected.contains("999")
    print("TEST2b-nested-back: inside=\(sawInside) after=\(sawAfterInner) never=\(sawNever) 999=\(saw999) innernever=\(hasInnerNever) (expect true true false true false)")

    // === Test 2b-slash-after-throw: \\S still stops outer file after inner load errors ===
    resetTest()
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    let fInnerErr = tmp.appendingPathComponent("tz-inner-err_\(suffix).fth")
    let fOuterErr = tmp.appendingPathComponent("tz-outer-err_\(suffix).fth")
    try! """
: badword 1 ;
badword-not-a-real-word-xyz
""".write(to: fInnerErr, atomically: true, encoding: String.Encoding.utf8)
    try! """
.( pre= ) 11 .
fload \(fInnerErr.lastPathComponent)
.( mid= ) 22 .
\\s
.( post= ) 33 .
: SHOULDNOT 99 ;
""".write(to: fOuterErr, atomically: true, encoding: String.Encoding.utf8)
    collected = ""
    forth.feedLine("fload \(fOuterErr.lastPathComponent)")
    let hasShouldnot = forth.debugFind("SHOULDNOT")
    let sawPre = collected.contains("pre=")
    let sawMid = collected.contains("mid=")
    let sawPost = collected.contains("post=")
    print("TEST2b-slash-after-throw: pre=\(sawPre) mid=\(sawMid) post=\(sawPost) shouldnot=\(hasShouldnot) (expect true true false false)")

    // === Test 2b-slash-space: `\ s` on its own line stops FLOAD like \S ===
    resetTest()
    let fSlashSpace = tmp.appendingPathComponent("testslash-space_\(suffix).fth")
    try! """
: press 55 ;
\\ s
: ignoredss 88 ;
""".write(to: fSlashSpace, atomically: true, encoding: String.Encoding.utf8)
    forth.loadFile(fSlashSpace)
    let hasPress = forth.debugFind("PRESS")
    let hasIgnSS = forth.debugFind("IGNOREDSS")
    print("TEST2b-slash-space: press=\(hasPress) ignored=\(hasIgnSS) (expect true false)")

    // === Test 2b-err: FLOAD stops at first line error (unless CATCH) ===
    resetTest()
    let ferr = tmp.appendingPathComponent("tz-errstop.fth")
    try! """
true verbose !
: shouldnot 99 ;
""".write(to: ferr, atomically: true, encoding: String.Encoding.utf8)
    collected = ""
    forth.loadFile(ferr)
    let hasErrStopBad = forth.debugFind("SHOULDNOT")
    let hasLine1 = collected.contains("line 1")
    print("TEST2b-err: shouldnot=\(hasErrStopBad) line1=\(hasLine1) (expect false true) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))")

    resetTest()
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    forth.feedLine(": safe-inc S\" \(ferr.lastPathComponent)\" ['] INCLUDED CATCH ;")
    collected = ""
    forth.feedLine("safe-inc . .ERROR")
    let caughtFload = collected.contains("-13") || collected.contains("-70") || collected.contains("undefined word") || collected.contains("File I/O")
    print("TEST2b-err-catch: caught=\(caughtFload) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))")

    // === Test 2b-include: FILE-ECHO + \S via INCLUDE (shared interpret path with FLOAD) ===
    resetTest()
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    forth.feedLine("FILE-ECHO OFF")
    collected = ""
    forth.feedLine("INCLUDE \(fecho.lastPathComponent)")
    let hasIncEchoPre = forth.debugFind("ECHOPRE")
    let hasIncEchoPost = forth.debugFind("ECHOPOST")
    let sawIncEchoSrc = collected.contains("FILE-ECHO ON") || collected.contains("echopre")
    print("TEST2b-include: echopre=\(hasIncEchoPre) echopost=\(hasIncEchoPost) sawEcho=\(sawIncEchoSrc)")

    // === Test 2b-nested: \\S in a nested FLOAD stops only that file; outer file continues ===
    resetTest()
    let fnInnerSlash = tmp.appendingPathComponent("tz-inner-slash_\(suffix).fth")
    let fnOuterSlash = tmp.appendingPathComponent("tz-outer-slash_\(suffix).fth")
    let fnOuterStop = tmp.appendingPathComponent("tz-outer-stop_\(suffix).fth")
    try! """
: innerok 11 ;
\\S
: neverinner 22 ;
""".write(to: fnInnerSlash, atomically: true, encoding: String.Encoding.utf8)
    try! """
: beforeouter 55 ;
fload \(fnInnerSlash.lastPathComponent)
: afterouter 77 ;
\\S
: neverouter 99 ;
""".write(to: fnOuterSlash, atomically: true, encoding: String.Encoding.utf8)
    let fnInnerLate = tmp.appendingPathComponent("tz-inner-late_\(suffix).fth")
    try! """
: innerskip 44 ;
""".write(to: fnInnerLate, atomically: true, encoding: String.Encoding.utf8)
    try! """
\\S
fload \(fnInnerLate.lastPathComponent)
: neverouter2 88 ;
""".write(to: fnOuterStop, atomically: true, encoding: String.Encoding.utf8)
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    forth.loadFile(fnOuterSlash)
    let hasBeforeOuter = forth.debugFind("BEFOREOUTER")
    let hasInnerOk = forth.debugFind("INNEROK")
    let hasNeverInner = forth.debugFind("NEVERINNER")
    let hasAfterOuter = forth.debugFind("AFTEROUTER")
    let hasNeverOuter = forth.debugFind("NEVEROUTER")
    print("TEST2b-nested: before=\(hasBeforeOuter) inner=\(hasInnerOk) neverinner=\(hasNeverInner) after=\(hasAfterOuter) neverouter=\(hasNeverOuter) (expect true true false true false)")
    forth.resetToSafeState()
    collected = ""
    forth.logicalCurrentDirectory = tmp.path
    forth.loadFile(fnOuterStop)
    let hasInnerLate = forth.debugFind("INNERSKIP")
    let hasNeverOuter2 = forth.debugFind("NEVEROUTER2")
    print("TEST2b-nested-outer: inner=\(hasInnerLate) neverouter2=\(hasNeverOuter2) (expect false false)")

    // === Test 2b-faultline: nested FLOAD faults cite inner file/line ===
    resetTest()
    let fnFaultChild = tmp.appendingPathComponent("ansval_fault_child_\(suffix).fth")
    let fnFaultParent = tmp.appendingPathComponent("ansval_fault_parent_\(suffix).fth")
    do {
        try "notaword\n".write(to: fnFaultChild, atomically: true, encoding: String.Encoding.utf8)
        try "1 2 + .  fload \(fnFaultChild.lastPathComponent)\n"
            .write(to: fnFaultParent, atomically: true, encoding: String.Encoding.utf8)
    } catch {
        print("TEST2b-faultline write fail: \(error)")
    }
    collected = ""
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    forth.loadFile(fnFaultParent)
    let childName = fnFaultChild.lastPathComponent
    let parentName = fnFaultParent.lastPathComponent
    let citesChild = collected.contains("\(childName) line 1")
    let citesParentContext = collected.contains("while interpreting \(parentName) line 1")
    let avoidsParentFault = !collected.contains("\(parentName) line 1: ? notaword")
    print("TEST2b-faultline: child=\(citesChild) context=\(citesParentContext) notParent=\(avoidsParentFault) (expect true true true)")

    // === Test 2b-nestedline: nested multi-line FLOAD must not advance parent line counter ===
    resetTest()
    let fnNestedChild = tmp.appendingPathComponent("ansval_nested_child_\(suffix).fth")
    let fnNestedParent = tmp.appendingPathComponent("ansval_nested_parent_\(suffix).fth")
    let fnNestedMissing = "ansval_nested_missing_\(suffix).fth"
    do {
        try (1...8).map { "\\ line \($0)\n" }.joined().write(to: fnNestedChild, atomically: true, encoding: String.Encoding.utf8)
        try "fload \(fnNestedChild.lastPathComponent)\nfload \(fnNestedMissing)\n"
            .write(to: fnNestedParent, atomically: true, encoding: String.Encoding.utf8)
    } catch {
        print("TEST2b-nestedline write fail: \(error)")
    }
    collected = ""
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    forth.loadFile(fnNestedParent)
    let nestedParentName = fnNestedParent.lastPathComponent
    let citesParentLine2 = collected.contains("in \(nestedParentName) line 2:")
    let avoidsParentLine9 = !collected.contains("in \(nestedParentName) line 9:")
    let citesMissing = collected.contains("could not read '\(fnNestedMissing)'")
    print("TEST2b-nestedline: line2=\(citesParentLine2) notline9=\(avoidsParentLine9) missing=\(citesMissing) (expect true true true)")

    // === Test 2c: DEBUG-ON / DEBUG-OFF inside a loaded file should take effect immediately
    // for subsequent lines in *that* file (live flag change during the shared load loop).
    // We expect [DEBUG] dumps only for lines between DEBUG-ON and DEBUG-OFF.
    resetTest()
    forth.feedLine("FILE-ECHO OFF")  // ensure no pollution from prior tests' FILE-ECHO ON
    collected = ""
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    forth.feedLine("fload \(fdebug.lastPathComponent)")
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
    func ansTestBlockOp(_ desc: String, _ line: String) {
        resetTest()
        forth.feedLine(line)
        ansTotal += 1
        let out = collected
        if !out.contains("?") && !forth.errorFlag && !forth.throwActive {
            ansPassed += 1
            print("TEST6 \(desc): pass")
        } else {
            print("TEST6 \(desc): FAIL got '\(out.trimmingCharacters(in: .whitespacesAndNewlines))'")
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
    ansTest("UM/MOD", "100 0 10 UM/MOD . .", "10 0")
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
    ansTest("DUMP", "t6mem 3 65 FILL t6mem 3 DUMP", "41 41 41")
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
    ansTest("H.", "255 H.", "FF")
    ansTest("H. ignores BASE", "DECIMAL 255 H.", "FF")
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

    // Hayes GD8/GD9 +LOOP circular arithmetic (Forth-2012 core+)
    forth.feedLine("VARIABLE BUMP")
    forth.feedLine("0 INVERT CONSTANT MAX-UINT")
    forth.feedLine("MAX-UINT 8 RSHIFT 1+ CONSTANT USTEP")
    forth.feedLine("USTEP NEGATE CONSTANT -USTEP")
    forth.feedLine("1 63 LSHIFT 1- CONSTANT MAX-INT")
    forth.feedLine("1 63 LSHIFT NEGATE CONSTANT MIN-INT")
    forth.feedLine("MAX-INT 7 RSHIFT 1+ CONSTANT STEP")
    forth.feedLine("STEP NEGATE CONSTANT -STEP")
    forth.feedLine(": GD8 BUMP ! DO 1+ BUMP @ +LOOP ;")
    ansTest("GD8 USTEP orbit", "0 MAX-UINT 0 USTEP GD8 .", "256")
    ansTest("GD8 -USTEP orbit", "0 0 MAX-UINT -USTEP GD8 .", "256")
    ansTest("GD8 STEP orbit", "0 MAX-INT MIN-INT STEP GD8 .", "256")
    ansTest("GD8 -STEP orbit", "0 MIN-INT MAX-INT -STEP GD8 .", "256")
    ansTest("J", ": t6j 0 2 0 DO 0 2 0 DO J + LOOP LOOP ; t6j .", "2")  // 0+0 +1+1 =2
    ansTest("RECURSE", ": t6rec 1- DUP 0= IF DROP 99 ELSE RECURSE THEN ; 5 t6rec .", "99")
    ansTest("EXECUTE", "3 4 ' + EXECUTE .", "7")

    // Dictionary / introspection (current words)
    ansTest(">HEADER >NFA ID.", "VARIABLE t6v ' t6v >NFA COUNT TYPE", "t6v")
    ansTest("' CFA >HEADER", "' DUP >HEADER 0<> .", "-1")
    ansTest(">XID DUP", "' DUP >XID .", "9")
    ansTest("['] CFA", ": t6xt ['] DUP ; ' DUP t6xt = .", "-1")
    ansTest("ID.", "' t6v ID.", "t6v")
    ansTest("HERE (value) DP", "HERE DP @ = .", "-1")  // they should match per current impl
    ansTest("LATEST", "LATEST @ 0= 0= .", "-1")  // at least non-zero after bootstrap
    ansTest("DEPTH", "1 2 3 DEPTH .", "3")
    ansTest("[']", ": t6p ['] DUP ; ' DUP t6p = .", "-1")

    // Programming-Tools (ANS 15)
    ansTest("?", "42 t6mem ! t6mem ?", "42")
    ansTest("NAME>STRING", "' DUP >HEADER DUP NAME>STRING TYPE", "DUP")
    ansTest("NAME>INTERPRET", "' DUP >HEADER DUP NAME>INTERPRET ' DUP = .", "-1")
    ansTest("TRAVERSE-WORDLIST", "VARIABLE t6tr : t6tw DROP 1 t6tr ! ; 0 t6tr ! ' t6tw GET-CURRENT TRAVERSE-WORDLIST t6tr @ .", "1")
    ansTest("SYNONYM", "SYNONYM T6DUP DUP : t6syn 5 T6DUP 1+ ; t6syn .", "6")
    forth.feedLine(": tloc 99 ;")
    ansTest("LOCATE", "LOCATE tloc", "LIT 99")
    ansTest("[DEFINED]", ": t6def [DEFINED] DUP DUP [THEN] ; 5 t6def . .", "5 5")
    ansTest("[UNDEFINED]", ": t6undef [UNDEFINED] NOPE 99 [THEN] ; t6undef .", "99")
    ansTest("N>R NR>", "10 20 2 N>R NR> . .", "20 10")
    ansTest("AHEAD", ": t6ah AHEAD 111 THEN 222 ; t6ah .", "222")
    ansTest("NAME>COMPILE xt", "' DUP >HEADER DUP NAME>COMPILE ' DUP >HEADER DUP NAME>INTERPRET = .", "0")

    // TYPE COUNT WORD (more coverage)
    ansTest("COUNT TYPE via WORD", "32 WORD HELLO COUNT TYPE", "HELLO")
    ansTest("WORD ) Hayes MSG", ": t6msg 41 WORD COUNT ; t6msg ab) DUP . TYPE", "2 ab")

    // 2@ 2! (use safe non-HERE to avoid prior side effects on DP)
    forth.feedLine("VARIABLE t2a")
    ansTest("2! 2@", "1111 2222 t2a 2! t2a 2@ SWAP . .", "1111 2222")
    ansTest("S\\\" escapes", ": t6sq S\\\" \\a\\b\\e\" ; t6sq DROP C@ .", "7")
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
    ansTest(">IN +! skip", "S\" 1 >IN +! xSOURCE TYPE\" EVALUATE", "SOURCE")
    ansTest("PAD", "PAD 0= 0= .", "-1")
    ansTest("PAD size", "PAD DUP 1023 + 65 OVER C! DROP S\" x\" DROP DROP PAD 1023 + C@ .", "65")
    ansTest("multi S\" interpret", "S\" hello\" S\" world\" SWAP ROT ROT ROT TYPE SPACE TYPE", "world hello")
    ansTest("S\" PAD isolate", "PAD DUP 100 + 42 OVER C! DROP S\" test\" 2DROP PAD 100 + C@ .", "42")
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
    ansTest("GET-ORDER SET-ORDER", "ONLY GET-ORDER SET-ORDER GET-ORDER .", "1")
    ansTest("SEARCH-WORDLIST", "S\" DUP\" FORTH-WORDLIST SEARCH-WORDLIST 0<> .", "-1")
    ansTest("SEARCH-WORDLIST immediate", "S\" IF\" FORTH-WORDLIST SEARCH-WORDLIST 1 = .", "-1")
    ansTest("SEARCH-WORDLIST miss", "S\" DUP\" WORDLIST SEARCH-WORDLIST 0= .", "-1")
    ansTest("ENVIRONMENT? WORDLISTS", "S\" WORDLISTS\" ENVIRONMENT? DROP .", "8")
    ansTest("ENVIRONMENT? SEARCH-ORDER", "S\" SEARCH-ORDER\" ENVIRONMENT? .", "-1")
    ansTest(".ENVIRONMENT", ".ENVIRONMENT", "WORDLISTS 8")

    // String word set (17): COMPARE SEARCH SLITERAL /STRING -TRAILING BLANK CMOVE
    ansTest("COMPARE equal", "S\" abc\" S\" abc\" COMPARE .", "0")
    ansTest("COMPARE less", "S\" ab\" S\" abc\" COMPARE .", "-1")
    ansTest("COMPARE greater", "S\" abcd\" S\" abc\" COMPARE .", "1")
    ansTest("/STRING", "S\" abcdef\" 2 /STRING TYPE", "cdef")
    ansTest("-TRAILING", "S\" abc   \" -TRAILING TYPE", "abc")
    ansTest("BLANK", "PAD 8 2DUP BLANK 2DUP COMPARE .", "0")
    ansTest("SEARCH found", "S\" xyzabc\" S\" abc\" SEARCH .", "-1")
    ansTest("SEARCH miss", "S\" xyz\" S\" abc\" SEARCH .", "0")
    ansTest("SEARCH empty", "S\" abc\" S\" \" SEARCH .", "-1")
    forth.feedLine(": t17sl [ S\" hello\" SLITERAL ] ;")
    ansTest("SLITERAL", "t17sl TYPE", "hello")
    ansTest("ENVIRONMENT? STRING", "S\" STRING\" ENVIRONMENT? .", "-1")

    // Facility (10): BEGIN-STRUCTURE / +FIELD / FIELD: (Hayes facilitytest subset)
    forth.feedLine("BEGIN-STRUCTURE T6S1 END-STRUCTURE")
    ansTest("empty structure", "T6S1 .", "0")
    forth.feedLine("BEGIN-STRUCTURE T6S2 1 CHARS +FIELD T6A 1 CELLS +FIELD T6B END-STRUCTURE")
    ansTest("structure size", "T6S2 .", "9")
    forth.feedLine("CREATE T6I T6S2 ALLOT")
    ansTest("structure field C!", "77 T6I T6A C! T6I T6A C@ .", "77")
    forth.feedLine("BEGIN-STRUCTURE T6S3 FIELD: T6X FIELD: T6Y END-STRUCTURE")
    ansTest("FIELD: offset", "0 T6Y .", "8")
    forth.feedLine("BEGIN-STRUCTURE T6S4 T6S2 +FIELD T6N ALIGNED T6S3 +FIELD T6M END-STRUCTURE")
    ansTest("nested structure size", "T6S4 .", "32")
    ansTest("ENVIRONMENT? FACILITY", "S\" FACILITY\" ENVIRONMENT? .", "-1")

    // Facility terminal (10.6.1): PAGE / AT-XY with 80×25 buffer
    var termScreen = ""
    forth.onTerminalRefresh = { termScreen = $0 }
    resetTest()
    termScreen = ""
    forth.feedLine("PAGE")
    ansTest("PAGE (no crash)", "42 .", "42")
    ansTotal += 1
    if termScreen.split(separator: "\n", omittingEmptySubsequences: false).count == 25 {
        ansPassed += 1
        print("TEST6 PAGE 80x25: pass")
    } else {
        print("TEST6 PAGE 80x25: FAIL rows=\(termScreen.split(separator: "\n", omittingEmptySubsequences: false).count)")
    }
    resetTest()
    termScreen = ""
    forth.feedLine("PAGE")
    forth.feedLine("2 1 AT-XY 65 EMIT")
    ansTotal += 1
    let termLines = termScreen.split(separator: "\n", omittingEmptySubsequences: false)
    if termLines.count >= 2 {
        let row1 = String(termLines[1])
        let idx = row1.index(row1.startIndex, offsetBy: 2, limitedBy: row1.endIndex)
        if let idx, row1[idx] == "A" {
            ansPassed += 1
            print("TEST6 AT-XY EMIT: pass")
        } else {
            print("TEST6 AT-XY EMIT: FAIL row1='\(row1)'")
        }
    } else {
        print("TEST6 AT-XY EMIT: FAIL short screen")
    }

    // Facility Phase 3: MS / TIME&DATE / EKEY* / EMIT? / K-*
    ansTest("EMIT?", "EMIT? .", "-1")
    ansTest("K-LEFT", "K-LEFT .", "1")
    let tdYear = Calendar.current.component(.year, from: Date())
    ansTest("TIME&DATE year", "TIME&DATE .", "\(tdYear)")
    ansTest("EKEY>CHAR a", "\(TZForth.makeCharKeyEvent(97)) EKEY>CHAR . .", "-1")
    ansTest("EKEY>FKEY left", "\(TZForth.makeFKeyEvent(TZForth.FacilityFKey.left)) EKEY>FKEY . .", "-1")
    ansTest("EKEY? empty", "EKEY? .", "0")
    resetTest()
    forth.enqueueExtendedKey(TZForth.makeCharKeyEvent(66, mods: 0))
    collected = ""
    forth.feedLine("EKEY? .")
    ansTotal += 1
    if collected.contains("-1") {
        ansPassed += 1
        print("TEST6 EKEY? queued: pass")
    } else {
        print("TEST6 EKEY? queued: FAIL got '\(collected.trimmingCharacters(in: .whitespacesAndNewlines))'")
    }
    resetTest()
    forth.feedLine("EKEY EKEY>CHAR DROP .")
    ansTotal += 1
    if forth.waitingForExtendedKey {
        forth.provideExtendedKey(TZForth.makeCharKeyEvent(65, mods: 0))
    }
    let ekeyOut = collected.trimmingCharacters(in: .whitespacesAndNewlines)
    if ekeyOut.contains("65") {
        ansPassed += 1
        print("TEST6 EKEY char: pass")
    } else {
        print("TEST6 EKEY char: FAIL got '\(ekeyOut)'")
    }
    ansTest("MS brief", "1 MS", "OK")

    // Memory-Allocation (14): GROWMEMORYMB first (once per session), then ALLOCATE FREE RESIZE
    // Cap at 64 MB (GROWMEMORYMB limit). If settings.json already restored full memory, skip grow.
    let maxGrowMB = 64
    let currentMB = max(1, forth.memory.count / (1024 * 1024))
    if currentMB >= maxGrowMB {
        // Memory already at cap (e.g. settings.json from SAVE-SETTINGS); consume one-time slot.
        ansTest("GROWMEMORYMB grow", "\(maxGrowMB) GROWMEMORYMB", "cannot shrink")
        ansTest("GROWMEMORYMB at-cap UNUSED", "UNUSED 3000000 > .", "-1")
    } else {
        let growMBTarget = min(maxGrowMB, max(5, currentMB + 4))
        ansTest("GROWMEMORYMB grow", "\(growMBTarget) GROWMEMORYMB UNUSED 3000000 > .", "-1")
    }
    ansTest("ALLOCATE", "64 ALLOCATE DROP DUP 42 SWAP ! DUP @ .", "42")
    ansTest("ALLOCATE ior", "128 ALLOCATE NIP 0= .", "-1")
    ansTest("FREE", "64 ALLOCATE DROP DUP FREE 0= .", "-1")
    ansTest("RESIZE grow", "64 ALLOCATE DROP DUP 128 RESIZE NIP 0= .", "-1")
    ansTest("GROWMEMORYMB already used", "2 GROWMEMORYMB", "already used")
    ansTest("ENVIRONMENT? MEMORY-ALLOCATION", "S\" MEMORY-ALLOCATION\" ENVIRONMENT? .", "-1")
    do {
        let fAfterAlloc = TZForth()
        var out = ""
        fAfterAlloc.onOutput = { out += $0 }
        fAfterAlloc.feedLine("64 ALLOCATE DROP DROP")
        out = ""
        fAfterAlloc.feedLine("4 GROWMEMORYMB")
        ansTotal += 1
        if out.contains("not allowed after ALLOCATE") {
            ansPassed += 1
            print("TEST6 GROWMEMORYMB after ALLOCATE: pass")
        } else {
            print("TEST6 GROWMEMORYMB after ALLOCATE: FAIL got '\(out.trimmingCharacters(in: .whitespacesAndNewlines))'")
        }
    }
    do {
        let fShrink = TZForth()
        var out = ""
        fShrink.onOutput = { out += $0 }
        fShrink.feedLine("1 GROWMEMORYMB")
        ansTotal += 1
        if out.contains("cannot shrink memory") {
            ansPassed += 1
            print("TEST6 GROWMEMORYMB shrink: pass")
        } else {
            print("TEST6 GROWMEMORYMB shrink: FAIL got '\(out.trimmingCharacters(in: .whitespacesAndNewlines))'")
        }
    }

    // Double-Number (8): D+ D. 2CONSTANT 2VALUE trailing-dot literals
    ansTest("double literal", "1234. DROP .", "1234")
    ansTest("double literal hi", "1234. .", "0")
    ansTest("S>D D.", "42 S>D D.", "42")
    ansTest("D+", "1. 2. D+ D.", "3")
    ansTest("D-", "5. 2. D- D.", "3")
    ansTest("DNEGATE", "7. DNEGATE D.", "-7")
    ansTest("DABS", "-9. DABS D.", "9")
    ansTest("D=", "100. 100. D= .", "-1")
    ansTest("D0=", "0. D0= .", "-1")
    ansTest("M+", "1. 5 M+ D.", "6")
    ansTest("M*/", "10. 10 5 M*/ D.", "20")
    ansTest("D>S", "1234. D>S .", "1234")
    forth.feedLine("1000. 2CONSTANT t8big")
    ansTest("2CONSTANT", "t8big D.", "1000")
    forth.feedLine("50. 2VALUE t8dv")
    forth.feedLine(": t8put 200. ;")
    ansTest("2VALUE TO", "t8put TO t8dv t8dv D.", "200")
    ansTest("DU<", "1. 2. DU< .", "-1")
    ansTest("2ROT", "1. 2. 3. 2ROT 2DROP D.", "3")
    ansTest("ENVIRONMENT? DOUBLE", "S\" DOUBLE\" ENVIRONMENT? .", "-1")

    // Locals (13): LOCALS| {: TO
    forth.feedLine(": t13a LOCALS| x | x ;")
    ansTest("LOCALS|", "10 t13a .", "10")
    forth.feedLine(": t13b LOCALS| x | 5 TO x x ;")
    ansTest("LOCALS| TO", "0 t13b .", "5")
    forth.feedLine(": t13c {: a b | c :} b . a . ;")
    ansTest("{: order", "3 4 t13c", "4 3")
    forth.feedLine(": t13d LOCALS| r | 3 0 DO I r + TO r LOOP r ;")
    ansTest("LOCALS in DO", "1 t13d .", "4")
    ansTest("ENVIRONMENT? LOCALS", "S\" LOCALS\" ENVIRONMENT? .", "-1")
    ansTest("ENVIRONMENT? #LOCALS", "S\" #LOCALS\" ENVIRONMENT? DROP .", "32")

    // Core Ext Tier 2: :NONAME ACTION-OF MARKER SAVE-INPUT RESTORE-INPUT SOURCE-ID S\" REFILL
    ansTest(":NONAME", "VARIABLE t7n1 :NONAME 1234 ; t7n1 ! t7n1 @ EXECUTE .", "1234")
    ansTest("ACTION-OF", "DEFER t7d : t7a1 42 ; ' t7a1 IS t7d ACTION-OF t7d EXECUTE .", "42")
    ansTest("MARKER", "MARKER t7m1 : t7w1 11 ; : t7w2 22 ; t7m1 t7w1 .", "? t7w1")
    ansTest("SOURCE-ID terminal", "SOURCE-ID .", "-1")
    ansTest("REFILL", "REFILL 0= .", "-1")
    ansTest("SAVE-INPUT RESTORE-INPUT", "SAVE-INPUT S\" 222 .\" EVALUATE RESTORE-INPUT . 333 .", "0 333")
    ansTest("RESTORE-INPUT fail", "SAVE-INPUT 2DROP 0 RESTORE-INPUT .", "-1")
    ansTest("SAVE-INPUT nested", "SAVE-INPUT S\" 11 .\" EVALUATE RESTORE-INPUT . 22 .", "0 22")
    ansTest("FILE-ECHO default", "FILE-ECHO @ .", "0")
    ansTest("WARNING default", "WARNING @ .", "-1")
    ansTest("\\ interpret comment", "3 . \\ drop trash", "3")
    resetTest()
    forth.feedLine(": tzbslash1 9 ; \\ noop")
    ansTest("\\ compile comment", "tzbslash1 .", "9")
    resetTest()
    collected = ""
    forth.feedLine(": TZWRDEF1 1 ;")
    forth.feedLine(": TZWRDEF1 2 ;")
    ansTotal += 1
    if collected.contains("TZWRDEF1 isn't unique") {
        ansPassed += 1
        print("TEST6 WARNING redef: pass")
    } else {
        print("TEST6 WARNING redef: FAIL out='\(collected.trimmingCharacters(in: .whitespacesAndNewlines))'")
    }
    collected = ""
    forth.feedLine("WARNING OFF")
    forth.feedLine(": TZWRDEF1 3 ;")
    ansTotal += 1
    if !collected.contains("isn't unique") {
        ansPassed += 1
        print("TEST6 WARNING off: pass")
    } else {
        print("TEST6 WARNING off: FAIL out='\(collected.trimmingCharacters(in: .whitespacesAndNewlines))'")
    }
    forth.feedLine("WARNING ON")
    resetTest()
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    forth.feedLine("FILE-ECHO OFF")
    collected = ""
    forth.feedLine("INCLUDE \(fecho.lastPathComponent)")
    ansTotal += 1
    if collected.contains("FILE-ECHO ON") && forth.debugFind("ECHOPRE") && !forth.debugFind("ECHOPOST") {
        ansPassed += 1
        print("TEST6 FILE-ECHO INCLUDE: pass")
    } else {
        print("TEST6 FILE-ECHO INCLUDE: FAIL echo='\(collected.trimmingCharacters(in: .whitespacesAndNewlines))'")
    }
    ansTest("S\\\"", ": t7sq S\\\" hello\" TYPE ; t7sq", "hello")
    ansTest("S\\\" escapes", ": t7sq2 S\\\" a\\\\b\" TYPE ; t7sq2", "a\\b")

    // File-Access (ANS word set 11)
    let flinePath = fline.path
    let fincPath = finc.path
    let fwrPath = fwr.path
    let frenamedPath = tmp.appendingPathComponent("testren_\(suffix).txt").path
    ansTest("R/O OPEN-FILE", "S\" \(flinePath)\" R/O OPEN-FILE 0= .", "-1")
    ansTest("FILE-SIZE", "S\" \(flinePath)\" R/O OPEN-FILE DROP FILE-SIZE DROP DROP .", "11")
    ansTest("FILE-POSITION", "S\" \(flinePath)\" R/O OPEN-FILE DROP DUP FILE-POSITION DROP DROP .", "0")
    ansTest("READ-LINE", "S\" \(flinePath)\" R/O OPEN-FILE DROP PAD 1+ SWAP 80 SWAP READ-LINE DROP DROP PAD 1+ SWAP TYPE CLOSE-FILE DROP", "alpha")
    ansTest("FILE-STATUS", "S\" \(flinePath)\" FILE-STATUS NIP 0= .", "-1")
    ansTest("INCLUDED", "S\" \(fincPath)\" INCLUDED fincw .", "42")

    // REQUIRE / REQUIRED (ANS F.11.6.2.2144.50) — REQUIRE parses name from input (not S").
    let freq1Base = freq1.lastPathComponent
    let freq2Base = freq2.lastPathComponent
    let freq3Base = freq3.lastPathComponent
    let freq4Base = freq4.lastPathComponent
    func resetIncludedNames() {
        forth.feedLine("0 INCLUDED-NAMES !")
    }
    resetIncludedNames()
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    ansTest("REQUIRED once", "1 S\" \(freq1Base)\" REQUIRED REQUIRE \(freq1Base) .", "2")
    resetIncludedNames()
    ansTest("INCLUDED reload", "1 INCLUDE \(freq2Base) REQUIRE \(freq2Base) 1 S\" \(freq2Base)\" INCLUDED .", "2")
    resetTest()
    resetIncludedNames()
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    forth.feedLine("1 fload \(freq3Base)")
    collected = ""
    forth.feedLine("S\" \(freq3Base)\" REQUIRED .")
    ansTotal += 1
    if collected.trimmingCharacters(in: .whitespacesAndNewlines).contains("2") {
        ansPassed += 1
        print("TEST6 REQUIRED FLOAD register: pass")
    } else {
        print("TEST6 REQUIRED FLOAD register: FAIL got '\(collected.trimmingCharacters(in: .whitespacesAndNewlines))' (expected 2)")
    }
    resetIncludedNames()
    ansTest("INCLUDED-NAMES", "S\" \(freq4Base)\" REQUIRED INCLUDED-NAMES @ 0= .", "0")
    resetTest()
    resetIncludedNames()
    forth.feedLine("S\" \(freq1Base)\" REQUIRED")
    collected = ""
    forth.feedLine(".INCLUDED")
    ansTotal += 1
    if collected.contains(freq1Base) {
        ansPassed += 1
        print("TEST6 .INCLUDED list: pass")
    } else {
        print("TEST6 .INCLUDED list: FAIL got '\(collected.trimmingCharacters(in: .whitespacesAndNewlines))' (expected \(freq1Base))")
    }

    ansTest("ENVIRONMENT? FILE", "S\" FILE\" ENVIRONMENT? .", "-1")
    ansTest("CREATE-FILE", "S\" \(fwrPath)\" W/O CREATE-FILE 0= SWAP CLOSE-FILE DROP .", "-1")
    forth.feedLine("VARIABLE t8hfid")
    ansTest("REPOSITION-FILE", "S\" \(flinePath)\" R/O OPEN-FILE DROP t8hfid ! 6 0 t8hfid @ REPOSITION-FILE DROP t8hfid @ PAD 1+ SWAP 80 SWAP READ-LINE DROP DROP PAD 1+ SWAP TYPE t8hfid @ CLOSE-FILE DROP", "beta")
    ansTest("WRITE-LINE", "S\" \(fwrPath)\" W/O CREATE-FILE DROP t8hfid ! S\" hi\" t8hfid @ WRITE-LINE DROP t8hfid @ CLOSE-FILE DROP 1 .", "1")
    ansTest("WRITE-LINE size", "S\" \(fwrPath)\" R/O OPEN-FILE DROP FILE-SIZE DROP DROP .", "3")
    ansTest("READ written file", "S\" \(fwrPath)\" R/O OPEN-FILE DROP PAD 1+ SWAP 80 SWAP READ-LINE DROP DROP PAD 1+ SWAP TYPE CLOSE-FILE DROP", "hi")
    ansTest("RESIZE-FILE", "S\" \(fwrPath)\" R/W OPEN-FILE DROP t8hfid ! 5 0 t8hfid @ RESIZE-FILE DROP t8hfid @ FILE-SIZE DROP DROP . t8hfid @ CLOSE-FILE DROP", "5")
    ansTest("FLUSH-FILE", "S\" \(fwrPath)\" R/W OPEN-FILE DROP DUP FLUSH-FILE 0= SWAP CLOSE-FILE DROP .", "-1")
    ansTest("RENAME-FILE", "S\" \(fwrPath)\" S\" \(frenamedPath)\" RENAME-FILE 0= .", "-1")
    ansTest("READ renamed file", "S\" \(frenamedPath)\" R/O OPEN-FILE DROP FILE-SIZE DROP DROP .", "5")

    // Exception word set (9): CATCH THROW; ABORT/ABORT" use THROW -1/-2
    forth.feedLine(": t9a 9 ; : t9c1 1 2 3 ['] t9a CATCH ;")
    ansTest("CATCH normal", "t9c1 . . . . .", "0 9 3 2 1")
    forth.feedLine(": t9t2 8 0 THROW ; : t9c2 1 2 ['] t9t2 CATCH ;")
    ansTest("THROW 0", "t9c2 . . . .", "0 8 2 1")
    forth.feedLine(": t9t3 7 8 9 99 THROW ; : t9c3 1 2 ['] t9t3 CATCH ;")
    ansTest("THROW catch", "t9c3 . . .", "99 2 1")
    forth.feedLine(": t9ab ABORT ; : t9abc 1 ['] t9ab CATCH ;")
    ansTest("ABORT CATCH", "t9abc . .", "-1 1")
    forth.feedLine(": t9abq 1 ABORT\" oops\" ; : t9abcq 1 ['] t9abq CATCH ;")
    ansTest("ABORT\" CATCH", "t9abcq . .", "-2 1")
    forth.feedLine("ABORT")
    ansTotal += 1
    let abortMsg = collected
    collected = ""
    forth.feedLine("42 .")
    ansTotal += 1
    if abortMsg.contains("Aborted!") && collected.contains("42") {
        ansPassed += 2
        print("TEST6 ABORT unhandled message: pass")
        print("TEST6 ABORT recover REPL: pass")
    } else {
        if !abortMsg.contains("Aborted!") {
            print("TEST6 ABORT unhandled message: FAIL got '\(abortMsg.trimmingCharacters(in: .whitespacesAndNewlines))' (expected Aborted!)")
        } else {
            ansPassed += 1
            print("TEST6 ABORT unhandled message: pass")
        }
        if collected.contains("42") {
            ansPassed += 1
            print("TEST6 ABORT recover REPL: pass")
        } else {
            print("TEST6 ABORT recover REPL: FAIL got '\(collected.trimmingCharacters(in: .whitespacesAndNewlines))' (expected 42 on next line)")
        }
    }
    ansTest("ABORT\" unhandled", "1 ABORT\" oops\" 42 .", "oops")
    ansTest("ENVIRONMENT? EXCEPTION", "S\" EXCEPTION\" ENVIRONMENT? .", "-1")
    forth.feedLine(": t9t5 2DROP 2DROP 9999 THROW ; : t9c5 1 2 3 4 ['] t9t5 CATCH DEPTH ;")
    ansTest("CATCH depth restore", "t9c5 .", "5")

    // Standard THROW codes (Phase 1): kernel faults are CATCH-able
    forth.feedLine(": t9div ['] / CATCH ;")
    ansTest("CATCH div-by-zero", "1 0 t9div .", "-9")
    forth.feedLine(": t9undef S\" no-such-word-tzforth-xyz\" ['] EVALUATE CATCH ;")
    ansTest("CATCH undefined word", "t9undef .", "-13")
    ansTest("CATCH EVALUATE tick", "S\" no-such-word-tzforth-xyz\" ' EVALUATE CATCH .", "-13")
    ansTest("CATCH-EVALUATE", "S\" no-such-word-tzforth-xyz\" CATCH-EVALUATE .", "-13")
    forth.feedLine(": t9under ['] drop CATCH ;")
    ansTest("CATCH stack underflow", "t9under .", "-3")
    ansTest("CATCH compile-only", "S\" IF\" CATCH-EVALUATE .", "-14")
    ansTest("CATCH invalid address", "-1 ' @ CATCH .", "-7")

    ansTest(".ERROR div-by-zero", "1 0 ' / CATCH .ERROR", "? Division by zero")
    ansTest(".ERROR success silent", "0 .ERROR 1 .", "1")
    ansTest(".ERROR abort code", "-1 .ERROR", "Aborted!")
    ansTest(".ERROR inline spaced", ".\" before\" 1 0 ' / CATCH .ERROR .\" after\"", "before ? Division by zero after")

    // THROW Phase 3: dictionary / defining-word faults
    ansTest("CATCH FORGET no name", "S\" FORGET\" CATCH-EVALUATE .", "-10")
    ansTest("CATCH CREATE no name", "S\" CREATE\" CATCH-EVALUATE .", "-10")
    ansTest("CATCH SEE undefined", "S\" SEE nosuchtzforthxyz\" CATCH-EVALUATE .", "-13")
    ansTest("CATCH SYNONYM undefined", "S\" SYNONYM newsyn nosuchtzforthxyz\" CATCH-EVALUATE .", "-13")

    // Caught throw during compile: STATE stays 1 and open : definition can finish with ;
    resetTest()
    forth.feedLine("VARIABLE t9pst")
    forth.feedLine(": t9pei ['] EVALUATE CATCH STATE @ t9pst ! ; IMMEDIATE")
    forth.feedLine(": t9ppi t9pst @ . ; IMMEDIATE")
    forth.feedLine(": t9pdef")
    collected = ""
    forth.feedLine("S\" nosuch-tzforth-compile-xyz\" t9pei t9ppi")
    let compileStateOne = collected.contains("1")
    forth.feedLine("789 ;")
    forth.feedLine("t9pdef .")
    ansTotal += 1
    let cstOut = collected.trimmingCharacters(in: .whitespacesAndNewlines)
    if compileStateOne && cstOut.contains("789") {
        ansPassed += 1
        print("TEST6 CATCH compile STATE preserve: pass")
    } else {
        print("TEST6 CATCH compile STATE preserve: FAIL compileState=\(compileStateOne) out='\(cstOut)' (expected 1 during compile, 789 at run)")
    }

    // THROW Phase 4: file I/O and host FLOAD
    ansTest("FLOAD trailing bare suppressed", "fload \(fecho.lastPathComponent) fload", "OK")
    if forth.fileLoadRequested {
        print("TEST6 FLOAD trailing bare suppressed: FAIL (fileLoadRequested set)")
        ansTotal += 1
    } else {
        ansPassed += 1
        ansTotal += 1
        print("TEST6 FLOAD trailing bare suppressed: pass")
    }
    forth.fileLoadRequested = false
    ansTest("CATCH FLOAD missing", "S\" fload nosuch-tzforth-missing.fth\" CATCH-EVALUATE .", "-74")
    forth.feedLine(": t4if 999 ['] INCLUDE-FILE CATCH ;")
    ansTest("CATCH INCLUDE-FILE invalid", "t4if .", "-68")
    forth.feedLine(": t4inc S\" nosuch-tzforth-missing.fth\" ['] INCLUDED CATCH ;")
    ansTest("CATCH INCLUDED missing", "t4inc .", "-74")

    // THROW Phase 5: -40 user, -67 closed file, catchable mid-file load abort (-13 / -70)
    ansTest("THROW user -40", ": t4u40 -40 throw ; : t4c40 ['] t4u40 catch ; t4c40 .", "-40")
    ansTest("CATCH THROW -70", ": t470 -70 throw ; : t4c70 ['] t470 catch ; t4c70 .", "-70")
    _ = fm.changeCurrentDirectoryPath(tmp.path)
    forth.logicalCurrentDirectory = tmp.path
    ansTest("CATCH FLOAD mid-file", "S\" fload \(fbad.lastPathComponent)\" CATCH-EVALUATE .", "-13")
    forth.feedLine("VARIABLE t4fid")
    forth.feedLine(": t4closed s\" \(fincPath)\" r/o open-file drop t4fid ! t4fid @ close-file drop t4fid @ ['] include-file catch ;")
    ansTest("CATCH INCLUDE-FILE closed", "t4closed .", "-67")

    // THROW Phase 5b: nested CATCH, safe-fload, mid-include, .ERROR file codes
    forth.feedLine(": t5in 99 throw ; : t5mid ['] t5in execute ; : t5out 1 2 ['] t5mid catch ;")
    ansTest("CATCH nested propagate", "t5out . . .", "99 2 1")
    forth.feedLine(": t5in2 99 throw ; : t5mid2 ['] t5in2 catch drop ; : t5out2 1 ['] t5mid2 catch ;")
    ansTest("CATCH inner absorbs", "t5out2 . .", "0 1")
    forth.feedLine("VARIABLE t5fid")
    forth.feedLine(": t5inc s\" \(fbad.path)\" r/o open-file drop t5fid ! t5fid @ ['] include-file catch ;")
    ansTest("CATCH INCLUDE-FILE mid-file", "t5inc .", "-13")
    ansTest(".ERROR closed file", "-67 .ERROR", "? Operation on closed file")
    ansTest(".ERROR file I/O", "-70 .ERROR", "? File I/O exception")
    ansTest(".ERROR not found", "-74 .ERROR", "? File not found")

    // Block subsystem (ANS Block 10.6.1 + TZForth .blk extensions). "TZ ext" = non-ANS.
    let blkVol = "ansval_\(suffix)_vol"
    let blkLoad = "ansval_\(suffix)_load"
    let blkLoadPath = tmp.appendingPathComponent("\(blkLoad).blk").path
    do {
        let bs = forth.effectiveBlockSize()
        var data = Data(repeating: 0, count: bs)
        let line = "42 ."
        for (i, b) in line.utf8.enumerated() where i < 64 {
            data[i] = b
        }
        try data.write(to: URL(fileURLWithPath: blkLoadPath))
    } catch {
        print("TEST7 block LOAD file setup fail: \(error)")
    }
    print("=== TZForth Extended-Character (ANS 18.6 UTF-8 memory + string words) ===")
    ansTest("XC-SIZE 0", "HEX 0 XC-SIZE DECIMAL .", "1")
    ansTest("XC-SIZE 7F", "HEX 7F XC-SIZE DECIMAL .", "1")
    ansTest("XC-SIZE 80", "HEX 80 XC-SIZE DECIMAL .", "2")
    ansTest("XC-SIZE 7FF", "HEX 7FF XC-SIZE DECIMAL .", "2")
    ansTest("XC-SIZE 800", "HEX 800 XC-SIZE DECIMAL .", "3")
    ansTest("XC-SIZE FFFF", "HEX FFFF XC-SIZE DECIMAL .", "3")
    ansTest("XC-SIZE 10000", "HEX 10000 XC-SIZE DECIMAL .", "4")
    ansTest("XC!+ XC@+", "HEX 80 PAD XC!+ DROP PAD XC@+ NIP 80 = .", "-1")
    ansTest("XC, encode size", "HEX PAD DUP 800 SWAP XC!+ SWAP - 3 = .", "-1")
    ansTest("XC!+?", "HEX FFFF PAD 2 XC!+? NIP NIP 0= .", "-1")
    ansTest("XCHAR+/-", "HEX PAD 16 ERASE 41 PAD SWAP XC!+ DUP XCHAR- XCHAR+ = .", "-1")
    ansTest("+X/STRING", "HEX PAD 16 ERASE PAD DUP 41 SWAP XC!+ 42 SWAP XC!+ DROP 2 +X/STRING NIP DUP 1 = .", "-1")
    ansTest("X\\STRING-", "HEX PAD 16 ERASE PAD DUP 41 SWAP XC!+ 42 SWAP XC!+ DROP 2 X\\STRING- NIP DUP 1 = .", "-1")
    ansTest("-TRAILING-GARBAGE ok", "HEX PAD 16 ERASE PAD DUP 41 SWAP XC!+ DROP 1 -TRAILING-GARBAGE NIP 1 = .", "-1")
    ansTest("-TRAILING-GARBAGE trim", "HEX PAD 16 ERASE C0 PAD C! PAD 1 -TRAILING-GARBAGE NIP 0= .", "-1")
    print("=== TZForth Extended-Character (ANS 18.6.2 parsing — shadow CHAR, [CHAR], PARSE) ===")
    ansTest("CHAR ascii", "DECIMAL CHAR Z .", "90")
    ansTest("CHAR utf8", "DECIMAL CHAR é .", "233")
    ansTest("[CHAR] utf8", ": xc [CHAR] é ; xc .", "233")
    ansTest("PARSE utf8 delim", "DECIMAL $20AC PARSE abc€ NIP 4 = .", "-1")
    print("=== TZForth Extended-Character (ANS 18.6.1 I/O — XEMIT, XKEY, XKEY?, EKEY>XCHAR) ===")
    ansTest("XEMIT ascii", "65 XEMIT", "A")
    ansTest("XEMIT utf8", "DECIMAL 8364 XEMIT", "€")
    ansTest("EKEY>XCHAR a", "\(TZForth.makeCharKeyEvent(97)) EKEY>XCHAR DROP DUP 97 = .", "-1")
    ansTest("EKEY>XCHAR euro", "\(TZForth.makeCharKeyEvent(8364)) EKEY>XCHAR DROP DUP 8364 = .", "-1")
    ansTest("EKEY>XCHAR fkey", "\(TZForth.makeFKeyEvent(TZForth.FacilityFKey.left)) EKEY>XCHAR NIP .", "0")
    ansTest("XKEY? idle", "XKEY? .", "0")
    resetTest()
    collected = ""
    forth.feedLine("XKEY .")
    ansTotal += 1
    if forth.waitingForXKey && forth.waitingForKey {
        forth.provideKey(65)
    }
    let xkeyOut = collected.trimmingCharacters(in: .whitespacesAndNewlines)
    if xkeyOut.contains("65") {
        ansPassed += 1
        print("TEST6 XKEY ascii: pass")
    } else {
        print("TEST6 XKEY ascii: FAIL got '\(xkeyOut)'")
    }
    resetTest()
    collected = ""
    forth.feedLine("XKEY .")
    ansTotal += 1
    if forth.waitingForXKey {
        forth.provideKey(0xC3)
    }
    if forth.waitingForXKey && forth.waitingForKey {
        forth.provideKey(0xA9)
    }
    let xkeyUtf8Out = collected.trimmingCharacters(in: .whitespacesAndNewlines)
    if xkeyUtf8Out.contains("233") {
        ansPassed += 1
        print("TEST6 XKEY utf8: pass")
    } else {
        print("TEST6 XKEY utf8: FAIL got '\(xkeyUtf8Out)'")
    }
    resetTest()
    forth.xkeyAssembly = [0xC3, 0xA9]
    collected = ""
    forth.feedLine("XKEY? .")
    ansTotal += 1
    if collected.contains("-1") {
        ansPassed += 1
        print("TEST6 XKEY? ready: pass")
    } else {
        print("TEST6 XKEY? ready: FAIL got '\(collected.trimmingCharacters(in: .whitespacesAndNewlines))'")
    }
    resetTest()
    forth.feedLine("DECIMAL")

    print("=== TZForth Extended-Character (ANS 18.6.2 pictured — XHOLD) ===")
    ansTest("XHOLD ascii", "123 S>D <# #S CHAR m XHOLD #> S\" m123\" COMPARE 0= .", "-1")
    ansTest("XHOLD utf8", "123 S>D <# #S DECIMAL $E9 XHOLD #> S\" é123\" COMPARE 0= .", "-1")
    print("=== TZForth Extended-Character (ANS 18.6.2 display width — XC-WIDTH, X-WIDTH) ===")
    ansTest("XC-WIDTH ascii", "HEX 41 XC-WIDTH DECIMAL .", "1")
    ansTest("XC-WIDTH CJK", "HEX 606D XC-WIDTH DECIMAL .", "2")
    ansTest("XC-WIDTH zero", "HEX 2060 XC-WIDTH DECIMAL .", "0")
    ansTest("X-WIDTH mixed", "HEX PAD 41 SWAP XC!+ 606D SWAP XC!+ DROP PAD DUP 4 X-WIDTH DECIMAL .", "3")
    print("=== TZForth Extended-Character (ANS 18.3.2 ENVIRONMENT?) ===")
    ansTest("ENVIRONMENT? EXTENDED-CHARACTER", "S\" EXTENDED-CHARACTER\" ENVIRONMENT? .", "-1")
    ansTest("ENVIRONMENT? XCHAR-ENCODING len", "S\" XCHAR-ENCODING\" ENVIRONMENT? DROP .", "5")
    ansTest("ENVIRONMENT? XCHAR-ENCODING text", "S\" XCHAR-ENCODING\" ENVIRONMENT? DROP S\" UTF-8\" COMPARE 0= .", "-1")
    ansTest("ENVIRONMENT? MAX-XCHAR", "S\" MAX-XCHAR\" ENVIRONMENT? DROP HEX U. DECIMAL", "10FFFF")
    ansTest("ENVIRONMENT? XCHAR-MAXMEM", "S\" XCHAR-MAXMEM\" ENVIRONMENT? DROP .", "4")

    print("=== TZForth Float Tier A (ANS 12 — minimal IEEE 64-bit, separate F stack) ===")
    ansTest("float literal", "2.5 FDEPTH .", "1")
    ansTest("S>F", "42 S>F FDEPTH .", "1")
    ansTest("F+", "1.5 2.5 F+ 4e0 FSWAP F- F0= .", "-1")
    ansTest("F-", "5e0 2e0 F- 3e0 FSWAP F- F0= .", "-1")
    ansTest("F*", "2e0 3e0 F* 6e0 FSWAP F- F0= .", "-1")
    ansTest("F/", "8e0 2e0 F/ 4e0 FSWAP F- F0= .", "-1")
    ansTest("FNEGATE", "-3e0 FNEGATE 3e0 FSWAP F- F0= .", "-1")
    ansTest("FDUP", "2.5 FDUP FDEPTH .", "2")
    ansTest("FSWAP", "2e0 1e0 FSWAP 1e0 FSWAP F- F0< .", "-1")
    ansTest("FDEPTH", "1.5 2.5 FDEPTH .", "2")
    ansTest("FLOATS", "1 FLOATS .", "8")
    ansTest("0 FLOATS", "0 FLOATS .", "0")
    ansTest("F@ F!", "PAD 3.14 F! PAD F@ 3.14 FSWAP F- F0= .", "-1")
    ansTest("FALIGNED", "HEX 1000 FALIGNED . DECIMAL", "-1")
    ansTest("D>F", "10 0 D>F 10e0 FSWAP F- F0= .", "-1")
    ansTest(">FLOAT", "S\" 1.25\" >FLOAT DROP FDEPTH .", "1")
    ansTest(">FLOAT blank", "S\"    \" >FLOAT DROP FDEPTH .", "1")
    ansTest(">FLOAT 1+1", "S\" 1+1\" >FLOAT DROP 10e0 FSWAP F- F0= .", "-1")
    ansTest(">FLOAT lead space", "pad 32 emit 57 emit 2 pad >float .", "0")
    ansTest("FCONSTANT", "3.14 FCONSTANT TPI TPI 3.14 FSWAP F- F0= .", "-1")
    ansTest("FLITERAL colon", ": tf 2.5 ; tf 2.5 FSWAP F- F0= .", "-1")
    ansTest("scientific literal", "1E2 100e0 FSWAP F- F0= .", "-1")
    ansTest(".FS", "1.5 2.5 .FS FDEPTH .", "2")
    print("=== TZForth Float Tier A (ANS 12.3.2 ENVIRONMENT?) ===")
    ansTest("ENVIRONMENT? FLOATING", "S\" FLOATING\" ENVIRONMENT? .", "-1")
    ansTest("ENVIRONMENT? FLOATING-STACK", "S\" FLOATING-STACK\" ENVIRONMENT? DROP .", "16")

    print("=== TZForth Float Tier B (ANS 12.6.2 Float Ext) ===")
    ansTest("0e literal", "0e 0e FSWAP F- F0= .", "-1")
    ansTest("F>D", "1e0 F>D 1. D= .", "-1")
    ansTest("FVARIABLE", "FVARIABLE TFV 2e0 TFV F! TFV F@ 2e0 FSWAP F- F0= .", "-1")
    ansTest("FVALUE TO", "3e0 FVALUE TFVAL TFVAL 4e0 TO TFVAL TFVAL 4e0 FSWAP F- F0= .", "-1")
    ansTest("F~ exact", "1e0 FDUP 0e F~ .", "-1")
    ansTest("F~ +0 -0", "0e 0e fnegate 0e f~ .", "0")
    ansTest("F~ abs tol", "0e 0e 7e f~ .", "-1")
    ansTest("F>", "2e0 1e0 F> .", "-1")
    ansTest("F> signed zero", "0e 0e fnegate f> .", "0")
    ansTest("F= signed zero", "0e 0e fnegate f= .", "-1")
    ansTest("F<> signed zero", "0e 0e fnegate f<> .", "0")
    ansTest("F<> paranoia Z", "0e fnegate 0e f<> .", "0")
    ansTest("BEGIN WHILE dot IF", ": t5w 0 begin 1+ dup 13 > invert while repeat .\" k\" dup . .\" .\" cr 14 = ; t5w .", "-1")
    ansTest("FABS", "-2e0 FABS 2e0 FSWAP F- F0= .", "-1")
    ansTest("FROT", "1e0 2e0 3e0 FROT 1e0 FSWAP F- F0= .", "-1")
    ansTest("FSIN zero", "0e FSIN 0e FSWAP F- F0= .", "-1")
    ansTest("FATAN2", "0e 1e0 FATAN2 0e FSWAP F- F0= .", "-1")
    ansTest("FATAN2 y0 xneg", "0e -1e FATAN2 3.141592653589793e0 FSWAP F- F0= .", "-1")
    ansTest("FATAN2 signed zero", "0e fnegate 1e FATAN2 0e fnegate 0e F~ .", "-1")
    ansTest("ttester BASE restore", "BASE @ S\" FLOATING-STACK\" ENVIRONMENT? [IF] [IF] [THEN] [THEN] BASE ! BASE @ .", "10")
    ansTest("SF@ SF!", "PAD -2e0 SF! PAD SF@ -2e0 FSWAP F- F0= .", "-1")
    ansTest("FSQRT", "4e0 FSQRT 2e0 FSWAP F- F0= .", "-1")
    ansTest("ENVIRONMENT? FLOAT-EXT", "S\" FLOAT-EXT\" ENVIRONMENT? .", "-1")

    print("=== TZForth Float Tier C (REPRESENT / FS. / FE. / F.) ===")
    ansTest("REPRESENT 1E k", "CREATE FBUF 20 ALLOT 1E FBUF 5 REPRESENT DROP DROP .", "1")
    ansTest("REPRESENT 1E flag", "1E FBUF 5 REPRESENT DROP . .", "0")
    ansTest("REPRESENT -1E flag", "-1E FBUF 5 REPRESENT DROP . .", "-1")
    ansTest("REPRESENT 100/3 k", "100E 3E F/ FBUF 5 REPRESENT DROP DROP .", "2")
    ansTest("REPRESENT 0.02/3 k", "0.02E 3E F/ FBUF 5 REPRESENT DROP DROP .", "-2")
    ansTest("FS. 20E", "5 SET-PRECISION 20E FS.", "2.0000E1")
    ansTest("FS. 0.02E", "5 SET-PRECISION 0.02E FS.", "2.0000E-2")
    ansTest("FE. 20E", "5 SET-PRECISION 20E FE.", "20.000E0")
    ansTest("FE. 4000E", "5 SET-PRECISION 4000E FE.", "4.0000E3")
    ansTest("F. 1E3", "5 SET-PRECISION 1E3 F.", "1000.")
    ansTest("F. 1/3", "5 SET-PRECISION 1E 3E F/ F.", "0.33333")
    ansTest("F. 200/3", "5 SET-PRECISION 200E 3E F/ F.", "66.667")
    ansTest("F. 0.000234E", "5 SET-PRECISION 0.000234E F.", "0.00023 ")
    ansTest("F. 0.000236E", "5 SET-PRECISION 0.000236E F.", "0.00024 ")

    print("=== TZForth Programming-Tools assembler (CODE ;CODE RET noop) ===")
    ansTest("CODE noop", "CODE tnoop ;CODE 1 tnoop .", "1")
    ansTest("CODE RET", "CODE tnoop2 RET ;CODE 2 tnoop2 .", "2")
    ansTest("SEE CODE", "CODE TSEECODE RET ;CODE SEE TSEECODE", "CODE TSEECODE RET ;CODE")

    print("=== TZForth Block subsystem (ANS Block + TZ ext .blk words; TZ ext = non-ANS) ===")
    ansTest("TZ ext CREATE-BLOCK-FILE", "S\" \(blkVol)\" 8 CREATE-BLOCK-FILE SWAP . .", "0")
    ansTest("TZ ext OPEN-BLOCK-FILE", "S\" \(blkVol)\" OPEN-BLOCK-FILE . .", "0")
    ansTest("TZ ext USE-BLOCK-FILE", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP DUP USE-BLOCK-FILE BLOCK-FILE @ = .", "-1")
    ansTest("TZ ext GROW-BLOCK-FILE", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP DUP 4 GROW-BLOCK-FILE .", "0")
    ansTest("TZ ext .BLOCK-FILES", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP .BLOCK-FILES", "open")
    ansTest("TZ ext CLOSE-BLOCK-FILE", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP DUP CLOSE-BLOCK-FILE . BLOCK-FILE @ .", "0 0")
    ansTest("TZ ext BLOCK-FILE", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP USE-BLOCK-FILE BLOCK-FILE @ 99 > .", "-1")
    ansTest("TZ ext .SETTINGS", ".SETTINGS", "BLOCK-SIZE")
    ansTest("TZ ext SAVE-SETTINGS", "SAVE-SETTINGS", "Settings saved")
    ansTest("Block BUFFER", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP USE-BLOCK-FILE 0 BLOCK 0 BUFFER = .", "-1")
    ansTestBlockOp("Block UPDATE", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP USE-BLOCK-FILE 0 BLOCK DROP UPDATE")
    ansTestBlockOp("Block SAVE-BUFFERS", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP USE-BLOCK-FILE 0 BLOCK DROP UPDATE SAVE-BUFFERS")
    ansTestBlockOp("Block FLUSH", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP USE-BLOCK-FILE FLUSH")
    ansTestBlockOp("Block EMPTY-BUFFERS", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP USE-BLOCK-FILE 0 BLOCK DROP UPDATE EMPTY-BUFFERS")
    ansTest("Block LIST/SCR", "S\" \(blkVol)\" OPEN-BLOCK-FILE DROP USE-BLOCK-FILE 0 LIST SCR @ .", "0")
    ansTest("Block LOAD", "S\" \(blkLoad)\" OPEN-BLOCK-FILE DROP USE-BLOCK-FILE 0 LOAD", "42")
    ansTest("Block THRU", "S\" \(blkLoad)\" OPEN-BLOCK-FILE DROP USE-BLOCK-FILE 0 0 THRU", "42")
    ansTest("Block BLK", "S\" \(blkLoad)\" OPEN-BLOCK-FILE DROP USE-BLOCK-FILE 0 LOAD BLK @ .", "0")

    print("TEST6 ANS core summary: \(ansPassed)/\(ansTotal) passed")
    if ansPassed != ansTotal {
        print("WARNING: some ANS 2012 core tests failed — review against standard stack effects.")
    }

    // cleanup
    try? fm.removeItem(at: fblock)
    try? fm.removeItem(at: fstop)
    try? fm.removeItem(at: fline)
    try? fm.removeItem(at: finc)
    try? fm.removeItem(at: freq1)
    try? fm.removeItem(at: freq2)
    try? fm.removeItem(at: freq3)
    try? fm.removeItem(at: freq4)
    try? fm.removeItem(at: fbad)
    try? fm.removeItem(at: fwr)
    try? fm.removeItem(atPath: frenamedPath)
    try? fm.removeItem(at: tmp.appendingPathComponent("\(blkVol).blk"))
    try? fm.removeItem(at: URL(fileURLWithPath: blkLoadPath))

    print("=== FTEST complete ===")
    forth.shutdownBlockSubsystem()
    exit(0)
}

// MARK: - Hayes forth2012-test-suite (run with: HAYES=1 swift ... TestTZForth.swift)
if ProcessInfo.processInfo.environment["HAYES"] == "1" {
    let fm = FileManager.default
    // Run from the TZForth repo root (where Tests/forth2012-test-suite lives).
    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let suiteSrc = repoRoot.appendingPathComponent("Tests/forth2012-test-suite/src")
    let runFile = suiteSrc.appendingPathComponent("runtests-tzforth.fth")
    let outFile = suiteSrc.appendingPathComponent("HAYES-RESULTS.txt")

    guard fm.fileExists(atPath: runFile.path) else {
        print("ERROR: Hayes suite not found at \(suiteSrc.path)")
        print("Clone: git clone https://github.com/gerryjackson/forth2012-test-suite.git Tests/forth2012-test-suite")
        exit(1)
    }

    print("=== Running Hayes forth2012-test-suite (TZForth subset) ===")
    print("Suite: \(suiteSrc.path)\n")

    var collected = ""
    forth.onOutput = { text in
        collected += text
        print(text, terminator: "")
    }
    _ = fm.changeCurrentDirectoryPath(suiteSrc.path)
    forth.logicalCurrentDirectory = suiteSrc.path

    // Quick >IN +! sanity check (Hayes prelimtest pass #2 pattern)
    forth.feedLine("( sanity ) 1 >IN +! xSOURCE TYPE CR")
    if collected.contains("? xSOURCE") || !collected.contains("SOURCE") {
        print("\nERROR: >IN +! skip still broken (expected SOURCE, not ? xSOURCE)")
        exit(1)
    }
    collected = ""
    forth.resetRuntimeState()

    forth.feedLine("CR .( Running ANS Forth tests for TZForth ) CR")

    // Match the console test.fth workflow: bootstrap, VERBOSE on, per-file fload + #ERRORS reset.
    let bootstrap = suiteSrc.appendingPathComponent("debug-bootstrap.fth")
    // Same order as Tests/forth2012-test-suite/src/test.fth (coreplus first; toolstest again at end).
    let hayesFiles = [
        "coreplustest.fth",
        "coreexttest.fth", "doubletest.fth", "exceptiontest.fth", "filetest.fth",
        "facilitytest.fth",
        "localstest.fth", "memorytest.fth", "toolstest.fth",
        "searchordertest.fth", "stringtest.fth",
        "blocktest.fth",
        "toolstest.fth",
    ]
    var ok = true
    guard fm.fileExists(atPath: bootstrap.path) else {
        print("ERROR: missing Hayes bootstrap \(bootstrap.path)")
        exit(1)
    }
    if !forth.loadFile(bootstrap) {
        ok = false
    }
    if ok {
        forth.feedLine("TRUE VERBOSE !")
    }
    for name in hayesFiles where ok {
        let url = suiteSrc.appendingPathComponent(name)
        guard fm.fileExists(atPath: url.path) else {
            print("ERROR: missing Hayes file \(name)")
            ok = false
            break
        }
        forth.feedLine("0 #ERRORS !")
        if !forth.loadFile(url) {
            ok = false
            break
        }
    }
    if ok {
        forth.feedLine("REPORT-ERRORS")
    }
    do {
        try collected.write(to: outFile, atomically: true, encoding: .utf8)
        print("\nResults written to \(outFile.path)")
    } catch {
        print("\nWARNING: could not write HAYES-RESULTS.txt: \(error.localizedDescription)")
    }

    let lines = collected.components(separatedBy: "\n")
    let testErrors = lines.filter {
        $0.contains("INCORRECT RESULT") || $0.contains("WRONG NUMBER OF RESULTS")
    }
    let aborts = lines.filter {
        $0.contains("aborted after error") || $0.hasPrefix("? ") && !$0.contains("INCORRECT") && !$0.contains("WRONG NUMBER")
    }

    print("\n=== Hayes summary ===")
    print("Load completed: \(ok)")
    print("T{ failures: \(testErrors.count)")
    if !testErrors.isEmpty {
        print("--- first failures ---")
        for e in testErrors.prefix(15) { print(e) }
        if testErrors.count > 15 { print("... and \(testErrors.count - 15) more") }
    }
    if !aborts.isEmpty {
        print("Aborts / undefined (\(aborts.count)):")
        for a in aborts.prefix(10) { print(a) }
    }

    if let reportStart = lines.firstIndex(where: { $0.contains("Error Report") }) {
        print("\n--- REPORT-ERRORS ---")
        for line in lines[reportStart..<min(reportStart + 20, lines.count)] {
            if !line.trimmingCharacters(in: .whitespaces).isEmpty { print(line) }
        }
    } else {
        print("\nWARNING: REPORT-ERRORS summary not found in output")
    }

    print("\n=== HAYES complete ===")
    forth.shutdownBlockSubsystem()
    exit(testErrors.isEmpty && ok ? 0 : 1)
}

// Simple REPL
while let line = readLine() {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if trimmed.lowercased() == "bye" {
        forth.shutdownBlockSubsystem()
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
    // Named FLOAD loads synchronously inside the FLOAD word (onPerformNamedLoad / loadFileContents).

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
