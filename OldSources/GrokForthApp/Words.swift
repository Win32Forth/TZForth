import Foundation

extension GrokForthInterpreter {
    
    // Single source of truth for primitive word documentation
    private static let primitives: [(name: String, stack: String, desc: String)] = [
        // Arithmetic
        ("+",       "( n1 n2 -- n )",     "addition"),
        ("-",       "( n1 n2 -- n )",     "subtraction"),
        ("*",       "( n1 n2 -- n )",     "multiplication"),
        ("/",       "( n1 n2 -- quot )",  "division"),
        ("MOD",     "( n1 n2 -- rem )",   "remainder"),
        ("1+",      "( n -- n+1 )",       "increment"),
        ("1-",      "( n -- n-1 )",       "decrement"),
        ("ABS",     "( n -- u )",         "absolute value"),
        ("NEGATE",  "( n -- -n )",        "negate"),
        ("MIN",     "( n1 n2 -- min )",   "minimum"),
        ("MAX",     "( n1 n2 -- max )",   "maximum"),
        
        // Stack
        ("DUP",     "( n -- n n )",       "duplicate"),
        ("DROP",    "( n -- )",           "discard top"),
        ("SWAP",    "( a b -- b a )",     "swap top two"),
        ("OVER",    "( a b -- a b a )",   "copy second"),
        ("ROT",     "( a b c -- b c a )", "rotate"),
        ("-ROT",    "( a b c -- c a b )", "reverse rotate"),
        ("NIP",     "( a b -- b )",       "remove second"),
        ("TUCK",    "( a b -- b a b )",   "tuck top under second"),
        
        // Memory
        ("@",       "( addr -- n )",      "fetch cell"),
        ("!",       "( n addr -- )",      "store cell"),
        ("+!",      "( n addr -- )",      "add to cell"),
        ("C@",      "( addr -- byte )",   "fetch byte"),
        ("C!",      "( byte addr -- )",   "store byte"),
        
        // Output
        (".",       "( n -- )",           "print number"),
        (".S",      "( -- )",             "print data stack"),
        ("CR",      "( -- )",             "carriage return"),
        ("SPACE",   "( -- )",             "print space"),
        ("SPACES",  "( n -- )",           "print n spaces"),
        ("\\S",     "( -- )",             "stop loading the current source file (used inside FLOAD)"),
        
        // Control Flow
        ("DO",      "( limit start -- )", "start counted loop"),
        ("LOOP",    "( -- )",             "end DO loop"),
        ("UNLOOP",  "( -- )",             "discard loop parameters"),
        ("LEAVE",   "( -- )",             "exit loop early"),
        ("?DO",     "( limit start -- )", "DO loop that skips if start == limit"),
        ("I",       "( -- n )",           "current loop index"),
        ("BEGIN",   "( -- )",             "start indefinite loop"),
        ("UNTIL",   "( flag -- )",        "loop while false"),
        ("AGAIN",   "( -- )",             "infinite loop"),
        ("IF",      "( flag -- )",        "conditional branch"),
        ("ELSE",    "( -- )",             "else branch"),
        ("THEN",    "( -- )",             "end IF"),
        
        // Dictionary & System
        ("WORDS",   "( -- )",             "list all words"),
        ("SEE",     "( -- name )",        "decompile word"),
        ("HELP",    "( -- ) name",        "show help for a word"),
        (".(",      "( -- )",             "print text until ) immediately (used while loading)"),
        ("FLOAD",   "( -- ) name",        "load Forth source file from disk"),
        ("RESET",   "( -- )",             "reset interpreter state and clear screen"),
        ("CLS",     "( -- )",             "clear the console screen"),
        ("FORGET",  "( -- ) name",        "forget a word and all words defined after it"),
        ("CHDIR",   "( -- ) [path]",      "change or display current directory"),
        ("DIR",     "( -- ) [filespec]",  "list directory (MS-DOS style, supports wildcards)"),
        ("LS",      "( -- ) [filespec]",  "synonym for DIR - list directory"),
        ("MKDIR",   "( -- ) name",        "create a new directory"),
        ("EDIT",    "( -- ) [name]",      "edit file in TextEdit (defaults to .fth)"),
        ("VARIABLE","( -- ) name",        "create variable"),
        ("CONSTANT","( n -- ) name",      "create constant"),
        ("VALUE",   "( n -- ) name",      "create value"),
 
        ("AND",     "( n1 n2 -- n )",     "bitwise and"),
        ("OR",      "( n1 n2 -- n )",     "bitwise or"),
        ("XOR",     "( n1 n2 -- n )",     "bitwise xor"),
        ("INVERT",  "( n -- ~n )",        "bitwise invert"),
        ("LSHIFT",  "( n bits -- n )",    "left shift"),
        ("RSHIFT",  "( n bits -- n )",    "right shift"),
        ("TRUE",    "( -- -1 )",          "true flag"),
        ("FALSE",   "( -- 0 )",           "false flag"),
        ("DEPTH",   "( -- n )",           "stack depth"),
        ("WITHIN",  "( n lo hi -- flag )","n within lo..hi"),
        
        // Base
        ("HEX",     "( -- )",             "set base 16"),
        ("DECIMAL", "( -- )",             "set base 10"),
        ("OCTAL",   "( -- )",             "set base 8"),
        ("BINARY",  "( -- )",             "set base 2"),
        ("BASE",    "( -- addr )",        "push base address"),

        // Comparisons (implemented in dispatch)
        ("=",       "( n1 n2 -- flag )",  "equal"),
        ("<>",      "( n1 n2 -- flag )",  "not equal"),
        ("<",       "( n1 n2 -- flag )",  "less than"),
        (">",       "( n1 n2 -- flag )",  "greater than"),
        ("<=",      "( n1 n2 -- flag )",  "less or equal"),
        (">=",      "( n1 n2 -- flag )",  "greater or equal"),
        ("0=",      "( n -- flag )",      "zero?"),
        ("0<",      "( n -- flag )",      "negative?"),
        ("0>",      "( n -- flag )",      "positive?"),

        // Extended Memory
        (",",       "( n -- )",           "compile cell"),
        ("C,",      "( b -- )",           "compile byte"),
        ("ALLOT",   "( n -- )",           "allocate memory"),
        ("HERE",    "( -- addr )",        "current dictionary pointer"),
        ("-!",      "( n addr -- )",      "subtract from cell"),
        ("CELL+",   "( addr -- addr' )",  "add cell size"),
        ("CELLS",   "( n -- n )",         "cells to bytes (identity here)"),
        ("CHAR+",   "( addr -- addr' )",  "add char size"),
        ("CHARS",   "( n -- n )",         "chars to bytes (identity here)"),
        ("2@",      "( addr -- n1 n2 )",  "fetch double cell"),
        ("2!",      "( n1 n2 addr -- )",  "store double cell"),

        // Extended Stack / Return
        (">R",      "( n -- ) ( R: -- n )", "to return stack"),
        ("R>",      "( -- n ) ( R: n -- )", "from return stack"),
        ("R@",      "( -- n ) ( R: n -- n )", "copy top of return stack"),
        ("2>R",     "( n1 n2 -- ) ( R: -- n1 n2 )", "two to return stack"),
        ("2R>",     "( -- n1 n2 ) ( R: n1 n2 -- )", "two from return stack"),
        ("2R@",     "( -- n1 n2 ) ( R: n1 n2 -- n1 n2 )", "copy two from return stack"),
        ("PICK",    "( n -- n )",         "pick nth stack item"),
        ("ROLL",    "( n -- )",           "roll nth stack item"),

        // More Output
        ("U.",      "( u -- )",           "print unsigned"),
        ("U.R",     "( u n -- )",         "print unsigned right justified"),
        ("TYPE",    "( addr len -- )",    "print string"),
        ("EMIT",    "( c -- )",           "print character"),

        // Misc
        ("ARSHIFT", "( n bits -- n )",    "arithmetic right shift"),
        ("BL",      "( -- 32 )",          "blank character (space)"),
        ("CHAR",    "( -- c )",           "parse character (stub)"),

        // Extended Control
        ("+LOOP",   "( n -- )",           "end DO loop with increment (partial)")
    ]
    
    internal static let primitiveLookup: [String: (stack: String, desc: String)] = {
        Dictionary(uniqueKeysWithValues: primitives.map { 
            ($0.name, (stack: $0.stack, desc: $0.desc)) 
        })
    }()
    
    func listWords() {
        // Built-in words in alphabetical order
        let builtinNames = Self.primitives.map { $0.name }.sorted()
        
        // User-defined words in the order they were compiled (definition order)
        let userNames = wordOrder
        
        // Internals first (alpha), then user words (compile order) at the end
        let allWords = builtinNames + userNames
        
        outputBuffer += allWords.joined(separator: " ") + "\n"
    }
    
    /// Displays help information for a single word (used by HELP <word>)
    func help(for word: String) {
        let upper = word.uppercased()
        
        if let info = Self.primitiveLookup[upper] {
            outputBuffer += "\n\(upper)  \(info.stack)  \(info.desc)\n\n"
            return
        }
        
        if dictionary[upper] != nil {
            outputBuffer += "\n\(upper)  ( -- )  user-defined\n\n"
            appendDefinition(of: upper)
            outputBuffer += "\n"
            return
        }
        
        outputBuffer += "\(upper) ?\n"
    }
}
