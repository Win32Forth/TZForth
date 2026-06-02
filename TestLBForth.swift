//
//  TestLBForth.swift
//
//  Standalone tester for the LBForth engine (Leif Bruder public-domain model).
//
//  How to run:
//
//      cd /path/to/TZForth
//      swift TZForth/LBForth.swift TestLBForth.swift
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
        forth.resetToSafeState()
        collected = ""
    }

    let fm = FileManager.default
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
    let suffix = UUID().uuidString.prefix(8)
    let fblock = tmp.appendingPathComponent("testblock_\(suffix).fth")
    let fstop = tmp.appendingPathComponent("teststop_\(suffix).fth")

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

    do {
        try blockSrc.write(to: fblock, atomically: true, encoding: .utf8)
        try stopSrc.write(to: fstop, atomically: true, encoding: .utf8)
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
        print(" [EDIT would open in editor + chdir to: \(u.deletingLastPathComponent().path) ]")
        // simulate the host side effect for cwd (so CHDIR etc follow in tester)
        _ = FileManager.default.changeCurrentDirectoryPath(u.deletingLastPathComponent().path)
        forth.pendingEditURL = nil
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