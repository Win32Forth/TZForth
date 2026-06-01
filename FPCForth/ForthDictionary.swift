// ForthDictionary.swift
//
// Dictionary and Header Design for FPCForth (Educational / Research System)
//
// DESIGN PHILOSOPHY (per project direction):
// - We use a relatively rich internal model inspired by classic F-PC (separate
//   header information, link fields, explicit parameter field addresses, etc.).
//   This is intentional for educational value so we can study and demonstrate
//   how traditional Forth dictionary structures worked.
// - HOWEVER, the public Forth words we eventually expose (', >BODY, >NAME, FIND,
//   IMMEDIATE, etc.) should follow the ANS Forth 2012 standard as closely as
//   reasonably possible regarding observable behavior and word usage.
// - We deliberately avoid getting too attached to F-PC's exact low-level quirks
//   when they conflict with the standard.
//
// MEMORY MODEL (updated 2026-06)
//
// The user has clarified their long-term direction:
//
// - There is significant interest in native code generation in the future,
//   motivated in part by TCOM (the multi-target optimizing compiler that
//   shipped with F-PC). While TCOM itself is a cross-compiler (and therefore
//   does not require JIT), the project should **plan for future JIT /
//   same-architecture native code generation**.
//
// - For the dictionary itself, the current preference is:
//   - A **single flat addressable memory buffer** containing both the
//     header region and the code/parameter field region. This is necessary
//     because headers (and parameter fields) need to be addressable from
//     within user definitions.
//   - A **separate token translation table** (this can remain independent).
//
// - When native code generation is eventually added, a **separate executable
//   memory region** will almost certainly be required on Apple Silicon due
//   to strict W^X (Write XOR Execute) enforcement. We should design the
//   current system so that a future JIT code region can be added cleanly
//   without major refactoring of the data dictionary.

//
// Open design questions (to be resolved):
// - Will the main buffer be a simple [UInt8] / Data, or a more structured
//   region-based allocator?
// - How will we represent "XT" — as a direct offset into the buffer,
//   or as an index into the separate token table?
// - How do we allocate variable-length headers (especially names) inside
//   the flat buffer? (counted strings, aligned, etc.)
// - What is the relationship between "Token" (the small integer we use
//   for threading) and actual memory addresses/offsets?
//
// JIT / Native Code Generation considerations (planning for future):
// - On Apple Silicon, any region that will contain executable machine code
//   will need special allocation (MAP_JIT) and write/execute toggling via
//   pthread_jit_write_protect_np(), plus instruction cache management.
// - We should avoid tightly coupling the main data dictionary buffer to
//   any future executable code buffer. They will likely need different
//   protection and allocation strategies.

// ---------------------------------------------------------------------------
// Note: The concrete `ForthMemory` implementation lives in ForthMemory.swift.
// This file focuses on dictionary structure and word headers.
// ---------------------------------------------------------------------------

import Foundation

// MARK: - Basic Types

/// Execution Token (XT) — a small integer in our Token Threaded model.
/// In classic F-PC this would usually be a direct address or CFA.
/// Here it is a stable index into the dictionary.
public typealias XT = Int

// `Address` is provided by ForthMemory.swift (single flat buffer model).

// MARK: - Header Representation

/// Represents the "header" portion of a dictionary entry.
///
/// F-PC STYLE / BEYOND ANS:
/// This explicit separation of header information is richer than what ANS
/// Forth 2012 requires. The standard treats most header details as
/// implementation-defined and only specifies limited observable behavior
/// through words like FIND, ', >NAME (CORE EXT), and >BODY.
///
/// We keep this structure for educational purposes so we can demonstrate
/// classic dictionary navigation techniques.
public struct WordHeader {
    /// The name as a Swift String (convenient for the host).
    /// Internally we can treat this as if it were a counted string or
    /// null-terminated string for simulation purposes.
    public var name: String
    
    /// Whether the word is IMMEDIATE.
    public var immediate: Bool = false
    
    /// Link to the previous word (simulates the classic link field).
    /// In F-PC this would be an actual address in the dictionary.
    public var link: XT?
    
    /// Length of the name (computed on demand).
    /// Useful when we need addr+count semantics for `>NAME` etc.
    public var nameLength: Int {
        name.utf8.count
    }
}

// MARK: - Code Field / Execution Semantics

/// What happens when this word is executed.
/// In our Token Threaded model this is where the token lives.
public enum ExecutionToken {
    /// A primitive implemented in Swift.
    /// The associated value is the token index into the central dispatch table.
    case primitive(Token: Int)
    
    /// A colon definition: a sequence of execution tokens.
    case colon([XT])
    
    /// CREATE ... DOES> style word.
    /// The `does` field contains the tokens to execute after pushing the body address.
    case does(does: [XT])
    
    /// Other runtime behaviors (VARIABLE, CONSTANT, DEFER, etc.) can be added here.
    case runtime(kind: RuntimeKind)  // 'deferred' case below represents Forth DEFER
}

public enum RuntimeKind {
    case variable
    case constant(value: Int)
    case value
    case deferred   // represents Forth DEFER (deferred execution)
    // Add more as we implement F-PC semantics
}

// MARK: - Full Dictionary Entry

/// A complete dictionary entry combining header and execution semantics.
///
/// F-PC STYLE / BEYOND ANS:
/// The explicit combination of a rich `WordHeader` with execution semantics
/// is more structured than the ANS Forth 2012 model requires. The standard
/// does not mandate this separation or these fields.
///
/// We maintain it here to support educational exploration of how traditional
/// Forths (especially F-PC) organized their dictionaries.
public struct DictionaryEntry {
    public var header: WordHeader
    public var execution: ExecutionToken
    
