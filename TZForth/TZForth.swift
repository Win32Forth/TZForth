//
//  TZForth.swift
//  TZForth
//
//  A Swift port of the core ideas from Leif Bruder's lbForth (public domain).
//  https://gist.github.com/lbruder/10007431
//
//  Externally named TZForth to reflect the project; internally the implementation
//  model, comments and credits continue to respect the Leif Bruder lbForth origins.
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

//
// Public Domain Statement
//
// This software is released into the public domain.
// 
// TZForth is free and unencumbered software dedicated to the public domain.
// 
// The engine (class TZForth, file TZForth.swift) and related test harness
// are externally named to reflect the TZForth project and its author.
// Internally, this implementation respects its origins as a Swift port of
// the public-domain lbForth model and techniques by Leif Bruder (2014).

// Also, I want to credit the Grok Build AI for doing most of the work.
// while I ( Tom Zimmer Win32Forth@mac.com ) did pay for the use of Grok Build,
// I could never have ompleted this project without the invaluble assisstance
// of Grok Build. Now, at an age of almost 76, my memory and skills are not what
// they once were, back in the 80s and 90s, when I was producing so many of the
// Forth systems I am credited with creating. Those were good years, but they
// are behind me. Having the opportunity to participate in producing another
// complex Forth system in my retirement years has been very encouraging to me,
// and can be credited with helping me retain or recover some of the
// intelligence and skills I once had.

//Thank you Grok Build, this is definitely a great adventure!

// See: https://gist.github.com/lbruder/10007431
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
//

import Foundation

public final class TZForth {

    // MARK: - Configuration

    private let MEM_SIZE = 256 * 1024   // generous for a modern machine
    private let STACK_SIZE = 256
    private let RSTACK_SIZE = 128
    private let WORD_BUFFER_SIZE = 64
    private let WORD_BUFFER: Int = 256  // fixed buffer for WORD, before stacks at 1024
    private let SOURCE_BUFFER: Int = 320
    private let SOURCE_BUFFER_SIZE = 256
    private let PAD_BUFFER: Int = 576
    private let PAD_BUFFER_SIZE = 128
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
    internal var LATEST:  Int { 0 }  // internal so TZForthTests.swift (and combined.swift for FTEST) can access for runANSValidation snapshots
    internal var DP_ADDR: Int { 8 }   // address of the DP variable (the cell holding the current dictionary pointer value); internal for test harness in TZForthTests.swift
    private var STATE:   Int { 16 }
    private var BASE:    Int { 24 }
    private var SP:      Int { 32 }   // address for future "SP @" compatibility (the live pointer is in the Swift var below)
    private var RSP:     Int { 40 }
    internal var IN:       Int { 48 }   // >IN ( -- addr )  current offset in input source; internal for tests
    internal var CONTEXT: Int { 56 } // holds the addr of the head-cell for the current search vocabulary (e.g. 0 for FORTH); internal for test harness snapshots
    internal var CURRENT: Int { 64 } // holds the addr of the head-cell for the current definitions vocabulary; internal for test harness snapshots

    private let MAX_VOCABS = 8
    internal var searchOrder: [Cell] = []  // array of wl head-cell-addrs; [0] is top (first searched)

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

    var errorFlag = false   // internal (module-visible) so host can check after named load for bookmark decisions
    private var exitReq = false

    // Debug output control (per-line state + stack dump after each feedLine)
    private var debugEnabled = false

    /// Set by CLS. The ConsoleView should observe this after feedLine and clear the display.
    public var clearScreenRequested = false

    /// The value of LATEST right after all kernel primitives have been registered.
    /// FORGET is not allowed to truncate past this point.
    private var kernelLatest: Cell = 0

    /// The value of the dictionary pointer (at DP_ADDR) right after bootstrap (kernel + high-level
    /// bootstrap words like FILE-ECHO, >LFA, etc.). RESET and full clear restore the dictionary to this point.
    private var kernelHere: Cell = 0

    /// Logical current directory maintained for the Forth environment (used for CHDIR reports,
    /// relative FLOAD/EDIT/DIR resolution, etc.). In a sandboxed app, the underlying
    /// FileManager.currentDirectoryPath can become empty or stuck in the container after
    /// user CHDIR to paths without active security scope. We keep this logical view in sync
    /// with user CHDIR and host-authorized dirs (from dialogs/bookmarks) so that Forth
    /// sees a sensible cwd even if the process cwd is restricted.
    public var logicalCurrentDirectory: String = ""

    // Input
    private var inputQueue: [UInt8] = []
    private var wordBuffer = [UInt8](repeating: 0, count: 64)
    private var currentSourceLen: Int = 0  // length of current SOURCE buffer (set on each feedLine / EVALUATE)

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

    /// When FLOAD <name> (named form, not bare) resolves a file, this URL is set by the engine
    /// instead of loading immediately. The host (after feedLine returns, in post-processing)
    /// performs startAccessingSecurityScopedResource (required in sandboxed app), chdir to
    /// parent, persists LastFLOADDirectory, then calls loadFile(url) to actually read it.
    /// This mirrors the pendingEditURL mechanism for sandbox friendliness.
    public var pendingLoadURL: URL? = nil

    /// Optional callback fired after a successful CHDIR (host uses it to persist a
    /// security-scoped bookmark for the new directory if the current scope allows,
    /// so that named FLOAD/EDIT continue to work after chdir without re-picking).
    public var onDirectoryChanged: ((URL) -> Void)? = nil

    /// Host callback for sandboxed directory reads (DIR). Activates security-scoped access
    /// and returns a listable URL (canonical path), or nil when the folder is not authorized.
    public var ensureDirectoryAccess: ((URL) -> URL?)? = nil

    /// Set by bare CHDIR (no path). Host shows a folder picker starting at logical cwd.
    public var directoryPickRequested = false

    /// Optional callback when bare CHDIR requests the folder picker (non-ConsoleView hosts).
    public var onDirectoryPickRequested: (() -> Void)? = nil

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
    private var emitID: Cell = 0
    private var dotQuoteID: Cell = 0   // runtime ID for (." ) used by . " to embed compact string literals

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
        ("/",       "( n1 n2 -- quot )",  "division (quotient)"),
        ("*/MOD",   "( n1 n2 n3 -- rem quot )", "multiply then divmod"),
        ("M*",      "( n1 n2 -- d )",     "signed double multiply (low high)"),
        ("FM/MOD",  "( d n -- rem quot )", "floored divmod"),
        ("SM/REM",  "( d n -- rem quot )", "symmetric divmod"),
        ("U<",      "( u1 u2 -- flag )",  "unsigned less"),
        ("U>",      "( u1 u2 -- flag )",  "unsigned greater"),
        ("UM*",     "( u1 u2 -- ud )",    "unsigned double multiply"),
        ("UM/MOD",  "( ud u -- rem quot )", "unsigned divmod"),
        ("+!",      "( n addr -- )",      "add to memory"),
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
        ("HERE",    "( -- addr )",        "current dictionary pointer (value)"),
        ("LATEST",  "( -- addr )",        "latest dictionary header"),
        ("DP",      "( -- addr )",        "dictionary pointer variable address (HERE is DP @)"),
        ("STATE",   "( -- addr )",        "compilation state variable"),
        ("BASE",    "( -- addr )",        "current numeric base variable"),
        ("SP",      "( -- addr )",        "data stack pointer (SP @ for compatibility)"),
        ("RSP",     "( -- addr )",        "return stack pointer (RSP @ for compatibility)"),
        (">IN",     "( -- addr )",        "current input pointer variable ( >IN @ for offset)"),
        ("CONTEXT", "( -- addr )",        "current search vocabulary (addr of its head-cell)"),
        ("CURRENT", "( -- addr )",        "current definitions vocabulary (addr of its head-cell)"),
        ("SOURCE",  "( -- c-addr u )",    "current input source buffer and length"),
        ("PARSE",   "( char -- c-addr u )", "parse text from input up to char (leaves delim, updates >IN)"),
        ("PAD",     "( -- addr )",        "user scratch buffer (fixed, 128 bytes)"),
        ("QUIT",    "( -- )",             "empty return stack, set interpret state, return to outer interpreter"),
        ("SP!",     "( n -- )",           "set data stack pointer (updates both cell and internal)"),
        ("RSP!",    "( n -- )",           "set return stack pointer (updates both cell and internal)"),
        ("POSTPONE","( -- ) name",        "append compilation semantics of next word (immediate)"),
        ("[COMPILE]","( -- ) name",       "force compile of next word even if immediate (immediate)"),
        ("VOCABULARY","( -- ) name",      "create a new vocabulary"),
        ("FORTH",   "( -- )",             "select the FORTH vocabulary (sets top of search order)"),
        ("ALSO",    "( -- )",             "duplicate top of search order"),
        ("ONLY",    "( -- )",             "reset search order to only FORTH"),
        ("VOCABULARIES","( -- )",         "display current search order and current definitions vocab"),
        ("DEFINITIONS","( -- )",          "set CURRENT to CONTEXT (new words go to current vocab)"),
        (">NUMBER", "( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )", "convert string digits to number accumulating in ud"),
        ("ALLOT",   "( n -- )",           "allocate n bytes in dictionary"),
        (",",       "( n -- )",           "compile a cell"),
        ("FILL",    "( addr u b -- )",    "fill u bytes at addr with b"),
        ("MOVE",    "( addr1 addr2 u -- )", "copy u bytes"),
        ("ALIGN",   "( -- )",             "align DP to cell boundary"),
        ("ALIGNED", "( addr -- addr' )",  "next aligned address"),
        (">BODY",   "( xt -- addr )",     "data field of a CREATEd word"),
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
        ("ABORT",   "( -- )",             "clear stacks, return to interpreter"),
        ("ABORT\"", "( flag \"text\" -- )", "if flag, type message and ABORT (immediate)"),
        ("ACCEPT",  "( c-addr +n1 -- +n2 )", "read up to n1 chars from input into buffer"),
        ("<#",      "( -- )",             "begin pictured numeric output"),
        ("#",       "( ud -- ud )",       "add one digit to pictured output"),
        ("#S",      "( ud -- ud )",       "add all remaining digits to pictured"),
        ("#>",      "( ud -- c-addr u )", "end pictured numeric, return string"),
        ("HOLD",    "( char -- )",        "insert char into pictured output"),
        ("SIGN",    "( n -- )",           "insert minus sign if n<0 into pictured"),
        ("S\"",     "( -- c-addr u )",    "compile/interpret \"-delimited string (leaves addr u)"),
        
        // Comparisons
        ("=",       "( n1 n2 -- flag )",  "equal?"),
        ("<",       "( n1 n2 -- flag )",  "less than?"),
        (">",       "( n1 n2 -- flag )",  "greater than?"),
        ("0=",      "( n -- flag )",      "zero?"),
        ("0<",      "( n -- flag )",      "negative?"),
        ("<>",      "( n1 n2 -- flag )",  "not equal?"),
        
        // Dictionary & System
        ("WORDS",   "( -- )",             "list all words (kernel alpha, then user in order)"),
        ("SEE",     "( -- name )",        "decompile a word"),
        ("HELP",    "( -- ) name",        "show help for a word"),
        ("' ",      "( -- xt ) name",     "tick: get execution token of name"),
        ("EXECUTE", "( xt -- )",          "execute the word with the given xt"),
        ("EVALUATE","( i*x c-addr u -- j*x )", "interpret the string as Forth source"),
        ("ENVIRONMENT?","( c-addr u -- false | i*x true )", "query environment string"),
        (">NUMBER", "( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )", "convert string digits to number accumulating in ud"),
        ("FIND",    "( c-addr -- c-addr 0 | xt 1 | xt -1 )", "find word from counted string (from WORD)"),
        ("FORGET",  "( -- ) name",        "forget name and all words defined after it"),
        ("FORGET-WORD", "( xt -- )",      "forget using xt ( ' NAME FORGET-WORD )"),
        (">HEADER", "( xt -- header )",   "convert xt to header (starts with link field; name count+text at +8/+9)"),
        (">LFA",    "( xt -- lfa )",      "convert xt to link field (alias for >HEADER)"),
        (">NFA",    "( xt -- nfa )",      "convert xt to name field addr (flags+len byte; COUNT TYPE works for ordinary words)"),
        ("ID.",     "( xt -- )",          "print the name of the word given its xt (robust, masks flags from count)"),
        ("VARIABLE","( -- ) name",        "create a variable"),
        ("CONSTANT","( n -- ) name",      "create a constant"),
        ("CREATE",  "( -- ) name",        "create a word that pushes its data field address (for use with DOES>)"),
        ("DOES>",   "( -- )",             "modify last CREATE'd word to execute the following code with data addr on stack (immediate)"),
        ("IMMEDIATE","( -- )",            "mark latest word as immediate"),
        ("TRUE",    "( -- -1 )",          "true flag"),
        ("FALSE",   "( -- 0 )",           "false flag"),
        ("BL",      "( -- 32 )",          "blank character (space)"),
        ("DUMP",    "( addr u -- )",      "dump u cells starting at addr"),
        (".(",      "( -- )",             "print text until ) immediately (immediate)"),
        (".\"",     "( -- )",             "print text until \" (immediate)"),
        ("(",       "( -- )",             "comment until ) (immediate)"),
        ("DEBUG-ON","( -- )",             "enable per-line [DEBUG] state+stack output"),
        ("DEBUG-OFF","( -- )",            "disable per-line debug output"),
        ("RESET",   "( -- )",             "reset stacks + dictionary to kernel, state, clear screen"),
        ("CLS",     "( -- )",             "clear the console screen"),
        
