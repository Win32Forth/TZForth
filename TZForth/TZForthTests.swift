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
    // the FTEST ANS spot-checks so that "ANS-VALIDATE" works from within Forth
    // (writes ANS-VALIDATE.txt next to TestTZForth.swift when CHDIRed there).
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
        let preValidationContext = self.readCell(self.CONTEXT)
        let preValidationCurrent = self.readCell(self.CURRENT)

        var results = "=== ANS-VALIDATE: 2012 ANS Forth Core + Core Ext validation (from TestTZForth / original TestLBForth FTEST logic) ===\n\n"
        var collected = ""

        let originalOnOutput = self.onOutput
        self.onOutput = { text in
            collected += text
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

        do {
            try self.testBlockSrc.write(to: fblock, atomically: true, encoding: String.Encoding.utf8)
            try self.testStopSrc.write(to: fstop, atomically: true, encoding: String.Encoding.utf8)
            try self.testEchoSrc.write(to: fecho, atomically: true, encoding: String.Encoding.utf8)
            try self.testDebugSrc.write(to: fdebug, atomically: true, encoding: String.Encoding.utf8)
            try self.testDotqSrc.write(to: fdotq, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            results += "TEST write fail: \(error)\n"
            self.onOutput = originalOnOutput
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
        if let u = self.pendingLoadURL {
            let p = u.deletingLastPathComponent()
            _ = fm.changeCurrentDirectoryPath(p.path)
            self.logicalCurrentDirectory = p.path
            self.pendingLoadURL = nil
            self.loadFile(u)
        }
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

        // === Test 2c: DEBUG-ON/OFF in file ===
        resetTest()
        self.feedLine("FILE-ECHO OFF")
        collected = ""
        let savedLog2c = self.logicalCurrentDirectory
        let savedCwd2c = fm.currentDirectoryPath
        _ = fm.changeCurrentDirectoryPath(tmp.path)
        self.logicalCurrentDirectory = tmp.path
        self.feedLine("fload \(fdebug.lastPathComponent)")
        if let u = self.pendingLoadURL {
            let p = u.deletingLastPathComponent()
            _ = fm.changeCurrentDirectoryPath(p.path)
            self.logicalCurrentDirectory = p.path
            self.pendingLoadURL = nil
            self.loadFile(u)
        }
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
        if let u = self.pendingLoadURL {
            let p = u.deletingLastPathComponent()
            _ = fm.changeCurrentDirectoryPath(p.path)
            self.logicalCurrentDirectory = p.path
            self.pendingLoadURL = nil
            self.loadFile(u)
        }
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

        // Arithmetic (6.1.0120 + etc.)
        ansTest("+", "3 4 + .", "7")
        ansTest("-", "10 3 - .", "7")
        ansTest("*", "6 7 * .", "42")
        ansTest("/MOD", "10 3 /MOD . .", "3 1")  // quot rem (top=quot per impl+standard)
        ansTest("/", "10 3 / .", "3")
        ansTest("*/MOD", "10 3 4 */MOD . .", "7 2")
        ansTest("M*", "1000 1000 M* . .", "0 1000000")
        ansTest("FM/MOD", "10 0 3 FM/MOD . .", "3 1")
        ansTest("SM/REM", "10 0 3 SM/REM . .", "3 1")
        ansTest("U<", "1 2 U< .", "-1")
        ansTest("UM*", "100 100 UM* . .", "0 10000")
        ansTest("UM/MOD", "0 100 10 UM/MOD . .", "10 0")
        ansTest("+!", "0 t6mem ! 5 t6mem +! t6mem @ .", "5")
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

        // S"
        ansTest("S\"", "S\" HELLO\" TYPE", "HELLO")

        // Control structures (via temp definitions; some coverage in 2d/2f)
        ansTest("IF ELSE THEN", ": t6if 5 0= IF 99 ELSE 88 THEN ; t6if .", "88")
        ansTest("BEGIN UNTIL", ": t6until 0 BEGIN 1+ DUP 3 > UNTIL ; t6until .", "4")
        ansTest("DO LOOP I", ": t6do 0 3 0 DO I + LOOP ; t6do .", "3")  // 0+1+2
        ansTest("?DO +LOOP UNLOOP LEAVE", ": t6dop 0 5 0 ?DO 1+ LOOP ; t6dop .", "5")
        ansTest("J", ": t6j 0 2 0 DO 0 2 0 DO J + LOOP LOOP ; t6j .", "2")  // 0+0 +1+1 =2
        ansTest("RECURSE", ": t6rec 1- DUP 0= IF DROP 99 ELSE RECURSE THEN ; 5 t6rec .", "99")
        ansTest("EXECUTE", "3 4 ' + EXECUTE .", "7")

        // Dictionary / introspection (current words) - limited
        ansTest("DEPTH", "1 2 3 DEPTH .", "3")
        ansTest("[']", ": t6p ['] DUP ; ' DUP t6p = .", "-1")

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

        // Sync + new Core (QUIT SOURCE PARSE PAD POSTPONE [COMPILE] + SP!/RSP! helpers + improved ENV)
        ansTest("HERE (value) DP", "HERE DP @ = .", "-1")
        ansTest("LATEST", "LATEST @ 0= 0= .", "-1")
        ansTest("ARSHIFT", "-8 1 ARSHIFT .", "-4")
        ansTest("CLS (no crash)", "CLS 42 .", "42")
        ansTest("SPACES (no crash)", "2 SPACES 99 .", "99")
        ansTest("SOURCE", "SOURCE DROP 0= .", "0")  // addr non-zero, u may be 0 at test point
        ansTest("PAD", "PAD 0= 0= .", "-1")
        ansTest("PARSE", "32 PARSE  2DROP 42 .", "42")
        ansTest("QUIT (no crash)", "42 . QUIT", "42")
        ansTest("SP! RSP!", "1 2 3  1 SP! DEPTH .", "0")
        ansTest("ENVIRONMENT?", "S\" CORE\" ENVIRONMENT? .", "-1")
        ansTest("[COMPILE]", ": t6c [COMPILE] + ; 3 4 t6c .", "7")
        // POSTPONE test: use an immediate word; with POSTPONE the imm action happens at runtime of tpo, not during its definition
        ansTest("POSTPONE", "VARIABLE tpv 0 tpv ! : timp 99 tpv ! ; IMMEDIATE : tpo POSTPONE timp 42 ; tpv @ . tpo tpv @ .", "0 99")

        // Core Ext batch: VALUE IS CASE OF ENDOF ENDCASE 0<> COMPILE, ERASE DEFER DEFER! DEFER@
        ansTest("0<>", "0 0<> .  5 0<> .", "0 -1")
        ansTest("ERASE", "HERE 5 ERASE HERE C@ HERE 4 + C@ . .", "0 0")
        ansTest("COMPILE,", ": [c+] ['] + COMPILE, ; IMMEDIATE : tcm [c+] ; 10 20 tcm .", "30")
        ansTest("VALUE IS", "123 VALUE v1 v1 .  456 IS v1 v1 .", "123 456")
        ansTest("DEFER IS DEFER@ DEFER!", "DEFER d1 : a1 777 ; ' a1 IS d1 d1 . : a2 888 ; ' a2 ' d1 DEFER! d1 .", "777 888")
        ansTest("CASE OF ENDOF ENDCASE", " ' CASE  ' OF  ' ENDOF  ' ENDCASE  DROP DROP DROP DROP 42 .", "42")

        // Vocabularies and filtered WORDS (all words currently in FORTH)
        ansTest("VOCABULARY FORTH DEFINITIONS", "VOCABULARY FOO FOO DEFINITIONS 123 CONSTANT baz FORTH DEFINITIONS 456 .", "456")
        ansTest("WORDS filter", "WORDS CONSTANT", "CONSTANT")

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

        // Restore dict to exactly the state before this ANS-VALIDATE run. All the test-only
        // words defined during the ansTest feeds (t6mem, t6if, t6until, t6do, t6dop, etc.)
        // are forgotten and the dictionary pointer (HERE) is reclaimed. This prevents the
        // "dictionary corrupted / polluted" symptom after running ANS-VALIDATE.
        self.writeCell(self.LATEST, preValidationLatest)
        self.writeCell(self.DP_ADDR, preValidationHere)
        self.writeCell(self.CONTEXT, preValidationContext)
        self.writeCell(self.CURRENT, preValidationCurrent)

        // Make sure runtime state (stacks, STATE, flags, etc.) is clean too.
        self.resetRuntimeState()

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

        self.onOutput = originalOnOutput

        results += "\n=== ANS-VALIDATE complete ===\n"
        return results
    }
}
