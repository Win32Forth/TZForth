//
//  LBForth.swift
//  TZForth
//
//  A Swift port of the core ideas from Leif Bruder's lbForth (public domain).
//  https://gist.github.com/lbruder/10007431
//
//  Central insight we are preserving:
//  - Primitives are given very small integer IDs (0, 1, 2, ...).
//  - In the threaded code stored in colon definitions we store these small IDs
//    for primitives, and full addresses only when calling other colon words.
//  - The inner interpreter does:  if (value < MAX_BUILTIN_ID) dispatch via table
//                                 else treat value as a code address and thread.
//  - This gives extremely compact threaded code and a trivial implementation,
//    while feeling very much like a token-threaded system to the user.
//
//  We are starting minimal and correct, then growing the word set.
//  The goal is a working classic Forth console experience as quickly as possible.
//

import Foundation

public final class LBForth {

    // MARK: - Configuration

    private let MEM_SIZE = 256 * 1024   // generous for a modern machine
    private let STACK_SIZE = 256
    private let RSTACK_SIZE = 128
    private let MAX_BUILTIN_ID = 256    // plenty of room

    private let FLAG_IMMEDIATE: UInt8 = 0x80
    private let FLAG_HIDDEN: UInt8 = 0x40
    private let MASK_NAMELENGTH: UInt8 = 0x1F

    // MARK: - Cell model (64-bit Int on Apple Silicon)

    public typealias Cell = Int

    private let CELL_SIZE = 8

    // MARK: - Memory and state

    private var memory: [UInt8]

    // System variables live at the bottom of memory (classic layout)
    private var LATEST:  Int { 0 }
    private var HERE:    Int { 8 }
    private var STATE:   Int { 16 }
    private var BASE:    Int { 24 }
    private var SP:      Int { 32 }   // address for future "SP @" compatibility (the live pointer is in the Swift var below)
    private var RSP:     Int { 40 }

    private var stackBase: Int
    private var rstackBase: Int

    // The actual live stack depths. Stored in Swift instance variables (not in the flat memory buffer)
    // so they cannot be corrupted by bad user writes, wild branches, or buggy control-flow code.
    // This is the key robustness fix for the recurring "SP cell trashed → constant underflows" problem.
    private var dataStackPointer: Cell = 1
    private var returnStackPointer: Cell = 1

    // Current IP for the threaded interpreter
    private var ip: Int = 0
    private var commandAddress: Int = 0

    private var errorFlag = false
    private var exitReq = false

    // Debug output control (per-line state + stack dump after each feedLine)
    private var debugEnabled = false

    /// Set by CLS. The ConsoleView should observe this after feedLine and clear the display.
    public var clearScreenRequested = false

    /// The value of LATEST right after all kernel primitives have been registered.
    /// FORGET is not allowed to truncate past this point.
    private var kernelLatest: Cell = 0

    // Input
    private var inputQueue: [UInt8] = []
    private var wordBuffer = [UInt8](repeating: 0, count: 64)

    // Output
    public var onOutput: ((String) -> Void)?

    /// Set by the BYE word. The host app (ConsoleView) should observe this and terminate.
    public var quitRequested = false

    /// Optional callback fired when BYE is executed. Useful for the host to quit cleanly.
    public var onQuitRequested: (() -> Void)?

    /// True when a KEY primitive is blocked waiting for the next character from the host console.
    /// The ConsoleView uses this to route the next typed character to provideKey(_:) instead of
    /// normal line interpretation.
    public var waitingForKey = false

    /// Set by FLOAD when invoked with no filename argument. The host UI observes this flag
    /// (typically via onOutput or post-feed checks) and presents a file dialog. After the user
    /// picks a file (or cancels), the host calls loadFile(_:) or clears the flag.
    public var fileLoadRequested = false

    /// Optional callback invoked when FLOAD needs a filename dialog (for hosts other than the main app).
    public var onFileLoadRequested: (() -> Void)?

    /// Set by EDIT when invoked with no filename argument. The host UI observes this flag
    /// and presents a file dialog (similar to FLOAD). After pick, host opens the file in the
    /// system text editor (via NSWorkspace) and updates cwd to the file's folder.
    public var fileEditRequested = false

    /// Optional callback invoked when EDIT needs a filename dialog (for hosts other than the main app).
    public var onFileEditRequested: (() -> Void)?

    /// When EDIT <name> (named form) resolves a file, this URL is set by the engine.
    /// The host (after feedLine returns, in its post-processing) performs the NSWorkspace.open,
    /// chdir to parent, and persist of last dir. Cleared by host. This keeps UI/AppKit actions
    /// out of the engine while still supporting named EDIT like named FLOAD.
    public var pendingEditURL: URL? = nil

    // Support for \\ (block comment to '{', can span lines in console or during FLOAD)
    // and \S (stop loading current file; no-op from console).
    private var inSlashSlashComment = false
    private var sourceLoadStop = false
    private var loadNesting = 0

    // Primitive dispatch table: ID -> implementation
    private var primitives: [(() -> Void)?] = []

    // ID of critical words we need during bootstrap
    private var docolID: Cell = 0
    private var exitID: Cell = 0
    private var litID: Cell = 0

    // Address of the FILE-ECHO variable's data cell (populated at bootstrap).
    private var fileEchoAddr: Cell = 0

    // Low-level branch primitives (captured so high-level control words can compile them)
    private var branchID: Cell = 0
    private var zeroBranchID: Cell = 0

    // CREATE / DOES> support (ANS 2012)
    private var createRuntimeID: Cell = 0
    private var dodoesID: Cell = 0
    private var doesPatchID: Cell = 0

    // Used by (CREATE) and (DOES) runtimes so they can locate their data/does fields
    // relative to the code cell being executed, even for top-level execution.
    private var currentCodeAddr: Cell = 0

    // True when the current primitive dispatch came from innerThread (threaded sub-call).
    // Used by (DOES) to decide whether to manually run the does code (leaf case) or just redirect ip.
    private var dispatchedFromInnerThread: Bool = false

    // Compile-time stack for DO/LOOP control (dest + sentinel + leave/?DO placeholders).
    // Using dedicated stack avoids interleaving issues with IF/ELSE/THEN/WHILE markers on data stack.
    private var loopControlStack: [Cell] = []

    // IDs for words used to emit setup code for DO/LOOP etc at compile time (for clean threaded DO...LOOP)
    private var swapID: Cell = 0
    private var toR_ID: Cell = 0
    private var rFrom_ID: Cell = 0
    private var rAt_ID: Cell = 0
    private var dupID: Cell = 0
    private var dropID: Cell = 0
    private var onePlusID: Cell = 0
    private var lessThanID: Cell = 0
    private var equalsID: Cell = 0

    // Reverse map: primitive ID -> name (for SEE and debugging)
    private var primitiveNames: [Cell: String] = [:]

