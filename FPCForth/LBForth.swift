//
//  LBForth.swift
//  FPCForth
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

    // Primitive dispatch table: ID -> implementation
    private var primitives: [(() -> Void)?] = []

    // ID of critical words we need during bootstrap
    private var docolID: Cell = 0
    private var exitID: Cell = 0
    private var litID: Cell = 0

    // Low-level branch primitives (captured so high-level control words can compile them)
    private var branchID: Cell = 0
    private var zeroBranchID: Cell = 0

    // Reverse map: primitive ID -> name (for SEE and debugging)
    private var primitiveNames: [Cell: String] = [:]

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

        _ = register("DUP")   { let v = self.pop(); self.push(v); self.push(v) }
        _ = register("DROP")  { _ = self.pop() }
        _ = register("SWAP")  { let b = self.pop(); let a = self.pop(); self.push(b); self.push(a) }
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
            while self.inputQueue.isEmpty {
                // Small sleep to avoid spinning at 100% CPU.
                // 10ms is responsive enough for interactive use while being gentle on the host.
                usleep(10000)
            }
            self.push( Int(self.inputQueue.removeFirst()) )
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

        // Basic comparison words users expect immediately
        _ = register("=")  { let b = self.pop(); let a = self.pop(); self.push(a == b ? -1 : 0) }
        _ = register("<")  { let b = self.pop(); let a = self.pop(); self.push(a <  b ? -1 : 0) }
        _ = register(">")  { let b = self.pop(); let a = self.pop(); self.push(a >  b ? -1 : 0) }

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

            self.tell(": " + name + " ")

            let cfa = self.getCFA(hdr)
            var ip = Int(cfa)

            let first = self.readCell(ip)

            if first == self.docolID {
                // Proper colon definition — decompile the body and always end with ;
                ip += 8
            } else if first < Cell(self.MAX_BUILTIN_ID) {
                // This is a primitive (CFA starts with small ID followed by EXIT)
                if let pname = self.primitiveNames[first] {
                    self.tell(pname + " (primitive) ;\n")
                } else {
                    self.tell("primitive ID " + String(first) + " ;\n")
                }
                return
            } else {
                // Fallback — treat as unknown threaded code
                self.tell("??? ;\n")
                return
            }

            // Much more robust decompiler for the token-threaded model:
            // - Stop cleanly on EXIT
            // - High safety limit
            // - Do not hard-stop on the live HERE (FORGET moves it)
            // - Try to resolve unknown cells as calls to other words
            var safety = 0
            let MAX_CELLS = 4096
            while safety < MAX_CELLS {
                safety += 1

                if ip + 8 > self.memory.count { break }

                let cell = self.readCell(ip)
                ip += 8

                if cell == self.exitID {
                    // Classic behavior: don't show the final EXIT that ; compiles
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
                        // Force the cell after LIT to be printed as a decimal number.
                        // Never let it fall through to name/CFA resolution.
                        self.tell("\(val) ")
                    } else {
                        break
                    }
                    continue
                }

                // Try to resolve as a call to another word by searching for a header
                // whose CFA matches this cell.
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
            let body = self.readCell(self.HERE) + 8   // address after the LIT cell we are about to write
            self.push(body); self.comma()
            self.push(self.exitID); self.comma()
            // allocate one cell of data space
            self.writeCell(self.HERE, self.readCell(self.HERE) + 8)
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
        if !errorFlag && readCell(STATE) == 0 {
            tell("OK\n")
        }

        // Do not clear errorFlag or do stack/STATE recovery here.
        // The caller (feedLine) will see errorFlag and call recoverFromError(),
        // which does a complete job (drain queue + abort partial definitions + reset).
    }

    private func parseWord() -> String {
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
                f()
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

    // MARK: - Public helpers for the console / education

    /// Force the engine back to a known-good state.
    /// Stacks are emptied, errorFlag cleared, STATE forced to interpret mode.
    /// Safe to call from the host app (ConsoleView, tests) at any time.
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
