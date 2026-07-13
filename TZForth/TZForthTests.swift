//
//  TZForthTests.swift
//
//  Split-out test harness code (the ANS-VALIDATE runner) from TZForth.swift
//  to keep the main engine source smaller (~400 lines of test logic moved).
//  Stored property lets for the test sources stay in TZForth.swift (Swift rule:
//  extensions cannot declare stored properties).
//
//  This file compiles into the app target (auto via synchronized group; only
//  TestTZForth.swift is membership-excepted for its top-level code).
//
//  The "ANS-VALIDATE" word registration (in TZForth.swift) calls into here.
//  Test sources + FTEST harness logic originated in TestTZForth.swift (lbForth model).
//

import Foundation

extension TZForth {
    // The runANSValidation (and its nested helpers) implement the full port of
    // the FTEST ANS spot-checks so that "ANS-VALIDATE" works from
    // within Forth (writes ANS-VALIDATE.txt next to TestTZForth.swift when CHDIRed there).
    public func runANSValidation() -> String {
        // Snapshot the "current" dir at start (the folder of the test .swift as user set via CHDIR or launch).
        // Internal tests may temporarily change logicalCurrentDirectory for fload sims; we use the
        // snapshot for the output file location so it always lands "in the same folder where the
        // current test .swift file is located".
        let originalLogical = self.logicalCurrentDirectory
        let originalCwd = FileManager.default.currentDirectoryPath

        // Snapshot dict state before running any tests. The tests (esp. the ansTest loop) define
        // many temporary words (t6mem, t6if, t6until, ...). We restore LATEST + HERE at the end
        // so the user's dictionary is left exactly as it was before the ANS-VALIDATE command ran
        // (no pollution / "corruption").
        let preValidationLatest = self.readCell(self.LATEST)
        let preValidationHere = self.readCell(self.DP_ADDR)
        let preValidationCurrent = self.readCell(self.CURRENT)
        let preValidationSearchOrder = self.searchOrder
        let preValidationDictBytes = self.captureValidationDictionaryBytes(upTo: preValidationHere)
        let preValidationEnvironment = self.captureSessionEnvironment()
        let preValidationSettings = self.settings

        var results = "=== ANS-VALIDATE: 2012 ANS Forth validation (Core, Core Ext, File-Access, String, Facility, Exception, Memory, Double, Locals, Programming-Tools, Block subsystem; from TestTZForth FTEST) ===\n\n"
        var collected = ""

        let originalOnOutput = self.onOutput
        let originalOnPerformNamedLoad = self.onPerformNamedLoad
        let originalOnMsDelayRequested = self.onMsDelayRequested
        self.onOutput = { text in
            collected += text
        }
        // ANS-VALIDATE feeds lines synchronously (ansTest checks output immediately after
        // feedLine). ConsoleView's async onMsDelayRequested would leave MS suspended with
        // no trailing " OK" yet — use the engine's Thread.sleep fallback instead.
        self.onMsDelayRequested = nil

        self.onPerformNamedLoad = { url in
            self.loadFile(url)
        }

        func resetTest() {
            self.resetRuntimeState()
            collected = ""
        }

        let fm = FileManager.default
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        let suffix = UUID().uuidString.prefix(8)
        let fblock = tmp.appendingPathComponent("ansval_block_\(suffix).fth")
        let fstop = tmp.appendingPathComponent("ansval_stop_\(suffix).fth")
        let fecho = tmp.appendingPathComponent("ansval_echo_\(suffix).fth")
        let fdebug = tmp.appendingPathComponent("ansval_debug_\(suffix).fth")
        let fdotq = tmp.appendingPathComponent("ansval_dotq_\(suffix).fth")
        let fline = tmp.appendingPathComponent("ansval_line_\(suffix).txt")
        let finc = tmp.appendingPathComponent("ansval_inc_\(suffix).fth")
        let fwr = tmp.appendingPathComponent("ansval_wr_\(suffix).txt")
        let freq1 = tmp.appendingPathComponent("ansval_req1_\(suffix).fth")
        let freq2 = tmp.appendingPathComponent("ansval_req2_\(suffix).fth")
        let freq3 = tmp.appendingPathComponent("ansval_req3_\(suffix).fth")
        let freq4 = tmp.appendingPathComponent("ansval_req4_\(suffix).fth")
        let fbad = tmp.appendingPathComponent("ansval_loadbad_\(suffix).fth")

        do {
            try self.testBlockSrc.write(to: fblock, atomically: true, encoding: String.Encoding.utf8)
            try self.testStopSrc.write(to: fstop, atomically: true, encoding: String.Encoding.utf8)
            try self.testEchoSrc.write(to: fecho, atomically: true, encoding: String.Encoding.utf8)
            try self.testDebugSrc.write(to: fdebug, atomically: true, encoding: String.Encoding.utf8)
            try self.testDotqSrc.write(to: fdotq, atomically: true, encoding: String.Encoding.utf8)
            try "alpha\nbeta\n".write(to: fline, atomically: true, encoding: String.Encoding.utf8)
            try ": fincw 42 ;\n".write(to: finc, atomically: true, encoding: String.Encoding.utf8)
            try "1+\n".write(to: freq1, atomically: true, encoding: String.Encoding.utf8)
            try "1+\n".write(to: freq2, atomically: true, encoding: String.Encoding.utf8)
            try "1+\n".write(to: freq3, atomically: true, encoding: String.Encoding.utf8)
            try "\n".write(to: freq4, atomically: true, encoding: String.Encoding.utf8)
            try "nosuch-tzforth-loaderr-xyz\n999 .\n".write(to: fbad, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            results += "TEST write fail: \(error)\n"
            self.onOutput = originalOnOutput
            self.onPerformNamedLoad = originalOnPerformNamedLoad
            self.onMsDelayRequested = originalOnMsDelayRequested
            return results
        }

        // === Test 1: block comments during FLOAD ===
        resetTest()
        self.loadFile(fblock)
        let hasLoad1 = self.debugFind("LOAD1")
        let hasNo1 = self.debugFind("NOSKIP1")
        let hasAfter1 = self.debugFind("AFTER1")
        let hasLoad2 = self.debugFind("LOAD2")
        results += "TEST1 block: load1=\(hasLoad1) noskip1=\(hasNo1) after1=\(hasAfter1) load2=\(hasLoad2)\n"

        resetTest()
        self.feedLine("load1 .")
        let saw11 = collected.contains("11")
        results += "TEST1 exec load1: saw11=\(saw11) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        resetTest()
        self.feedLine("after1 .")
        let saw33 = collected.contains("33")
        results += "TEST1 exec after1: saw33=\(saw33) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        // === Test 2: \S stops load ===
        resetTest()
        self.loadFile(fstop)
        let hasPre = self.debugFind("PRE")
        let hasPost = self.debugFind("POST")
        let hasPre2 = self.debugFind("PRE2")
        let hasIgn = self.debugFind("IGNORED")
        let hasPost2 = self.debugFind("POST2")
        results += "TEST2 stop: pre=\(hasPre) pre2=\(hasPre2) ign=\(hasIgn) post2=\(hasPost2) post=\(hasPost)\n"

        // === Test 2b: FILE-ECHO + \S ===
        resetTest()
        let savedLog2b = self.logicalCurrentDirectory
        let savedCwd2b = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        self.feedLine("fload \(fecho.lastPathComponent)")
        // restore immediately so subsequent tests don't run with cwd at /tmp
        self.logicalCurrentDirectory = savedLog2b
        _ = fm.changeCurrentDirectoryPath(savedCwd2b)
        let hasEchoPre = self.debugFind("ECHOPRE")
        let hasEchoPost = self.debugFind("ECHOPOST")
        results += "TEST2b echo+slash: echopre=\(hasEchoPre) echopost=\(hasEchoPost)\n"
        let sawEchoSrc = collected.contains("FILE-ECHO ON") || collected.contains("echopre")
        let sawPostSrc = collected.contains("echopost")
        results += "TEST2b echo output: saw pre-src=\(sawEchoSrc) saw post-src=\(sawPostSrc)\n"

        resetTest()
        self.feedLine("123 constant postslashok")
        let hasPostSlash = self.debugFind("POSTSLASHOK")
        results += "TEST2b post-slash repl: postslashok=\(hasPostSlash)\n"
        collected = ""
        self.feedLine("postslashok .")
        let saw123 = collected.contains("123")
        results += "TEST2b post-slash exec: saw123=\(saw123) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        // === Test 2b-include: FILE-ECHO + \S via INCLUDE (same interpret path as FLOAD) ===
        resetTest()
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        self.feedLine("FILE-ECHO OFF")
        collected = ""
        self.feedLine("INCLUDE \(fecho.lastPathComponent)")
        self.logicalCurrentDirectory = savedLog2b
        _ = fm.changeCurrentDirectoryPath(savedCwd2b)
        let hasIncEchoPre = self.debugFind("ECHOPRE")
        let hasIncEchoPost = self.debugFind("ECHOPOST")
        let sawIncEchoSrc = collected.contains("FILE-ECHO ON") || collected.contains("echopre")
        results += "TEST2b-include: echopre=\(hasIncEchoPre) echopost=\(hasIncEchoPost) sawEcho=\(sawIncEchoSrc)\n"

        // === Test 2b-repl: \S from console stops remainder of a multi-line submit (paste) ===
        resetTest()
        self.clearReplBatchStop()
        let replBatch = [": prebatch 11 ;", "\\S", ": postbatch 22 ;"]
        for ln in replBatch {
            self.feedLine(ln)
            if self.replBatchStopRequested { break }
        }
        let hasPreBatch = self.debugFind("PREBATCH")
        let hasPostBatch = self.debugFind("POSTBATCH")
        results += "TEST2b-repl: prebatch=\(hasPreBatch) postbatch=\(hasPostBatch) (expect true false)\n"

        // === Test 2b-err: FLOAD stops at first line error (unless CATCH) ===
        resetTest()
        let ferr = tmp.appendingPathComponent("ansval_errstop_\(suffix).fth")
        do {
            try """
true verbose !
: shouldnot 99 ;
""".write(to: ferr, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            results += "TEST2b-err write fail: \(error)\n"
        }
        collected = ""
        self.loadFile(ferr)
        let hasErrStopBad = self.debugFind("SHOULDNOT")
        let hasLine1 = collected.contains("line 1")
        results += "TEST2b-err: shouldnot=\(hasErrStopBad) line1=\(hasLine1) (expect false true) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        resetTest()
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        self.feedLine(": safe-inc S\" \(ferr.lastPathComponent)\" ['] INCLUDED CATCH ;")
        collected = ""
        self.feedLine("safe-inc . .ERROR")
        let caughtFload = collected.contains("-13") || collected.contains("-70") || collected.contains("undefined word") || collected.contains("File I/O")
        results += "TEST2b-err-catch: caught=\(caughtFload) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        self.logicalCurrentDirectory = savedLog2b
        _ = fm.changeCurrentDirectoryPath(savedCwd2b)

        // === Test 2b-nested: \S in a nested FLOAD stops only that file; outer continues ===
        resetTest()
        let fnInnerSlash = tmp.appendingPathComponent("ansval_inner_slash_\(suffix).fth")
        let fnOuterSlash = tmp.appendingPathComponent("ansval_outer_slash_\(suffix).fth")
        let fnOuterStop = tmp.appendingPathComponent("ansval_outer_stop_\(suffix).fth")
        let fnInnerLate = tmp.appendingPathComponent("ansval_inner_late_\(suffix).fth")
        do {
            try """
: innerok 11 ;
\\S
: neverinner 22 ;
""".write(to: fnInnerSlash, atomically: true, encoding: String.Encoding.utf8)
            try """
: beforeouter 55 ;
fload \(fnInnerSlash.lastPathComponent)
: afterouter 77 ;
\\S
: neverouter 99 ;
""".write(to: fnOuterSlash, atomically: true, encoding: String.Encoding.utf8)
            try """
: innerskip 44 ;
""".write(to: fnInnerLate, atomically: true, encoding: String.Encoding.utf8)
            try """
\\S
fload \(fnInnerLate.lastPathComponent)
: neverouter2 88 ;
""".write(to: fnOuterStop, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            results += "TEST2b-nested write fail: \(error)\n"
        }
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        self.loadFile(fnOuterSlash)
        let hasBeforeOuter = self.debugFind("BEFOREOUTER")
        let hasInnerOk = self.debugFind("INNEROK")
        let hasNeverInner = self.debugFind("NEVERINNER")
        let hasAfterOuter = self.debugFind("AFTEROUTER")
        let hasNeverOuter = self.debugFind("NEVEROUTER")
        results += "TEST2b-nested: before=\(hasBeforeOuter) inner=\(hasInnerOk) neverinner=\(hasNeverInner) after=\(hasAfterOuter) neverouter=\(hasNeverOuter) (expect true true false true false)\n"
        self.resetToSafeState()
        collected = ""
        self.logicalCurrentDirectory = tmp.path
        self.loadFile(fnOuterStop)
        let hasInnerLate = self.debugFind("INNERSKIP")
        let hasNeverOuter2 = self.debugFind("NEVEROUTER2")
        results += "TEST2b-nested-outer: inner=\(hasInnerLate) neverouter2=\(hasNeverOuter2) (expect false false)\n"
        self.logicalCurrentDirectory = savedLog2b
        _ = fm.changeCurrentDirectoryPath(savedCwd2b)

        // === Test 2c: DEBUG-ON/OFF in file ===
        resetTest()
        self.feedLine("FILE-ECHO OFF")
        collected = ""
        let savedLog2c = self.logicalCurrentDirectory
        let savedCwd2c = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        self.feedLine("fload \(fdebug.lastPathComponent)")
        // restore immediately
        self.logicalCurrentDirectory = savedLog2c
        _ = fm.changeCurrentDirectoryPath(savedCwd2c)
        let hasDbg1 = self.debugFind("DBG1")
        let hasDbg2 = self.debugFind("DBG2")
        let hasDbg3 = self.debugFind("DBG3")
        results += "TEST2c debug: dbg1=\(hasDbg1) dbg2=\(hasDbg2) dbg3=\(hasDbg3)\n"
        let sawDbgOn = collected.contains("[DEBUG]")
        results += "TEST2c debug output: saw any [DEBUG]=\(sawDbgOn)\n"
        resetTest()
        collected = ""
        self.feedLine("1 2 + .")
        let sawDbgInRepl = collected.contains("[DEBUG]")
        results += "TEST2c post-debug repl: sawDbgInRepl=\(sawDbgInRepl) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        // === Test 2d: ."
        resetTest()
        let savedLog2d = self.logicalCurrentDirectory
        let savedCwd2d = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        self.feedLine("fload \(fdotq.lastPathComponent)")
        // restore immediately
        self.logicalCurrentDirectory = savedLog2d
        _ = fm.changeCurrentDirectoryPath(savedCwd2d)
        let hasHello = self.debugFind("HELLO")
        let hasAfterBad = self.debugFind("AFTERBAD")
        results += "TEST2d dotq: hello=\(hasHello) afterbad=\(hasAfterBad)\n"
        let sawHelloOut = collected.contains("Hello from dot quote")
        results += "TEST2d dotq output: saw hello text=\(sawHelloOut)\n"
        resetTest()
        collected = ""
        self.feedLine("42 .")
        let saw42 = collected.contains("42")
        let stillCompiling = collected.contains("state=compiling")
        results += "TEST2d post-err repl: saw42=\(saw42) stillCompiling=\(stillCompiling) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        // === Test 2e: WORD
        resetTest()
        collected = ""
        self.feedLine("32 WORD TEST COUNT TYPE")
        let sawTest = collected.contains("TEST")
        results += "TEST2e WORD: sawTest=\(sawTest) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        // === Test 2f: STATE
        resetTest()
        self.feedLine("DEBUG-ON")
        collected = ""
        self.feedLine(": state-test 123")
        let sawCompilingDuringDef = collected.contains("state=compiling")
        results += "TEST2f after open : line (no ;): sawCompilingDuringDef=\(sawCompilingDuringDef)\n"
        collected = ""
        self.feedLine(";")
        let sawInterpretingAfterClose = collected.contains("state=interpreting")
        results += "TEST2f after ; : sawInterpretingAfterClose=\(sawInterpretingAfterClose)\n"
        collected = ""
        self.feedLine("state-test .")
        let sawInterpretingExec = collected.contains("state=interpreting")
        results += "TEST2f after exec: sawInterpretingExec=\(sawInterpretingExec) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        resetTest()
        self.feedLine("DEBUG-ON")
        collected = ""
        self.feedLine(": state-test2 [ 42 ]")
        collected = ""
        self.feedLine(";")
        let sawFinalInterp = collected.contains("state=interpreting")
        let sawStuckCompile = collected.contains("state=compiling")
        results += "TEST2f after ; for [ test: sawFinalInterp=\(sawFinalInterp) sawStuckCompile=\(sawStuckCompile)\n"

        // === Test 3: console block
        resetTest()
        self.feedLine("\\\\ console block start")
        self.feedLine(": noskipc 123 ;")
        self.feedLine("42 constant noskipc2")
        self.feedLine(" { : afterc 456 ;  99 constant afterc2 ")
        let hasNoC = self.debugFind("NOSKIPC")
        let hasNoC2 = self.debugFind("NOSKIPC2")
        let hasAfterC = self.debugFind("AFTERC")
        let hasAfterC2 = self.debugFind("AFTERC2")
        results += "TEST3 console-block: noskipc=\(hasNoC) noskipc2=\(hasNoC2) afterc=\(hasAfterC) afterc2=\(hasAfterC2)\n"

        resetTest()
        self.feedLine("afterc .")
        let saw456 = collected.contains("456")
        results += "TEST3 exec afterc: saw456=\(saw456)\n"

        // === Test 4: console \S
        resetTest()
        self.feedLine("\\S : stillc 789 ;  7 constant stillc2")
        let hasStillC = self.debugFind("STILLC")
        let hasStillC2 = self.debugFind("STILLC2")
        results += "TEST4 console-s: stillc=\(hasStillC) stillc2=\(hasStillC2)\n"

        // === Test 5: nested
        resetTest()
        self.feedLine(": square dup * ;")
        self.feedLine(": cube dup square * ;")
        self.feedLine("3 square .")
        let saw9 = collected.contains("9")
        collected = ""
        self.feedLine("4 cube .")
        let saw64 = collected.contains("64")
        let stillNoOverflow = !collected.contains("overflow")
        results += "TEST5 nested: square9=\(saw9) cube64=\(saw64) no-overflow=\(stillNoOverflow)\n"

        collected = ""
        self.feedLine(": squar dup * ;")
        self.feedLine("3 squar .")
        let saw9b = collected.contains("9")
        results += "TEST5 post: squar9=\(saw9b)\n"

        // Test STATE addr
        resetTest()
        collected = ""
        self.feedLine("STATE")
        self.feedLine("DEBUG-ON")
        collected = ""
        self.feedLine("STATE 16 = .")
        let stateReturnsAddr = collected.contains(" -1") || collected.contains("-1")
        results += "TEST state-word: STATE 16 = => \(stateReturnsAddr)\n"
        collected = ""
        self.feedLine("STATE @ .")
        let stateFetch = collected.contains("0 ")
        results += "TEST STATE @: STATE @ . => \(stateFetch) out=\(collected.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        // === Expanded ANS 2012 Core + Core Ext spot checks (full port) ===
        // This is the rich TEST6 block from the original TestLBForth.swift FTEST harness (now in TestTZForth.swift).
        // ~60 individual tests exercising documented 2012 ANS stack effects + behaviors
        // for arithmetic, logic, compares, stacks, rstack, memory, consts, I/O, control,
        // dict words, etc. Each produces a "TEST6 foo: pass" or detailed FAIL line.
        // These (plus the earlier TEST1..5 + state tests) are accumulated into the log
        // written to ANS-VALIDATE.txt. We turn debug off first so the collected outputs
        // for the checks are clean (no [DEBUG] spam mixed into the .txt log).
        resetTest()
        self.feedLine("DEBUG-OFF")
        collected = ""
        results += "=== Starting expanded ANS 2012 Core word tests ===\n"
        self.feedLine("VARIABLE t6mem 256 ALLOT")   // safe cell + extra buffer space for memory tests (MOVE/FILL use offsets to avoid low system-var addrs)
        var ansPassed = 0
        var ansTotal = 0
        func ansTest(_ desc: String, _ line: String, _ expectedSubstring: String) {
            resetTest()
            self.feedLine(line)
            ansTotal += 1
            let out = collected.trimmingCharacters(in: .whitespacesAndNewlines)
            if out.contains(expectedSubstring) {
                ansPassed += 1
                results += "TEST6 \(desc): pass\n"
            } else {
                results += "TEST6 \(desc): FAIL got '\(out)' (expected contain '\(expectedSubstring)')\n"
            }
        }
        /// Block words with no output (UPDATE, FLUSH, …): pass when no error/throw text.
        func ansTestBlockOp(_ desc: String, _ line: String) {
            resetTest()
            self.feedLine(line)
            ansTotal += 1
            let out = collected
            if !out.contains("?") && !self.errorFlag && !self.throwActive {
                ansPassed += 1
                results += "TEST6 \(desc): pass\n"
            } else {
                results += "TEST6 \(desc): FAIL got '\(out.trimmingCharacters(in: .whitespacesAndNewlines))'\n"
            }
        }

        // Arithmetic (6.1.0120 + etc.)
        ansTest("+", "3 4 + .", "7")
        ansTest("-", "10 3 - .", "7")
        ansTest("*", "6 7 * .", "42")
        ansTest("/MOD", "10 3 /MOD . .", "3 1")  // quot rem (top=quot per impl+standard)
        ansTest("/", "10 3 / .", "3")
        ansTest("*/MOD", "10 3 4 */MOD . .", "7 2")
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

        // S"
        ansTest("S\"", "S\" HELLO\" TYPE", "HELLO")

        // Control structures (via temp definitions; some coverage in 2d/2f)
        ansTest("IF ELSE THEN", ": t6if 5 0= IF 99 ELSE 88 THEN ; t6if .", "88")
        ansTest("BEGIN UNTIL", ": t6until 0 BEGIN 1+ DUP 3 > UNTIL ; t6until .", "4")
        ansTest("DO LOOP I", ": t6do 0 3 0 DO I + LOOP ; t6do .", "3")  // 0+1+2
        ansTest("?DO +LOOP UNLOOP LEAVE", ": t6dop 0 5 0 ?DO 1+ LOOP ; t6dop .", "5")

        // Hayes GD8/GD9 +LOOP circular arithmetic (Forth-2012 core+)
        self.feedLine("VARIABLE BUMP")
        self.feedLine("0 INVERT CONSTANT MAX-UINT")
        self.feedLine("MAX-UINT 8 RSHIFT 1+ CONSTANT USTEP")
        self.feedLine("USTEP NEGATE CONSTANT -USTEP")
        self.feedLine("1 63 LSHIFT 1- CONSTANT MAX-INT")
        self.feedLine("1 63 LSHIFT NEGATE CONSTANT MIN-INT")
        self.feedLine("MAX-INT 7 RSHIFT 1+ CONSTANT STEP")
        self.feedLine("STEP NEGATE CONSTANT -STEP")
        self.feedLine(": GD8 BUMP ! DO 1+ BUMP @ +LOOP ;")
        ansTest("GD8 USTEP orbit", "0 MAX-UINT 0 USTEP GD8 .", "256")
        ansTest("GD8 -USTEP orbit", "0 0 MAX-UINT -USTEP GD8 .", "256")
        ansTest("GD8 STEP orbit", "0 MAX-INT MIN-INT STEP GD8 .", "256")
        ansTest("GD8 -STEP orbit", "0 MIN-INT MAX-INT -STEP GD8 .", "256")
        ansTest("J", ": t6j 0 2 0 DO 0 2 0 DO J + LOOP LOOP ; t6j .", "2")  // 0+0 +1+1 =2
        ansTest("RECURSE", ": t6rec 1- DUP 0= IF DROP 99 ELSE RECURSE THEN ; 5 t6rec .", "99")
        ansTest("EXECUTE", "3 4 ' + EXECUTE .", "7")

        // Dictionary / introspection
        ansTest(">HEADER >NFA ID.", "VARIABLE t6v ' t6v >NFA COUNT TYPE", "t6v")
        ansTest("ID.", "' t6v ID.", "t6v")
        ansTest("' CFA >HEADER", "' DUP >HEADER 0<> .", "-1")
        ansTest(">XID DUP", "' DUP >XID .", "8")
        ansTest("['] CFA", ": t6xt ['] DUP ; ' DUP t6xt = .", "-1")
        ansTest("HERE (value) DP", "HERE DP @ = .", "-1")
        ansTest("LATEST", "LATEST @ 0= 0= .", "-1")
        ansTest("DEPTH", "1 2 3 DEPTH .", "3")
        ansTest("[']", ": t6p ['] DUP ; ' DUP t6p = .", "-1")

        // Programming-Tools (ANS 15)
        ansTest("?", "42 t6mem ! t6mem ?", "42")
        ansTest("NAME>STRING", "' DUP >HEADER DUP NAME>STRING TYPE", "DUP")
        ansTest("NAME>INTERPRET", "' DUP >HEADER DUP NAME>INTERPRET ' DUP = .", "-1")
        ansTest("TRAVERSE-WORDLIST", "VARIABLE t6tr : t6tw DROP 1 t6tr ! ; 0 t6tr ! ' t6tw GET-CURRENT TRAVERSE-WORDLIST t6tr @ .", "1")
        ansTest("SYNONYM", "SYNONYM T6DUP DUP : t6syn 5 T6DUP 1+ ; t6syn .", "6")
        self.feedLine(": tloc 99 ;")
        ansTest("LOCATE", "LOCATE tloc", "LIT 99")
        ansTest("[DEFINED]", ": t6def [DEFINED] DUP DUP [THEN] ; 5 t6def . .", "5 5")
        ansTest("[UNDEFINED]", ": t6undef [UNDEFINED] NOPE 99 [THEN] ; t6undef .", "99")
        ansTest("N>R NR>", "10 20 2 N>R NR> . .", "20 10")
        ansTest("AHEAD", ": t6ah AHEAD 111 THEN 222 ; t6ah .", "222")
        ansTest("NAME>COMPILE xt", "' DUP >HEADER DUP NAME>COMPILE ' DUP >HEADER DUP NAME>INTERPRET = .", "0")

        // TYPE COUNT WORD (more coverage)
        ansTest("COUNT TYPE via WORD", "32 WORD HELLO COUNT TYPE", "HELLO")

        // New batch: >IN >NUMBER ABORT ABORT" ACCEPT ENVIRONMENT? EVALUATE FIND
        ansTest(">IN", ": t6in 0 >IN ! >IN @ ; t6in .", "0")
        ansTest(">NUMBER", "0 0 S\" 123\" >NUMBER 2DROP DROP .", "123")
        ansTest("EVALUATE", "S\" 3 4 +\" EVALUATE .", "7")
        ansTest("FIND", "32 WORD DUP FIND SWAP DROP 0= 0= .", "-1")
        ansTest("FIND not", "32 WORD NOPE FIND 0= .", "-1")
        ansTest("ACCEPT basic", "HERE 0 ACCEPT .", "0")
        ansTest("ABORT\" no", "0 ABORT\" oops\" 42 .", "42")

        // Core (QUIT SOURCE PARSE PAD POSTPONE [COMPILE] + SP!/RSP! helpers + improved ENV)
        ansTest("ARSHIFT", "-8 1 ARSHIFT .", "-4")
        ansTest("CLS (no crash)", "CLS 42 .", "42")
        ansTest("SPACES (no crash)", "2 SPACES 99 .", "99")
        ansTest("SOURCE", "SOURCE DROP 0= .", "0")  // addr non-zero, u may be 0 at test point
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
        ansTest("C\"", "C\" HELLO\" COUNT TYPE", "HELLO")
        ansTest("C\" compile", ": tcq C\" world\" COUNT TYPE ; tcq", "world")
        ansTest("C\" EVALUATE", ": tcqe C\" 42 .\" ; tcqe COUNT EVALUATE", "42")
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
        self.feedLine(": t17sl [ S\" hello\" SLITERAL ] ;")
        ansTest("SLITERAL", "t17sl TYPE", "hello")
        ansTest("ENVIRONMENT? STRING", "S\" STRING\" ENVIRONMENT? .", "-1")

        // Facility (10): BEGIN-STRUCTURE / +FIELD / FIELD: / CFIELD: (Hayes facilitytest subset)
        self.feedLine("BEGIN-STRUCTURE T6S1 END-STRUCTURE")
        ansTest("empty structure", "T6S1 .", "0")
        self.feedLine("BEGIN-STRUCTURE T6S2 1 CHARS +FIELD T6A 1 CELLS +FIELD T6B END-STRUCTURE")
        ansTest("structure size", "T6S2 .", "9")
        self.feedLine("CREATE T6I T6S2 ALLOT")
        ansTest("structure field C!", "77 T6I T6A C! T6I T6A C@ .", "77")
        self.feedLine("BEGIN-STRUCTURE T6S3 FIELD: T6X FIELD: T6Y END-STRUCTURE")
        ansTest("FIELD: offset", "0 T6Y .", "8")
        self.feedLine("BEGIN-STRUCTURE T6S4 T6S2 +FIELD T6N ALIGNED T6S3 +FIELD T6M END-STRUCTURE")
        ansTest("nested structure size", "T6S4 .", "32")
        ansTest("ENVIRONMENT? FACILITY", "S\" FACILITY\" ENVIRONMENT? .", "-1")

        // Facility terminal (10.6.1): PAGE / AT-XY with 80×25 buffer
        var termScreen = ""
        self.onTerminalRefresh = { termScreen = $0 }
        resetTest()
        termScreen = ""
        self.feedLine("PAGE")
        ansTest("PAGE (no crash)", "42 .", "42")
        ansTotal += 1
        if termScreen.split(separator: "\n", omittingEmptySubsequences: false).count == 25 {
            ansPassed += 1
            results += "TEST6 PAGE 80x25: pass\n"
        } else {
            results += "TEST6 PAGE 80x25: FAIL rows=\(termScreen.split(separator: "\n", omittingEmptySubsequences: false).count)\n"
        }
        resetTest()
        termScreen = ""
        self.feedLine("PAGE")
        self.feedLine("2 1 AT-XY 65 EMIT")
        ansTotal += 1
        let termLines = termScreen.split(separator: "\n", omittingEmptySubsequences: false)
        if termLines.count >= 2 {
            let row1 = String(termLines[1])
            let idx = row1.index(row1.startIndex, offsetBy: 2, limitedBy: row1.endIndex)
            if let idx, row1[idx] == "A" {
                ansPassed += 1
                results += "TEST6 AT-XY EMIT: pass\n"
            } else {
                results += "TEST6 AT-XY EMIT: FAIL row1='\(row1)'\n"
            }
        } else {
            results += "TEST6 AT-XY EMIT: FAIL short screen\n"
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
        self.enqueueExtendedKey(TZForth.makeCharKeyEvent(66, mods: 0))
        collected = ""
        self.feedLine("EKEY? .")
        ansTotal += 1
        if collected.contains("-1") {
            ansPassed += 1
            results += "TEST6 EKEY? queued: pass\n"
        } else {
            results += "TEST6 EKEY? queued: FAIL got '\(collected.trimmingCharacters(in: .whitespacesAndNewlines))'\n"
        }
        resetTest()
        self.feedLine("EKEY EKEY>CHAR DROP .")
        ansTotal += 1
        if self.waitingForExtendedKey {
            self.provideExtendedKey(TZForth.makeCharKeyEvent(65, mods: 0))
        }
        let ekeyOut = collected.trimmingCharacters(in: .whitespacesAndNewlines)
        if ekeyOut.contains("65") {
            ansPassed += 1
            results += "TEST6 EKEY char: pass\n"
        } else {
            results += "TEST6 EKEY char: FAIL got '\(ekeyOut)'\n"
        }
        ansTest("MS brief", "1 MS", "OK")

        // Memory-Allocation (14): GROWMEMORYMB first (once per session), then ALLOCATE FREE RESIZE
        let growMBTarget = max(5, self.memory.count / (1024 * 1024) + 4)
        ansTest("GROWMEMORYMB grow", "\(growMBTarget) GROWMEMORYMB UNUSED 3000000 > .", "-1")
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
                results += "TEST6 GROWMEMORYMB after ALLOCATE: pass\n"
            } else {
                results += "TEST6 GROWMEMORYMB after ALLOCATE: FAIL got '\(out.trimmingCharacters(in: .whitespacesAndNewlines))'\n"
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
                results += "TEST6 GROWMEMORYMB shrink: pass\n"
            } else {
                results += "TEST6 GROWMEMORYMB shrink: FAIL got '\(out.trimmingCharacters(in: .whitespacesAndNewlines))'\n"
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
        self.feedLine("VARIABLE t2a")
        ansTest("2! 2@", "1111 2222 t2a 2! t2a 2@ SWAP . .", "1111 2222")
        ansTest("S\\\" escapes", ": t6sq S\\\" \\a\\b\\e\" ; t6sq DROP C@ .", "7")
        ansTest("D>S", "1234. D>S .", "1234")
        self.feedLine("1000. 2CONSTANT t8big")
        ansTest("2CONSTANT", "t8big D.", "1000")
        self.feedLine("50. 2VALUE t8dv")
        self.feedLine(": t8put 200. ;")
        ansTest("2VALUE TO", "t8put TO t8dv t8dv D.", "200")
        ansTest("DU<", "1. 2. DU< .", "-1")
        ansTest("2ROT", "1. 2. 3. 2ROT 2DROP D.", "3")
        ansTest("ENVIRONMENT? DOUBLE", "S\" DOUBLE\" ENVIRONMENT? .", "-1")

        // Locals (13): LOCALS| {: TO
        self.feedLine(": t13a LOCALS| x | x ;")
        ansTest("LOCALS|", "10 t13a .", "10")
        self.feedLine(": t13b LOCALS| x | 5 TO x x ;")
        ansTest("LOCALS| TO", "0 t13b .", "5")
        self.feedLine(": t13c {: a b | c :} b . a . ;")
        ansTest("{: order", "3 4 t13c", "4 3")
        self.feedLine(": t13d LOCALS| r | 3 0 DO I r + TO r LOOP r ;")
        ansTest("LOCALS in DO", "1 t13d .", "4")
        ansTest("ENVIRONMENT? LOCALS", "S\" LOCALS\" ENVIRONMENT? .", "-1")
        ansTest("ENVIRONMENT? #LOCALS", "S\" #LOCALS\" ENVIRONMENT? DROP .", "32")

        // Core Ext Tier 2: :NONAME ACTION-OF MARKER SAVE-INPUT RESTORE-INPUT SOURCE-ID S" REFILL
        ansTest(":NONAME", "VARIABLE t7n1 :NONAME 1234 ; t7n1 ! t7n1 @ EXECUTE .", "1234")
        ansTest("ACTION-OF", "DEFER t7d : t7a1 42 ; ' t7a1 IS t7d ACTION-OF t7d EXECUTE .", "42")
        ansTest("MARKER", "MARKER t7m1 : t7w1 11 ; : t7w2 22 ; t7m1 t7w1 .", "? t7w1")
        ansTest("SOURCE-ID terminal", "SOURCE-ID .", "-1")
        ansTest("REFILL", "REFILL 0= .", "-1")
        ansTest("SAVE-INPUT RESTORE-INPUT", "SAVE-INPUT S\" 222 .\" EVALUATE RESTORE-INPUT . 333 .", "0 333")
        ansTest("RESTORE-INPUT fail", "SAVE-INPUT 2DROP 0 RESTORE-INPUT .", "-1")
        ansTest("SAVE-INPUT nested", "SAVE-INPUT S\" 11 .\" EVALUATE RESTORE-INPUT . 22 .", "0 22")
        ansTest("FILE-ECHO default", "FILE-ECHO @ .", "0")
        resetTest()
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        self.feedLine("FILE-ECHO OFF")
        collected = ""
        self.feedLine("INCLUDE \(fecho.lastPathComponent)")
        ansTotal += 1
        if collected.contains("FILE-ECHO ON") && self.debugFind("ECHOPRE") && !self.debugFind("ECHOPOST") {
            ansPassed += 1
            results += "TEST6 FILE-ECHO INCLUDE: pass\n"
        } else {
            results += "TEST6 FILE-ECHO INCLUDE: FAIL echo='\(collected.trimmingCharacters(in: .whitespacesAndNewlines))'\n"
        }
        ansTest("S\\\"", ": t7sq S\\\" hello\" TYPE ; t7sq", "hello")
        ansTest("S\\\" escapes", ": t7sq2 S\\\" a\\\\b\" TYPE ; t7sq2", "a\\b")

        // File-Access (ANS word set 11): read pre-seeded files, write via CREATE-FILE/WRITE-LINE, read back
        let flinePath = fline.path
        let fincPath = finc.path
        let fwrPath = fwr.path
        let frenamedPath = tmp.appendingPathComponent("ansval_renamed_\(suffix).txt").path
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
            self.feedLine("0 INCLUDED-NAMES !")
        }
        resetIncludedNames()
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        ansTest("REQUIRED once", "1 S\" \(freq1Base)\" REQUIRED REQUIRE \(freq1Base) .", "2")
        resetIncludedNames()
        ansTest("INCLUDED reload", "1 INCLUDE \(freq2Base) REQUIRE \(freq2Base) 1 S\" \(freq2Base)\" INCLUDED .", "2")
        resetTest()
        resetIncludedNames()
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        self.feedLine("1 fload \(freq3Base)")
        collected = ""
        self.feedLine("S\" \(freq3Base)\" REQUIRED .")
        ansTotal += 1
        if collected.trimmingCharacters(in: .whitespacesAndNewlines).contains("2") {
            ansPassed += 1
            results += "TEST6 REQUIRED FLOAD register: pass\n"
        } else {
            results += "TEST6 REQUIRED FLOAD register: FAIL got '\(collected.trimmingCharacters(in: .whitespacesAndNewlines))' (expected 2)\n"
        }
        resetIncludedNames()
        ansTest("INCLUDED-NAMES", "S\" \(freq4Base)\" REQUIRED INCLUDED-NAMES @ 0= .", "0")
        resetTest()
        resetIncludedNames()
        self.feedLine("S\" \(freq1Base)\" REQUIRED")
        collected = ""
        self.feedLine(".INCLUDED")
        ansTotal += 1
        if collected.contains(freq1Base) {
            ansPassed += 1
            results += "TEST6 .INCLUDED list: pass\n"
        } else {
            results += "TEST6 .INCLUDED list: FAIL got '\(collected.trimmingCharacters(in: .whitespacesAndNewlines))' (expected \(freq1Base))\n"
        }

        ansTest("ENVIRONMENT? FILE", "S\" FILE\" ENVIRONMENT? .", "-1")
        ansTest("CREATE-FILE", "S\" \(fwrPath)\" W/O CREATE-FILE 0= SWAP CLOSE-FILE DROP .", "-1")
        self.feedLine("VARIABLE t8hfid")
        ansTest("REPOSITION-FILE", "S\" \(flinePath)\" R/O OPEN-FILE DROP t8hfid ! 6 0 t8hfid @ REPOSITION-FILE DROP t8hfid @ PAD 1+ SWAP 80 SWAP READ-LINE DROP DROP PAD 1+ SWAP TYPE t8hfid @ CLOSE-FILE DROP", "beta")
        ansTest("WRITE-LINE", "S\" \(fwrPath)\" W/O CREATE-FILE DROP t8hfid ! S\" hi\" t8hfid @ WRITE-LINE DROP t8hfid @ CLOSE-FILE DROP 1 .", "1")
        ansTest("WRITE-LINE size", "S\" \(fwrPath)\" R/O OPEN-FILE DROP FILE-SIZE DROP DROP .", "3")
        ansTest("READ written file", "S\" \(fwrPath)\" R/O OPEN-FILE DROP PAD 1+ SWAP 80 SWAP READ-LINE DROP DROP PAD 1+ SWAP TYPE CLOSE-FILE DROP", "hi")
        ansTest("RESIZE-FILE", "S\" \(fwrPath)\" R/W OPEN-FILE DROP t8hfid ! 5 0 t8hfid @ RESIZE-FILE DROP t8hfid @ FILE-SIZE DROP DROP . t8hfid @ CLOSE-FILE DROP", "5")
        ansTest("FLUSH-FILE", "S\" \(fwrPath)\" R/W OPEN-FILE DROP DUP FLUSH-FILE 0= SWAP CLOSE-FILE DROP .", "-1")
        ansTest("RENAME-FILE", "S\" \(fwrPath)\" S\" \(frenamedPath)\" RENAME-FILE 0= .", "-1")
        ansTest("READ renamed file", "S\" \(frenamedPath)\" R/O OPEN-FILE DROP FILE-SIZE DROP DROP .", "5")

        // Exception word set (9): CATCH THROW; ABORT/ABORT" use THROW -1/-2
        self.feedLine(": t9a 9 ; : t9c1 1 2 3 ['] t9a CATCH ;")
        ansTest("CATCH normal", "t9c1 . . . . .", "0 9 3 2 1")
        self.feedLine(": t9t2 8 0 THROW ; : t9c2 1 2 ['] t9t2 CATCH ;")
        ansTest("THROW 0", "t9c2 . . . .", "0 8 2 1")
        self.feedLine(": t9t3 7 8 9 99 THROW ; : t9c3 1 2 ['] t9t3 CATCH ;")
        ansTest("THROW catch", "t9c3 . . .", "99 2 1")
        self.feedLine(": t9ab ABORT ; : t9abc 1 ['] t9ab CATCH ;")
        ansTest("ABORT CATCH", "t9abc . .", "-1 1")
        self.feedLine(": t9abq 1 ABORT\" oops\" ; : t9abcq 1 ['] t9abq CATCH ;")
        ansTest("ABORT\" CATCH", "t9abcq . .", "-2 1")
        self.feedLine("ABORT")
        ansTotal += 1
        let abortMsg = collected
        collected = ""
        self.feedLine("42 .")
        ansTotal += 1
        if abortMsg.contains("Aborted!") && collected.contains("42") {
            ansPassed += 2
            results += "TEST6 ABORT unhandled message: pass\n"
            results += "TEST6 ABORT recover REPL: pass\n"
        } else {
            if !abortMsg.contains("Aborted!") {
                results += "TEST6 ABORT unhandled message: FAIL got '\(abortMsg.trimmingCharacters(in: .whitespacesAndNewlines))' (expected Aborted!)\n"
            } else {
                ansPassed += 1
                results += "TEST6 ABORT unhandled message: pass\n"
            }
            if collected.contains("42") {
                ansPassed += 1
                results += "TEST6 ABORT recover REPL: pass\n"
            } else {
                results += "TEST6 ABORT recover REPL: FAIL got '\(collected.trimmingCharacters(in: .whitespacesAndNewlines))' (expected 42 on next line)\n"
            }
        }
        ansTest("ABORT\" unhandled", "1 ABORT\" oops\" 42 .", "oops")
        ansTest("ENVIRONMENT? EXCEPTION", "S\" EXCEPTION\" ENVIRONMENT? .", "-1")
        self.feedLine(": t9t5 2DROP 2DROP 9999 THROW ; : t9c5 1 2 3 4 ['] t9t5 CATCH DEPTH ;")
        ansTest("CATCH depth restore", "t9c5 .", "5")

        // Standard THROW codes (Phase 1): kernel faults are CATCH-able
        self.feedLine(": t9div ['] / CATCH ;")
        ansTest("CATCH div-by-zero", "1 0 t9div .", "-9")
        self.feedLine(": t9undef S\" no-such-word-tzforth-xyz\" ['] EVALUATE CATCH ;")
        ansTest("CATCH undefined word", "t9undef .", "-13")
        ansTest("CATCH EVALUATE tick", "S\" no-such-word-tzforth-xyz\" ' EVALUATE CATCH .", "-13")
        ansTest("CATCH-EVALUATE", "S\" no-such-word-tzforth-xyz\" CATCH-EVALUATE .", "-13")
        self.feedLine(": t9under ['] drop CATCH ;")
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
        self.feedLine("VARIABLE t9pst")
        self.feedLine(": t9pei ['] EVALUATE CATCH STATE @ t9pst ! ; IMMEDIATE")
        self.feedLine(": t9ppi t9pst @ . ; IMMEDIATE")
        self.feedLine(": t9pdef")
        collected = ""
        self.feedLine("S\" nosuch-tzforth-compile-xyz\" t9pei t9ppi")
        let compileStateOne = collected.contains("1")
        self.feedLine("789 ;")
        self.feedLine("t9pdef .")
        ansTotal += 1
        let cstOut = collected.trimmingCharacters(in: .whitespacesAndNewlines)
        if compileStateOne && cstOut.contains("789") {
            ansPassed += 1
            results += "TEST6 CATCH compile STATE preserve: pass\n"
        } else {
            results += "TEST6 CATCH compile STATE preserve: FAIL compileState=\(compileStateOne) out='\(cstOut)' (expected 1 during compile, 789 at run)\n"
        }

        // THROW Phase 4: file I/O and host FLOAD
        ansTest("CATCH FLOAD missing", "S\" fload nosuch-tzforth-missing.fth\" CATCH-EVALUATE .", "-74")
        self.feedLine(": t4if 999 ['] INCLUDE-FILE CATCH ;")
        ansTest("CATCH INCLUDE-FILE invalid", "t4if .", "-68")
        self.feedLine(": t4inc S\" nosuch-tzforth-missing.fth\" ['] INCLUDED CATCH ;")
        ansTest("CATCH INCLUDED missing", "t4inc .", "-74")

        // THROW Phase 5: -40 user, -67 closed file, catchable mid-file load abort
        ansTest("THROW user -40", ": t4u40 -40 throw ; : t4c40 ['] t4u40 catch ; t4c40 .", "-40")
        ansTest("CATCH THROW -70", ": t470 -70 throw ; : t4c70 ['] t470 catch ; t4c70 .", "-70")
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        ansTest("CATCH FLOAD mid-file", "S\" fload \(fbad.lastPathComponent)\" CATCH-EVALUATE .", "-13")
        self.feedLine("VARIABLE t4fid")
        self.feedLine(": t4closed s\" \(fincPath)\" r/o open-file drop t4fid ! t4fid @ close-file drop t4fid @ ['] include-file catch ;")
        ansTest("CATCH INCLUDE-FILE closed", "t4closed .", "-67")

        // THROW Phase 5b: nested CATCH, safe-fload, mid-include, .ERROR file codes
        self.feedLine(": t5in 99 throw ; : t5mid ['] t5in execute ; : t5out 1 2 ['] t5mid catch ;")
        ansTest("CATCH nested propagate", "t5out . . .", "99 2 1")
        self.feedLine(": t5in2 99 throw ; : t5mid2 ['] t5in2 catch drop ; : t5out2 1 ['] t5mid2 catch ;")
        ansTest("CATCH inner absorbs", "t5out2 . .", "0 1")
        self.feedLine("VARIABLE t5fid")
        self.feedLine(": t5inc s\" \(fbad.path)\" r/o open-file drop t5fid ! t5fid @ ['] include-file catch ;")
        ansTest("CATCH INCLUDE-FILE mid-file", "t5inc .", "-13")
        ansTest(".ERROR closed file", "-67 .ERROR", "? Operation on closed file")
        ansTest(".ERROR file I/O", "-70 .ERROR", "? File I/O exception")
        ansTest(".ERROR not found", "-74 .ERROR", "? File not found")

        // Block subsystem (ANS Block 10.6.1 + TZForth .blk extensions). "TZ ext" = non-ANS.
        let blkVol = "ansval_\(suffix)_vol"
        let blkLoad = "ansval_\(suffix)_load"
        let blkLoadPath = tmp.appendingPathComponent("\(blkLoad).blk").path
        do {
            let bs = self.effectiveBlockSize()
            var data = Data(repeating: 0, count: bs)
            let line = "42 ."
            for (i, b) in line.utf8.enumerated() where i < 64 {
                data[i] = b
            }
            try data.write(to: URL(fileURLWithPath: blkLoadPath))
        } catch {
            results += "TEST7 block LOAD file setup fail: \(error)\n"
        }
        results += "=== TZForth Block subsystem (ANS Block + TZ ext .blk words; TZ ext = non-ANS) ===\n"
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

        results += "TEST6 ANS core summary: \(ansPassed)/\(ansTotal) passed\n"
        if ansPassed != ansTotal {
            results += "WARNING: some ANS 2012 core tests failed — review against standard stack effects.\n"
        }

        // cleanup temps
        try? fm.removeItem(at: fblock)
        try? fm.removeItem(at: fstop)
        try? fm.removeItem(at: fecho)
        try? fm.removeItem(at: fdebug)
        try? fm.removeItem(at: fdotq)
        try? fm.removeItem(at: fline)
        try? fm.removeItem(at: finc)
        try? fm.removeItem(at: fwr)
        try? fm.removeItem(at: fbad)
        try? fm.removeItem(atPath: frenamedPath)
        try? fm.removeItem(at: tmp.appendingPathComponent("\(blkVol).blk"))
        try? fm.removeItem(at: URL(fileURLWithPath: blkLoadPath))
        self.shutdownBlockSubsystem()

        // Restore dict to exactly the state before this ANS-VALIDATE run. All the test-only
        // words defined during the ansTest feeds (t6mem, t6if, t6until, t6do, t6dop, etc.)
        // are forgotten and the dictionary pointer (HERE) is reclaimed. Also restore the
        // user dictionary bytes — validation can corrupt link fields below the saved HERE
        // (common after FLOAD TEST / Hayes), which breaks word lookup even when LATEST/HERE
        // pointers look correct.
        self.restoreValidationDictionaryBytes(preValidationDictBytes, upTo: preValidationHere)
        self.writeCell(self.LATEST, preValidationLatest)
        self.writeCell(self.DP_ADDR, preValidationHere)

        // Make sure runtime state (stacks, STATE, flags, etc.) is clean too.
        self.resetRuntimeState()

        // resetRuntimeState() resets searchOrder/CURRENT; restore the user's order.
        self.searchOrder = preValidationSearchOrder
        self.writeCell(self.CURRENT, preValidationCurrent)

        // Restore kernel variables and session flags (FILE-ECHO, BASE, GROWMEMORYMB, etc.).
        self.restoreSessionEnvironment(preValidationEnvironment)
        for warning in self.sessionEnvironmentRestoreWarnings(expected: preValidationEnvironment) {
            results += warning + "\n"
        }

        // Restore original dir state (logical + fm cwd).
        self.logicalCurrentDirectory = originalLogical
        _ = FileManager.default.changeCurrentDirectoryPath(originalCwd)

        // Re-fire onDirectoryChanged for the original directory. The internal fload simulations
        // above did direct logical/fm chdir to /tmp (bypassing the host's onDirectoryChanged hook
        // that does bookmarking + activateLastDirectoryScope). Firing it now ensures the host
        // re-activates the security-scoped bookmark for the user's real dir. This fixes the
        // "can't EDIT the ANS-VALIDATE.txt file" (or other files in the dir) after running
        // ANS-VALIDATE, because EDIT needs an active scope for NSWorkspace handoff + resolve.
        if let cb = self.onDirectoryChanged {
            cb(URL(fileURLWithPath: originalLogical))
        }

        do {
            try preValidationSettings.save()
            self.settings = preValidationSettings
        } catch {
            results += "WARNING: could not restore settings.json after validation: \(error.localizedDescription)\n"
        }

        self.onOutput = originalOnOutput
        self.onPerformNamedLoad = originalOnPerformNamedLoad
        self.onMsDelayRequested = originalOnMsDelayRequested

        results += "\n=== ANS-VALIDATE complete ===\n"
        return results
    }
}