    // Documentation for built-in words (brought over from historical GrokForthApp
    // to support HELP <word>).  Name is uppercased.  Stack effect + short description.
    private static let primitiveHelpData: [(name: String, stack: String, desc: String)] = [
        // Arithmetic
        ("+",       "( n1 n2 -- n )",     "addition"),
        ("-",       "( n1 n2 -- n )",     "subtraction"),
        ("*",       "( n1 n2 -- n )",     "multiplication"),
        ("/MOD",    "( n1 n2 -- rem quot )", "remainder and quotient"),
        ("1+",      "( n -- n+1 )",       "increment"),
        ("1-",      "( n -- n-1 )",       "decrement"),
        ("ABS",     "( n -- u )",         "absolute value"),
        ("NEGATE",  "( n -- -n )",        "negate"),
        ("MIN",     "( n1 n2 -- min )",   "minimum"),
        ("MAX",     "( n1 n2 -- max )",   "maximum"),
        ("AND",     "( n1 n2 -- n )",     "bitwise and"),
        ("OR",      "( n1 n2 -- n )",     "bitwise or"),
        ("XOR",     "( n1 n2 -- n )",     "bitwise xor"),
        ("INVERT",  "( n -- ~n )",        "bitwise invert"),
        ("LSHIFT",  "( n bits -- n )",    "left shift"),
        ("RSHIFT",  "( n bits -- n )",    "right shift"),
        
        // Stack
        ("DUP",     "( n -- n n )",       "duplicate top"),
        ("DROP",    "( n -- )",           "discard top"),
        ("SWAP",    "( a b -- b a )",     "swap top two"),
        ("OVER",    "( a b -- a b a )",   "copy second"),
        ("ROT",     "( a b c -- b c a )", "rotate top three"),
        ("?DUP",    "( n -- n n | 0 )",   "dup if non-zero"),
        (">R",      "( n -- ) ( R: -- n )", "to return stack"),
        ("R>",      "( -- n ) ( R: n -- )", "from return stack"),
        ("R@",      "( -- n ) ( R: n -- n )", "copy top of return stack"),
        ("DEPTH",   "( -- n )",           "data stack depth"),
        
        // Memory
        ("@",       "( addr -- n )",      "fetch cell"),
        ("!",       "( n addr -- )",      "store cell"),
        ("C@",      "( addr -- byte )",   "fetch byte"),
        ("C!",      "( byte addr -- )",   "store byte"),
        ("HERE",    "( -- addr )",        "current dictionary pointer"),
        ("LATEST",  "( -- addr )",        "latest dictionary header"),
        ("STATE",   "( -- addr )",        "compilation state variable"),
        ("BASE",    "( -- addr )",        "current numeric base variable"),
        ("ALLOT",   "( n -- )",           "allocate n bytes in dictionary"),
        (",",       "( n -- )",           "compile a cell"),
        ("C,",      "( b -- )",           "compile a byte"),
        
        // Output / Input
        (".",       "( n -- )",           "print number (with space)"),
        (".S",      "( -- )",             "print data stack contents"),
        ("CR",      "( -- )",             "carriage return / newline"),
        ("SPACE",   "( -- )",             "print one space"),
        ("EMIT",    "( c -- )",           "print character by code"),
        ("KEY",     "( -- c )",           "wait for and return next key code"),
        ("KEY?",    "( -- flag )",        "true if a key is available now"),
        ("TYPE",    "( addr len -- )",    "print len characters from addr"),
        ("U.",      "( u -- )",           "print unsigned number"),
        
        // Comparisons
        ("=",       "( n1 n2 -- flag )",  "equal?"),
        ("<",       "( n1 n2 -- flag )",  "less than?"),
        (">",       "( n1 n2 -- flag )",  "greater than?"),
        ("0=",      "( n -- flag )",      "zero?"),
        ("0<",      "( n -- flag )",      "negative?"),
        
        // Dictionary & System
        ("WORDS",   "( -- )",             "list all words (kernel alpha, then user in order)"),
        ("SEE",     "( -- name )",        "decompile a word"),
        ("HELP",    "( -- ) name",        "show help for a word"),
        ("' ",      "( -- xt ) name",     "tick: get execution token of name"),
        ("FORGET",  "( -- ) name",        "forget name and all words defined after it"),
        ("FORGET-WORD", "( xt -- )",      "forget using xt ( ' NAME FORGET-WORD )"),
        (">HEADER", "( xt -- header )",   "convert xt to header address"),
        (">LFA",    "( xt -- lfa )",      "convert xt to link field (alias for >HEADER)"),
        ("VARIABLE","( -- ) name",        "create a variable"),
        ("CONSTANT","( n -- ) name",      "create a constant"),
        ("CREATE",  "( -- ) name",        "create a word that pushes its data field address (for use with DOES>)"),
        ("DOES>",   "( -- )",             "modify last CREATE'd word to execute the following code with data addr on stack (immediate)"),
        ("TRUE",    "( -- -1 )",          "true flag"),
        ("FALSE",   "( -- 0 )",           "false flag"),
        ("BL",      "( -- 32 )",          "blank character (space)"),
        ("DUMP",    "( addr u -- )",      "dump u cells starting at addr"),
        (".(",      "( -- )",             "print text until ) immediately (immediate)"),
        ("(",       "( -- )",             "comment until ) (immediate)"),
        ("DEBUG-ON","( -- )",             "enable per-line [DEBUG] state+stack output"),
        ("DEBUG-OFF","( -- )",            "disable per-line debug output"),
        ("RESET",   "( -- )",             "reset stacks, state, clear screen"),
        ("CLS",     "( -- )",             "clear the console screen"),
        
        // Base
        ("HEX",     "( -- )",             "set BASE to 16"),
        ("DECIMAL", "( -- )",             "set BASE to 10"),
        ("OCTAL",   "( -- )",             "set BASE to 8"),
        ("BINARY",  "( -- )",             "set BASE to 2"),
        
        // Control flow (many are immediate)
        (":",       "( -- ) name",        "start colon definition"),
        (";",       "( -- )",             "end colon definition (immediate)"),
        ("[",       "( -- )",             "enter interpret mode (immediate)"),
        ("]",       "( -- )",             "enter compile mode"),
        ("BEGIN",   "( -- )",             "start indefinite loop (immediate)"),
        ("AGAIN",   "( -- )",             "unconditional branch back (immediate)"),
        ("UNTIL",   "( flag -- )",        "loop until true (immediate)"),
        ("WHILE",   "( flag -- )",        "conditional exit from BEGIN (immediate)"),
        ("REPEAT",  "( -- )",             "branch back from WHILE (immediate)"),
        ("IF",      "( flag -- )",        "conditional (immediate)"),
        ("ELSE",    "( -- )",             "else part of IF (immediate)"),
        ("THEN",    "( -- )",             "end of IF/ELSE (immediate)"),
        ("0BRANCH", "( -- )",             "internal: branch if zero"),
        ("BRANCH",  "( -- )",             "internal: unconditional branch"),
        ("LIT",     "( -- n )",           "internal: literal value"),
        ("EXIT",    "( -- )",             "return from colon definition"),
        ("DO",      "( limit start -- )", "start counted loop"),
        ("LOOP",    "( -- )",             "end DO loop (add 1 to index, branch back if < limit)"),
        ("I",       "( -- n )",           "current DO loop index"),
        ("UNLOOP",  "( -- )",             "discard current DO loop params from rstack"),
        ("LEAVE",   "( -- )",             "exit current DO loop (branch to after LOOP)"),
        ("?DO",     "( limit start -- )", "start counted loop that skips if start==limit"),
        ("+LOOP",   "( n -- )",           "end DO loop with custom increment (delta from stack)"),
        
        // Comparisons & logic
        ("=",       "( n1 n2 -- flag )",  "equal"),
        ("<",       "( n1 n2 -- flag )",  "less than"),
        (">",       "( n1 n2 -- flag )",  "greater than"),
        ("0=",      "( n -- flag )",      "zero?"),
        ("0<",      "( n -- flag )",      "negative?"),
        ("0>",      "( n -- flag )",      "positive?"),
        
        // Misc
        ("CELL+",   "( addr -- addr' )",  "add size of one cell"),
        ("CELLS",   "( n -- n )",         "cells to address units"),
        ("CHAR+",   "( addr -- addr' )",  "add size of one char"),
        ("CHARS",   "( n -- n )",         "chars to address units"),
        ("WITHIN",  "( n lo hi -- flag )","true if n is within lo..hi"),
        ("PICK",    "( n -- n )",         "copy nth stack item (0-based from top)"),
        ("ROLL",    "( n -- )",           "roll nth item to top"),
        ("TUCK",    "( a b -- b a b )",   "tuck"),
        ("NIP",     "( a b -- b )",       "nip"),
        ("2@",      "( addr -- n1 n2 )",  "fetch two cells"),
        ("2!",      "( n1 n2 addr -- )",  "store two cells"),
        ("2>R",     "( n1 n2 -- ) (R: -- )", "two to return stack"),
        ("2R>",     "( -- n1 n2 ) (R: -- )", "two from return stack"),
        ("2R@",     "( -- n1 n2 ) (R: -- )", "copy two from return stack"),
        ("U.",      "( u -- )",           "print unsigned"),
        ("EMIT",    "( c -- )",           "emit character"),
        ("TYPE",    "( addr len -- )",    "type string"),
        ("ARSHIFT", "( n bits -- n )",    "arithmetic right shift"),
        ("LSHIFT",  "( n bits -- n )",    "logical left shift"),
        ("RSHIFT",  "( n bits -- n )",    "logical right shift"),
        ("INVERT",  "( n -- ~n )",        "bitwise invert"),
        ("ABS",     "( n -- u )",         "absolute value"),
        ("NEGATE",  "( n -- -n )",        "negate"),
        ("MIN",     "( n1 n2 -- min )",   "minimum"),
        ("MAX",     "( n1 n2 -- max )",   "maximum"),
        ("1+",      "( n -- n+1 )",       "increment"),
        ("1-",      "( n -- n-1 )",       "decrement"),
        ("MOD",     "( n1 n2 -- rem )",   "modulo"),
        ("WITHIN",  "( n lo hi -- f )",   "within range"),
        ("PICK",    "( n -- n )",         "pick"),
        ("ROLL",    "( n -- )",           "roll"),
        ("TUCK",    "( a b -- b a b )",   "tuck"),
        ("NIP",     "( a b -- b )",       "nip"),
        ("BL",      "( -- 32 )",          "blank (space)"),
        ("CHAR",    "( -- c )",           "parse next char (stub)"),

        // New for FLOAD / EDIT / file helpers (cwd + dialog driven by host for sandbox friendliness)
        ("\\",      "( -- )",             "comment to end of line (immediate)"),
        ("\\\\",    "( -- )",             "block comment to next '{' (spans lines in console or FLOAD, for old code) (immediate)"),
        ("\\S",     "( -- )",             "stop loading current file (no-op in console) (immediate)"),
        ("FLOAD",   "( -- ) name|dialog", "load .fth file (auto .fth ext + cwd if needed; no name opens dialog)"),
        ("EDIT",    "( -- ) name|dialog", "open in system text editor (nav dialog or name; updates cwd to file's folder; no load/interpret)"),
        ("FILE-ECHO","( -- addr )",       "variable controlling FLOAD source echo (use with ON/OFF)"),
        ("ON",      "( addr -- )",        "store 1 at addr (e.g. file-echo ON)"),
        ("OFF",     "( addr -- )",        "store 0 at addr (e.g. file-echo OFF)"),
        ("CHDIR",   "( -- ) path",        "change dir (no arg: show current); supports ~ and relative"),
        ("DIR",     "( -- ) filespec",    "list dir (no arg: current; <path><filespec> with *? wildcards)"),
        ("(DO)",    "( limit start -- )", "internal runtime for DO (setup rstack)"),
        ("(?DO)",   "( limit start -- )", "internal runtime for ?DO"),
        ("(LOOP)",  "( -- )",             "internal runtime for LOOP"),
        ("(+LOOP)", "( n -- )",           "internal runtime for +LOOP"),
        ("(CREATE)", "( -- a-addr )",     "internal runtime for CREATE (pushes data field address)"),
        ("(DOES)",  "( -- a-addr )",      "internal runtime for CREATE...DOES> children (push data addr + run does code)"),
        ("(DOES>)", "( -- )",             "internal: patch latest CREATE word for DOES> and return from parent"),
    ]
    
    private static let primitiveHelp: [String: (stack: String, desc: String)] = {
        var d: [String: (stack: String, desc: String)] = [:]
        for item in primitiveHelpData {
            let key = item.name.trimmingCharacters(in: .whitespaces)
            d[key] = (stack: item.stack, desc: item.desc)
        }
        return d
    }()
    
    // The address of the QUIT word's threaded code (for restarting the outer loop)
    private var quitCodeAddress: Int = 0

    // MARK: - Init

    public init() {
        memory = Array(repeating: 0, count: MEM_SIZE)

        // Layout the fixed system variables
        stackBase = 1024
        rstackBase = stackBase + STACK_SIZE * CELL_SIZE

        // Initialize system variables
        writeCell(LATEST, 0)
        writeCell(HERE, rstackBase + RSTACK_SIZE * CELL_SIZE)   // start of dictionary
        writeCell(STATE, 0)
        writeCell(BASE, 10)

        // Live stack depths live in Swift vars (corruption-proof).
        // We still write the old fixed locations for any future raw memory inspection or "SP @" compatibility.
        dataStackPointer = 1
        returnStackPointer = 1
        writeCell(SP, 1)
        writeCell(RSP, 1)

        primitives = []
        primitives.reserveCapacity(MAX_BUILTIN_ID)

        registerCorePrimitives()

        // Bootstrap a tiny set of immediate and defining words by hand
        bootstrapMinimalDictionary()

        // Record the end of the kernel dictionary so FORGET cannot delete primitives.
        kernelLatest = readCell(LATEST)

        // Seed the interpreter IP at the QUIT code we just created
        ip = quitCodeAddress

        // === Strong diagnostic after registration ===
        print("=== LBForth INIT DIAGNOSTICS ===")
        print("primitives[0] (DOCOL) set: \(primitives[0] != nil)")
        print("primitives.count after registration: \(primitives.count)")

        let plusHeader = findWord("+")
        if plusHeader == 0 {
            print("ERROR: '+' NOT FOUND in dictionary!")
        } else {
            let cfa = getCFA(plusHeader)
            let first = readCell(Int(cfa))
            let second = readCell(Int(cfa) + 8)
            print(" '+' header=\(plusHeader) cfa=\(cfa) firstCell=\(first) secondCell=\(second)")
        }

        // Also check a couple other primitives
        for testName in ["DUP", "CR", "@"] {
            let h = findWord(testName)
            if h != 0 {
                let c = getCFA(h)
                let f = readCell(Int(c))
                print(" \(testName): cfa=\(c) first=\(f)")
            } else {
                print(" \(testName): NOT FOUND")
            }
        }
        print("=== END INIT DIAGNOSTICS ===")
    }

    // MARK: - Low-level memory

    private func readCell(_ addr: Int) -> Cell {
        if addr < 0 || addr + 8 > memory.count {
            tell("? Memory read out of range (addr=\(addr))\n")
            errorFlag = true
            return 0
        }
        return memory.withUnsafeBytes { $0.load(fromByteOffset: addr, as: Cell.self) }
    }

    private func writeCell(_ addr: Int, _ value: Cell) {
        if addr < 0 || addr + 8 > memory.count {
            tell("? Memory write out of range (addr=\(addr))\n")
            errorFlag = true
            return
        }
        withUnsafeBytes(of: value) { raw in
            let src = raw.bindMemory(to: UInt8.self)
            for i in 0..<8 { memory[addr + i] = src[i] }
        }
    }

    private func readByte(_ addr: Int) -> UInt8 {
        memory[addr]
    }

    private func writeByte(_ addr: Int, _ value: UInt8) {
        memory[addr] = value
    }

    // MARK: - Stacks

    private func spGet() -> Cell { dataStackPointer }
    private func spSet(_ v: Cell) { dataStackPointer = v }

    private func rspGet() -> Cell { returnStackPointer }
    private func rspSet(_ v: Cell) { returnStackPointer = v }

    private func pop() -> Cell {
        var s = spGet()
        if s < 1 || s > Cell(STACK_SIZE) {
            tell("? Corrupted data stack pointer (SP=\(s)), auto-recovering\n")
            s = 1
            spSet(1)
        }
        if s <= 1 {
            if readCell(STATE) != 0 {
                tell("? Stack underflow while compiling\n")
            } else {
                tell("? Stack underflow\n")
            }
            spSet(1)
            errorFlag = true
            return 0
        }
        spSet(s - 1)
        return readCell(stackBase + (s - 2) * 8)
    }

    private func push(_ v: Cell) {
        var s = spGet()
        if s < 1 || s > Cell(STACK_SIZE) {
            tell("? Corrupted data stack pointer (SP=\(s)), auto-recovering\n")
            s = 1
            spSet(1)
        }
        if s >= Cell(STACK_SIZE) {
            tell("? Stack overflow\n"); errorFlag = true; return
        }
        writeCell(stackBase + (s - 1) * 8, v)
        spSet(s + 1)
    }

    private func rpop() -> Cell {
        var rs = rspGet()
        if rs < 1 || rs > Cell(RSTACK_SIZE) {
            tell("? Corrupted return stack pointer (RSP=\(rs)), auto-recovering\n")
            rs = 1
            rspSet(1)
        }
        if rs <= 1 {
            if readCell(STATE) != 0 {
                tell("? Return stack underflow while compiling\n")
            } else {
                tell("? Return stack underflow\n")
            }
            rspSet(1)
            errorFlag = true
            return 0
        }
        rspSet(rs - 1)
        return readCell(rstackBase + (rs - 2) * 8)
    }

    private func rpush(_ v: Cell) {
        var rs = rspGet()
        if rs < 1 || rs > Cell(RSTACK_SIZE) {
            tell("? Corrupted return stack pointer (RSP=\(rs)), auto-recovering\n")
            rs = 1
            rspSet(1)
        }
        if rs >= Cell(RSTACK_SIZE) {
            tell("? Return stack overflow\n"); errorFlag = true; return
        }
        writeCell(rstackBase + (rs - 1) * 8, v)
        rspSet(rs + 1)
    }

    // MARK: - Output