        // Base
        ("HEX",     "( -- )",             "set BASE to 16"),
        ("DECIMAL", "( -- )",             "set BASE to 10"),
        ("OCTAL",   "( -- )",             "set BASE to 8"),
        ("BINARY",  "( -- )",             "set BASE to 2"),
        
        // Control flow (many are immediate)
        (":",       "( -- ) name",        "start colon definition"),
        (";",       "( -- )",             "end colon definition (immediate)"),
        ("RECURSE", "( -- )",             "recurse into current definition (immediate)"),
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
        ("J",       "( -- n )",           "outer DO loop index (for nested loops)"),
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
        ("<>",      "( n1 n2 -- flag )",  "not equal?"),
        ("U>",      "( u1 u2 -- flag )",  "unsigned greater"),
        
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
        ("2DROP",   "( n1 n2 -- )",       "drop two items"),
        ("2DUP",    "( n1 n2 -- n1 n2 n1 n2 )", "duplicate pair"),
        ("2OVER",   "( n1 n2 n3 n4 -- n1 n2 n3 n4 n1 n2 )", "copy second pair"),
        ("2SWAP",   "( n1 n2 n3 n4 -- n3 n4 n1 n2 )", "swap pairs"),
        ("S>D",     "( n -- d )",         "sign extend single to double"),
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
        ("CHAR",    "( -- c )",           "parse next word, return its first char"),
        ("WORD",    "( char -- addr )",   "parse input up to delimiter char, return addr of counted string (trailing blank appended)"),
        ("COUNT",   "( c-addr -- addr u )", "from counted string addr return char-addr and length"),

        // Core Extensions (6.2)
        ("0<>",     "( x -- flag )",      "true if not zero"),
        ("<>",      "( n1 n2 -- flag )",  "not equal"),
        ("U>",      "( u1 u2 -- flag )",  "unsigned greater"),
        ("ERASE",   "( addr u -- )",      "fill u bytes at addr with zero"),
        ("COMPILE,","( xt -- )",          "compile the execution token xt"),
        ("VALUE",   "( n -- ) name",      "create a value (mutable constant); set with IS or TO"),
        ("IS",      "( xt -- ) name",     "set the xt for a DEFER or the value for a VALUE (parsing)"),
        ("DEFER",   "( -- ) name",        "create a deferred word (execution can be changed)"),
        ("DEFER!",  "( xt1 xt2 -- )",     "set defer xt2 to execute xt1"),
        ("DEFER@",  "( xt1 -- xt2 )",     "get the xt that defer xt1 currently executes"),
        ("CASE",    "( -- )",             "start CASE structure (immediate)"),
        ("OF",      "( x x -- | x )",     "CASE of branch (immediate)"),
        ("ENDOF",   "( -- )",             "end of OF, branch to ENDCASE (immediate)"),
        ("ENDCASE", "( -- )",             "end CASE, resolve branches (immediate)"),

        // New for FLOAD / EDIT / file helpers (cwd + dialog driven by host for sandbox friendliness)
        ("\\",      "( -- )",             "comment to end of line (immediate)"),
        ("\\\\",    "( -- )",             "block comment to next '{' (spans lines; use \\ not single \\ for single-line comments) (immediate)"),
        ("\\S",     "( -- )",             "stop loading current file (no-op in console) (immediate)"),
        ("FLOAD",   "( -- ) name|dialog", "load .fth file (auto .fth if no ext in name; relative to cwd or abs/~; named uses host for sandbox scope+chdir; bare opens dialog)"),
        ("EDIT",    "( -- ) name|dialog", "open in system text editor (nav dialog or name; auto .fth fallback for bare names like FLOAD; updates cwd to file's folder; no load/interpret)"),
        ("FILE-ECHO","( -- addr )",       "variable controlling FLOAD source echo (use with ON/OFF)"),
        ("ON",      "( addr -- )",        "store 1 at addr (e.g. file-echo ON)"),
        ("OFF",     "( addr -- )",        "store 0 at addr (e.g. file-echo OFF)"),
        ("CHDIR",   "( -- ) path",        "change dir (no arg: folder picker at current); supports ~ and relative"),
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

    // Pictured numeric output (<# # #S #> HOLD SIGN) support
    private let PNO_BUFFER_SIZE = 128
    private var pnoBufferAddr: Int = 0
    private var pnoPtr: Int = 0

    private var executeID: Cell = 0  // captured ID for EXECUTE so POSTPONE can emit LIT xt EXECUTE for immediates
    private var fetchID: Cell = 0    // ID for @
    private var sQuoteID: Cell = 0   // runtime for (S") used by S" to embed compact string literals that leave c-addr u
    private var abortQuoteID: Cell = 0  // runtime for (ABORT")

    // MARK: - Init

