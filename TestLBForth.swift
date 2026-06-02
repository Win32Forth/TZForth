//
//  TestLBForth.swift
//
//  Standalone tester for the LBForth engine (Leif Bruder public-domain model).
//
//  How to run:
//
//      cd /path/to/FPCForth
//      swift FPCForth/LBForth.swift TestLBForth.swift
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