    private func putkey(_ c: UInt8) {
        onOutput?(String(UnicodeScalar(c)))
    }

    private func tell(_ s: String) {
        for b in s.utf8 { putkey(b) }
    }

    // MARK: - Input (line-driven from SwiftUI)

    public func feedLine(_ line: String) {
        // Top-level defensive entry point for the host application (ConsoleView, tests, etc.).
        // All serious error conditions inside the engine are now turned into clean
        // "? message" reports + stack resets instead of Swift traps/fatalErrors.
        // This guarantees feedLine always returns normally and leaves the engine
        // ready for the next command.
        validateAndRepairSystemState()

        for b in line.utf8 { inputQueue.append(b) }
        inputQueue.append(10) // \n

        runInterpreter()

        if errorFlag {
            recoverFromError()
        }

        // Optional per-line debug output (state + stack after each feedLine).
        // Enabled via DEBUG-ON / DEBUG-OFF. Default is off.
        if debugEnabled {
            let stateStr = readCell(STATE) != 0 ? "compiling" : "interpreting"
            let depth = Int(spGet() - 1)
            tell("[DEBUG] state=\(stateStr)  stack=<\(depth)> \(stackAsString)\n")
        }
    }

    /// Called by the host UI (ConsoleView) when the user types a character while
    /// a KEY is waiting (waitingForKey == true). This supplies the character to the
    /// pending KEY and resumes interpretation (outer or threaded) from the suspension point.
    public func provideKey(_ char: Int) {
        if !waitingForKey { return }
        waitingForKey = false

        // Provide the value as if the KEY primitive itself had pushed it.
        push(char)

        // Resume execution.
        // - If we were inside a colon definition (return stack has frames), re-enter
        //   innerThread. Because we rewound ip in innerThread on suspend, we must now
        //   advance past the KEY cell (we have already injected the value via push).
        //   This avoids re-executing the KEY primitive.
        if returnStackPointer > 1 {
            ip += 8
            innerThread()
        }
        // In all cases (top-level KEY or after a colon def), give the outer interpreter
        // a chance to finish processing any remaining words on the current top-level line
        // (e.g. nothing, or if somehow more) and print the "OK" if the line completed.
        runInterpreter()
    }

    // MARK: - FLOAD support (file loading / including source)

    /// Public entry point for the host to load a file after a dialog (or programmatically).
    /// Clears any pending request flag and processes the file's lines.
    public func loadFile(_ url: URL) {
        fileLoadRequested = false
        fileEditRequested = false
        pendingEditURL = nil
        loadFileContents(url)
    }

    /// Public entry point for the host after EDIT dialog pick (or future programmatic).
    /// Just clears flags; the actual open-in-editor + chdir + persist is done by the host
    /// (in showFileEditDialog completion or post-feed handler) because it requires AppKit (NSWorkspace).
    public func editFile(_ url: URL) {
        fileEditRequested = false
        pendingEditURL = nil
        // No load/interpret happens for EDIT — that's the point (edit bad sources safely before FLOAD).
    }

    /// Common resolution for FLOAD/EDIT specs (auto .fth if basename has no dot, ~ expansion,
    /// absolute vs relative to currentDirectoryPath). Factored to keep behavior identical.
    private func resolvedURL(for spec: String) -> URL {
        let fm = FileManager.default
        var name = spec
        // Only auto-append .fth if the basename has no extension at all (common Forth convention).
        // If user gave an explicit ext (even .txt), respect it.
        var base = name
        if let slash = name.lastIndex(of: "/") ?? name.lastIndex(of: "\\") {
            base = String(name[name.index(after: slash)...])
        }
        if !base.contains(".") {
            name += ".fth"
        }
        let url: URL
        if name.contains("/") || name.contains("\\") {
            if name.hasPrefix("~") {
                let expanded = (name as NSString).expandingTildeInPath
                url = URL(fileURLWithPath: expanded)
            } else {
                url = URL(fileURLWithPath: name)
            }
        } else {
            // Relative to current working directory (as specified).
            let cwd = fm.currentDirectoryPath
            url = URL(fileURLWithPath: cwd).appendingPathComponent(name)
        }
        return url
    }

    private func resolveAndLoadFile(spec: String) {
        let url = resolvedURL(for: spec)
        loadFileContents(url)
    }

    /// For named EDIT <spec>: resolve exactly like FLOAD would, set pendingEditURL so the
    /// host's post-feedLine handler (in ConsoleView) can do NSWorkspace.open + chdir + persist.
    /// We do not perform chdir or open inside the engine to keep AppKit/UserDefaults concerns
    /// in the host, and to ensure post-feed checks run uniformly.
    private func resolveAndEditFile(spec: String) {
        let url = resolvedURL(for: spec)
        self.pendingEditURL = url
    }