    public init() {
        memory = Array(repeating: 0, count: MEM_SIZE)

        // Layout the fixed system variables
        stackBase = 1024
        rstackBase = stackBase + STACK_SIZE * CELL_SIZE

        // Initialize system variables
        writeCell(LATEST, 0)
        writeCell(DP_ADDR, rstackBase + RSTACK_SIZE * CELL_SIZE)   // initial value of the dictionary pointer (stored at DP_ADDR)
        writeCell(STATE, 0)
        writeCell(BASE, 10)
        writeCell(IN, 0)
        searchOrder = [LATEST]
        setContext(LATEST)
        writeCell(CURRENT, LATEST)
        searchOrder = [LATEST]

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

        // Record the end of the kernel dictionary (and HERE) so FORGET/RESET cannot
        // delete or go before the kernel + bootstrap words (TRUE, FILE-ECHO, >LFA, etc.).
        kernelLatest = readCell(LATEST)
        kernelHere = readCell(DP_ADDR)

        // Seed the interpreter IP at the QUIT code we just created
        ip = quitCodeAddress

        // Initial logical cwd (host may override via setup or after scoped chdirs)
        logicalCurrentDirectory = FileManager.default.currentDirectoryPath

        // Pictured numeric output buffer (high in mem, away from growing dictionary)
        pnoBufferAddr = MEM_SIZE - PNO_BUFFER_SIZE
        pnoPtr = pnoBufferAddr + PNO_BUFFER_SIZE

        // === Strong diagnostic after registration ===
        print("=== TZForth INIT DIAGNOSTICS ===")
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

    internal func readCell(_ addr: Int) -> Cell {  // internal to allow access from TZForthTests.swift extension for ANS validation
        if addr < 0 || addr + 8 > memory.count {
            tell("? Memory read out of range (addr=\(addr))\n")
            errorFlag = true
            return 0
        }
        return memory.withUnsafeBytes { $0.load(fromByteOffset: addr, as: Cell.self) }
    }

    internal func writeCell(_ addr: Int, _ value: Cell) {  // internal to allow access from TZForthTests.swift extension for ANS validation restore
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
    private func spSet(_ v: Cell) {
        dataStackPointer = v
        writeCell(SP, v)  // keep memory mirror for "SP @" compatibility and raw inspection
    }

    private func rspGet() -> Cell { returnStackPointer }
    private func rspSet(_ v: Cell) {
        returnStackPointer = v
        writeCell(RSP, v)  // keep memory mirror for "RSP @" compatibility and raw inspection
    }

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

    // Helper for number output that respects BASE (2..36). Used by ., U., U.R etc.
    // signed: true for . (handles negative with - sign), false for U. (treats Cell as unsigned)
    private func formatNumber(_ n: Cell, base: Cell, signed: Bool) -> String {
        let b = Int( max(2, min(36, base)) )
        if signed {
            return String(n, radix: b).uppercased()
        } else {
            let u = UInt64(bitPattern: Int64(n))
            return String(u, radix: b).uppercased()
        }
    }

    // Pictured numeric output helpers (build string backwards in pno buffer)
    private func startPictured() {
        pnoPtr = pnoBufferAddr + PNO_BUFFER_SIZE
    }

    private func picturedAddDigit(_ digit: Cell) {
        if pnoPtr <= pnoBufferAddr { return }
        pnoPtr -= 1
        let ch: UInt8 = (digit < 10) ? UInt8(48 + digit) : UInt8(55 + digit)  // 0-9, A-Z
        writeByte(pnoPtr, ch)
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

        // Prepare the SOURCE buffer and >IN for this line (supports SOURCE, PARSE, >IN tracking).
        // Each feedLine (REPL or per-line during FLOAD) becomes the "current input source".
        self.currentSourceLen = 0
        let lineBytes = Array(line.utf8)
        let n = min(lineBytes.count, SOURCE_BUFFER_SIZE)
        for i in 0..<n {
            self.writeByte(SOURCE_BUFFER + i, lineBytes[i])
        }
        self.currentSourceLen = n
        self.writeCell(self.IN, 0)

        for b in line.utf8 { inputQueue.append(b) }
        inputQueue.append(10) // \n

        runInterpreter()

        if errorFlag {
            recoverFromError()
        }

        // Optional per-line debug output (state + stack after each feedLine).
        // Enabled via DEBUG-ON / DEBUG-OFF. Default is off.
        // Changes take effect immediately, including for subsequent lines when
        // DEBUG-ON/OFF appears inside a file being FLOADed (live flag, checked after
        // each feedLine, independent of loadNesting).
        if debugEnabled {
            let stateStr = readCell(STATE) != 0 ? "compiling" : "interpreting"
            let depth = Int(spGet() - 1)
            tell("[DEBUG] state=\(stateStr)  stack=<\(depth)> \(stackAsString)\n")
        }

        // Ensure a clean IP (0 = top-level sentinel) after each top-level feed in
        // interpret mode. This prevents a dirty IP (leftover from errors, FLOAD
        // recursion, or previous bad threaded runs) from being rpush'ed as the
        // return frame for the *next* command line's colon executions.
        if readCell(STATE) == 0 && !waitingForKey {
            ip = 0
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
        // (e.g. nothing, or if somehow more) and print the "OK" if the line completed
        // (note: OK is suppressed for feeds that happen during FLOAD).
        runInterpreter()
    }

    // MARK: - FLOAD support (file loading / including source)

    /// Public entry point for the host to load a file after a dialog (or programmatically).
    /// Clears any pending request flag and processes the file's lines.
    public func loadFile(_ url: URL) {
        fileLoadRequested = false
        fileEditRequested = false
        pendingEditURL = nil
        pendingLoadURL = nil
        loadFileContents(url)
    }

    /// Public entry point for the host after EDIT dialog pick (or future programmatic).
    /// Just clears flags; the actual open-in-editor + chdir + persist is done by the host
    /// (in showFileEditDialog completion or post-feed handler) because it requires AppKit (NSWorkspace).
    public func editFile(_ url: URL) {
        fileEditRequested = false
        fileLoadRequested = false
        pendingEditURL = nil
        pendingLoadURL = nil
        // No load/interpret happens for EDIT — that's the point (edit bad sources safely before FLOAD).
    }

    /// Common resolution for FLOAD/EDIT specs (~ expansion, absolute vs relative to
    /// currentDirectoryPath). Factored to keep behavior identical. Auto .fth append for
    /// FLOAD (when leaf name has no dot) is handled in FLOAD's resolve path.
    private func resolvedURL(for spec: String) -> URL {
        let fm = FileManager.default
        let name = spec
        let url: URL
        if name.contains("/") || name.contains("\\") {
            if name.hasPrefix("~") {
                let expanded = (name as NSString).expandingTildeInPath
                url = URL(fileURLWithPath: expanded)
            } else {
                url = URL(fileURLWithPath: name)
            }
        } else {
            // Relative to current (logical) working directory (as specified).
            let cwd = logicalCurrentDirectory.isEmpty ? fm.currentDirectoryPath : logicalCurrentDirectory
            url = URL(fileURLWithPath: cwd).appendingPathComponent(name)
        }
        return url
    }

    private func resolveAndLoadFile(spec: String) {
        let url = resolvedURL(for: spec)
        // Defer actual load (and any .fth auto-fallback) to host + loadFileContents.
        // Host will scope + chdir + call loadFile.
        self.pendingLoadURL = url
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
        // Support FLOAD auto .fth: if the provided url's leaf has no dot, try the literal
        // name first; if it doesn't exist, fall back to name + ".fth". This lets
        // "fload foo" work whether the file is "foo" or "foo.fth".
        let leaf = url.lastPathComponent
        let candidates: [URL] = !leaf.contains(".") ?
            [url, url.deletingLastPathComponent().appendingPathComponent(leaf + ".fth")] :
            [url]

        for target in candidates {
            do {
                let data = try Data(contentsOf: target)
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

                self.loadNesting += 1
                self.sourceLoadStop = false
                self.inSlashSlashComment = false
                defer {
                    if self.loadNesting > 0 { self.loadNesting -= 1 }
                    self.sourceLoadStop = false
                    self.inSlashSlashComment = false
                }

                for raw in rawLines {
                    // Re-evaluate echoOn on every line so that FILE-ECHO ON (or OFF) executed
                    // from earlier lines in *this* file take effect for subsequent lines.
                    // Also force-echo the directive line itself so "FILE-ECHO ON" at top of
                    // file visibly enables echo for the load (and turns on for lines after it).
                    let echoOn = (fileEchoAddr != 0) && (readCell(fileEchoAddr) != 0)
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    let lower = trimmed.lowercased()
                    let isEchoToggle = lower.hasPrefix("file-echo") && (lower.contains("on") || lower.contains("off"))
                    if echoOn || isEchoToggle {
                        tell(raw + "\n")
                    }
                    if !trimmed.isEmpty {
                        feedLine(raw)
                        if self.sourceLoadStop {
                            break
                        }
                        if errorFlag {
                            tell("? FLOAD aborted after error in \(target.lastPathComponent)\n")
                            errorFlag = false
                            break
                        }
                    }
                }
                return  // success on this candidate
            } catch {
                // try next candidate (literal then auto-.fth for bare FLOAD names)
            }
        }
        // All candidates failed (or only one).
        let reportURL = candidates.last ?? url
        // Use a clean message; avoid embedding Cocoa's localizedDescription which
        // can contain curly/smart quotes and cause display oddities in the console.
        tell("? FLOAD could not read '\(reportURL.lastPathComponent)' (not found or unreadable)\n")
        // Helpful hint for the common sandbox case (no bookmark/scope for the logical dir yet).
        tell("  (If the file is in your current directory, type bare `fload` and pick any file in that folder once to authorize it. Then named FLOAD and CHDIR will stick across launches.)\n")
        errorFlag = true
    }

    // CHDIR support (used by the CHDIR word)
    private func changeDirectory(spec: String) {
        let fm = FileManager.default
        if spec.isEmpty {
            directoryPickRequested = true
            onDirectoryPickRequested?()
            return
        }
        let expanded = (spec as NSString).expandingTildeInPath
        let newURL: URL
        if expanded.hasPrefix("/") {
            newURL = URL(fileURLWithPath: expanded)
        } else {
            let cwd = logicalCurrentDirectory.isEmpty ? fm.currentDirectoryPath : logicalCurrentDirectory
            newURL = URL(fileURLWithPath: cwd).appendingPathComponent(expanded)
        }
        var isDirectory: ObjCBool = false
        let visibleAsDir = fm.fileExists(atPath: newURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
        // Always update logical (and fire host callback) so that even before any security
        // grant, the user can "chdir" to their actual folder (e.g. the project dir containing
        // Forthing.fth). This makes the default "the right place", bare "chdir" reports it,
        // and subsequent named "fload Forthing.fth" resolves against the correct logical dir.
        // The open may still fail until a bare FLOAD dialog has authorized the tree (creating
        // a bookmark that activate/pending can use for startAccess + Data).
        logicalCurrentDirectory = newURL.path
        if fm.changeCurrentDirectoryPath(newURL.path) {
            tell("Current directory: \(logicalCurrentDirectory)\n")
        } else {
            // Report the logical even if process-level chdir didn't fully stick (sandbox).
            tell("Current directory: \(logicalCurrentDirectory)\n")
        }
        if !visibleAsDir {
            // Soft note (no errorFlag, so REPL stays usable). User can still use full paths
            // or bare fload to authorize; named relative will attempt the logical path.
            tell("(note: directory not visible to sandbox yet; bare `fload` to authorize if loads fail)\n")
        }
        // Notify host so it can try to create/activate a bookmark for this exact dir
        // (succeeds if current scope from ancestor or panel covers it).
        let dirURL = URL(fileURLWithPath: logicalCurrentDirectory)
        self.onDirectoryChanged?(dirURL)
    }

    // DIR support (used by the DIR word). Supports optional <path><filespec> with * ? wildcards.
    private func listDirectory(spec: String) {
        let fm = FileManager.default
        var basePath = logicalCurrentDirectory.isEmpty ? fm.currentDirectoryPath : logicalCurrentDirectory
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
        let listURL: URL
        if let ensured = ensureDirectoryAccess?(dirURL) {
            listURL = ensured
            logicalCurrentDirectory = ensured.path
        } else {
            listURL = dirURL
        }
        do {
            let contents = try fm.contentsOfDirectory(at: listURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
            tell("\nDirectory of \(listURL.path)\n\n")
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
            tell("DIR error: Cannot read directory '\(listURL.path)'\n")
            tell("  (Use bare `fload` to pick/authorize a folder if you have not yet; CHDIR to it may help too.)\n")
            // Do not set errorFlag: DIR failure shouldn't leave the REPL in error state.
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
        var h = readCell(DP_ADDR)
        while (h & 7) != 0 {
            writeByte(h, 0)
            h += 1
        }
        writeCell(DP_ADDR, h)
    }

    // Direct memory versions — these do NOT touch the data stack.
    // Critical during init when building the primitive dictionary.
    private func writeCellHere(_ value: Cell) {
        let h = readCell(DP_ADDR)
        writeCell(h, value)
        writeCell(DP_ADDR, h + 8)
    }

    private func writeByteHere(_ value: UInt8) {
        let h = readCell(DP_ADDR)
        writeByte(h, value)
        writeCell(DP_ADDR, h + 1)
    }

    private func createWord(name: String, immediate: Bool) {
        let newLatest = readCell(DP_ADDR)

        // link field (previous head in current defs vocab)
        let defsHeadCell = readCell(CURRENT)
        let oldLatest = readCell(defsHeadCell)
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

        // Update the current defs head-cell to point at this new header (newest in this vocab)
        writeCell(defsHeadCell, newLatest)
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

    private func setContext(_ wlID: Cell) {
        writeCell(CONTEXT, wlID)
        if searchOrder.isEmpty {
            searchOrder.append(wlID)
        } else {
            searchOrder[0] = wlID
        }
    }

    private func nameForVocab(_ wlID: Cell) -> String {
        if wlID == self.LATEST { return "FORTH" }
        var link = readCell(self.LATEST)
        var safety = 0
        while link != 0 && safety < 10000 {
            safety += 1
            if !isValidDictionaryLink(link) { break }
            let cfa = getCFA(link)
            let first = readCell(Int(cfa))
            if first == createRuntimeID || first == dodoesID {
                let dataAddr = readCell(Int(cfa) + 8)
                if dataAddr == wlID {
                    let flagsLen = readByte(Int(link) + 8)
                    let len = Int(flagsLen & MASK_NAMELENGTH)
                    var nameBytes: [UInt8] = []
                    for i in 0..<len {
                        nameBytes.append(readByte(Int(link) + 9 + i))
                    }
                    return String(bytes: nameBytes, encoding: .utf8) ?? "???"
                }
            }
            link = readCell(link)
        }
        return "???"
    }

    // MARK: - Finding words

    private func findWord(_ name: String) -> Cell {
        let upper = name.uppercased()
        for wlID in searchOrder {
            var link = readCell(wlID)
            var safety = 0
            while link != 0 && safety < 10000 {
                safety += 1
                if !isValidDictionaryLink(link) { break }
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

    /// Returns true for any character that should be treated as a double quote
    /// for the purposes of S" . " ABORT" etc. string delimiters and word names like S".
    /// Covers straight ASCII " plus various curly/smart double quotes that macOS produces.
    private func isDoubleQuoteLike(_ c: Character) -> Bool {
        switch c {
        case "\"", "“", "”", "„", "‟", "«", "»",
             "\u{2033}", "\u{2036}", "\u{FF02}":
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

        // ID 0 = DOCOL / RUNDOCOL  (marker only; first cell of colon definitions)
        docolID = Cell(primitives.count)
        primitives.append {
            // DOCOL is a marker value stored as the first cell at a colon def's CFA.
            // Callers (top-level execute or innerThread large-cell path) jump directly to
            // body (cfa+8) and push any needed return frame themselves. This body is
            // defensive only (in case of direct dispatch) and must not push extra frames.
            self.ip = Int(self.currentCodeAddr) + 8
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

        // Runtime support for ."  (traditional compact form).
        // . " (immediate) compiles a call to this + inlines a counted string (len byte + chars, cell-aligned).
        // When this executes in innerThread, it outputs the string (like TYPE) and advances IP
        // past the inline data so the next threaded instruction is found correctly.
        // This replaces the old per-char LIT+EMIT expansion, making dictionary usage for strings
        // much more compact and SEE decompilations readable (shows ." text " instead of a long
        // sequence of LIT <n> EMIT for each character).
        dotQuoteID = register("(.\\\")") {
            let strAddr = self.ip
            let len = Int(self.readByte(strAddr))
            for i in 0..<len {
                self.putkey(self.readByte(strAddr + 1 + i))
            }
            var newIP = self.ip + 1 + len
            while (newIP & 7) != 0 { newIP += 1 }
            self.ip = newIP
        }

        // Runtime for S" : like (.") but leaves c-addr u on stack instead of printing.
        sQuoteID = register("(S\\\")") {
            let strAddr = self.ip
            let len = Int(self.readByte(strAddr))
            let charAddr = strAddr + 1
            self.push(Cell(charAddr))
            self.push(Cell(len))
            var newIP = self.ip + 1 + len
            while (newIP & 7) != 0 { newIP += 1 }
            self.ip = newIP
        }

        // Runtime for ABORT" : if flag on stack, type the inline string then ABORT (reset).
        self.abortQuoteID = register("(ABORT\\\")") {
            let flag = self.pop()
            let strAddr = self.ip
            let len = Int(self.readByte(strAddr))
            if flag != 0 {
                for i in 0..<len {
                    self.putkey(self.readByte(strAddr + 1 + i))
                }
                self.putkey(10) // nl?
                self.resetRuntimeState()
                self.errorFlag = true  // so outer can see abort
            }
            var newIP = self.ip + 1 + len
            while (newIP & 7) != 0 { newIP += 1 }
            self.ip = newIP
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
        _ = register("/")     {
            let b = self.pop(); let a = self.pop()
            if b == 0 { self.tell("? Division by zero\n"); self.errorFlag = true; self.push(0); return }
            self.push(a / b)
        }
        _ = register("*/MOD") {
            let n3 = self.pop(); let n2 = self.pop(); let n1 = self.pop()
            if n3 == 0 { self.tell("? Division by zero\n"); self.errorFlag = true; self.push(0); self.push(0); return }
            let prod = n1 * n2
            self.push( prod % n3 ); self.push( prod / n3 )
        }
        _ = register("M*") {
            let b = self.pop(); let a = self.pop()
            let prod = Int64(a) * Int64(b)
            self.push( Cell( prod & 0xffffffff ) )
            self.push( Cell( (prod >> 32) & 0xffffffff ) )
        }
        _ = register("FM/MOD") {
            let n = self.pop(); let dlow = self.pop(); let dhigh = self.pop()
            let d = (dhigh << 32) | (dlow & 0xffffffff)
            if n == 0 { self.tell("? Division by zero\n"); self.errorFlag = true; self.push(0); self.push(0); return }
            var quot = d / n
            var rem = d % n
            if (rem < 0) != (n < 0) && rem != 0 { rem += n; quot -= (n > 0 ? 1 : -1) }
            self.push(rem); self.push(quot)
        }
        _ = register("SM/REM") {
            let n = self.pop(); let dlow = self.pop(); let dhigh = self.pop()
            let d = (dhigh << 32) | (dlow & 0xffffffff)
            if n == 0 { self.tell("? Division by zero\n"); self.errorFlag = true; self.push(0); self.push(0); return }
            self.push( d % n ); self.push( d / n )
        }
        _ = register("U<") { let b = self.pop(); let a = self.pop(); let ua = UInt64( bitPattern: Int64(a) ); let ub = UInt64( bitPattern: Int64(b) ); self.push( ua < ub ? -1 : 0 ) }
        _ = register("U>") { let b = self.pop(); let a = self.pop(); let ua = UInt64( bitPattern: Int64(a) ); let ub = UInt64( bitPattern: Int64(b) ); self.push( ua > ub ? -1 : 0 ) }
        _ = register("UM*") {
            let b = self.pop(); let a = self.pop()
            let ua = UInt64( bitPattern: Int64(a) )
            let ub = UInt64( bitPattern: Int64(b) )
            let prod = ua * ub
            self.push( Cell( prod & 0xffffffff ) )
            self.push( Cell( (prod >> 32) & 0xffffffff ) )
        }
        _ = register("UM/MOD") {
            let u = self.pop(); let dlow = self.pop(); let dhigh = self.pop()
            let d = (UInt64( bitPattern: Int64(dhigh) ) << 32) | UInt64( bitPattern: Int64(dlow) )
            if u == 0 { self.tell("? Division by zero\n"); self.errorFlag = true; self.push(0); self.push(0); return }
            let uu = UInt64( bitPattern: Int64(u) )
            let quot = d / uu
            let rem = d % uu
            self.push( Cell( rem & 0xffffffff ) ); self.push( Cell( quot & 0xffffffff ) )
        }
        _ = register("+!") {
            let addr = Int(self.pop()); let n = self.pop()
            let old = self.readCell(addr)
            self.writeCell(addr, old + n)
        }

        _ = register(".")     { 
            let n = self.pop()
            let b = self.readCell(self.BASE)
            self.tell( self.formatNumber(n, base: b, signed: true) ); self.putkey(32) 
        }
        _ = register("CR")    { self.putkey(10) }
        _ = register("SPACE") { self.putkey(32) }
        emitID = register("EMIT")  { self.putkey(UInt8(self.pop() & 0xff)) }

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
            // The host (ConsoleView or TestTZForth) will call provideKey(_ char) when the user
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
        fetchID = register("@")     { let addr = Int(self.pop()); self.push(self.readCell(addr)) }
        _ = register("C!")    { let addr = Int(self.pop()); let val = self.pop(); self.writeByte(addr, UInt8(val & 0xff)) }
        _ = register("C@")    { let addr = Int(self.pop()); self.push(Cell(self.readByte(addr))) }

        // Public "," and "C," so that interpret-time "42 ," and "65 C," work (compile into dictionary).
        _ = register(",")  { self.comma() }
        _ = register("C,") { self.commaByte() }

        _ = register("HERE")  { self.push( Cell( self.DP_ADDR ) ) }  // NOTE: this primitive is shadowed by high-level : HERE DP @ ; so HERE returns the value
        _ = register("LATEST"){ self.push( Cell( self.LATEST ) ) }
        _ = register("DP")    { self.push( Cell( self.DP_ADDR ) ) }  // DP ( -- addr )  the dictionary pointer variable; HERE is DP @
        _ = register("STATE") { self.push( Cell( self.STATE ) ) }
        _ = register("BASE")  { self.push( Cell( self.BASE ) ) }
        _ = register("SP")    { self.push( Cell( self.SP ) ) }
        _ = register("RSP")   { self.push( Cell( self.RSP ) ) }
        _ = register("SP!")   { let v = self.pop(); self.spSet(v) }
        _ = register("RSP!")  { let v = self.pop(); self.rspSet(v) }
        _ = register(">IN")   { self.push( Cell( self.IN ) ) }
        _ = register("CONTEXT") { self.push( Cell( self.CONTEXT ) ) }
        _ = register("CURRENT") { self.push( Cell( self.CURRENT ) ) }

        _ = register("SET-CONTEXT") {
            let wlID = self.pop()
            self.setContext(wlID)
        }

        _ = register("ALSO") {
            if self.searchOrder.count >= self.MAX_VOCABS {
                self.tell("? Search order full\n")
                self.errorFlag = true
                return
            }
            if self.searchOrder.isEmpty {
                self.searchOrder.append(self.LATEST)
            }
            let top = self.searchOrder[0]
            self.searchOrder.insert(top, at: 0)
            self.setContext(top)
        }

        _ = register("ONLY") {
            self.searchOrder = [self.LATEST]
            self.setContext(self.LATEST)
        }

        _ = register("VOCABULARIES") {
            self.validateAndRepairSystemState()
            self.tell("Context: ")
            for wlID in self.searchOrder {
                let nm = self.nameForVocab(wlID)
                self.tell(nm + " ")
            }
            self.tell("\nCurrent: ")
            let cur = self.readCell(self.CURRENT)
            let cnm = self.nameForVocab(cur)
            self.tell(cnm + "\n")
        }

        // >HEADER ( xt -- header )  Given a code field address (xt), return the
        // start of its dictionary header (the link field address).  This is the
        // key primitive needed to implement proper linked-list dictionary walking.
        // The active user-facing FORGET is the parsing primitive below (FORGET NAME).
        // FORGET now also restores HERE to reclaim memory for the forgotten word(s).
        _ = register(">HEADER") {
            let targetCFA = self.pop()
            for wlID in self.searchOrder {
                var link = self.readCell(wlID)
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
            }
            self.push(0)   // not found
        }

        _ = register("]", immediate: false) { self.writeCell(self.STATE, 1) }
        _ = register("[", immediate: true)  { self.writeCell(self.STATE, 0) }

        _ = register("IMMEDIATE") {
            let defsHeadCell = self.readCell(self.CURRENT)
            let l = self.readCell(defsHeadCell)
            if l == 0 { self.tell("? No latest word\n"); self.errorFlag = true; return }
            let fl = self.readByte( Int(l) + 8 )
            self.writeByte( Int(l) + 8 , fl | self.FLAG_IMMEDIATE )
        }

        _ = register("LITERAL", immediate: true) {
            if self.readCell(self.STATE) == 0 { self.tell("? LITERAL only while compiling\n"); self.errorFlag = true; return }
            let n = self.pop()
            self.push(self.litID); self.comma()
            self.push(n); self.comma()
        }

        _ = register("[CHAR]", immediate: true) {
            if self.readCell(self.STATE) == 0 { self.tell("? [CHAR] only while compiling\n"); self.errorFlag = true; return }
            let name = self.parseWord()
            if name.isEmpty { self.tell("? [CHAR] needs char\n"); self.errorFlag = true; return }
            let c = Cell( name.utf8.first ?? 0 )
            self.push(self.litID); self.comma()
            self.push(c); self.comma()
        }

        _ = register("[']", immediate: true) {
            if self.readCell(self.STATE) == 0 { self.tell("? ['] only while compiling\n"); self.errorFlag = true; return }
            let name = self.parseWord()
            if name.isEmpty { self.tell("? ['] needs name\n"); self.errorFlag = true; return }
            let hdr = self.findWord(name)
            if hdr == 0 { self.tell("? ['] ? " + name + "\n"); self.errorFlag = true; return }
            let cfa = self.getCFA(hdr)
            let firstCell = self.readCell(Int(cfa))
            let xt: Cell
            if firstCell < Cell(self.MAX_BUILTIN_ID) && firstCell != self.docolID {
                xt = firstCell
            } else {
                xt = cfa
            }
            self.push(self.litID); self.comma()
            self.push(xt); self.comma()
        }

        // [COMPILE] name  (immediate)  Force compilation of the next word's reference even if
        // the word is immediate. (Older form; POSTPONE is preferred in ANS.)
        _ = register("[COMPILE]", immediate: true) {
            if self.readCell(self.STATE) == 0 { self.tell("? [COMPILE] only while compiling\n"); self.errorFlag = true; return }
            let name = self.parseWord()
            if name.isEmpty { self.tell("? [COMPILE] needs name\n"); self.errorFlag = true; return }
            let hdr = self.findWord(name)
            if hdr == 0 { self.tell("? [COMPILE] ? " + name + "\n"); self.errorFlag = true; return }
            let cfa = self.getCFA(hdr)
            let first = self.readCell(Int(cfa))
            // Always emit a reference (ignore the target's IMMEDIATE flag)
            if first < Cell(self.MAX_BUILTIN_ID) && first != self.docolID {
                self.push(first); self.comma()
            } else {
                self.push(cfa); self.comma()
            }
        }

        // COMPILE, ( xt -- )  Core Ext. Compile the given xt as if it had been found while compiling.
        // Useful with ' and ['] .
        _ = register("COMPILE,") {
            if self.readCell(self.STATE) == 0 {
                self.tell("? COMPILE, only while compiling\n")
                self.errorFlag = true
                return
            }
            let xt = self.pop()
            if xt < Cell(self.MAX_BUILTIN_ID) && xt != self.docolID {
                self.push(xt); self.comma()
            } else {
                self.push(xt); self.comma()
            }
        }

        // POSTPONE name  (immediate)  Append the compilation semantics of the next word.
        // If the word is immediate, this means "compile code that will execute it later"
        // (LIT xt EXECUTE). For non-immediate, same as normal reference emission.
        // Requires executeID (captured at registration of EXECUTE).
        _ = register("POSTPONE", immediate: true) {
            if self.readCell(self.STATE) == 0 { self.tell("? POSTPONE only while compiling\n"); self.errorFlag = true; return }
            let name = self.parseWord()
            if name.isEmpty { self.tell("? POSTPONE needs name\n"); self.errorFlag = true; return }
            let hdr = self.findWord(name)
            if hdr == 0 { self.tell("? POSTPONE ? " + name + "\n"); self.errorFlag = true; return }
            let cfa = self.getCFA(hdr)
            let first = self.readCell(Int(cfa))
            let isImm = (self.readByte(Int(hdr) + 8) & self.FLAG_IMMEDIATE) != 0
            if isImm {
                // Postpone the *execution* semantics: when this def runs, execute the (imm) word.
                self.push(self.litID); self.comma()
                if first < Cell(self.MAX_BUILTIN_ID) && first != self.docolID {
                    self.push(first); self.comma()
                } else {
                    self.push(cfa); self.comma()
                }
                self.push(self.executeID); self.comma()
            } else {
                // Normal compile of reference (compilation semantics for non-imm)
                if first < Cell(self.MAX_BUILTIN_ID) && first != self.docolID {
                    self.push(first); self.comma()
                } else {
                    self.push(cfa); self.comma()
                }
            }
        }

        // : and ; are special because they affect STATE and compile DOCOL / EXIT
        _ = register(":") {
            // Read the next word as the name
            let name = self.parseWord()
            if name.isEmpty { self.tell("? : needs a name\n"); self.errorFlag = true; return }

            self.createWord(name: name, immediate: false)

            // Compile DOCOL into the code field (as if user had done DOCOL , )
            self.push(self.docolID); self.comma()

            // Hide the word while we are compiling it (classic behaviour)
            let defsHeadCell = self.readCell(self.CURRENT)
            let l = self.readCell(defsHeadCell)
            let fl = self.readByte(Int(l) + 8)
            self.writeByte(Int(l) + 8, fl | self.FLAG_HIDDEN)

            self.writeCell(self.STATE, 1)
        }

        _ = register(";", immediate: true) {
            self.push(self.exitID); self.comma()

            // Unhide
            let defsHeadCell = self.readCell(self.CURRENT)
            let l = self.readCell(defsHeadCell)
            let fl = self.readByte(Int(l) + 8)
            self.writeByte(Int(l) + 8, fl & ~self.FLAG_HIDDEN)

            self.writeCell(self.STATE, 0)
            self.loopControlStack.removeAll()  // clean any leftover from unbalanced loops in this def
        }

        // RECURSE ( -- )  immediate: compile a call to the current definition (for recursion)
        _ = register("RECURSE", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? RECURSE only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            let defsHeadCell = self.readCell(self.CURRENT)
            let latest = self.readCell(defsHeadCell)
            if latest == 0 {
                self.tell("? RECURSE with no current definition\n")
                self.errorFlag = true
                return
            }
            let cfa = self.getCFA(latest)
            let first = self.readCell(Int(cfa))
            if first < Cell(self.MAX_BUILTIN_ID) && first != self.docolID {
                self.push(first); self.comma()
            } else {
                self.push(cfa); self.comma()
            }
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
            let defsHeadCell = self.readCell(self.CURRENT)
            let latest = self.readCell(defsHeadCell)
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
            let here = self.readCell(self.DP_ADDR)
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
            let here = self.readCell(self.DP_ADDR)
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
            let here = self.readCell(self.DP_ADDR)
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
            let placeholderAddr = self.readCell(self.DP_ADDR)  // address of the offset cell we just reserved
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
            let here = self.readCell(self.DP_ADDR)
            let backOffset = dest - (here + 8)
            self.push(backOffset); self.comma()

            // Now resolve the forward branch that WHILE left behind.
            // The code after REPEAT (current HERE) is where the 0BRANCH should jump to
            // when its condition was false.
            let afterRepeat = self.readCell(self.DP_ADDR)
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
            let placeholderAddr = self.readCell(self.DP_ADDR)
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
            let elsePlaceholder = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.push(elsePlaceholder)

            let afterElseBranch = self.readCell(self.DP_ADDR)
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
            let here = self.readCell(self.DP_ADDR)
            let forwardOffset = here - (placeholder + 8)
            self.writeCell(Int(placeholder), forwardOffset)
        }

        // === CASE / OF / ENDOF / ENDCASE (Core Ext 6.2) ===
        // Implemented in Swift for reliable compile-time data stack management (same technique as IF).
        // 0 is used as sentinel on the compile-time stack (left by CASE, consumed by ENDCASE).
        // This allows clean decompile of user code (the structure words are in the dict) even if
        // the generated body shows the 0BRANCH/BRANCH details.
        _ = register("CASE", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? CASE only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            self.push(0)  // sentinel for ENDCASE
        }

        _ = register("OF", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? OF only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            // Emit: OVER =   then the IF part (0BRANCH ph + push ph)
            // Then emit DROP (so matched case drops the selector before running the OF code)
            func emitRef(_ name: String) {
                let hdr = self.findWord(name)
                if hdr != 0 {
                    let cfa = self.getCFA(hdr)
                    let first = self.readCell(Int(cfa))
                    let toEmit = (first < Cell(self.MAX_BUILTIN_ID) && first != self.docolID) ? first : cfa
                    self.push(toEmit); self.comma()
                }
            }
            emitRef("OVER")
            emitRef("=")
            // The IF emit:
            self.push(self.zeroBranchID); self.comma()
            let ph = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.push(ph)
            emitRef("DROP")
        }

        _ = register("ENDOF", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? ENDOF only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            // Like ELSE: resolve previous ph (from OF or prev ENDOF), emit forward BRANCH with new ph
            let prevPh = self.pop()
            self.push(self.branchID); self.comma()
            let newPhAddr = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.push(newPhAddr)
            // resolve prev to after the branch we just emitted
            let here = self.readCell(self.DP_ADDR)
            let off = here - (prevPh + 8)
            self.writeCell(Int(prevPh), off)
        }

        _ = register("ENDCASE", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.tell("? ENDCASE only allowed while compiling a word\n")
                self.errorFlag = true
                return
            }
            // Resolve the pending forward branches from ENDOFs (and last false OF) to the cleanup point.
            // At this moment HERE is right after the default code (if any). Patch targets the upcoming DROP.
            while true {
                let s = self.spGet()
                if s <= 1 { break }
                let x = self.pop()
                if x == 0 { break }
                let here = self.readCell(self.DP_ADDR)
                let off = here - (x + 8)
                self.writeCell(Int(x), off)
            }
            // Now emit the final DROP (cleans the case selector for default path and after patches).
            let hdr = self.findWord("DROP")
            if hdr != 0 {
                let cfa = self.getCFA(hdr)
                let first = self.readCell(Int(cfa))
                let toEmit = (first < Cell(self.MAX_BUILTIN_ID) && first != self.docolID) ? first : cfa
                self.push(toEmit); self.comma()
            }
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
            if firstCell < Cell(self.MAX_BUILTIN_ID) && firstCell != self.docolID && firstCell != self.createRuntimeID && firstCell != self.dodoesID {
                self.push(firstCell)
            } else {
                self.push(cfa)
            }
        }

        // EXECUTE ( xt -- )
        // xt may be a primitive ID (small number from ' on prim) or a CFA address.
        // Delegates to the internal execute() which handles both cases (prim dispatch or threaded).
        self.executeID = register("EXECUTE") {
            let xt = self.pop()
            if xt < Cell(self.MAX_BUILTIN_ID) {
                // primitive ID case (as pushed by ' on primitives)
                self.execute(cfa: xt, firstCell: xt)
            } else {
                let cfa = xt
                let firstCell = self.readCell(Int(cfa))
                self.execute(cfa: cfa, firstCell: firstCell)
            }
        }

        // FIND ( c-addr -- c-addr 0 | xt 1 | xt -1 )
        // c-addr is counted string (as from WORD). Returns 0 + orig if not found,
        // or xt and flag (+1 immediate, -1 not) if found. Uses same xt logic as ' .
        _ = register("FIND") {
            let caddr = Int(self.pop())
            let len = Int(self.readByte(caddr))
            var nameBytes: [UInt8] = []
            for i in 0..<len {
                nameBytes.append(self.readByte(caddr + 1 + i))
            }
            let name = String(bytes: nameBytes, encoding: .utf8) ?? ""
            let hdr = self.findWord(name)
            if hdr == 0 {
                self.push(Cell(caddr))
                self.push(0)
                return
            }
            let cfa = self.getCFA(hdr)
            let firstCell = self.readCell(Int(cfa))
            let xt: Cell
            if firstCell < Cell(self.MAX_BUILTIN_ID) && firstCell != self.docolID {
                xt = firstCell
            } else {
                xt = cfa
            }
            let flagsLen = self.readByte(Int(hdr) + 8)
            let isImmediate = (flagsLen & self.FLAG_IMMEDIATE) != 0
            self.push(xt)
            self.push(isImmediate ? 1 : -1)
        }

        // EVALUATE ( i*x c-addr u -- j*x )
        // Temporarily replace input queue with the string (as if fed), run interpreter,
        // restore previous input and >IN. Supports nested eval, compile etc.
        _ = register("EVALUATE") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            let savedQueue = self.inputQueue
            let savedIN = self.readCell(self.IN)
            let savedSourceLen = self.currentSourceLen
            var savedSource: [UInt8] = []
            for i in 0..<savedSourceLen {
                savedSource.append(self.readByte(self.SOURCE_BUFFER + i))
            }
            self.inputQueue = []
            for i in 0..<u {
                self.inputQueue.append( self.readByte(caddr + i) )
            }
            self.inputQueue.append(10) // \n
            self.writeCell(self.IN, 0)
            // Update SOURCE buffer for the evaluated string so SOURCE/PARSE/>IN work inside EVALUATE
            self.currentSourceLen = min(u, self.SOURCE_BUFFER_SIZE)
            for i in 0..<self.currentSourceLen {
                self.writeByte(self.SOURCE_BUFFER + i, self.readByte(caddr + i))
            }
            self.runInterpreter()
            // if error during eval, leave errorFlag for outer to see (like in load)
            self.inputQueue = savedQueue
            self.writeCell(self.IN, savedIN)
            // restore previous source buffer
            self.currentSourceLen = savedSourceLen
            for i in 0..<savedSourceLen {
                self.writeByte(self.SOURCE_BUFFER + i, savedSource[i])
            }
        }

        // ABORT ( -- )  clear stacks and return to interpreter (reset state)
        _ = register("ABORT") {
            self.resetRuntimeState()
        }

        // QUIT ( -- )  Empty return stack (to top level), set interpret mode, clear current input.
        // This is the classic "return to outer interpreter" word. Implemented as primitive
        // so it has no return frame of its own to corrupt when it wipes RSP.
        _ = register("QUIT") {
            self.rspSet(1)
            self.writeCell(self.STATE, 0)
            self.writeCell(self.IN, 0)
            self.inputQueue.removeAll(keepingCapacity: true)
            self.errorFlag = false
            // Draining queue here will cause runInterpreter's while to exit cleanly after this word.
        }

        // >NUMBER ( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )
        // Convert as many digits as possible in current BASE from the string,
        // accumulating into ud (unsigned double). Returns updated ud and remaining string.
        _ = register(">NUMBER") {
            let u1 = Int(self.pop())
            let caddr1 = Int(self.pop())
            let udHigh = self.pop()
            let udLow = self.pop()
            var ud = (UInt64(bitPattern: Int64(udHigh)) << 32) | UInt64(bitPattern: Int64(udLow))
            let b = max(2, min(36, self.readCell(self.BASE)))
            var i = 0
            while i < u1 {
                let ch = self.readByte(caddr1 + i)
                var d = -1
                if ch >= 48 && ch <= 57 { d = Int(ch) - 48 }
                else if ch >= 65 && ch <= 90 { d = 10 + Int(ch) - 65 }
                else if ch >= 97 && ch <= 122 { d = 10 + Int(ch) - 97 }
                if d < 0 || d >= b { break }
                ud = ud * UInt64(b) + UInt64(d)
                i += 1
            }
            let newHigh = Cell( (ud >> 32) & 0xffffffff )
            let newLow = Cell( ud & 0xffffffff )
            self.push(newLow)
            self.push(newHigh)
            self.push( Cell(caddr1 + i) )
            self.push( Cell(u1 - i) )
        }

        // ( comment ) — classic and essential
        _ = register("(", immediate: true) {
            // Eat characters until we see )
            while !self.inputQueue.isEmpty {
                let c = self.consumeInput() ?? 0
                if c == 41 { break } // ')'
            }
        }

        // \ comment to end of line — essential for loading typical .fth source files that use
        // line comments. Immediate so it works while compiling too.
        _ = register("\\", immediate: true) {
            while !self.inputQueue.isEmpty {
                let c = self.consumeInput() ?? 0
                if c == 10 || c == 13 { break }
            }
        }

        // \\  (two backslashes) starts a block comment area, skipped until a '{' is seen.
        // The skipped region can span multiple lines (works in console REPL and during FLOAD).
        // Text after the '{' on the closing line is processed normally.
        // Immediate so it works while compiling loaded files too. For old code compatibility.
        // Note: use single \ for a normal single-line comment to end-of-line (like in most Forths).
        // Accidentally using \\ instead of \ will start a block comment that may swallow the rest
        // of the file (until a { is seen), preventing \S, definitions, etc. from taking effect.
        _ = register("\\\\", immediate: true) {
            while !self.inputQueue.isEmpty {
                let c = self.consumeInput() ?? 0
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
                    let c = self.consumeInput() ?? 0
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
        _ = register("0<>") { let a = self.pop(); self.push(a != 0 ? -1 : 0) }
        _ = register("<>") { let b = self.pop(); let a = self.pop(); self.push(a != b ? -1 : 0) }

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

        _ = register("2DROP") { _ = self.pop(); _ = self.pop() }
        _ = register("2DUP")  { let b = self.pop(); let a = self.pop(); self.push(a); self.push(b); self.push(a); self.push(b) }
        _ = register("2OVER") { let d = self.pop(); let c = self.pop(); let b = self.pop(); let a = self.pop(); self.push(a); self.push(b); self.push(c); self.push(d); self.push(a); self.push(b) }
        _ = register("2SWAP") { let d = self.pop(); let c = self.pop(); let b = self.pop(); let a = self.pop(); self.push(c); self.push(d); self.push(a); self.push(b) }

        _ = register("S>D") { let n = self.pop(); self.push(n); self.push( n < 0 ? -1 : 0 ) }

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
            let b = self.readCell(self.BASE)
            self.tell( self.formatNumber(v, base: b, signed: false) ); self.putkey(32)
        }
        _ = register("U.R") {
            let wid = Int(self.pop())
            let v = self.pop()
            let b = self.readCell(self.BASE)
            var s = self.formatNumber(v, base: b, signed: false)
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

        // Pictured numeric output (core)
        _ = register("<#") { self.startPictured() }
        _ = register("#") {
            let high = self.pop()
            let low = self.pop()
            let b = max(2, min(36, self.readCell(self.BASE)))
            var ud = (UInt64(bitPattern: Int64(high)) << 32) | UInt64(bitPattern: Int64(low))
            let digit = ud % UInt64(b)
            ud /= UInt64(b)
            let nh = Cell( (ud >> 32) & 0xffffffff )
            let nl = Cell( ud & 0xffffffff )
            self.push(nl); self.push(nh)
            self.picturedAddDigit( Cell(digit) )
        }
        _ = register("#S") {
            let high = self.pop()
            let low = self.pop()
            let b = max(2, min(36, self.readCell(self.BASE)))
            var ud = (UInt64(bitPattern: Int64(high)) << 32) | UInt64(bitPattern: Int64(low))
            repeat {
                let digit = ud % UInt64(b)
                ud /= UInt64(b)
                self.picturedAddDigit( Cell(digit) )
            } while ud != 0
            let nh = Cell( (ud >> 32) & 0xffffffff )
            let nl = Cell( ud & 0xffffffff )
            self.push(nl); self.push(nh)
        }
        _ = register("#>") {
            _ = self.pop()
            _ = self.pop()  // ud consumed (not used)
            let end = self.pnoBufferAddr + self.PNO_BUFFER_SIZE
            let u = end - self.pnoPtr
            self.push( Cell(self.pnoPtr) )
            self.push( Cell(u) )
        }
        _ = register("HOLD") {
            let ch = UInt8( self.pop() & 0xff )
            if self.pnoPtr > self.pnoBufferAddr {
                self.pnoPtr -= 1
                self.writeByte(self.pnoPtr, ch)
            }
        }
        _ = register("SIGN") {
            if self.pop() < 0 {
                if self.pnoPtr > self.pnoBufferAddr {
                    self.pnoPtr -= 1
                    self.writeByte(self.pnoPtr, 45) // '-'
                }
            }
        }

        _ = register("MOD") {
            let b = self.pop(); let a = self.pop()
            if b == 0 { self.tell("? Division by zero\n"); self.errorFlag = true; self.push(0); return }
            self.push( a % b )
        }

        _ = register("ALLOT") { let n = self.pop(); let h = self.readCell(self.DP_ADDR); self.writeCell(self.DP_ADDR, h + n) }

        _ = register("FILL") {
            let b = UInt8( self.pop() & 0xff ); let u = Int(self.pop()); let addr = Int(self.pop())
            for i in 0..<u { self.writeByte( addr + i , b ) }
        }
        // ERASE can be high-level too (: ERASE 0 FILL ;), but primitive for speed and to appear in WORDS early.
        _ = register("ERASE") {
            let u = Int(self.pop()); let addr = Int(self.pop())
            for i in 0..<u { self.writeByte( addr + i , 0 ) }
        }
        _ = register("MOVE") {
            let u = Int(self.pop()); let dst = Int(self.pop()); let src = Int(self.pop())
            if u <= 0 { return }
            if dst < src {
                for i in 0..<u { self.writeByte( dst + i , self.readByte(src + i) ) }
            } else {
                for i in (0..<u).reversed() { self.writeByte( dst + i , self.readByte(src + i) ) }
            }
        }
        _ = register("ALIGN") {
            var h = self.readCell(self.DP_ADDR)
            while (h & 7) != 0 { h += 1 }
            self.writeCell(self.DP_ADDR, h)
        }
        _ = register("ALIGNED") {
            var a = self.pop()
            while (a & 7) != 0 { a += 1 }
            self.push(a)
        }
        _ = register(">BODY") {
            // For docol+LIT style (VALUE, old manual DEFER): data at xt+16
            // For CREATE / DOES> children (standard DEFER): data at xt+8
            let xt = self.pop()
            let first = self.readCell( Int(xt) )
            let dataAddr: Cell
            if first == self.docolID {
                dataAddr = self.readCell( Int(xt) + 16 )
            } else if first == self.createRuntimeID || first == self.dodoesID {
                dataAddr = self.readCell( Int(xt) + 8 )
            } else {
                dataAddr = self.readCell( Int(xt) + 16 )
            }
            self.push( dataAddr )
        }

        _ = register("CHAR") {
            let addr = self.parseToWordBuffer(using: 32)
            // CHAR returns the first character of the parsed "word"
            let c = self.readByte(Int(addr) + 1)  // after count byte
            self.push(Cell(c))
        }

        // WORD ( char -- addr )
        // Parse the input stream (inputQueue, from keyboard lines or FLOADed file lines)
        // using the given delimiter char. Skip leading delimiters, collect chars until
        // the next delimiter (leaving the delimiter in the stream), build a counted string
        // at the fixed WORD_BUFFER in memory (count byte, chars, trailing blank), return its addr.
        // This is the general parser needed for strings, names, etc. (e.g. to implement .", S", etc.).
        _ = register("WORD") {
            let delim = UInt8(self.pop() & 0xff)
            let addr = self.parseToWordBuffer(using: delim)
            self.push(addr)
        }

        // COUNT ( c-addr -- addr u )
        // For a counted string (as returned by WORD), return the address of first char and the length.
        _ = register("COUNT") {
            let caddr = Int(self.pop())
            let len = Int( self.readByte(caddr) )
            self.push( Cell(caddr + 1) )
            self.push( Cell(len) )
        }

        // SOURCE ( -- c-addr u )  Current input buffer (the line from last feedLine or EVALUATE).
        // >IN is the offset (in chars) consumed so far into it. Used by PARSE, WORD etc.
        _ = register("SOURCE") {
            self.push( Cell( self.SOURCE_BUFFER ) )
            self.push( Cell( self.currentSourceLen ) )
        }

        // PAD ( -- addr )  A transient scratch buffer (for pictured output hold area, user strings etc).
        // Fixed location so it doesn't move when HERE advances.
        _ = register("PAD") {
            self.push( Cell( self.PAD_BUFFER ) )
        }

        // PARSE ( char -- c-addr u )
        // Parse from current input source starting at >IN, up to (but not consuming) the delim char
        // or end of source. Returns address (slice of SOURCE buffer) and length. Updates >IN.
        // Does not skip leading instances of the delim (unlike WORD).
        _ = register("PARSE") {
            let delim = UInt8( self.pop() & 0xff )
            let startPos = Int( self.readCell(self.IN) )
            var len = 0
            while !self.inputQueue.isEmpty {
                let b = self.inputQueue.first!
                if self.peekIsDelim(delim) || b == delim || b == 10 || b == 13 {
                    break
                }
                _ = self.consumeInput()
                len += 1
            }
            // Do not consume the delim (standard PARSE leaves it in the input stream)
            let addr = self.SOURCE_BUFFER + startPos
            self.push( Cell(addr) )
            self.push( Cell(len) )
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

        // J -- outer loop index in nested DO loops
        // rstack layout for nested: ... outer_limit outer_index inner_limit inner_index(top)
        // I is at rs-2, J (outer index) at rs-4
        _ = register("J") {
            let rs = self.rspGet()
            if rs < 4 {
                self.tell("? Return stack underflow\n")
                self.errorFlag = true
                self.push(0)
                return
            }
            self.push( self.readCell( self.rstackBase + (rs - 4) * 8 ) )
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
            let placeholderAddr = self.readCell(self.DP_ADDR)
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
            let dest = self.readCell(self.DP_ADDR)  // body starts right after setup
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
            let phAddr = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            let dest = self.readCell(self.DP_ADDR)  // body starts after the ph cell for skip branch
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
            let here = self.readCell(self.DP_ADDR)
            let offset = dest - (here + 8)
            self.push(offset); self.comma()
            let afterLoop = self.readCell(self.DP_ADDR)
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
            let here = self.readCell(self.DP_ADDR)
            let offset = dest - (here + 8)
            self.push(offset); self.comma()
            let afterLoop = self.readCell(self.DP_ADDR)
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
        // - Adds .fth if no extension (only if basename has no dot).
        // - Resolves relative names against currentDirectoryPath (or absolute/~ paths).
        // - For named form: sets pendingLoadURL (host will scope access for sandbox, chdir, then load).
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
        // - With name: resolves (same ~, cwd-relative as FLOAD; .fth auto-fallback if no dot and exact missing),
        //   sets pending so host post-processing opens it in editor + updates cwd.
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

        // CHDIR — with no arg: host folder picker at current logical dir. With <path>: change (~/relative).
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

            let filter = self.parseWord().uppercased()

            // Collect kernel (internal) words vs user-defined words from *current vocabulary only*.
            // Kernel = everything that existed at the end of bootstrap (kernelLatest).
            var kernelWords: [(name: String, header: Cell)] = []
            var userWords:   [(name: String, header: Cell)] = []

            let searchHeadCell = self.searchOrder.isEmpty ? self.LATEST : self.searchOrder[0]
            var link = self.readCell(searchHeadCell)
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

                let uname = name.uppercased()
                if !filter.isEmpty && !uname.contains(filter) {
                    link = self.readCell(link)
                    continue
                }

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

            let searchHeadCell = self.searchOrder.isEmpty ? self.LATEST : self.searchOrder[0]
            var link = self.readCell(searchHeadCell)
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
                    self.writeCell(searchHeadCell, newLatest)
                    self.writeCell(self.DP_ADDR, link)   // reclaim memory from this header forward (set the DP value back)

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

        // ANS-VALIDATE — run the 2012 ANS Forth Core + Core Ext validation tests (ported
        // from the TestTZForth FTEST harness, originally TestLBForth.swift) and write detailed results to ANS-VALIDATE.txt
        // in the folder containing the TestTZForth.swift (i.e. next to the tests source).
        // The runner impl is in TZForthTests.swift (split for file size); sources/lets remain here.
        // Internally we respect the Leif Bruder lbForth origins of the test logic.
        // The tests exercise many current words against their standard stack effects and
        // behaviors. Results are also returned on the stack as a counted string for inspection.
        // (Uses temp files + loadFile/feedLine internally; restores output handler afterwards.)
        _ = register("ANS-VALIDATE") {
            let results = self.runANSValidation()
            // After runANSValidation, logicalCurrentDirectory has been restored to the value
            // it had when ANS-VALIDATE was invoked. Use it (or fm cwd) for the output file.
            // This ensures ANS-VALIDATE.txt lands in "the same folder where your current test
            // .swift file is located" if the user CHDIR'd there (or launched with that as cwd).
            var outBase = self.logicalCurrentDirectory.isEmpty ? FileManager.default.currentDirectoryPath : self.logicalCurrentDirectory
            let fm2 = FileManager.default
            let subDir = URL(fileURLWithPath: outBase).appendingPathComponent("TZForth")
            let directTest = URL(fileURLWithPath: outBase).appendingPathComponent("TestTZForth.swift")
            let subTest = subDir.appendingPathComponent("TestTZForth.swift")
            if fm2.fileExists(atPath: subTest.path) {
                outBase = subDir.path   // txt next to .swift inside TZForth/ subdir
            } else if fm2.fileExists(atPath: directTest.path) {
                outBase = outBase       // already in the folder with TestTZForth.swift
            }
            let outURL = URL(fileURLWithPath: outBase).appendingPathComponent("ANS-VALIDATE.txt")
            do {
                try results.write(to: outURL, atomically: true, encoding: .utf8)
                self.tell("ANS-VALIDATE results written to \(outURL.path)\n")
            } catch {
                self.tell("? Failed to write ANS-VALIDATE.txt: \(error.localizedDescription)\n")
            }
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
                let c = self.consumeInput() ?? 0
                if c == 41 { break } // ')'
                self.putkey(c)
            }
        }

        // ."  immediate — print the following " delimited text.
        // Uses parseToWordBuffer (like WORD) for parsing the delimited content from the input
        // stream (works for keyboard or during FLOAD).
        // Skips a leading whitespace separator (standard ." text" usage).
        //
        // Interpret: output the text immediately.
        // Compile: emit a call to the runtime (.") primitive, followed by an *inlined counted
        // string* (count byte + the characters, then aligned to cell boundary). This is the
        // classic compact representation. The runtime (.") will output the string (equivalent
        // to TYPE) and advance the IP past the inline data.
        //
        // Benefits: much smaller dictionary footprint for long strings (O(1) cells + string
        // bytes vs. 3 cells per character), and SEE produces clean output like the source:
        //   : TESTING ." This is a test of the testing" ;
        // instead of a huge LIT/EMIT expansion.
        _ = register(".\"", immediate: true) {
            let caddr = self.parseToWordBuffer(using: 34)
            // closing " already consumed by parseToWordBuffer (tolerates smart quotes)
            var len = Int( self.readByte( Int(caddr) ) )
            var saddr = Int(caddr) + 1
            // skip leading ws separator if present (so ." text" yields "text" not " text")
            if len > 0 && self.readByte(saddr) <= 32 {
                saddr += 1
                len -= 1
            }
            if self.readCell(self.STATE) != 0 {
                // Compile: call the runtime string emitter, then inline the counted string data.
                self.push(self.dotQuoteID); self.comma()
                self.writeByteHere(UInt8(len))
                for i in 0..<len {
                    self.writeByteHere( self.readByte(saddr + i) )
                }
                self.alignHere()
            } else {
                // Interpret: just output the text now.
                for i in 0..<len {
                    self.putkey( self.readByte( saddr + i ) )
                }
            }
        }

        // ABORT"  immediate — if flag, print the delimited text and ABORT.
        // Similar to ."
        _ = register("ABORT\"", immediate: true) {
            let caddr = self.parseToWordBuffer(using: 34)
            // closing " consumed inside parseToWordBuffer
            var len = Int( self.readByte( Int(caddr) ) )
            var saddr = Int(caddr) + 1
            if len > 0 && self.readByte(saddr) <= 32 {
                saddr += 1
                len -= 1
            }
            if self.readCell(self.STATE) != 0 {
                self.push(self.abortQuoteID); self.comma()
                self.writeByteHere(UInt8(len))
                for i in 0..<len {
                    self.writeByteHere( self.readByte(saddr + i) )
                }
                self.alignHere()
            } else {
                let flag = self.pop()
                if flag != 0 {
                    for i in 0..<len {
                        self.putkey( self.readByte( saddr + i ) )
                    }
                    self.resetRuntimeState()
                    self.errorFlag = true
                }
            }
        }

        // ACCEPT ( c-addr +n1 -- +n2 )
        // Consume up to n1 chars from inputQueue (or until nl), store at c-addr, return count.
        // Basic version for this engine (line-oriented input).
        _ = register("ACCEPT") {
            let n1 = Int(self.pop())
            let caddr = Int(self.pop())
            var count = 0
            while count < n1 && !self.inputQueue.isEmpty {
                let b = self.consumeInput() ?? 0
                if b == 10 || b == 13 { break }
                self.writeByte(caddr + count, b)
                count += 1
            }
            self.push(Cell(count))
        }

        // ENVIRONMENT? ( c-addr u -- false | i*x true )
        // Minimal but useful support for common ANS queries (so that portable code can probe).
        _ = register("ENVIRONMENT?") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            // Build query string (assume ASCII for env queries)
            var q: [UInt8] = []
            for i in 0..<u {
                q.append( self.readByte(caddr + i) )
            }
            let query = (String(bytes: q, encoding: .utf8) ?? "").uppercased()
            switch query {
            case "CORE":
                self.push(-1) // true
            case "/COUNTED-STRING", "COUNTED-STRING":
                self.push(255); self.push(-1)
            case "ADDRESS-UNIT-BITS":
                self.push(8); self.push(-1)
            case "MAX-CHAR":
                self.push(255); self.push(-1)
            case "CORE-EXT":
                self.push(-1) // we have many ext words too
            default:
                self.push(0) // false
            }
        }

        // S"  immediate — like ." but leaves ( c-addr u ) on the stack instead of printing.
        // Uses same parser. In interpret: push char-addr u (first char addr, length).
        // In compile: compile (S") + inline counted string (so at runtime it pushes the addr u of the literal string data).
        _ = register("S\"", immediate: true) {
            let caddr = self.parseToWordBuffer(using: 34)
            // closing delim already consumed inside parseToWordBuffer (supports smart quotes)
            var len = Int( self.readByte( Int(caddr) ) )
            var saddr = Int(caddr) + 1
            if len > 0 && self.readByte(saddr) <= 32 {
                saddr += 1
                len -= 1
            }
            if self.readCell(self.STATE) != 0 {
                self.push(self.sQuoteID); self.comma()
                self.writeByteHere(UInt8(len))
                for i in 0..<len {
                    self.writeByteHere( self.readByte(saddr + i) )
                }
                self.alignHere()
            } else {
                self.push( Cell(saddr) )
                self.push( Cell(len) )
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
            let dataAddr = self.readCell(self.DP_ADDR) + 16
            self.push(dataAddr); self.comma()
            self.push(self.exitID); self.comma()
            // allocate one cell of data space (advances the dict pointer past the data cell)
            self.writeCell(self.DP_ADDR, self.readCell(self.DP_ADDR) + 8)
        }

        // DEFER ( "<spaces>name" -- )  Core Ext
        // Manual docol + LIT + storage + @ EXECUTE style (efficient, ' gives cfa).
        // (We also support high-level CREATE/DOES> defers via updated DEFER!/IS logic.)
        _ = register("DEFER") {
            let name = self.parseWord()
            if name.isEmpty { self.tell("? DEFER needs a name\n"); self.errorFlag = true; return }
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            // After docol + LIT + <payload> + @ + EXECUTE + EXIT the storage cell is allocated.
            let xtCellAddr = self.readCell(self.DP_ADDR) + 32
            self.push(xtCellAddr); self.comma()
            self.push(self.fetchID); self.comma()
            self.push(self.executeID); self.comma()
            self.push(self.exitID); self.comma()
            self.writeCell(self.DP_ADDR, self.readCell(self.DP_ADDR) + 8)
            // initial behavior left as 0 (will error if executed before IS/DEFER!)
        }

        // VALUE ( n "<spaces>name" -- )  Core Ext
        // docol + LIT <val-cell> @ EXIT style.
        _ = register("VALUE") {
            let name = self.parseWord()
            if name.isEmpty { self.tell("? VALUE needs a name\n"); self.errorFlag = true; return }
            let n = self.pop()
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            let valCellAddr = self.readCell(self.DP_ADDR) + 24
            self.push(valCellAddr); self.comma()
            self.push(self.fetchID); self.comma()
            self.push(self.exitID); self.comma()
            self.writeCell(self.DP_ADDR, self.readCell(self.DP_ADDR) + 8)
            self.writeCell(Int(valCellAddr), n)
        }

        // DEFER! ( xt2 xt1 -- )  Core Ext
        // Set the word represented by defer-xt1 to execute xt2.
        _ = register("DEFER!") {
            let deferXt = self.pop()
            let newXt = self.pop()
            if deferXt < Cell(self.MAX_BUILTIN_ID) {
                self.tell("? DEFER! on a primitive\n"); self.errorFlag = true; return
            }
            let cfa = Int(deferXt)
            let first = self.readCell(cfa)
            var storageAddr: Int = 0
            if first == self.docolID {
                // old docol + LIT <storage> style (VALUE, old DEFER)
                let second = self.readCell(cfa + 8)
                if second != self.litID {
                    self.tell("? DEFER! target does not look like a DEFER or VALUE\n"); self.errorFlag = true; return
                }
                storageAddr = Int( self.readCell(cfa + 16) )
            } else if first == self.createRuntimeID || first == self.dodoesID {
                // CREATE or DOES> child (standard high-level DEFER using CREATE DOES>)
                // storage / behavior cell is the second cell after the runtime ID
                storageAddr = Int( self.readCell(cfa + 8) )
            } else {
                self.tell("? DEFER! target is not a supported defer or value\n"); self.errorFlag = true; return
            }
            self.writeCell(storageAddr, newXt)
        }

        // DEFER@ ( xt1 -- xt2 )  Core Ext
        // Return the xt that the defer xt1 currently executes.
        _ = register("DEFER@") {
            let deferXt = self.pop()
            if deferXt < Cell(self.MAX_BUILTIN_ID) {
                self.tell("? DEFER@ on a primitive\n"); self.errorFlag = true; return
            }
            let cfa = Int(deferXt)
            let first = self.readCell(cfa)
            var storageAddr: Int = 0
            if first == self.docolID {
                let second = self.readCell(cfa + 8)
                if second != self.litID { self.push(0); return }
                storageAddr = Int( self.readCell(cfa + 16) )
            } else if first == self.createRuntimeID || first == self.dodoesID {
                storageAddr = Int( self.readCell(cfa + 8) )
            } else {
                self.push(0); return
            }
            self.push( self.readCell(storageAddr) )
        }

        // IS ( xt "<name>" -- )  Core Ext (parsing form of DEFER! / VALUE assignment)
        // Also works for VALUEs (stores the new value into the VALUE's cell).
        _ = register("IS", immediate: false) {   // not immediate; the parsing version
            let newXt = self.pop()
            let name = self.parseWord()
            if name.isEmpty { self.tell("? IS needs a name\n"); self.errorFlag = true; return }
            let hdr = self.findWord(name)
            if hdr == 0 { self.tell("? IS ? " + name + "\n"); self.errorFlag = true; return }
            let cfa = self.getCFA(hdr)
            let first = self.readCell(Int(cfa))
            var storageAddr: Int = 0
            if first == self.docolID {
                let second = self.readCell(Int(cfa) + 8)
                if second != self.litID {
                    self.tell("? IS target does not look like DEFER/VALUE\n"); self.errorFlag = true; return
                }
                storageAddr = Int( self.readCell(Int(cfa) + 16) )
            } else if first == self.createRuntimeID || first == self.dodoesID {
                storageAddr = Int( self.readCell(Int(cfa) + 8) )
            } else {
                self.tell("? IS target is not a supported defer or value\n"); self.errorFlag = true; return
            }
            self.writeCell(storageAddr, newXt)
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
            let dataAddr = self.readCell(self.DP_ADDR) + 16
            self.push(self.createRuntimeID); self.comma()
            self.push(dataAddr); self.comma()
            // DP_ADDR is now at the data field start. No extra ALLOT (unlike VARIABLE).
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
            let placeholder = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.push(self.doesPatchID); self.comma()

            // The does code starts at the current DP_ADDR (dict ptr value).
            let doesCodeAddr = self.readCell(self.DP_ADDR)
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

        // For teaching purposes, let's also define a few classic words by compiling them.
        // (QUIT is provided as a primitive so RSP wipe is safe; it appears in WORDS/SEE/HELP.)

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

        // >NFA gives address of the name field (the flags+length byte). For words
        // defined without IMMEDIATE or HIDDEN, the byte value is just the name length,
        // so COUNT TYPE on it will print the name cleanly. For flagged words the
        // count will be inflated by the flag bits.
        self.feedLine(": >NFA >HEADER 8 + ;   ( xt -- nfa )")

        // ID. is a robust "print name from xt" that masks the length out of the
        // flags+len byte, so it always prints exactly the name chars even for
        // IMMEDIATE words etc. This avoids the "anomaly" of garbage before/after
        // the name when inspecting headers with COUNT TYPE directly on >HEADER
        // (which points at the link field, not the name) or on >NFA for flagged words.
        self.feedLine(": ID. ( xt -- ) >NFA DUP C@ 31 AND SWAP 1+ SWAP TYPE ;")

        // Teaching version: a minimal high-level FORGET that assumes an xt is already
        // on the stack (from a preceding tick). We deliberately give it a different
        // name so it does *not* shadow the user-friendly parsing primitive FORGET
        // (the one registered above that accepts "FORGET NAME" directly and also
        // restores HERE to reclaim memory).
        // Users normally just type:   FORGET TEST
        // The primitive version has the kernelLatest safety guard and good errors.
        // Advanced / teaching usage:  ' TEST FORGET-WORD
        self.feedLine(": FORGET-WORD >LFA @ LATEST ! ;")

        // HERE is the current dictionary pointer value (for allocation, , etc.).
        // DP is the variable holding it (DP -- addr of the ptr cell).
        // This matches the classic expectation "HERE is DP @".
        self.feedLine(": HERE DP @ ;")

        // Vocabulary support (high-level for nice SEE decompile)
        self.feedLine(": VOCABULARY CREATE 0 , DOES> @ SET-CONTEXT ;")
        self.feedLine(": FORTH 0 SET-CONTEXT ;")
        self.feedLine(": DEFINITIONS CONTEXT @ CURRENT ! ;")

        // file-echo variable (user can do: file-echo ON   or   file-echo OFF ).
        // Controls whether FLOAD echoes each source line to the console as it loads.
        // Created via the VARIABLE word so it appears in WORDS / SEE / FORGET etc.
        // Default is 0 (off) because the data cell lives in the zeroed memory area.
        self.feedLine("VARIABLE FILE-ECHO")
        self.feedLine(": ERASE 0 FILL ;")  // high-level so SEE shows source (0 FILL)

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
            self.fileEchoAddr = self.readCell(self.DP_ADDR)
            self.writeCell(self.DP_ADDR, self.fileEchoAddr + 8)
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
                // Try number, respecting current BASE (supports 2..36, signs, letters A-Z)
                let b = self.readCell(self.BASE)
                if let num = Int(name, radix: Int( max(2, min(36, b)) )) {
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

        // Classic Forth behavior: after successfully interpreting a complete *interactive*
        // (top-level REPL) line in interpret mode, print "OK" followed by newline.
        // During FLOAD (loadNesting > 0), we never emit these per-line OKs -- only
        // explicit FILE-ECHO source lines (if enabled) + whatever regular output the
        // interpreted source actually produces (., TYPE, EMIT, etc.).
        //
        // (No leading space so that after ".s" or CR it doesn't look indented,
        // and after "." we get the single space that "." already emitted.)
        //
        // Do not print OK if we suspended for a blocking input word like KEY;
        // the OK will be printed when the line is resumed and completed after provideKey.
        if !errorFlag && readCell(STATE) == 0 && !waitingForKey && loadNesting == 0 {
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
                let c = self.consumeInput() ?? 0
                if c == 123 { // '{'
                    self.inSlashSlashComment = false
                    break
                }
            }
            if self.inSlashSlashComment {
                // This entire line (and future feeds until {) is comment; stop word parsing for this feed.
                // (For interactive REPL feeds, OK will still be emitted at end of this feedLine,
                // consistent with \ and ( comments. During FLOAD the OK is suppressed anyway.)
                return ""
            }
        }

        // Skip whitespace
        while let b = inputQueue.first, b <= 32 {
            _ = consumeInput()
        }
        if inputQueue.isEmpty { return "" }

        var word: [UInt8] = []
        while let b = inputQueue.first, b > 32 {
            word.append(consumeInput()!)
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
            result = String(result.map { 
                if isApostropheLike($0) { return "'" }
                if isDoubleQuoteLike($0) { return "\"" }
                return $0 
            })
        }

        return result
    }

    /// Returns true if the current queue position starts a delimiter matching 'delim'.
    /// For delim==34, also accepts multi-byte UTF-8 smart/curly double quotes.
    /// Does not consume.
    private func peekIsDelim(_ delim: UInt8) -> Bool {
        if inputQueue.isEmpty { return false }
        let b0 = inputQueue.first!
        if b0 == delim { return true }
        if delim != 34 { return false }
        if inputQueue.count >= 3 {
            let b1 = inputQueue[1]
            let b2 = inputQueue[2]
            if b0 == 0xe2 && b1 == 0x80 && [0x9c, 0x9d, 0x9e, 0x9f, 0xb3, 0xb6].contains(b2) { return true }
            if b0 == 0xef && b1 == 0xbc && b2 == 0x82 { return true }
        }
        if inputQueue.count >= 2 {
            let b1 = inputQueue[1]
            if b0 == 0xc2 && [0xab, 0xbb].contains(b1) { return true }
        }
        return false
    }

    /// If current position matches the given delim (exact for non-34, or ascii+smart for 34),
    /// consume the matching byte(s) and return true.
    private func consumeDelim(_ delim: UInt8) -> Bool {
        if inputQueue.isEmpty { return false }
        let b0 = inputQueue.first!
        if b0 == delim {
            _ = inputQueue.removeFirst()
            let pos = readCell(IN); writeCell(IN, pos + 1)
            return true
        }
        if delim != 34 { return false }
        // smart doubles
        if inputQueue.count >= 3 {
            let b1 = inputQueue[1]
            let b2 = inputQueue[2]
            if b0 == 0xe2 && b1 == 0x80 && [0x9c, 0x9d, 0x9e, 0x9f, 0xb3, 0xb6].contains(b2) {
                for _ in 0..<3 { _ = inputQueue.removeFirst() }
                let pos = readCell(IN); writeCell(IN, pos + 3)
                return true
            }
            if b0 == 0xef && b1 == 0xbc && b2 == 0x82 {
                for _ in 0..<3 { _ = inputQueue.removeFirst() }
                let pos = readCell(IN); writeCell(IN, pos + 3)
                return true
            }
        }
        if inputQueue.count >= 2 {
            let b1 = inputQueue[1]
            if b0 == 0xc2 && [0xab, 0xbb].contains(b1) {
                _ = inputQueue.removeFirst()
                _ = inputQueue.removeFirst()
                let pos = readCell(IN); writeCell(IN, pos + 2)
                return true
            }
        }
        return false
    }

    /// Consume one byte from the input source (queue), advancing >IN by 1.
    /// Used by all parsers (WORD, PARSE, comments, ACCEPT, etc.) so that SOURCE + >IN stay in sync.
    private func consumeInput() -> UInt8? {
        if inputQueue.isEmpty { return nil }
        let b = inputQueue.removeFirst()
        let pos = readCell(IN)
        writeCell(IN, pos + 1)
        return b
    }

    // Helper used by WORD and CHAR (and future string parsers). Consumes from inputQueue
    // (which receives appended lines from feedLine, whether REPL or FLOAD content).
    // Skips leading exact delims, collects until delim or line-end, builds counted string
    // (len byte + chars + trailing blank) at fixed WORD_BUFFER in the memory array.
    // Returns the Forth addr of the count byte. The trailing delim (if any) is left in queue.
    private func parseToWordBuffer(using delim: UInt8) -> Cell {
        var collected: [UInt8] = []

        // Skip leading delimiters (exact ascii or smart-double for ")
        while !self.inputQueue.isEmpty {
            if !self.consumeDelim(delim) {
                break
            }
        }

        // Collect non-delim chars; also stop at line ends (10/13) so we don't eat \n etc.
        while !self.inputQueue.isEmpty {
            let b = self.inputQueue.first!
            if self.peekIsDelim(delim) || b == delim || b == 10 || b == 13 {
                break
            }
            collected.append(self.consumeInput()!)
        }

        // Consume a closing delim if present (supports smart doubles for ")
        _ = self.consumeDelim(delim)

        let len = min(collected.count, self.WORD_BUFFER_SIZE - 2)
        self.writeByte(self.WORD_BUFFER, UInt8(len))
        for (i, b) in collected.prefix(len).enumerated() {
            self.writeByte(self.WORD_BUFFER + 1 + i, b)
        }
        self.writeByte(self.WORD_BUFFER + 1 + len, 32)  // trailing blank per classic
        return Cell(self.WORD_BUFFER)
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
                // Treat as address of another colon definition (threaded call).
                // Jump directly past the DOCOL marker cell at the target CFA; the
                // return frame was already pushed above (standard for this marker style).
                rpush(ip)
                ip = Int(cell) + 8
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

            // LIT must be handled *before* the generic primitive name check, because LIT
            // is itself a registered primitive (small ID). If we check primitiveNames first,
            // we print "LIT " (via name lookup) and continue without consuming the inline
            // literal operand cell. The next cell (the actual value, e.g. a char code from ."
            // or a number) would then be misinterpreted as the next opcode — leading to
            // garbage decompiles that print random word names (whose IDs happen to match
            // the literal values) instead of the values, and "LIT <name> EMIT" etc. for
            // string literals. Execution was unaffected because LIT runtime always reads
            // the inline value.
            if cell == self.litID {
                if ip + 8 <= self.memory.count {
                    let val = self.readCell(ip)
                    ip += 8
                    // Print the value. For small printable ASCII (common from .") show a
                    // hint of the char to make decompiles of string defs more readable.
                    var shown = "\(val)"
                    if (32...126).contains(Int(val)),
                       let scalar = UnicodeScalar(UInt32(val)) {
                        shown += " ('\(Character(scalar))')"
                    }
                    self.tell("LIT \(shown) ")
                } else {
                    break
                }
                continue
            }

            // Special handling for the runtime string emitter used by ."
            // This lets SEE produce traditional readable output instead of trying to
            // decompile the inlined string bytes as instructions.
            if cell == self.dotQuoteID {
                self.tell(".\" ")
                let strAddr = ip
                let len = Int(self.readByte(strAddr))
                var content = ""
                for i in 0..<len {
                    let b = self.readByte(strAddr + 1 + i)
                    if b == 34 {
                        content += "\\\""
                    } else if b == 92 {
                        content += "\\\\"
                    } else if let scalar = UnicodeScalar(UInt32(b)) {
                        content += String(Character(scalar))
                    } else {
                        content += "?"
                    }
                }
                self.tell(content + "\" ")
                var newIP = ip + 1 + len
                while (newIP & 7) != 0 { newIP += 1 }
                ip = newIP
                continue
            }

            // Special handling for the runtime string emitter used by S"
            // Mirrors the dotQuote handling so SEE produces "S" text " " instead of
            // (S\") <garbage number> etc.
            if cell == self.sQuoteID {
                self.tell("S\" ")
                let strAddr = ip
                let len = Int(self.readByte(strAddr))
                var content = ""
                for i in 0..<len {
                    let b = self.readByte(strAddr + 1 + i)
                    if b == 34 {
                        content += "\\\""
                    } else if b == 92 {
                        content += "\\\\"
                    } else if let scalar = UnicodeScalar(UInt32(b)) {
                        content += String(Character(scalar))
                    } else {
                        content += "?"
                    }
                }
                self.tell(content + "\" ")
                var newIP = ip + 1 + len
                while (newIP & 7) != 0 { newIP += 1 }
                ip = newIP
                continue
            }

            // Special handling for the runtime used by ABORT" (for completeness in decompiles)
            if cell == self.abortQuoteID {
                self.tell("ABORT\" ")
                let strAddr = ip
                let len = Int(self.readByte(strAddr))
                var content = ""
                for i in 0..<len {
                    let b = self.readByte(strAddr + 1 + i)
                    if b == 34 {
                        content += "\\\""
                    } else if b == 92 {
                        content += "\\\\"
                    } else if let scalar = UnicodeScalar(UInt32(b)) {
                        content += String(Character(scalar))
                    } else {
                        content += "?"
                    }
                }
                self.tell(content + "\" ")
                var newIP = ip + 1 + len
                while (newIP & 7) != 0 { newIP += 1 }
                ip = newIP
                continue
            }

            if let pname = self.primitiveNames[cell] {
                self.tell(pname + " ")
                continue
            }

            let searchHeadCell = self.searchOrder.isEmpty ? self.LATEST : self.searchOrder[0]
            var targetHeader = self.readCell(searchHeadCell)
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
    /// Stacks are emptied, dictionary is truncated to the initial kernel+bootstrap state
    /// (all user-defined words and their data space are forgotten, like a full FORGET of
    /// everything after kernel), errorFlag cleared, STATE forced to interpret mode.
    /// Safe to call from the host app (ConsoleView, tests) at any time.
    // Temp for debug
    public func debugFind(_ n: String) -> Bool { return findWord(n) != 0 }

    /// Restore LATEST and HERE to the post-bootstrap kernel state, removing all
    /// user-defined words (and reclaiming their memory). Also re-captures
    /// fileEchoAddr from the (still-present) kernel FILE-ECHO word.
    private func restoreKernelDictionary() {
        if kernelLatest != 0 {
            writeCell(LATEST, kernelLatest)
        }
        if kernelHere != 0 {
            writeCell(DP_ADDR, kernelHere)
        }

        // Re-capture fileEchoAddr (the VARIABLE and its data cell are part of kernel).
        // Do not allocate in the fallback here — that would advance HERE past kernelHere.
        fileEchoAddr = 0
        let hdr = self.findWord("FILE-ECHO")
        if hdr != 0 {
            let cfa = self.getCFA(hdr)
            if self.readCell(Int(cfa)) == self.docolID {
                if self.readCell(Int(cfa) + 8) == self.litID {
                    self.fileEchoAddr = self.readCell(Int(cfa) + 16)
                }
            }
        }
        // If still 0 (shouldn't happen), FLOAD will just treat echo as off; safe.

        // Reset to FORTH vocabulary
        searchOrder = [LATEST]
        setContext(LATEST)
        writeCell(CURRENT, LATEST)
    }

    /// Resets only runtime execution state (stacks, IP, flags, queues, debug, KEY/FLOAD
    /// pending, loop controls, comment state). Does *not* touch the dictionary.
    /// Useful for test harnesses that want to clean between steps while leaving
    /// previously loaded/defined words intact. For a user-visible full reset (incl.
    /// clearing all user words), use resetToSafeState().
    public func resetRuntimeState() {
        spSet(1)
        rspSet(1)
        ip = 0
        commandAddress = 0
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
        pendingLoadURL = nil
        loopControlStack.removeAll()
        self.inSlashSlashComment = false
        self.sourceLoadStop = false
        self.loadNesting = 0
        // pictured state
        self.pnoPtr = self.pnoBufferAddr + self.PNO_BUFFER_SIZE
        writeCell(IN, 0)
        searchOrder = [LATEST]
        setContext(LATEST)
        writeCell(CURRENT, LATEST)
        self.currentSourceLen = 0
    }

    public func resetToSafeState() {
        validateAndRepairSystemState()   // extra belt-and-suspenders

        // Clean runtime state first (stacks, flags, etc.).
        resetRuntimeState()

        // Full dictionary reset to initial state (user words + their data space gone).
        restoreKernelDictionary()

        // Leave IP wherever it is; the next feedLine will start fresh parsing from
        // whatever input arrives next. (A real high-level QUIT now exists via bootstrap.)
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
        pendingLoadURL = nil
        loopControlStack.removeAll()
        self.inSlashSlashComment = false
        self.sourceLoadStop = false
        self.pnoPtr = self.pnoBufferAddr + self.PNO_BUFFER_SIZE
        self.currentSourceLen = 0
        searchOrder = [LATEST]
        setContext(LATEST)
        writeCell(CURRENT, LATEST)

        let wasLoading = self.loadNesting > 0
        // Do not zero loadNesting here; the loadFileContents defer (or its error path) will
        // handle the decrement when the load aborts/ends. Zeroing here could make later \S
        // in the same file see nesting==0 and fail to stop.

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
            if wasLoading {
                // Aborting load due to compile error inside the file: clean up the partial
                // definition (unhide it) and force back to interpret mode so the REPL after
                // the aborted FLOAD is not left in compiling state.
                let defsHeadCell = readCell(CURRENT)
                let latest = readCell(defsHeadCell)
                if latest != 0 {
                    let fl = readByte(Int(latest) + 8)
                    writeByte(Int(latest) + 8, fl & ~FLAG_HIDDEN)
                }
                writeCell(STATE, 0)
            } else {
                // Do NOT unhide or force STATE=0 here for interactive.
                // The definition remains open for further lines.
                tell("? Compile error — definition is still open.\n")
                tell("? Type more lines to continue it, or `;` alone to finish it.\n")
            }
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
        let safeDictStart = (kernelHere != 0 ? kernelHere : initialDict)
        let h = readCell(DP_ADDR)
        if h < safeDictStart || h > MEM_SIZE - 1024 {
            writeCell(DP_ADDR, safeDictStart)
        }
        let b = readCell(BASE)
        if b < 2 || b > 36 { writeCell(BASE, 10) }
        writeCell(IN, 0)

        ip = 0
        commandAddress = 0

        // For errors during FLOAD (loadNesting > 0 at time of error), leave errorFlag set so that
        // loadFileContents can observe it after the sub-feedLine returns and abort
        // further lines in the current file (classic "stop on first error" for include).
        // The load loop will clear it after reporting. We captured wasLoading before zeroing nesting.
        if wasLoading {
            errorFlag = true
        } else {
            errorFlag = false
        }
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
        let safeDictStart = (kernelHere != 0 ? kernelHere : initialDict)
        let h = readCell(DP_ADDR)
        if h < safeDictStart || h >= MEM_SIZE - 1024 {
            writeCell(DP_ADDR, safeDictStart)
        }
        // If the dictionary chain looks completely broken, reset the FORTH head (LATEST cell) to kernel
        // (never below kernel; preserves core words on corruption recovery).
        let l = readCell(LATEST)
        if l != 0 && !isValidDictionaryLink(l) {
            writeCell(LATEST, kernelLatest != 0 ? kernelLatest : 0)
        }
        // Ensure CONTEXT/CURRENT point to a valid head cell (default to FORTH)
        let cctx = readCell(CONTEXT)
        if cctx != LATEST && cctx != 0 { /* leave, or could validate */ }
        if readCell(CONTEXT) == 0 || readCell(CURRENT) == 0 || searchOrder.isEmpty {
            searchOrder = [LATEST]
            setContext(LATEST)
            writeCell(CURRENT, LATEST)
        }

        let st = readCell(STATE)
        if st != 0 && st != 1 {
            writeCell(STATE, 0)
        }

        let b = readCell(BASE)
        if b < 2 || b > 36 {
            writeCell(BASE, 10)
        }
        pnoPtr = pnoBufferAddr + PNO_BUFFER_SIZE
        writeCell(IN, 0)
    }

    public var stackAsString: String {
        let depth = Int(spGet() - 1)
        let b = self.readCell(self.BASE)
        var s = ""
        for i in 0..<depth {
            let v = readCell(stackBase + i * 8)
            s += self.formatNumber(v, base: b, signed: true) + " "
        }
        return s
    }

    public var dictionarySnapshot: [(name: String, xt: Cell)] {
        var result: [(String, Cell)] = []
        let searchHeadCell = readCell(CONTEXT)
        var link = readCell(searchHeadCell)
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

    // MARK: - ANS Validation Tests (ported/adapted from TestTZForth.swift FTEST, originally TestLBForth.swift)
    // These sources and runner allow the ANS-VALIDATE word to run the 2012 ANS Forth
    // Core/Core Ext compliance tests from inside the interpreter and write results to
    // ANS-VALIDATE.txt next to the test source (in the dev folder of TestTZForth.swift).
    // The test logic and sources originated in the standalone tester; we respect the lbForth model origins internally.

    internal let testBlockSrc = """
\\ normal line comment
: load1 11 ;
\\\\ block comment start (spans lines)
: noskip1 22 ;
spanning line without closer yet
{ : after1 33 ;  \\ closer, text after { runs
: load2 44 ;
"""

    internal let testStopSrc = """
: pre 55 ;
: pre2 77 ;
\\\\ block comment protects the \\S below from stopping the load
\\S
: ignored 88 ;
{ : post2 99 ;
\\S
: post 66 ;
"""

    internal let testEchoSrc = """
FILE-ECHO ON
: echopre 42 ;
\\S
: echopost 99 ;
"""

    internal let testDebugSrc = """
DEBUG-ON
: dbg1 123 ;
DEBUG-OFF
: dbg2 456 ;
: dbg3 789 ;
"""

    internal let testDotqSrc = """
: hello ." Hello from dot quote" ;
hello
.(  -- above should have printed without leading space )
: bad ." test " FOO  ;   \\ will error on FOO (after .") while compiling
: afterbad 999 ;
"""

}