    /// In F-PC, the Parameter Field Address (PFA) is what >BODY returns.
    /// For colon words this would be the address of the threaded code.
    /// For CREATE words it points to the data space allocated after the code field.
    ///
    /// For now we simulate this with an optional address.
    public var parameterFieldAddress: Address?
}

// MARK: - Dictionary

public final class ForthDictionary {
    
    /// All defined words, indexed by their execution token (XT).
    private var entries: [XT: DictionaryEntry] = [:]
    
    /// The most recently defined word (like LATEST in classic Forth).
    private var latestXT: XT?
    
    /// Next available execution token.
    private var nextToken: XT = 1
    
    // MARK: - Public API
    
    /// The execution token of the most recently defined word.
    public var latest: XT? {
        latestXT
    }
    
    /// Define a new word and return its execution token.
    @discardableResult
    public func define(name: String,
                       immediate: Bool = false,
                       execution: ExecutionToken) -> XT {
        
        let header = WordHeader(
            name: name,
            immediate: immediate,
            link: latestXT
        )
        
        let entry = DictionaryEntry(
            header: header,
            execution: execution,
            parameterFieldAddress: nil
        )
        
        let xt = nextToken
        nextToken += 1
        
        entries[xt] = entry
        latestXT = xt
        
        return xt
    }
    
    // MARK: - Navigation Methods (Educational / F-PC-inspired)
    
    /// Returns the header for a given execution token.
    ///
    /// F-PC STYLE / BEYOND ANS:
    /// Direct access to the header structure is not part of the ANS standard.
    /// This method exists primarily for educational introspection and for
    /// implementing higher-level words.
    public func header(for xt: XT) -> WordHeader? {
        entries[xt]?.header
    }
    
    /// Returns the parameter-field address for a given execution token.
    ///
    /// RELATIONSHIP TO ANS FORTH 2012:
    /// This is the internal mechanism that will eventually support the
    /// standard word `>BODY` (6.1.2033).
    ///
    /// IMPORTANT (Standard Compliance):
    /// Per ANS Forth, `>BODY` is only required to work for words defined
    /// with `CREATE` (and words that behave like them). At the Forth word
    /// level we must enforce this restriction, even though our internal
    /// representation currently allows it for more word types.
    ///
    /// F-PC STYLE:
    /// In F-PC, >BODY was more broadly usable. We are intentionally moving
    /// away from unrestricted F-PC behavior toward standard rules.
    public func bodyAddress(for xt: XT) -> Address? {
        entries[xt]?.parameterFieldAddress
    }
    
    /// Returns the length of the name for a given word.
    ///
    /// This is useful when implementing `>NAME` (CORE EXT) or other
    /// reflective words that need `c-addr u` semantics.
    ///
    /// Note: We currently do not store a "name address" because we are
    /// not maintaining a flat memory buffer for dictionary names yet.
    /// When (or if) we decide to provide real or simulated addresses for
    /// names, we can extend this method or add a companion.
    public func nameCount(for xt: XT) -> Int? {
        entries[xt]?.header.nameLength
    }
    
    /// Find a word by name (case insensitive).
    ///
    /// RELATIONSHIP TO ANS FORTH 2012:
    /// This implements the core behavior of the required word `FIND`
    /// (6.1.1550). The standard specifies the *result* of FIND (xt + flag),
    /// not the internal search mechanism. Our link-walking approach is a
    /// common traditional technique (F-PC style) but is not mandated.
    public func find(_ name: String) -> XT? {
        let upper = name.uppercased()
        
        var current = latestXT
        while let xt = current {
            if let header = entries[xt]?.header,
               header.name.uppercased() == upper {
                return xt
            }
            current = entries[xt]?.header.link
        }
        return nil
    }
    
    /// Returns the execution semantics for a token.
    public func execution(for xt: XT) -> ExecutionToken? {
        entries[xt]?.execution
    }
    
    /// Mark a word as IMMEDIATE (like the F-PC IMMEDIATE word).
    public func makeImmediate(_ xt: XT) {
        guard var entry = entries[xt] else { return }
        entry.header.immediate = true
        entries[xt] = entry
    }
    
    /// Number of words currently defined.
    public var count: Int {
        entries.count
    }
}

// MARK: - Design Notes & Future Considerations

/*
 EDUCATIONAL GOAL:
 We want rich enough internals to demonstrate and experiment with classic
 dictionary techniques (headers, parameter fields, link chains, etc.).

 STANDARD COMPLIANCE GOAL:
 When we expose Forth words that operate on these structures (', >BODY,
 >NAME, FIND, IMMEDIATE, etc.), their *observable behavior* from the
 perspective of Forth source code should follow ANS Forth 2012 as closely
 as reasonably possible.

 Key distinctions we must maintain:
 - `>BODY` (6.1.2033) is only specified for CREATE words in the standard.
   Even though our internal `bodyAddress(for:)` may work more broadly,
   the Forth-level word must respect this restriction.
 - `>NAME` lives in the CORE EXT wordset, not CORE.
 - Dictionary internals (link fields, exact header layout, etc.) are
   deliberately left implementation-defined by the standard.

 This file deliberately leans "F-PC flavored" internally for learning
 purposes, while we will keep the public wordset behavior closer to the
 standard than original F-PC was.
*/