    private func loadFileContents(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            // Be tolerant of old source files (e.g. renamed .SEQ from OldSources) that may
            // not be strict UTF-8 (high-bit chars, legacy encodings, etc.). Fall back so
            // FLOAD doesn't complain "isn’t in the correct format".
            let content: String
            if let utf8 = String(data: data, encoding: .utf8) {
                content = utf8
            } else if let latin = String(data: data, encoding: .isoLatin1) {
                content = latin
            } else {
                // Last resort: decode with replacement characters for any bad bytes.
                content = String(decoding: data, as: UTF8.self)
            }
            // Split on any line ending (handles \n, \r, \r\n etc. cleanly).
            let rawLines = content.components(separatedBy: .newlines)
            let echoOn = (fileEchoAddr != 0) && (readCell(fileEchoAddr) != 0)

            self.loadNesting += 1
            self.sourceLoadStop = false
            self.inSlashSlashComment = false
            defer { self.loadNesting -= 1 }

            for raw in rawLines {
                if echoOn {
                    tell(raw + "\n")
                }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    feedLine(raw)
                    if self.sourceLoadStop {
                        self.sourceLoadStop = false
                        break
                    }
                    if errorFlag {
                        tell("? FLOAD aborted after error in \(url.lastPathComponent)\n")
                        break
                    }
                }
            }
        } catch {
            tell("? FLOAD could not read '\(url.lastPathComponent)': \(error.localizedDescription)\n")
            errorFlag = true
        }
    }

    // CHDIR support (used by the CHDIR word)
    private func changeDirectory(spec: String) {
        let fm = FileManager.default
        if spec.isEmpty {
            tell("Current directory: \(fm.currentDirectoryPath)\n")
            return
        }
        let expanded = (spec as NSString).expandingTildeInPath
        let newURL: URL
        if expanded.hasPrefix("/") {
            newURL = URL(fileURLWithPath: expanded)
        } else {
            let cwd = fm.currentDirectoryPath
            newURL = URL(fileURLWithPath: cwd).appendingPathComponent(expanded)
        }
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: newURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            if fm.changeCurrentDirectoryPath(newURL.path) {
                tell("Current directory: \(fm.currentDirectoryPath)\n")
            } else {
                tell("CHDIR error: could not change to '\(spec)'\n")
                errorFlag = true
            }
        } else {
            tell("CHDIR error: '\(spec)' is not a directory\n")
            errorFlag = true
        }
    }

    // DIR support (used by the DIR word). Supports optional <path><filespec> with * ? wildcards.
    private func listDirectory(spec: String) {
        let fm = FileManager.default
        var basePath = fm.currentDirectoryPath
        var filter = ""
        if !spec.isEmpty {
            let expanded = (spec as NSString).expandingTildeInPath
            let hasWild = expanded.contains("*") || expanded.contains("?")
            if hasWild {
                if let lastSlash = expanded.lastIndex(of: "/") {
                    let dirPart = String(expanded[..<lastSlash])
                    filter = String(expanded[expanded.index(after: lastSlash)...])
                    if dirPart.isEmpty {
                        basePath = "/"
                    } else {
                        let dirExpanded = (dirPart as NSString).expandingTildeInPath
                        if dirExpanded.hasPrefix("/") {
                            basePath = dirExpanded
                        } else {
                            basePath = (basePath as NSString).appendingPathComponent(dirExpanded)
                        }
                    }
                } else {
                    filter = expanded
                }
            } else {
                // no wildcard: prefer treating as directory if it exists
                let testPath = (expanded as NSString).expandingTildeInPath
                let testURL = testPath.hasPrefix("/") ? URL(fileURLWithPath: testPath) : URL(fileURLWithPath: (basePath as NSString).appendingPathComponent(testPath))
                var isD: ObjCBool = false
                if fm.fileExists(atPath: testURL.path, isDirectory: &isD) && isD.boolValue {
                    basePath = testURL.path
                    filter = ""
                } else {
                    filter = expanded
                    // base remains current
                }
            }
        }
        let dirURL = URL(fileURLWithPath: basePath)
        do {
            let contents = try fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
            tell("\nDirectory of \(dirURL.path)\n\n")
            var count = 0
            for fileURL in contents.sorted(by: { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }) {
                let name = fileURL.lastPathComponent
                if !filter.isEmpty {
                    if !matchesWildcard(filter, in: name) {
                        continue
                    }
                }
                var isDir: ObjCBool = false
                fm.fileExists(atPath: fileURL.path, isDirectory: &isDir)
                let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
                let size = resourceValues?.fileSize ?? 0
                if isDir.boolValue {
                    tell(" \(name.padding(toLength: 30, withPad: " ", startingAt: 0)) <DIR>\n")
                } else {
                    let sizeStr = String(size).padding(toLength: 12, withPad: " ", startingAt: 0)
                    tell(" \(name.padding(toLength: 30, withPad: " ", startingAt: 0)) \(sizeStr)\n")
                }
                count += 1
            }
            tell("\n \(count) file(s)\n\n")
        } catch {
            tell("DIR error: Cannot read directory '\(dirURL.path)'\n")
            errorFlag = true
        }
    }

    /// Simple MS-DOS style wildcard matcher (* and ? supported), case-insensitive.
    private func matchesWildcard(_ pattern: String, in name: String) -> Bool {
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
            + "$"
        if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: name.utf16.count)
            return regex.firstMatch(in: name, options: [], range: range) != nil
        }
        return false
    }

    private func refillLineBuffer() -> Bool {
        // For simplicity in the first version we read directly from inputQueue
        // into wordBuffer when needed. The original used a separate line buffer.
        return !inputQueue.isEmpty
    }

    private func getKey() -> Int {
        if inputQueue.isEmpty { return -1 }
        return Int(inputQueue.removeFirst())
    }

    // MARK: - Dictionary creation (very close to the original)

    private func alignHere() {
        var h = readCell(HERE)
        while (h & 7) != 0 {
            writeByte(h, 0)
            h += 1
        }
        writeCell(HERE, h)
    }

    // Direct memory versions — these do NOT touch the data stack.
    // Critical during init when building the primitive dictionary.
    private func writeCellHere(_ value: Cell) {
        let h = readCell(HERE)
        writeCell(h, value)
        writeCell(HERE, h + 8)
    }

    private func writeByteHere(_ value: UInt8) {
        let h = readCell(HERE)
        writeByte(h, value)
        writeCell(HERE, h + 1)
    }

    private func createWord(name: String, immediate: Bool) {
        let newLatest = readCell(HERE)

        // link field (previous LATEST) — direct write
        let oldLatest = readCell(LATEST)
        writeCellHere(oldLatest)

        // flags + length byte — direct write
        let namelen = UInt8(name.utf8.count)
        let flags: UInt8 = immediate ? FLAG_IMMEDIATE : 0
        writeByteHere(namelen | flags)

        // name bytes — direct write
        for b in name.utf8 {
            writeByteHere(b)
        }

        alignHere()

        // Update LATEST to point at this new header
        writeCell(LATEST, newLatest)
    }

    // These three are the public "," "C," and cell version that *do* use the data stack,
    // so user-level Forth code like "42 ," will work correctly.
    private func comma() {
        let value = pop()
        writeCellHere(value)
    }

    private func commaByte() {
        let value = pop()
        writeByteHere(UInt8(value & 0xff))
    }

    private func commaCell(_ value: Cell) {
        writeCellHere(value)
    }

    // MARK: - Finding words

    private func findWord(_ name: String) -> Cell {
        let upper = name.uppercased()
        var link = readCell(LATEST)

        var safety = 0
        while link != 0 && safety < 10000 {
            safety += 1
            if !isValidDictionaryLink(link) {
                break
            }
            let flagsLen = readByte(link + 8)
            let namelen = Int(flagsLen & MASK_NAMELENGTH)

            if namelen == upper.utf8.count {
                var match = true
                for (i, ch) in upper.utf8.enumerated() {
                    if up(readByte(link + 9 + i)) != up(ch) {
                        match = false
                        break
                    }
                }
                if match && (flagsLen & FLAG_HIDDEN) == 0 {
                    return link
                }
            }
            link = readCell(link)
        }
        return 0
    }

    private func up(_ c: UInt8) -> UInt8 {
        (c >= 97 && c <= 122) ? c - 32 : c
    }

    /// Returns true for any character that should be treated as an apostrophe / tick
    /// for the purposes of tick (') and name lookup. This covers the straight ASCII
    /// apostrophe plus the various curly/smart quotes, backtick, and prime characters
    /// that macOS keyboards and smart-quotes features commonly produce.
    private func isApostropheLike(_ c: Character) -> Bool {
        switch c {
        case "'", "`", "\u{00B4}",          // ASCII ' , backtick, acute
             "\u{2018}", "\u{2019}",        // ‘ ’  left/right single quotation mark (most common smart quotes)
             "\u{201A}", "\u{201B}",        // ‚ ‛  low-9 and high-reversed-9
             "\u{2032}", "\u{FF07}":        // ′  prime,  ＇ fullwidth apostrophe
            return true
        default:
            return false
        }
    }

    private func isValidDictionaryLink(_ addr: Cell) -> Bool {
        if addr == 0 { return true }
        if (addr & 7) != 0 { return false } // must be 8-byte aligned

        // Only do a very loose bounds check against the entire memory buffer.
        // We deliberately do *not* use the current HERE value here.
        //
        // Reason: FORGET intentionally sets HERE backwards to reclaim memory.
        // Using the live HERE as an upper bound would incorrectly make
        // perfectly valid older headers (including core primitives like HERE
        // itself) appear "invalid" after a FORGET.
        //
        // We rely on proper LATEST maintenance + the alignment check + the
        // safety iteration limit instead.
        return addr >= 0 && addr < MEM_SIZE
    }

    private func getCFA(_ headerAddr: Cell) -> Cell {
        let flagsLen = readByte(Int(headerAddr) + 8)
        var len = Int(flagsLen & MASK_NAMELENGTH) + 1  // +1 for the flags/len byte itself
        while (len & 7) != 0 { len += 1 }
        return headerAddr + Cell(8 + len)
    }

    // MARK: - Primitive registration

    private func register(_ name: String, immediate: Bool = false, _ body: @escaping () -> Void) -> Cell {
        // Sequential ID = current count. We start empty in init(), so this gives 0,1,2...
        let id = Cell(primitives.count)
        primitives.append(body)
        primitiveNames[id] = name.uppercased()

        // Create the dictionary entry for this primitive:
        //   link, flags+len, name, padding,  <ID cell> , EXIT
        createWord(name: name, immediate: immediate)

        // The code field contains the small ID followed by EXIT.
        // Use direct writes (not the data-stack versions) because we are building
        // the kernel dictionary here.
        writeCellHere(id)
        writeCellHere(exitID)

        return id
    }

    private func registerCorePrimitives() {
        // We must define EXIT and DOCOL first because everything else uses them.

        // ID 0 = DOCOL / RUNDOCOL
        docolID = Cell(primitives.count)
        primitives.append {
            // On entry, commandAddress points at the DOCOL cell.
            // We want to push the old IP and start executing the body after DOCOL.
            self.rpush(self.ip)
            self.ip = self.commandAddress + 8   // skip the DOCOL cell itself
        }

        // EXIT
        exitID = Cell(primitives.count)
        primitives.append {
            self.ip = self.rpop()
        }

        // LIT
        litID = register("LIT") {
            let value = self.readCell(self.ip)
            self.ip += 8
            self.push(value)
        }

        // Now safe to define the rest
        _ = register("EXIT") { /* already implemented above */ }

        dupID = register("DUP")   { let v = self.pop(); self.push(v); self.push(v) }
        dropID = register("DROP")  { _ = self.pop() }
        swapID = register("SWAP")  { let b = self.pop(); let a = self.pop(); self.push(b); self.push(a) }
        _ = register("OVER")  { let b = self.pop(); let a = self.pop(); self.push(a); self.push(b); self.push(a) }

        _ = register("+")     { let b = self.pop(); let a = self.pop(); self.push(a + b) }
        _ = register("-")     { let b = self.pop(); let a = self.pop(); self.push(a - b) }
        _ = register("*")     { let b = self.pop(); let a = self.pop(); self.push(a * b) }
        _ = register("/MOD")  {
            let b = self.pop(); let a = self.pop()
            if b == 0 {
                self.tell("? Division by zero\n"); self.errorFlag = true; self.push(0); self.push(0); return
            }
            self.push(a % b); self.push(a / b)
        }

        _ = register(".")     { self.tell(String(self.pop())); self.putkey(32) }
        _ = register("CR")    { self.putkey(10) }
        _ = register("SPACE") { self.putkey(32) }
        _ = register("EMIT")  { self.putkey(UInt8(self.pop() & 0xff)) }

        // KEY ( -- char )
        // Classic blocking behavior: waits until at least one input character is available,
        // then returns the next byte from the input queue.
        //
        // Because the host console feeds whole lines via feedLine(), KEY will wait until
        // the user types a line (and presses return) and that line's characters (plus the
        // newline) have been appended to the queue.
        //
        // We sleep briefly in the spin loop so we don't burn 100% CPU while waiting.
        _ = register("KEY") {
            // KEY is always treated as a blocking input request in this console.
            // We do *not* consume any characters from the current inputQueue (even if "key ."
            // was typed on the same line). The remaining text on the line (e.g. " .") is left
            // in the queue to be processed *after* the key value is supplied and we resume.
            //
            // This gives the exact behavior requested: typing "key ." <return> causes the system
            // to wait for the user to press a key (via a subsequent provideKey from the UI),
            // then the "." will print the ascii value of the key that was entered.
            self.waitingForKey = true
            // The host (ConsoleView or TestLBForth) will call provideKey(_ char) when the user
            // supplies a character. That will push the value and resume the suspended interpreter
            // (outer or innerThread, with proper IP/return stack handling).
            return
        }

        // KEY? ( -- flag )
        // Non-blocking test. Returns -1 if a character is immediately available, 0 otherwise.
        // Useful for polling loops when you don't want to block.
        _ = register("KEY?") {
            self.push( self.inputQueue.isEmpty ? 0 : -1 )
        }

        _ = register("!")     { let addr = Int(self.pop()); let val = self.pop(); self.writeCell(addr, val) }
        _ = register("@")     { let addr = Int(self.pop()); self.push(self.readCell(addr)) }
        _ = register("C!")    { let addr = Int(self.pop()); let val = self.pop(); self.writeByte(addr, UInt8(val & 0xff)) }
        _ = register("C@")    { let addr = Int(self.pop()); self.push(Cell(self.readByte(addr))) }

        // Public "," and "C," so that interpret-time "42 ," and "65 C," work (compile into dictionary).
        _ = register(",")  { self.comma() }
        _ = register("C,") { self.commaByte() }

        _ = register("HERE")  { self.push(self.readCell(self.HERE)) }
        _ = register("LATEST"){ self.push(self.readCell(self.LATEST)) }
        _ = register("STATE") { self.push(self.readCell(self.STATE)) }
        _ = register("BASE")  { self.push(self.readCell(self.BASE)) }

        // >HEADER ( xt -- header )  Given a code field address (xt), return the
        // start of its dictionary header (the link field address).  This is the
        // key primitive needed to implement proper linked-list dictionary walking.
        // The active user-facing FORGET is the parsing primitive below (FORGET NAME).
        // FORGET now also restores HERE to reclaim memory for the forgotten word(s).
        _ = register(">HEADER") {
            let targetCFA = self.pop()
            var link = self.readCell(self.LATEST)
            var safety = 0
            while link != 0 && safety < 10000 {
                safety += 1
                if !self.isValidDictionaryLink(link) { break }
                let thisCFA = self.getCFA(link)
                if thisCFA == targetCFA {
                    self.push(link)
                    return
                }
                link = self.readCell(link)
            }
            self.push(0)   // not found
        }

        _ = register("]", immediate: false) { self.writeCell(self.STATE, 1) }
        _ = register("[", immediate: true)  { self.writeCell(self.STATE, 0) }

        // : and ; are special because they affect STATE and compile DOCOL / EXIT
        _ = register(":") {
            // Read the next word as the name
            let name = self.parseWord()
            if name.isEmpty { self.tell("? : needs a name\n"); self.errorFlag = true; return }

            self.createWord(name: name, immediate: false)

            // Compile DOCOL into the code field (as if user had done DOCOL , )
            self.push(self.docolID); self.comma()

            // Hide the word while we are compiling it (classic behaviour)
            let l = self.readCell(self.LATEST)
            let fl = self.readByte(Int(l) + 8)
            self.writeByte(Int(l) + 8, fl | self.FLAG_HIDDEN)

            self.writeCell(self.STATE, 1)
        }

        _ = register(";", immediate: true) {
            self.push(self.exitID); self.comma()

            // Unhide
            let l = self.readCell(self.LATEST)
            let fl = self.readByte(Int(l) + 8)
            self.writeByte(Int(l) + 8, fl & ~self.FLAG_HIDDEN)

            self.writeCell(self.STATE, 0)
            self.loopControlStack.removeAll()  // clean any leftover from unbalanced loops in this def
        }

        // A few more essentials
        zeroBranchID = register("0BRANCH") {
            let offset = self.readCell(self.ip)
            self.ip += 8
            if self.pop() == 0 {
                self.ip += offset
            }
            // The next iteration of innerThread will validate via readCell + dispatch guard,
            // but we also check immediately so a wildly bad offset produces a clear message fast.
            if self.ip < 0 || self.ip + 8 > self.memory.count {
                self.tell("? Bad branch target (ip=\(self.ip) after 0BRANCH)\n")
                self.errorFlag = true
            }
        }

        branchID = register("BRANCH") {
            let offset = self.readCell(self.ip)
            self.ip += 8
            self.ip += offset
            if self.ip < 0 || self.ip + 8 > self.memory.count {
                self.tell("? Bad branch target (ip=\(self.ip) after BRANCH)\n")
                self.errorFlag = true
            }
        }

        // === CREATE / DOES> (ANS Forth 2012) support ===
        // These are internal runtimes. CREATE and DOES> (the user words) are registered later.

        // (CREATE) -- runtime for plain CREATE words.
        // Layout: [header] <createRuntimeID> <dataAddrValue> [data field starts here]
        // Read the dataAddrValue from the following cell, advance ip past it (threaded case),
        // push the data address.
        createRuntimeID = register("(CREATE)") {
            let dataAddr = self.readCell(self.currentCodeAddr + 8)
            self.ip += 8
            self.push(dataAddr)
        }

        // (DOES) -- runtime for CREATE ... DOES> children.
        // Layout: [header] <dodoesID> <doesCodeAddr> [data field starts here]
        // Pushes data addr (currentCodeAddr + 16), redirects ip to the does code.
        dodoesID = register("(DOES)") {
            let doesAddr = self.readCell(self.currentCodeAddr + 8)
            let dataAddr = self.currentCodeAddr + 16
            self.push(dataAddr)
            self.ip = Int(doesAddr)
            if !self.dispatchedFromInnerThread {
                // This does-child is being executed directly (top-level or leaf from outer interpreter).
                // No active caller innerThread to pick up the redirected ip, so run the does code here.
                self.rpush(0)  // sentinel so the does code's EXIT can return cleanly
                self.innerThread()
                // After does code EXITS (rpop 0), this dodoes body returns; outer continues (e.g. to ".").
            }
            // If dispatchedFromInnerThread, we just redirected ip; the caller's innerThread will continue
            // from the new ip when this body returns.
        }

        // Internal patch primitive compiled by DOES> .
        // At runtime (inside a parent definition, right after a CREATE has defined a child):
        //   stack: doesCodeAddr
        // It patches the latest word (the child) to use dodoesID + doesCodeAddr instead of its plain create runtime,
        // then returns from the parent definition (so the does code is not executed in the parent's context).
        doesPatchID = register("(DOES>)") {
            let doesAddr = self.pop()
            let latest = self.readCell(self.LATEST)
            if latest == 0 {
                self.tell("? DOES> without a preceding CREATE\n")
                self.errorFlag = true
                return
            }
            let cfa = self.getCFA(latest)
            // Patch the first cell after the header (was createRuntimeID) to dodoesID
            self.writeCell(Int(cfa), self.dodoesID)
            // Patch the second cell (was the dataAddr value) to the does code address
            self.writeCell(Int(cfa) + 8, doesAddr)
            // Consume the colon return frame (pushed by docol when entering the parent)
            // to keep rstack accounting correct, then force this innerThread level to stop
            // processing the does code (by setting ip=0). The outer context continues normally.
            if self.rspGet() > 1 {
                let _ = self.rpop()
            }
            self.ip = 0
        }

        // === Structured control flow (loops + conditionals) ===
        // BEGIN ... AGAIN / UNTIL / WHILE ... REPEAT
        // IF ... ELSE ... THEN
        //
        // All are immediate words. They execute at compile time and emit the low-level
        // BRANCH / 0BRANCH primitives plus forward/backward offsets.
        // They use the classic Forth technique of using the data stack (at compile time)
        // to hold branch target addresses. This keeps the implementation small, readable,
        // and very educational. No extra control-flow stack is required.

        _ = register("BEGIN", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? BEGIN only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            let here = self.readCell(self.HERE)
            self.push(here)   // destination address for backward branches (AGAIN, UNTIL, REPEAT)
        }

        _ = register("AGAIN", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? AGAIN only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            let dest = self.pop()
            self.push(self.branchID); self.comma()          // compile the unconditional branch token
            let here = self.readCell(self.HERE)
            let offset = dest - (here + 8)                  // offset from after the offset cell
            self.push(offset); self.comma()
        }

        _ = register("UNTIL", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? UNTIL only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            let dest = self.pop()
            self.push(self.zeroBranchID); self.comma()
            let here = self.readCell(self.HERE)
            let offset = dest - (here + 8)
            self.push(offset); self.comma()
        }

        _ = register("WHILE", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? WHILE only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            // Compile a 0BRANCH with a placeholder offset (0 for now).
            // The offset will be resolved later by REPEAT.
            self.push(self.zeroBranchID); self.comma()
            let placeholderAddr = self.readCell(self.HERE)  // address of the offset cell we just reserved
            self.push(0); self.comma()                      // placeholder offset (will be patched by REPEAT)

            // Leave the address of the placeholder on the compile-time stack
            // so REPEAT can resolve the forward branch.
            // Stack transition (at compile time):  ... begin-dest   -->   ... begin-dest  placeholderAddr
            self.push(placeholderAddr)
        }

        _ = register("REPEAT", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? REPEAT only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            let origPlaceholder = self.pop()   // address of the forward 0BRANCH offset left by WHILE
            let dest = self.pop()              // the BEGIN destination

            // First, compile unconditional branch back to BEGIN
            self.push(self.branchID); self.comma()
            let here = self.readCell(self.HERE)
            let backOffset = dest - (here + 8)
            self.push(backOffset); self.comma()

            // Now resolve the forward branch that WHILE left behind.
            // The code after REPEAT (current HERE) is where the 0BRANCH should jump to
            // when its condition was false.
            let afterRepeat = self.readCell(self.HERE)
            let forwardOffset = afterRepeat - (origPlaceholder + 8)
            self.writeCell(Int(origPlaceholder), forwardOffset)
        }

        // === Classic IF / ELSE / THEN (structured conditionals) ===
        // These use the same forward-branch placeholder technique as WHILE/REPEAT.
        // All are immediate and operate on the compile-time data stack.

        _ = register("IF", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? IF only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            self.push(self.zeroBranchID); self.comma()
            let placeholderAddr = self.readCell(self.HERE)
            self.push(0); self.comma()
            self.push(placeholderAddr)
        }

        _ = register("ELSE", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? ELSE only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            let ifPlaceholder = self.pop()
            self.push(self.branchID); self.comma()
            let elsePlaceholder = self.readCell(self.HERE)
            self.push(0); self.comma()
            self.push(elsePlaceholder)

            let afterElseBranch = self.readCell(self.HERE)
            let skipOffset = afterElseBranch - (ifPlaceholder + 8)
            self.writeCell(Int(ifPlaceholder), skipOffset)
        }

        _ = register("THEN", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? THEN only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            let placeholder = self.pop()
            let here = self.readCell(self.HERE)
            let forwardOffset = here - (placeholder + 8)
            self.writeCell(Int(placeholder), forwardOffset)
        }

        // ' (tick) — simplified non-immediate version for now
        _ = register("'") {
            // parseWord() has already normalized any curly/smart quote that the
            // user typed in place of the tick character, so the name we get here
            // for the *target* of tick is clean (or normalized if it contained quotes).
            let name = self.parseWord()
            if name.isEmpty {
                self.tell("? ' needs a name\n"); self.errorFlag = true; return
            }

            let hdr = self.findWord(name)
            if hdr == 0 {
                self.tell("? \(name) ?\n"); self.errorFlag = true; return
            }
            let cfa = self.getCFA(hdr)
            // Match the exact distinction used by the interpreter and SEE:
            // - Real primitives (first cell is a small ID that is *not* DOCOL) → push the ID
            // - Colon definitions (start with DOCOL) and anything else → push the CFA
            // This is why ' TEST was returning 0 (DOCOL id) instead of the real execution token.
            let firstCell = self.readCell(Int(cfa))
            if firstCell < Cell(self.MAX_BUILTIN_ID) && firstCell != self.docolID {
                self.push(firstCell)
            } else {
                self.push(cfa)
            }
        }

        // ( comment ) — classic and essential
        _ = register("(", immediate: true) {
            // Eat characters until we see )
            while !self.inputQueue.isEmpty {
                let c = self.inputQueue.removeFirst()
                if c == 41 { break } // ')'
            }
        }

        // \ comment to end of line — essential for loading typical .fth source files that use
        // line comments. Immediate so it works while compiling too.
        _ = register("\\", immediate: true) {
            while !self.inputQueue.isEmpty {
                let c = self.inputQueue.removeFirst()
                if c == 10 || c == 13 { break }
            }
        }

        // \\  (two backslashes) starts a block comment area, skipped until a '{' is seen.
        // The skipped region can span multiple lines (works in console REPL and during FLOAD).
        // Text after the '{' on the closing line is processed normally.
        // Immediate so it works while compiling loaded files too. For old code compatibility.
        _ = register("\\\\", immediate: true) {
            while !self.inputQueue.isEmpty {
                let c = self.inputQueue.removeFirst()
                if c == 123 { // '{'
                    return
                }
            }
            // No '{' seen on this line (or in queue); set flag so subsequent feedLine/parseWord
            // calls will skip until a line containing '{' is seen (then resume after it).
            self.inSlashSlashComment = true
        }

        // \S  stops further loading/interpretation of the current source file (FLOAD).
        // Drains rest of current line (so anything after \S on the line is ignored).
        // If used from the console (loadNesting==0), the stop has no effect (no-op),
        // but rest of the line is still drained for consistency.
        // Immediate so it takes effect as soon as seen on a line during load.
        _ = register("\\S", immediate: true) {
            if self.loadNesting > 0 {
                // Drain rest of line so anything after \S on the source line is ignored.
                while !self.inputQueue.isEmpty {
                    let c = self.inputQueue.removeFirst()
                    if c == 10 || c == 13 { break }
                }
                self.sourceLoadStop = true
            }
            // else (console): do absolutely nothing — per spec "does nothing when interpreting"
        }

        // Basic comparison words users expect immediately
        equalsID = register("=")  { let b = self.pop(); let a = self.pop(); self.push(a == b ? -1 : 0) }
        lessThanID = register("<")  { let b = self.pop(); let a = self.pop(); self.push(a <  b ? -1 : 0) }
        _ = register(">")  { let b = self.pop(); let a = self.pop(); self.push(a >  b ? -1 : 0) }
        _ = register("0=") { let a = self.pop(); self.push(a == 0 ? -1 : 0) }
        _ = register("0<") { let a = self.pop(); self.push(a <  0 ? -1 : 0) }
        _ = register("0>") { let a = self.pop(); self.push(a >  0 ? -1 : 0) }

        // A couple of stack words that are used constantly in examples
        _ = register("?DUP") { let v = self.pop(); self.push(v); if v != 0 { self.push(v) } }
        _ = register("ROT")  {
            let c = self.pop(); let b = self.pop(); let a = self.pop()
            self.push(b); self.push(c); self.push(a)
        }

        // Stack inspection — extremely useful while developing
        _ = register(".S") {
            let depth = Int(self.spGet() - 1)
            self.tell("<\(depth)> ")
            for i in 0..<depth {
                let val = self.readCell(self.stackBase + i * self.CELL_SIZE)
                self.tell("\(val) ")
            }
            self.putkey(10)
        }

        // Debug output control (default is off)
        _ = register("DEBUG-ON")  { self.debugEnabled = true }
        _ = register("DEBUG-OFF") { self.debugEnabled = false }

        // === Additional words from help data (ported from GrokForthApp) to satisfy HELP ===
        onePlusID = register("1+") { let a = self.pop(); self.push(a + 1) }
        _ = register("1-") { let a = self.pop(); self.push(a - 1) }
        _ = register("ABS") { let a = self.pop(); self.push( a < 0 ? -a : a ) }
        _ = register("NEGATE") { let a = self.pop(); self.push( -a ) }
        _ = register("MIN") { let b = self.pop(); let a = self.pop(); self.push( a < b ? a : b ) }
        _ = register("MAX") { let b = self.pop(); let a = self.pop(); self.push( a > b ? a : b ) }
        _ = register("AND") { let b = self.pop(); let a = self.pop(); self.push( a & b ) }
        _ = register("OR") { let b = self.pop(); let a = self.pop(); self.push( a | b ) }
        _ = register("XOR") { let b = self.pop(); let a = self.pop(); self.push( a ^ b ) }
        _ = register("INVERT") { let a = self.pop(); self.push( ~a ) }
        _ = register("LSHIFT") { let sh = self.pop(); let a = self.pop(); self.push( a << sh ) }
        _ = register("RSHIFT") { let sh = self.pop(); let a = self.pop(); self.push( a >> sh ) }
        _ = register("ARSHIFT") { let sh = self.pop(); let a = self.pop(); self.push( a >> sh ) }

        toR_ID = register(">R") { self.rpush( self.pop() ) }
        rFrom_ID = register("R>") { self.push( self.rpop() ) }
        rAt_ID = register("R@") {
            let rs = self.rspGet()
            if rs < 2 { self.tell("? Return stack underflow\n"); self.errorFlag = true; self.push(0); return }
            self.push( self.readCell( self.rstackBase + (rs - 2) * 8 ) )
        }
        _ = register("2>R") { let n2 = self.pop(); let n1 = self.pop(); self.rpush(n1); self.rpush(n2) }
        _ = register("2R>") { let n2 = self.rpop(); let n1 = self.rpop(); self.push(n1); self.push(n2) }
        _ = register("2R@") {
            let rs = self.rspGet()
            if rs < 3 { self.tell("? Return stack underflow\n"); self.errorFlag = true; self.push(0); self.push(0); return }
            let n2 = self.readCell(self.rstackBase + (rs-2)*8 )
            let n1 = self.readCell(self.rstackBase + (rs-3)*8 )
            self.push(n1); self.push(n2)
        }

        _ = register("PICK") {
            let n = Int(self.pop())
            if n < 0 { self.push(0); return }
            var saved: [Cell] = []
            for _ in 0...n { saved.append( self.pop() ) }
            let picked = saved[n]
            for i in (0..<saved.count).reversed() { self.push( saved[i] ) }
            self.push( picked )
        }
        _ = register("ROLL") {
            let n = Int(self.pop())
            if n <= 0 { return }
            var saved: [Cell] = []
            for _ in 0...n { saved.append( self.pop() ) }
            let rolled = saved[n]
            for i in (0..<n).reversed() { self.push( saved[i] ) }
            self.push( rolled )
        }
        _ = register("TUCK") { let b = self.pop(); let a = self.pop(); self.push(b); self.push(a); self.push(b) }
        _ = register("NIP") { let b = self.pop(); _ = self.pop(); self.push(b) }

        _ = register("2@") {
            let a = Int(self.pop())
            let x2 = self.readCell(a)
            let x1 = self.readCell(a + 8)
            self.push(x1); self.push(x2)
        }
        _ = register("2!") {
            let a = Int(self.pop())
            let x2 = self.pop()
            let x1 = self.pop()
            self.writeCell(a, x1)
            self.writeCell(a + 8, x2)
        }

        _ = register("CELL+") { let a = self.pop(); self.push(a + 8) }
        _ = register("CELLS") { let n = self.pop(); self.push(n * 8) }
        _ = register("CHAR+") { let a = self.pop(); self.push(a + 1) }
        _ = register("CHARS") { let n = self.pop(); self.push(n ) } // bytes here are 1:1 with cells? for char addr units
        _ = register("-!") { let a = Int(self.pop()); let n = self.pop(); let old = self.readCell(a); self.writeCell(a, old - n) }

        _ = register("WITHIN") {
            let hi = self.pop(); let lo = self.pop(); let n = self.pop()
            self.push( (lo <= n && n < hi) ? -1 : 0 )
        }

        _ = register("SPACES") { let n = Int(self.pop()); for _ in 0..<n { self.putkey(32) } }
        _ = register("U.") {
            let v = self.pop()
            let u = UInt64( bitPattern: Int64(v) )
            self.tell( String(u) ); self.putkey(32)
        }
        _ = register("U.R") {
            let wid = Int(self.pop())
            let v = self.pop()
            let u = UInt64( bitPattern: Int64(v) )
            var s = String(u)
            if s.count < wid { s = String(repeating: " ", count: wid - s.count) + s }
            self.tell(s)
        }
        _ = register("TYPE") {
            let len = Int(self.pop())
            let addr = Int(self.pop())
            for i in 0..<len {
                self.putkey( self.readByte(addr + i) )
            }
        }

        _ = register("MOD") {
            let b = self.pop(); let a = self.pop()
            if b == 0 { self.tell("? Division by zero\n"); self.errorFlag = true; self.push(0); return }
            self.push( a % b )
        }

        _ = register("ALLOT") { let n = self.pop(); let h = self.readCell(self.HERE); self.writeCell(self.HERE, h + n) }

        _ = register("CHAR") {
            let w = self.parseWord()
            if w.isEmpty { self.push(0); return }
            self.push( Int( w.utf8.first ?? 0 ) )
        }

        // === Full implementation of counted loops: DO ... LOOP / +LOOP , ?DO, I, UNLOOP, LEAVE ===
        // These use the return stack to hold (limit, index) with index on top.
        // DO/?DO/LOOP/+LOOP/LEAVE are immediate (compile-time actions that emit threaded code + placeholders).
        // I and UNLOOP are runtime primitives.
        // Internal helpers (DO) (?DO) (LOOP) (+LOOP) are also registered so decompile/SEE shows them nicely.

        let doSetupID = register("(DO)") {
            let start = self.pop()
            let limit = self.pop()
            self.rpush(limit)
            self.rpush(start)
        }

        let qdoSetupID = register("(?DO)") {
            let start = self.pop()
            let limit = self.pop()
            if start == limit {
                // skip the loop body: consume offset that follows in threaded code and branch forward
                let offset = self.readCell(self.ip)
                self.ip += 8
                self.ip += offset
                if self.ip < 0 || self.ip + 8 > self.memory.count {
                    self.tell("? Bad branch target (ip=\(self.ip)) after ?DO\n")
                    self.errorFlag = true
                }
            } else {
                self.rpush(limit)
                self.rpush(start)
                // skip the inline offset cell (used only in the skip case)
                self.ip += 8
            }
        }

        let loopID = register("(LOOP)") {
            // offset cell follows this in threaded code (back to body start)
            let backOffset = self.readCell(self.ip)
            self.ip += 8
            // rstack: ... limit index(top)
            let index = self.rpop()
            let limit = self.rpop()
            let newIndex = index + 1
            if newIndex < limit {
                self.rpush(limit)
                self.rpush(newIndex)
                self.ip += backOffset
                if self.ip < 0 || self.ip + 8 > self.memory.count {
                    self.tell("? Bad branch target (ip=\(self.ip)) after (LOOP)\n")
                    self.errorFlag = true
                }
            } else {
                // fall through to after LOOP; params already dropped by the rpops
            }
        }

        let plusLoopID = register("(+LOOP)") {
            let delta = self.pop()
            let backOffset = self.readCell(self.ip)
            self.ip += 8
            let index = self.rpop()
            let limit = self.rpop()
            let newIndex = index + delta
            let continueLoop = (delta >= 0) ? (newIndex < limit) : (newIndex > limit)
            if continueLoop {
                self.rpush(limit)
                self.rpush(newIndex)
                self.ip += backOffset
                if self.ip < 0 || self.ip + 8 > self.memory.count {
                    self.tell("? Bad branch target (ip=\(self.ip)) after (+LOOP)\n")
                    self.errorFlag = true
                }
            } else {
                // fall out, params dropped
            }
        }

        // I -- current loop index (top item on rstack for active DO loop)
        _ = register("I") {
            let rs = self.rspGet()
            if rs < 2 {
                self.tell("? Return stack underflow\n")
                self.errorFlag = true
                self.push(0)
                return
            }
            self.push( self.readCell( self.rstackBase + (rs - 2) * 8 ) )
        }

        // UNLOOP -- drop the current loop's limit+index from rstack (no branch)
        let unloopID = register("UNLOOP") {
            let rs = self.rspGet()
            if rs < 3 {
                self.tell("? Return stack underflow\n")
                self.errorFlag = true
                return
            }
            self.rspSet(rs - 2)
        }

        // LEAVE -- compile-time: emit unconditional branch to after the matching LOOP (patched by LOOP)
        _ = register("LEAVE", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? LEAVE only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            self.push(unloopID); self.comma()  // ensure rstack loop params dropped at runtime before branching out
            self.push(self.branchID); self.comma()
            let placeholderAddr = self.readCell(self.HERE)
            self.push(0); self.comma()
            self.loopControlStack.append(placeholderAddr)  // leave for LOOP to resolve to after-loop addr (like a LEAVE ph)
        }

        // DO -- compile time immediate: emit setup, record body dest + leave sentinel on compile stack
        _ = register("DO", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? DO only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            self.push(doSetupID); self.comma()
            let dest = self.readCell(self.HERE)  // body starts right after setup
            self.loopControlStack.append(dest)
            self.loopControlStack.append(0)  // sentinel for leave/?DO placeholders (0 means end of list)
        }

        // ?DO -- like DO but skips body (and consumes limit/start) if start==limit
        _ = register("?DO", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? ?DO only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            self.push(qdoSetupID); self.comma()
            let phAddr = self.readCell(self.HERE)
            self.push(0); self.comma()
            let dest = self.readCell(self.HERE)  // body starts after the ph cell for skip branch
            // append so collect gets: ... phs , 0 , dest   (phs after 0 get collected first)
            self.loopControlStack.append(dest)
            self.loopControlStack.append(0)
            self.loopControlStack.append(phAddr)
        }

        // LOOP -- compile time: emit (LOOP) + back offset, resolve any pending LEAVE/?DO phs to after
        _ = register("LOOP", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? LOOP only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            var leavePhs: [Cell] = []
            while !self.loopControlStack.isEmpty {
                let x = self.loopControlStack.removeLast()
                if x == 0 { break }
                leavePhs.append(x)
            }
            let dest = self.loopControlStack.removeLast()
            self.push(loopID); self.comma()
            let here = self.readCell(self.HERE)
            let offset = dest - (here + 8)
            self.push(offset); self.comma()
            let afterLoop = self.readCell(self.HERE)
            for ph in leavePhs {
                let fwdOff = afterLoop - (ph + 8)
                self.writeCell(Int(ph), fwdOff)
            }
        }

        // +LOOP -- like LOOP but delta from stack at runtime
        _ = register("+LOOP", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? +LOOP only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            var leavePhs: [Cell] = []
            while !self.loopControlStack.isEmpty {
                let x = self.loopControlStack.removeLast()
                if x == 0 { break }
                leavePhs.append(x)
            }
            let dest = self.loopControlStack.removeLast()
            self.push(plusLoopID); self.comma()
            let here = self.readCell(self.HERE)
            let offset = dest - (here + 8)
            self.push(offset); self.comma()
            let afterLoop = self.readCell(self.HERE)
            for ph in leavePhs {
                let fwdOff = afterLoop - (ph + 8)
                self.writeCell(Int(ph), fwdOff)
            }
        }

        // ON / OFF — set a variable (addr) to 1 or 0. Used e.g. with file-echo.
        _ = register("ON") {
            let addr = Int(self.pop())
            self.writeCell(addr, 1)
        }
        _ = register("OFF") {
            let addr = Int(self.pop())
            self.writeCell(addr, 0)
        }

        // FLOAD <name> — load and interpret/compile a text file as Forth source.
        // - Adds .fth if no extension.
        // - Resolves relative names against currentDirectoryPath.
        // - If no name given, sets fileLoadRequested so host can show dialog.
        _ = register("FLOAD") {
            self.validateAndRepairSystemState()
            let spec = self.parseWord()
            if spec.isEmpty {
                self.fileLoadRequested = true
                self.onFileLoadRequested?()
                return
            }
            self.resolveAndLoadFile(spec: spec)
        }

        // EDIT <name|dialog> — open in the system default text editor (TextEdit or user-chosen app for the type).
        // - No name: sets fileEditRequested so host shows NSOpenPanel (starting at current dir, like FLOAD).
        //   On pick: host opens the file via NSWorkspace, chdirs to its parent folder (so CHDIR/DIR/relative
        //   FLOAD/EDIT etc. now use that folder), and persists it for next launch.
        // - With name: resolves (same .fth auto-ext, ~, cwd-relative rules as FLOAD), sets pending so host
        //   post-processing opens it in editor + updates cwd.
        // This lets you navigate + pick a bad source file (e.g. one full of old cruft that would crash/hang
        // on FLOAD) and edit it externally first, without ever feeding its contents to the interpreter.
        // After editing/saving the file, you can FLOAD the cleaned version.
        _ = register("EDIT") {
            self.validateAndRepairSystemState()
            let spec = self.parseWord()
            if spec.isEmpty {
                self.fileEditRequested = true
                self.onFileEditRequested?()
                return
            }
            self.resolveAndEditFile(spec: spec)
        }

        // CHDIR — with no arg: display current directory. With <path>: change to it (supports ~, relative).
        _ = register("CHDIR") {
            self.validateAndRepairSystemState()
            let spec = self.parseWord()
            self.changeDirectory(spec: spec)
        }

        // DIR — with no arg: list current dir. With <path><filespec>: list matching files in that path
        // (supports * and ? wildcards, ~, relative paths).
        _ = register("DIR") {
            self.validateAndRepairSystemState()
            let spec = self.parseWord()
            self.listDirectory(spec: spec)
        }

        // === Utility words ported/adapted from GrokForth style ===

        _ = register("CLS") {
            self.clearScreenRequested = true
        }

        _ = register("WORDS") {
            self.validateAndRepairSystemState()

            // Collect kernel (internal) words vs user-defined words.
            // Kernel = everything that existed at the end of bootstrap (kernelLatest).
            var kernelWords: [(name: String, header: Cell)] = []
            var userWords:   [(name: String, header: Cell)] = []

            var link = self.readCell(self.LATEST)
            var safety = 0
            while link != 0 && safety < 10000 {
                safety += 1
                if !self.isValidDictionaryLink(link) { break }

                let flagsLen = self.readByte(Int(link) + 8)
                let len = Int(flagsLen & self.MASK_NAMELENGTH)
                var nameBytes: [UInt8] = []
                for i in 0..<len {
                    nameBytes.append(self.readByte(Int(link) + 9 + i))
                }
                let name = String(bytes: nameBytes, encoding: .utf8) ?? "???"

                if link <= self.kernelLatest {
                    kernelWords.append((name, link))
                } else {
                    userWords.append((name, link))
                }
                link = self.readCell(link)
            }

            // Internal words first, in alphabetic order (case-insensitive)
            kernelWords.sort { $0.name.uppercased() < $1.name.uppercased() }

            // User words in "compile order" = chronological definition order.
            // We walked the chain backwards (newest first), so reverse to get oldest-user-first.
            userWords.reverse()

            // Print kernel section
            var count = 0
            for (name, _) in kernelWords {
                self.tell(name + " ")
                count += 1
                if count % 8 == 0 { self.putkey(10) }
            }
            if count % 8 != 0 { self.putkey(10) }

            // Then user words (in the order the user actually defined them)
            for (name, _) in userWords {
                self.tell(name + " ")
                count += 1
                if count % 8 == 0 { self.putkey(10) }
            }
            if count % 8 != 0 { self.putkey(10) }
        }

        _ = register("FORGET") {
            // The user-facing, classic "FORGET NAME" parsing word.
            // (The high-level >LFA-based version is available as FORGET-WORD for teaching.)
            self.validateAndRepairSystemState()

            let name = self.parseWord().uppercased()
            if name.isEmpty {
                self.tell("? FORGET needs a name\n")
                self.errorFlag = true
                return
            }

            var link = self.readCell(self.LATEST)
            var prev: Cell = 0
            var safety = 0
            while link != 0 && safety < 10000 {
                safety += 1
                if !self.isValidDictionaryLink(link) { break }

                let flagsLen = self.readByte(Int(link) + 8)
                let len = Int(flagsLen & self.MASK_NAMELENGTH)
                var nameBytes: [UInt8] = []
                for i in 0..<len {
                    nameBytes.append(self.readByte(Int(link) + 9 + i))
                }
                let wname = String(bytes: nameBytes, encoding: .utf8) ?? ""
                if wname.uppercased() == name {
                    // Safety: do not allow FORGET to remove kernel primitives.
                    if link <= self.kernelLatest {
                        self.tell("? Cannot FORGET kernel word '\(name)'\n")
                        self.errorFlag = true
                        return
                    }

                    // Truncate the dictionary: everything from this header onward is forgotten.
                    // Because all dictionary walkers now use only alignment + buffer-bounds checks
                    // (plus kernelLatest guard and iteration limits), it is now safe to also
                    // restore HERE. This reclaims the memory used by the forgotten word(s).
                    //
                    // Headers are allocated at increasing addresses. The header at 'link'
                    // is the first thing we want to reclaim, so new HERE = link.
                    let newLatest: Cell
                    if prev == 0 {
                        // The word being forgotten is the current head of the dictionary.
                        // Its link field already points at the previous (older) word.
                        newLatest = self.readCell(link)
                    } else {
                        newLatest = prev
                    }
                    self.writeCell(self.LATEST, newLatest)
                    self.writeCell(self.HERE, link)   // reclaim memory from this header forward

                    // Extra defensive repair after modifying critical system variables.
                    self.validateAndRepairSystemState()
                    return
                }
                prev = link
                link = self.readCell(link)
            }
            self.tell("? \(name) ?\n")
            self.errorFlag = true
        }

        _ = register("HELP") {
            self.validateAndRepairSystemState()
            let name = self.parseWord().uppercased()
            if name.isEmpty {
                self.tell("HELP <word>\n")
                return
            }
            let lookupName = name.trimmingCharacters(in: .whitespaces)
            let hdr = self.findWord(lookupName)
            if hdr == 0 {
                self.tell("? \(lookupName) ?\n")
                return
            }
            // First the SEE/decompile (using shared helper)
            self.printDecompiled(name: lookupName, hdr: hdr)
            // Then the HELP information on the next line
            if let info = Self.primitiveHelp[lookupName] {
                self.tell("\(lookupName)  \(info.stack)  \(info.desc)\n")
            }
        }

        _ = register("SEE") {
            self.validateAndRepairSystemState()
            let name = self.parseWord().uppercased()
            if name.isEmpty {
                self.tell("SEE <name>\n")
                return
            }
            let hdr = self.findWord(name)
            if hdr == 0 {
                self.tell("? \(name) ?\n")
                return
            }

            self.printDecompiled(name: name, hdr: hdr)
            // Make SEE also a synonym of the combined HELP: append help info if available
            if let info = Self.primitiveHelp[name] {
                self.tell("\(name)  \(info.stack)  \(info.desc)\n")
            }
        }

        // === Additional utility words from old GrokForth style ===

        _ = register("DEPTH") {
            let depth = Int(self.spGet() - 1)
            self.push(Cell(depth))
        }

        _ = register("HEX")     { self.writeCell(self.BASE, 16) }
        _ = register("DECIMAL") { self.writeCell(self.BASE, 10) }
        _ = register("OCTAL")   { self.writeCell(self.BASE, 8) }
        _ = register("BINARY")  { self.writeCell(self.BASE, 2) }

        _ = register("RESET") {
            self.resetToSafeState()
            self.clearScreenRequested = true
        }

        // BYE — quit the host application
        _ = register("BYE") {
            self.quitRequested = true
            self.onQuitRequested?()
        }

        // Simple DUMP ( addr u -- )  prints u cells starting at addr
        _ = register("DUMP") {
            let u = Int(self.pop())
            var addr = Int(self.pop())
            for i in 0..<u {
                if i > 0 && i % 8 == 0 { self.putkey(10) }
                let val = self.readCell(addr)
                self.tell(String(format: "%016llx ", UInt64(bitPattern: Int64(val))))
                addr += 8
            }
            self.putkey(10)
        }

        // .(  immediate — print characters until )
        _ = register(".(", immediate: true) {
            while !self.inputQueue.isEmpty {
                let c = self.inputQueue.removeFirst()
                if c == 41 { break } // ')'
                self.putkey(c)
            }
        }

        // Simple CONSTANT (enough for education)
        _ = register("CONSTANT") {
            let name = self.parseWord()
            if name.isEmpty { self.errorFlag = true; return }
            let value = self.pop()
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            self.push(value); self.comma()
            self.push(self.exitID); self.comma()
        }

        // VARIABLE (very simple)
        _ = register("VARIABLE") {
            let name = self.parseWord()
            if name.isEmpty { self.errorFlag = true; return }
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            // After docol + LIT we are at the value slot V. The EXIT will live at V+8, so the
            // var's data cell lives at V+16. Store that address as the literal so the var
            // word (when executed) pushes the correct data address.
            let dataAddr = self.readCell(self.HERE) + 16
            self.push(dataAddr); self.comma()
            self.push(self.exitID); self.comma()
            // allocate one cell of data space (advances the dict pointer past the data cell)
            self.writeCell(self.HERE, self.readCell(self.HERE) + 8)
        }

        // CREATE ( "<spaces>name" -- )  ANS 2012
        // Create a word "name" whose execution semantics are to push its data-field address.
        // The data field starts at the current HERE after CREATE (user can then , ALLOT etc.).
        // Used together with DOES> for defining words.
        _ = register("CREATE") {
            let name = self.parseWord()
            if name.isEmpty { self.tell("? CREATE needs a name\n"); self.errorFlag = true; return }
            self.createWord(name: name, immediate: false)

            // Set up the runtime for this new child word (two cells after header):
            //   <createRuntimeID>
            //   <dataAddr value>     (the PFA we will push)
            // Data field starts after these two cells (HERE left there for user , ALLOT).
            let dataAddr = self.readCell(self.HERE) + 16
            self.push(self.createRuntimeID); self.comma()
            self.push(dataAddr); self.comma()
            // HERE is now at the data field start. No extra ALLOT (unlike VARIABLE).
        }

        // DOES> ( -- )  ANS 2012  (immediate)
        // Modify the most recently defined word (which must have been created by CREATE)
        // so that when it is executed it will push its data field address and then
        // execute the code following this DOES> .
        _ = register("DOES>", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? DOES> only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            // Compile into the current definition (the parent):
            //   LIT <doesCodeAddr>
            //   (DOES>)     -- the patch primitive
            // The does code (user's code after DOES>) will be compiled by the normal loop right after this.
            self.push(self.litID); self.comma()
            let placeholder = self.readCell(self.HERE)
            self.push(0); self.comma()
            self.push(self.doesPatchID); self.comma()

            // The does code starts at the current HERE.
            let doesCodeAddr = self.readCell(self.HERE)
            self.writeCell(Int(placeholder), doesCodeAddr)

            // The user's code after DOES> (e.g. @ or more) continues to be compiled here
            // into the parent's body. At runtime of the parent the (DOES>) patch will
            // return early (via rpop) so the does code is not executed in the parent's context.
        }
    }

    // Bootstrap the words that the original put in the init script but that we need
    // for the absolute minimum useful system (we will expand this).
    private func bootstrapMinimalDictionary() {
        // We already have : ; . CR + - * etc. from registerCorePrimitives.

        // Create a QUIT that just keeps running the outer interpreter.
        // In this minimal version we don't actually define QUIT as a Forth word;
        // the Swift driver calls runInterpreter() directly.
        // We still record where a "QUIT" word would live if someone wants to see it.

        // For teaching purposes, let's also define a few classic words by compiling them.

        // TRUE FALSE
        defineConstant("TRUE", -1)
        defineConstant("FALSE", 0)

        // BL
        defineConstant("BL", 32)

        // === High-level dictionary traversal words (for proper FORGET etc.) ===

        // >HEADER ( xt -- header ) is a primitive (see registration above).
        // It searches the dictionary and returns the start of the header
        // (the link field address) for the word with that code field address.
        // This is the key traversal word from CFA back toward NFA/LFA.

        // >LFA is an alias (in this header layout the link field is at the
        // very start of the header, so >HEADER is effectively >LFA).
        self.feedLine(": >LFA >HEADER ;")

        // Teaching version: a minimal high-level FORGET that assumes an xt is already
        // on the stack (from a preceding tick). We deliberately give it a different
        // name so it does *not* shadow the user-friendly parsing primitive FORGET
        // (the one registered above that accepts "FORGET NAME" directly and also
        // restores HERE to reclaim memory).
        // Users normally just type:   FORGET TEST
        // The primitive version has the kernelLatest safety guard and good errors.
        // Advanced / teaching usage:  ' TEST FORGET-WORD
        self.feedLine(": FORGET-WORD >LFA @ LATEST ! ;")

        // file-echo variable (user can do: file-echo ON   or   file-echo OFF ).
        // Controls whether FLOAD echoes each source line to the console as it loads.
        // Created via the VARIABLE word so it appears in WORDS / SEE / FORGET etc.
        // Default is 0 (off) because the data cell lives in the zeroed memory area.
        self.feedLine("VARIABLE FILE-ECHO")

        // Capture the data address of FILE-ECHO by walking its colon body (DOCOL LIT <addr> EXIT).
        // This lets FLOAD check it quickly without repeated dictionary lookup or tick+exec.
        let hdr = self.findWord("FILE-ECHO")
        if hdr != 0 {
            let cfa = self.getCFA(hdr)
            if self.readCell(Int(cfa)) == self.docolID {
                if self.readCell(Int(cfa) + 8) == self.litID {
                    self.fileEchoAddr = self.readCell(Int(cfa) + 16)
                }
            }
        }
        if self.fileEchoAddr == 0 {
            // Fallback (should never happen): allocate a cell now.
            self.fileEchoAddr = self.readCell(self.HERE)
            self.writeCell(self.HERE, self.fileEchoAddr + 8)
        }

        // We can add more high-level words later by feeding source once we have WORD, FIND, etc.
    }

    private func defineConstant(_ name: String, _ value: Cell) {
        createWord(name: name, immediate: false)
        self.push(docolID); self.comma()
        self.push(litID); self.comma()
        self.push(value); self.comma()
        self.push(exitID); self.comma()
    }

    // MARK: - Outer interpreter (the heart of the REPL)

    private func runInterpreter() {
        validateAndRepairSystemState()
        errorFlag = false

        while !inputQueue.isEmpty && !errorFlag && !exitReq {
            let name = parseWord()
            if name.isEmpty { break }

            let hdr = findWord(name)
            if hdr != 0 {
                let cfa = getCFA(hdr)
                let first = readCell(Int(cfa))

                let compiling = readCell(STATE) != 0
                let immediate = (readByte(Int(hdr) + 8) & FLAG_IMMEDIATE) != 0

                if compiling && !immediate {
                    // Compile either the small ID or the address
                    if first < Cell(MAX_BUILTIN_ID) && first != docolID {
                        self.push(first); self.comma()
                    } else {
                        self.push(cfa); self.comma()
                    }
                } else {
                    // Execute
                    execute(cfa: cfa, firstCell: first)
                    if waitingForKey {
                        // A blocking input word (currently only KEY) has suspended.
                        // Break out of the line interpreter so control returns to the UI.
                        // The UI will later call provideKey when the user supplies a character.
                        break
                    }
                }
            } else {
                // Try number
                if let num = Int(name) {
                    if readCell(STATE) != 0 {
                        self.push(litID); self.comma()
                        self.push(num); self.comma()
                    } else {
                        push(num)
                    }
                } else {
                    if readCell(STATE) != 0 {
                        tell("? \(name) ?  (while compiling)\n")
                    } else {
                        tell("? \(name)\n")
                    }
                    errorFlag = true
                }
            }
        }

        // Classic Forth behavior: after successfully interpreting a complete line
        // in interpret mode, print "OK" followed by newline.
        // (No leading space so that after ".s" or CR it doesn't look indented,
        // and after "." we get the single space that "." already emitted.)
        //
        // Do not print OK if we suspended for a blocking input word like KEY;
        // the OK will be printed when the line is resumed and completed after provideKey.
        if !errorFlag && readCell(STATE) == 0 && !waitingForKey {
            tell("OK\n")
        }

        // Do not clear errorFlag or do stack/STATE recovery here.
        // The caller (feedLine) will see errorFlag and call recoverFromError(),
        // which does a complete job (drain queue + abort partial definitions + reset).
    }

    private func parseWord() -> String {
        // Support \\ ... { block comments (can span lines in console REPL or during FLOAD).
        // Flag set by the \\ word (when it sees no '{' on its line); cleared when '{' found.
        if self.inSlashSlashComment {
            while !self.inputQueue.isEmpty {
                let c = self.inputQueue.removeFirst()
                if c == 123 { // '{'
                    self.inSlashSlashComment = false
                    break
                }
            }
            if self.inSlashSlashComment {
                // This entire line (and future feeds until {) is comment; stop word parsing for this feed.
                // (OK will still be emitted at end of this feedLine, consistent with \ and ( comments.)
                return ""
            }
        }

        // Skip whitespace
        while let b = inputQueue.first, b <= 32 {
            _ = inputQueue.removeFirst()
        }
        if inputQueue.isEmpty { return "" }

        var word: [UInt8] = []
        while let b = inputQueue.first, b > 32 {
            word.append(inputQueue.removeFirst())
        }

        var result = String(bytes: word, encoding: .utf8) ?? ""

        // Normalize *any* apostrophe-like characters (macOS smart quotes from the
        // `~ key or '" key, backtick, etc.) to plain ASCII '. This makes tick,
        // SEE, FORGET, :, and every other name-consuming word tolerant of real
        // keyboard input without requiring the user to hunt for the straight quote.
        // Examples of what users actually type on macOS:
        //   ‘ test     (curly instead of ' tick)
        //   see ‘
        //   ‘foo       (no space — becomes 'foo)
        if !result.isEmpty {
            result = String(result.map { isApostropheLike($0) ? "'" : $0 })
        }

        return result
    }

    private func execute(cfa: Cell, firstCell: Cell) {
        // If the first cell at the CFA is a small primitive ID, we dispatch directly.
        // Otherwise we treat the CFA as a threaded code address (colon definition).
        if firstCell < Cell(MAX_BUILTIN_ID), let body = primitives[Int(firstCell)] {
            // For primitives that are not DOCOL we just call them.
            // DOCOL is special: it sets up threading.
            if firstCell == docolID {
                // This is a colon definition. Push return address and start threading.
                rpush(ip)
                ip = Int(cfa) + 8   // skip the DOCOL cell
                if ip < 0 || ip + 8 > memory.count {
                    tell("? Bad colon definition target (cfa=\(cfa))\n")
                    errorFlag = true
                } else {
                    innerThread()
                }
            } else {
                self.currentCodeAddr = cfa
                self.dispatchedFromInnerThread = false
                body()
            }
        } else {
            // Not a primitive ID — assume threaded code
            rpush(ip)
            ip = Int(cfa)
            if ip < 0 || ip + 8 > memory.count {
                tell("? Bad execution target (cfa=\(cfa))\n")
                errorFlag = true
            } else {
                innerThread()
            }
        }
    }

    private func innerThread() {
        // Classic indirect-threaded / token-threaded inner interpreter
        var safety = 0
        let SAFETY_LIMIT = 100000
        while safety < SAFETY_LIMIT && !errorFlag && !exitReq {
            safety += 1

            let instrAddr = ip
            let cell = readCell(ip)
            ip += 8

            if errorFlag { break }

            // Hard IP bounds check — prevents following corrupted threaded code or wild branches
            // into completely invalid regions. readCell would catch it too, but this gives a clearer message.
            if ip < 0 || ip + 8 > memory.count {
                tell("? Invalid instruction pointer (ip=\(ip)) — possible corrupted threaded code or bad branch\n")
                errorFlag = true
                break
            }

            if cell >= 0 && cell < Cell(primitives.count),
               let f = primitives[Int(cell)] {
                self.currentCodeAddr = Cell(instrAddr)
                self.dispatchedFromInnerThread = true
                f()
                self.dispatchedFromInnerThread = false
                if waitingForKey {
                    // A blocking primitive (KEY) has decided to wait for host input.
                    // Rewind IP so the next innerThread() call will hit this cell again.
                    // In provideKey we will advance past it after injecting the value,
                    // so we do not re-execute the KEY primitive.
                    ip -= 8
                    break
                }
            } else if cell < Cell(MAX_BUILTIN_ID) {
                // A small integer that is not a registered primitive ID.
                // This usually means a branch or call landed on a data literal
                // (e.g. the "1" or "-16" in your looper example) and tried to
                // execute it as code. We turn it into a clean error instead of
                // a fatal array subscript trap.
                tell("? Invalid executable token \(cell) (not a registered primitive; possible bad branch offset)\n")
                errorFlag = true
            } else {
                // Treat as address of another colon definition (threaded call)
                rpush(ip)
                ip = Int(cell)
                if ip < 0 || ip + 8 > memory.count {
                    tell("? Bad threaded call target (ip=\(ip))\n")
                    errorFlag = true
                }
            }

            if ip == 0 { break }   // safety
        }

        if safety >= SAFETY_LIMIT && !errorFlag {
            tell("? Execution limit exceeded (possible infinite loop or very deep recursion)\n")
            errorFlag = true
        }
    }

    /// Shared decompiler used by both SEE and HELP.
    /// Prints the classic ": NAME body ;" or primitive form.
    private func printDecompiled(name: String, hdr: Cell) {
        self.tell(": " + name + " ")

        let cfa = self.getCFA(hdr)
        var ip = Int(cfa)

        let first = self.readCell(ip)

        if first == self.docolID {
            ip += 8
        } else if first < Cell(self.MAX_BUILTIN_ID) {
            if let pname = self.primitiveNames[first] {
                self.tell(pname + " (primitive) ;\n")
            } else {
                self.tell("primitive ID " + String(first) + " ;\n")
            }
            return
        } else {
            self.tell("??? ;\n")
            return
        }

        var safety = 0
        let MAX_CELLS = 4096
        while safety < MAX_CELLS {
            safety += 1

            if ip + 8 > self.memory.count { break }

            let cell = self.readCell(ip)
            ip += 8

            if cell == self.exitID {
                break
            }

            if let pname = self.primitiveNames[cell] {
                self.tell(pname + " ")
                continue
            }

            if cell == self.litID {
                if ip + 8 <= self.memory.count {
                    let val = self.readCell(ip)
                    ip += 8
                    self.tell("\(val) ")
                } else {
                    break
                }
                continue
            }

            var targetHeader = self.readCell(self.LATEST)
            var foundName: String? = nil
            var walkSafety = 0
            while targetHeader != 0 && walkSafety < 10000 {
                walkSafety += 1
                if !self.isValidDictionaryLink(targetHeader) { break }
                if self.getCFA(targetHeader) == cell {
                    let flagsLen = self.readByte(Int(targetHeader) + 8)
                    let len = Int(flagsLen & self.MASK_NAMELENGTH)
                    var nameBytes: [UInt8] = []
                    for i in 0..<len {
                        nameBytes.append(self.readByte(Int(targetHeader) + 9 + i))
                    }
                    foundName = String(bytes: nameBytes, encoding: .utf8)
                    break
                }
                targetHeader = self.readCell(targetHeader)
            }

            if let n = foundName {
                self.tell(n + " ")
            } else {
                self.tell("\(cell) ")
            }
        }

        self.tell(";\n")
    }

    // MARK: - Public helpers for the console / education

    /// Force the engine back to a known-good state.
    /// Stacks are emptied, errorFlag cleared, STATE forced to interpret mode.
    /// Safe to call from the host app (ConsoleView, tests) at any time.
    // Temp for debug
    public func debugFind(_ n: String) -> Bool { return findWord(n) != 0 }

    public func resetToSafeState() {
        validateAndRepairSystemState()   // extra belt-and-suspenders
        spSet(1)
        rspSet(1)
        errorFlag = false
        exitReq = false
        writeCell(STATE, 0)
        inputQueue.removeAll(keepingCapacity: true)
        debugEnabled = false   // return to clean default
        clearScreenRequested = false
        waitingForKey = false
        fileLoadRequested = false
        fileEditRequested = false
        pendingEditURL = nil
        loopControlStack.removeAll()
        self.inSlashSlashComment = false
        self.sourceLoadStop = false
        // Leave IP wherever it is; the next feedLine will start fresh parsing from
        // whatever input arrives next. Future improvement: point ip at a real QUIT
        // threaded-code sequence once we have one.
    }

    /// Called after any error (unknown word, bad branch, compile error, etc.).
    /// - Drains any leftover input from the bad line (fixes "stuff left in buffer").
    /// - If we were in the middle of a colon definition, aborts it cleanly
    ///   (unhides the partial word and forces interpret mode).
    /// - Resets stacks.
    private func recoverFromError() {
        validateAndRepairSystemState()

        // 1. Drain everything remaining from the current (bad) line.
        //    This is the main fix for "left over stuff in a buffer".
        inputQueue.removeAll(keepingCapacity: true)
        waitingForKey = false
        fileLoadRequested = false
        fileEditRequested = false
        pendingEditURL = nil
        loopControlStack.removeAll()
        self.inSlashSlashComment = false
        self.sourceLoadStop = false

        // 2. Error handling during compilation vs interpretation.
        //
        // When an error occurs *while compiling* a colon definition (STATE != 0),
        // we deliberately do NOT abort the definition. The partial word stays
        // hidden and STATE stays 1. This lets you continue typing lines and
        // they will keep being compiled into the same word. You can use the
        // per-line [DEBUG] output to watch stack + state after each line.
        //
        // Only when you successfully reach a line with ";" (or call
        // resetToSafeState / start a fresh definition) does the definition
        // finish or get abandoned.
        if readCell(STATE) != 0 {
            // Do NOT unhide or force STATE=0 here.
            // The definition remains open for further lines.
            tell("? Compile error — definition is still open.\n")
            tell("? Type more lines to continue it, or `;` alone to finish it.\n")
        } else {
            // Normal interpretation error — nothing special to do beyond
            // the stack reset below.
        }

        // 3. Aggressively force critical system variables sane.
        //    Previous bad branches / wild writes can trash SP/RSP/HERE/STATE/BASE.
        //    This + the per-operation checks below make the engine much harder to wedge.
        spSet(1)
        rspSet(1)
        let initialDict = rstackBase + RSTACK_SIZE * CELL_SIZE
        let h = readCell(HERE)
        if h < initialDict || h > MEM_SIZE - 1024 {
            writeCell(HERE, initialDict)
        }
        let b = readCell(BASE)
        if b < 2 || b > 36 { writeCell(BASE, 10) }

        errorFlag = false
    }

    /// Called proactively at the start of every feedLine / runInterpreter.
    /// This makes the engine extremely resistant to the kind of low-memory
    /// corruption (especially the SP/RSP cells) that manual bad branches and
    /// early control-flow experiments can cause. It prevents the repeated
    /// "Stack underflow (forcing SP sane)" messages during compilation that
    /// you are still seeing on the sign definition.
    private func validateAndRepairSystemState() {
        let spv = spGet()
        if spv < 1 || spv > Cell(STACK_SIZE) {
            spSet(1)
        }

        let rspv = rspGet()
        if rspv < 1 || rspv > Cell(RSTACK_SIZE) {
            rspSet(1)
        }

        let initialDict = rstackBase + RSTACK_SIZE * CELL_SIZE
        let h = readCell(HERE)
        if h < initialDict || h >= MEM_SIZE - 1024 {
            writeCell(HERE, initialDict)
        }
        // If the dictionary chain looks completely broken, reset LATEST too
        let l = readCell(LATEST)
        if l != 0 && !isValidDictionaryLink(l) {
            writeCell(LATEST, 0)
        }

        let st = readCell(STATE)
        if st != 0 && st != 1 {
            writeCell(STATE, 0)
        }

        let b = readCell(BASE)
        if b < 2 || b > 36 {
            writeCell(BASE, 10)
        }
    }

    public var stackAsString: String {
        let depth = Int(spGet() - 1)
        var s = ""
        for i in 0..<depth {
            let v = readCell(stackBase + i * 8)
            s += "\(v) "
        }
        return s
    }

    public var dictionarySnapshot: [(name: String, xt: Cell)] {
        var result: [(String, Cell)] = []
        var link = readCell(LATEST)
        var safety = 0
        while link != 0 && safety < 10000 {
            safety += 1
            if !isValidDictionaryLink(link) { break }
            let flagsLen = readByte(Int(link) + 8)
            let len = Int(flagsLen & MASK_NAMELENGTH)
            var nameBytes: [UInt8] = []
            for i in 0..<len {
                nameBytes.append(readByte(Int(link) + 9 + i))
            }
            let name = String(bytes: nameBytes, encoding: .utf8) ?? "???"
            result.append((name, link))
            link = readCell(link)
        }
        return result.reversed()
    }
}
