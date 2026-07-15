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

    private static let DEFAULT_MEMORY_BYTES = 1024 * 1024   // 1 MB default dictionary / heap region
    private static let MAX_MEMORY_BYTES = 64 * 1024 * 1024  // 64 MB cap for GROWMEMORYMB
    private static let HEAP_HEADER_BYTES = 8
    private let STACK_SIZE = 256         // data stack depth (cells)
    private let RSTACK_SIZE = 256        // return stack depth (cells)
    internal let FSTACK_SIZE = 16        // floating-point stack depth (IEEE 64-bit values)
    /// Fixed low-memory layout: SOURCE, STRING_BUFFER (parse scratch ring), PAD (user only), then stacks.
    private enum MemLayout {
        static let sourceBuffer = 128
        static let sourceBufferSize = 1024
        static let stringBuffer = sourceBuffer + sourceBufferSize
        static let stringBufferSize = 4096
        static let stringBufferSlotSize = 512
        static let padBuffer = stringBuffer + stringBufferSize
        static let padBufferSize = 1024
    }
    internal let SOURCE_BUFFER: Int = MemLayout.sourceBuffer  // TZForthBlock.swift
    private let SOURCE_BUFFER_SIZE = MemLayout.sourceBufferSize
    private let STRING_BUFFER: Int = MemLayout.stringBuffer
    private let STRING_BUFFER_SIZE = MemLayout.stringBufferSize
    private let STRING_BUFFER_SLOT_SIZE = MemLayout.stringBufferSlotSize
    internal let PAD_BUFFER: Int = MemLayout.padBuffer
    private let PAD_BUFFER_SIZE = MemLayout.padBufferSize
    /// Max chars for counted strings in STRING_BUFFER slots (ANS /COUNTED-STRING = 255).
    private let STRING_BUFFER_MAX_COUNTED_CHARS = 255
    private let MAX_BUILTIN_ID = 512    // primitive dispatch table size (IDs 0 ..< 512)

    private let FLAG_IMMEDIATE: UInt8 = 0x80
    internal let FLAG_HIDDEN: UInt8 = 0x40
    private let MASK_NAMELENGTH: UInt8 = 0x1F

    // MARK: - Cell model (64-bit Int on Apple Silicon)

    public typealias Cell = Int

    private let CELL_SIZE = 8

    // MARK: - Memory and state

    internal var memory: [UInt8]  // TZForthBlock.swift (PRINT-SETTINGS / SAVE-SETTINGS)

    // System variables live at the bottom of memory (classic layout)
    internal var LATEST:  Int { 0 }  // internal so TZForthTests.swift (and combined.swift for FTEST) can access for runANSValidation snapshots
    internal var DP_ADDR: Int { 8 }   // address of the DP variable (the cell holding the current dictionary pointer value); internal for test harness in TZForthTests.swift
    internal var STATE:   Int { 16 }   // internal for TZForthXChar.swift extension
    internal var BASE:   Int { 24 }   // TZForthFloat.swift
    private var SP:      Int { 32 }   // address for future "SP @" compatibility (the live pointer is in the Swift var below)
    private var RSP:     Int { 40 }
    internal var IN:       Int { 48 }   // >IN ( -- addr )  current offset in input source; internal for tests
    internal var CURRENT: Int { 64 } // compilation wordlist head-cell (GET-CURRENT / SET-CURRENT); internal for test harness snapshots

    internal let MAX_VOCABS = 8
    internal var searchOrder: [Cell] = []  // array of wl head-cell-addrs; [0] is top (first searched)

    private var stackBase: Int
    private var rstackBase: Int
    internal var fstackBase: Int         // TZForthFloat.swift

    // The actual live stack depths. Stored in Swift instance variables (not in the flat memory buffer)
    // so they cannot be corrupted by bad user writes, wild branches, or buggy control-flow code.
    // This is the key robustness fix for the recurring "SP cell trashed → constant underflows" problem.
    private var dataStackPointer: Cell = 1
    private var returnStackPointer: Cell = 1
    internal var floatingStackPointer: Cell = 1  // TZForthFloat.swift

    // Current IP for the threaded interpreter
    internal var ip: Int = 0  // TZForthFloat.swift (FLIT)
    private var commandAddress: Int = 0

    var errorFlag = false   // internal (module-visible) so host can check after named load for bookmark decisions
    /// Set when FLOAD / INCLUDE-FILE stops interpreting before EOF due to a line error.
    private var midFileLoadAborted = false
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

    /// High-water mark of HERE (DP). validateAndRepair must never rewind DP below this except via
    /// explicit FORGET/MARKER/RESET — Hayes FP suites can transiently corrupt the DP cell during
    /// deep FSTACK imbalance, and clamping to kernelHere would orphan LATEST and break `(` lookups.
    private var dictionaryHighWater: Cell = 0

    /// Logical current directory maintained for the Forth environment (used for CHDIR reports,
    /// relative FLOAD/EDIT/DIR resolution, etc.). In a sandboxed app, the underlying
    /// FileManager.currentDirectoryPath can become empty or stuck in the container after
    /// user CHDIR to paths without active security scope. We keep this logical view in sync
    /// with user CHDIR and host-authorized dirs (from dialogs/bookmarks) so that Forth
    /// sees a sensible cwd even if the process cwd is restricted.
    public var logicalCurrentDirectory: String = ""

    // Input
    internal var inputQueue: [UInt8] = []  // TZForthBlock.swift
    internal var currentSourceLen: Int = 0  // length of current SOURCE buffer (set on each feedLine / EVALUATE)

    // Output
    public var onOutput: ((String) -> Void)?
    /// Facility terminal screen refresh (80×25 buffer from PAGE / AT-XY / EMIT). Host replaces
    /// or overlays console content when this fires.
    public var onTerminalRefresh: ((String) -> Void)?
    /// True when PAGE or AT-XY has activated the facility terminal buffer.
    public var isFacilityTerminalActive: Bool { facilityTerminal.isActive }

    /// Set by the BYE word. The host app (ConsoleView) should observe this and terminate.
    public var quitRequested = false

    /// Optional callback fired when BYE is executed. Useful for the host to quit cleanly.
    public var onQuitRequested: (() -> Void)?

    /// True when a KEY primitive is blocked waiting for the next character from the host console.
    /// The ConsoleView uses this to route the next typed character to provideKey(_:) instead of
    /// normal line interpretation.
    public var waitingForKey = false

    /// True when EKEY is blocked waiting for an extended keyboard event from the host.
    public var waitingForExtendedKey = false

    /// True when MS is waiting for an asynchronous host delay (see onMsDelayRequested).
    public var waitingForMs = false

    /// True when XKEY is assembling a multi-byte UTF-8 sequence via repeated KEY reads.
    internal var waitingForXKey = false
    /// Bytes collected so far for an in-progress XKEY (UTF-8).
    internal var xkeyAssembly: [UInt8] = []
    /// Stable c-addr of ANS `XCHAR-ENCODING` answer (`"UTF-8"`).
    internal var xcharEncodingAddr: Int = 0

    /// Host schedules MS delays without blocking the UI thread. Invoked with milliseconds and a
    /// completion handler that must call resumeAfterMs() on the engine (done automatically if
    /// the closure only calls the passed completion).
    public var onMsDelayRequested: ((Int, @escaping () -> Void) -> Void)?

    /// ANS Facility K-* / EKEY>FKEY identifiers (implementation-defined; stable within TZForth).
    public enum FacilityFKey {
        public static let shiftMask = 1 << 13
        public static let ctrlMask = 1 << 14
        public static let altMask = 1 << 15
        public static let left = 1
        public static let right = 2
        public static let up = 3
        public static let down = 4
        public static let home = 5
        public static let end = 6
        public static let prior = 7
        public static let next = 8
        public static let insert = 9
        public static let delete = 10
        public static let f1 = 11
        public static let f2 = 12
        public static let f3 = 13
        public static let f4 = 14
        public static let f5 = 15
        public static let f6 = 16
        public static let f7 = 17
        public static let f8 = 18
        public static let f9 = 19
        public static let f10 = 20
        public static let f11 = 21
        public static let f12 = 22
    }

    /// EKEY character event: tag `0x01` in bits 24..25; ASCII (+ optional mods in 8..23) or
    /// full xchar code point in low 24 bits when char > $FF.
    public static func makeCharKeyEvent(_ char: Int, mods: Int = 0) -> Int {
        let cp = char & 0x1FFFFF
        if cp > 0xFF {
            return (1 << 24) | cp
        }
        return (1 << 24) | ((mods & 0xFFFF) << 8) | cp
    }

    /// EKEY function-key event for EKEY>FKEY / K-* constants.
    public static func makeFKeyEvent(_ fkeyId: Int) -> Int {
        (2 << 24) | (fkeyId & 0xFFFFFF)
    }

    /// True when the interpreter is suspended waiting for host input or an MS delay.
    public var isBlockingOnHost: Bool {
        self.waitingForKey || self.waitingForExtendedKey || self.waitingForMs
    }

    private var extendedKeyQueue: [Int] = []

    /// Set by FLOAD when invoked with no filename argument. The host UI observes this flag
    /// (typically via onOutput or post-feed checks) and presents a file dialog. After the user
    /// picks a file (or cancels), the host calls loadFile(_:) or clears the flag.
    public var fileLoadRequested = false

    /// True after a named FLOAD on the current REPL feedLine succeeds; suppresses a bare FLOAD
    /// on the same line (avoids dialog when the line is reparsed or has a stray trailing token).
    private var namedFloadOnCurrentReplLine = false

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
    /// Deprecated for named FLOAD: the FLOAD word now loads synchronously via onPerformNamedLoad
    /// (or direct loadFileContents when no host callback is set). Cleared before load runs.
    public var pendingLoadURL: URL? = nil

    /// Host performs a named FLOAD load (sandbox scope + read) synchronously before FLOAD returns.
    /// Return true when the file was loaded. On failure the engine has already raised kernelThrow.
    public var onPerformNamedLoad: ((URL) -> Bool)? = nil

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
    // and \S (stop file load, or stop remainder of a multi-line console submit).
    private var inSlashSlashComment = false
    /// `( ... )` comment spanning FLOAD/REPL lines when `)` is not on the same line as `(`.
    private var inParenComment = false
    internal var sourceLoadStop = false  // TZForthBlock.swift (legacy; block LOAD uses fileInterpretStopStack)
    /// Per active includeFileInterpret: \\S sets only the innermost entry true (nested FLOAD safe).
    internal var fileInterpretStopStack: [Bool] = []  // TZForthBlock.swift
    private var replBatchStop = false
    internal var loadNesting = 0  // TZForthBlock.swift
    /// Current 1-based source line number while includeFileInterpret is running.
    private var fileInterpretLineNumber = 0
    /// Saved outer line counters while a nested FLOAD/INCLUDED runs (blocktest must not advance test.fth's line).
    private var fileInterpretLineNumberStack: [Int] = []
    /// True when SOURCE was last filled by the REFILL word (vs the FLOAD line loop).
    private var sourceLoadedByRefill = false
    /// Byte offset in the open interpreter file where the current SOURCE line begins.
    private var currentFileLineStart: Int? = nil
    /// Pending error text for the current loaded line (reported with line number after the line ends).
    private var fileLoadPendingErrorMessage = ""
    /// Innermost source location where a load-time fault occurred (nested FLOAD/INCLUDED).
    private struct FileLoadErrorSite {
        var fileId: Int
        var line: Int
        var sourceLine: String
        var loadLabel: String
        var message: String
        var enclosingFileId: Int
        var enclosingLine: Int
        /// True when a nested FLOAD/INCLUDED could not open its target file (no inner source to cite).
        var isOpenFailure: Bool = false
    }
    private var fileLoadErrorSite: FileLoadErrorSite?
    private var fileLoadErrorReported = false
    /// Load label for the innermost active includeFileInterpret (FLOAD vs INCLUDED vs INCLUDE-FILE).
    private var currentIncludeLoadLabel = "INCLUDE-FILE"
    /// Call chain of file/line/source for each active runInterpreter inside includeFileInterpret.
    private struct FileLoadCallerFrame {
        var fileId: Int
        var line: Int
        var sourceLine: String
    }
    private var fileLoadEnclosingStack: [FileLoadCallerFrame] = []

    /// True while FLOAD / INCLUDED / INCLUDE-FILE is interpreting source (nested counts included).
    /// The console host uses this to explain why typed commands may not get OK immediately.
    public var isLoadingSource: Bool { self.isInterpretingLoadedFile() }

    /// File-load interpret active (survives resetRuntimeState during in-file THROW recovery).
    private func isInterpretingLoadedFile() -> Bool {
        self.isInsideFileLoadInterpret()
    }

    /// Broader than loadNesting alone: active during each includeFileInterpret runInterpreter pass.
    private func isInsideFileLoadInterpret() -> Bool {
        self.loadNesting > 0
            || self.interpreterInputFileId >= 2
            || !self.fileLoadEnclosingStack.isEmpty
            || self.countFloadInterpreterRefills
    }

    /// Set by \\S when the innermost loaded file should stop before EOF.
    public var sourceLoadStopRequested: Bool { self.fileInterpretStopStack.last == true }

    /// Set by \\S from the console REPL; host should skip any further lines in the current submit batch.
    public var replBatchStopRequested: Bool { replBatchStop }

    public func clearReplBatchStop() {
        self.replBatchStop = false
    }

    /// True while compiling a :NONAME definition (; leaves xt on stack).
    private var nonameCompile = false

    /// Nesting depth of nested EVALUATE (for SOURCE-ID and SAVE-INPUT tagging).
    private var evaluateNesting = 0
    /// Original c-addr/u passed to the innermost active EVALUATE (for SOURCE inside evaluate).
    private var evaluateSourceAddr: Cell = 0
    private var evaluateSourceLen: Cell = 0

    /// Identifier for the current input source (SOURCE-ID): -1 terminal, 0 evaluate, 1 file.
    internal var currentSourceId: Cell = -1  // TZForthBlock.swift

    /// Saved input states for SAVE-INPUT / RESTORE-INPUT (opaque handles on data stack).
    private struct InputSnapshot {
        var sourceId: Cell
        var inPos: Cell
        var sourceLen: Int
        var sourceBytes: [UInt8]
        var queue: [UInt8]
        var evaluateNesting: Int
        /// When saved during FLOAD/INCLUDE, byte offset in the open file at the start of SOURCE.
        var fileId: Int?
        var fileLineStart: Int?
        var fromRefill: Bool
        var blockFileId: Int?
        var blockNum: Int?
        var blockLine: Int?
    }
    private var inputSnapshots: [InputSnapshot] = []

    /// Runtime primitive for MARKER restore (pops storage addr from stack).
    private var markerRestoreID: Cell = 0

    // MARK: - File-Access (ANS optional word set 11)

    /// Implementation-defined file access methods (documented in HELP / ANS_COMPLIANCE).
    private let FAM_RDONLY: Cell = 1
    private let FAM_WRONLY: Cell = 2
    private let FAM_RDWR: Cell = 3
    private let FAM_BIN: Cell = 8
    let FILE_IO_SUCCESS: Cell = 0
    let FILE_IO_ERROR: Cell = 1

    private struct FileEntry {
        var path: String
        var fam: Cell
        var data: Data
        var position: Int = 0
        var isOpen: Bool = true
        var writeDirty: Bool = false
    }

    private var openFiles: [Int: FileEntry] = [:]
    private var nextFileId: Int = 10

    // MARK: - Block subsystem (ANS Block + TZForth .blk extensions)

    var settings: TZForthSettings = TZForthSettings.load()
    var blockPoolBase: Int = 0
    static let BLOCK_LINES_PER_BLOCK = 16
    static let BLOCK_SOURCE_ID: Cell = 1000
    static let BLOCK_FILE_ID_BASE = 100

    struct BlockFileEntry {
        var path: String
        var blockSize: Int
        var blockCount: Int
        var data: Data
        var isOpen: Bool = true
        var writeDirty: Bool = false
    }

    struct BlockBufferSlot {
        var blockNum: Int = -1
        var blockFileId: Int = -1
        var dirty: Bool = false
        var lastUsed: UInt64 = 0
    }

    var openBlockFiles: [Int: BlockFileEntry] = [:]
    var nextBlockFileId: Int = BLOCK_FILE_ID_BASE
    var blockBufferSlots: [BlockBufferSlot] = []
    var blockCacheSequence: UInt64 = 0
    var lastBlockAccessNum: Int = -1
    var lastBlockAccessFileId: Int = -1
    var lastBlockAccessSlotIndex: Int = -1

    var blockInterpretActive = false
    var blockLoadDepth = 0
    var blockInterpretFileId: Int = 0
    var blockInterpretBlockNum: Int = 0
    var blockInterpretEndBlock: Int = 0
    var blockInterpretStopBlock: Int = 0
    var blockRefillMaxBlock: Int = 0
    var blockRefillInProgress: Bool = false
    var blockInterpretLine: Int = 0
    /// Cross-block RESTORE-INPUT: resume parsing mid-line after replaying saved block prefix.
    var blockRestoreResumeTail: [UInt8] = []
    var blockRestoreResumeBlock: Int = -1
    var blockRestoreResumeLine: Int = -1

    var blkVarAddr: Cell = 0
    var blockFileVarAddr: Cell = 0
    var blockSizeVarAddr: Cell = 0
    var defaultBlockCountVarAddr: Cell = 0
    var blockBufferCountVarAddr: Cell = 0
    var scrVarAddr: Cell = 0

    /// When >= 2, the text interpreter is reading lines from this fileid (INCLUDE-FILE / INCLUDED).
    private var interpreterInputFileId: Cell = -1

    private struct InputSourceFrame {
        var sourceId: Cell
        var inPos: Cell
        var sourceLen: Int
        var sourceBytes: [UInt8]
        var queue: [UInt8]
        var evaluateNesting: Int
        var interpreterInputFileId: Cell
    }
    private var inputSourceStack: [InputSourceFrame] = []

    // Primitive dispatch table: ID -> implementation
    private var primitives: [(() -> Void)?] = []

    // ID of critical words we need during bootstrap
    internal var docolID: Cell = 0  // TZForthBlock.swift
    internal var exitID: Cell = 0   // TZForthAssembler.swift
    /// Marker at CFA of CODE definitions (thread body at cfa+8, like DOCOL for colon words).
    internal var codeEntryID: Cell = 0
    /// True while a CODE … ;CODE assembler definition is open.
    internal var assemblerCompileActive = false
    /// Header link field of the CODE definition being assembled.
    internal var codeDefinitionHeader: Cell = 0
    /// True when CODE prepended ASSEMBLER to the search order.
    internal var assemblerSearchPushed = false
    internal var litID: Cell = 0  // TZForthBlock.swift
    internal var flitID: Cell = 0  // TZForthFloat.swift
    internal var fvalueFetchID: Cell = 0  // TZForthFloat.swift (FVALUE body / TO target)
    internal var fvalueStoreID: Cell = 0  // TZForthFloat.swift (TO compile for FVALUE)
    internal var floatSetPrecision: Int = 6  // TZForthFloat.swift (SET-PRECISION / FS. / FE.)
    private var emitID: Cell = 0
    private var dotQuoteID: Cell = 0   // runtime ID for (." ) used by . " to embed compact string literals
    private var cQuoteID: Cell = 0     // runtime for (C") used by C" to embed counted string literals

    // Address of the FILE-ECHO variable's data cell (populated at bootstrap).
    private var fileEchoAddr: Cell = 0
    /// Data cell for kernel VARIABLE WARNING (F-PC style redefinition warnings when non-zero).
    private var warningAddr: Cell = 0
    /// Set when a colon definition stores 0 into >IN (!); outer offset is restored after it returns.
    private var inVarZeroedInColon = false
    /// Set when @ on >IN runs after inVarZeroedInColon (t6in); suppresses outer-line rescan on return.
    private var inVarZeroFetchAfterZero = false

    /// Address of the INCLUDED-NAMES variable's data cell (list head; 0 = empty).
    private var includedNamesVarAddr: Cell = 0
    /// User parse spec for the current named FLOAD (registered on successful load).
    private var pendingFloadSpec: String = ""
    /// Detect re-entrant REQUIRED/INCLUDED on the same spec (ANS ambiguous condition).
    private var currentlyLoadingSpec: String? = nil

    // Low-level branch primitives (captured so high-level control words can compile them)
    private var branchID: Cell = 0
    private var zeroBranchID: Cell = 0

    // CREATE / DOES> support (ANS 2012)
    internal var createRuntimeID: Cell = 0
    internal var dodoesID: Cell = 0
    private var doesPatchID: Cell = 0
    private var synonymID: Cell = 0
    private var compileCfaID: Cell = 0

    // Used by (CREATE) and (DOES) runtimes so they can locate their data/does fields
    // relative to the code cell being executed, even for top-level execution.
    private var currentCodeAddr: Cell = 0

    // True when the current primitive dispatch came from innerThread (threaded sub-call).
    // Used by (DOES) to decide whether to manually run the does code (leaf case) or just redirect ip.
    private var dispatchedFromInnerThread: Bool = false

    /// Return-stack depth at which the current innerThread (started by execute) must stop.
    /// EXIT pops a frame; when rsp <= this value, innerThread returns instead of continuing at ip.
    private var innerThreadStopRsp: Int = -1

    // Compile-time stack for DO/LOOP control (dest + sentinel + leave/?DO placeholders).
    // Using dedicated stack avoids interleaving issues with IF/ELSE/THEN/WHILE markers on data stack.
    private var loopControlStack: [Cell] = []

    // Compile-time stacks for nested WHILE/REPEAT (repeat targets + nested-condition hints).
    private var whileRepeatStack: [Cell] = []
    private var whileNestStack: [Cell] = []
    /// ANS control-flow stack during compilation (CS-PICK / CS-ROLL / IF / BEGIN / AHEAD).
    private var controlFlowStack: [Cell] = []

    /// CASE/OF/ENDOF branch placeholders (0 sentinel + forward-branch addrs); avoids data-stack pollution.
    private var caseBranchStack: [Cell] = []

    /// Saved machine state for each active CATCH (ANS 9.3.2 exception frame).
    private struct ExceptionFrame {
        var dataStackDepth: Cell
        var returnStackDepth: Cell
        var savedIp: Int
        var state: Cell
        var inputSourceStackDepth: Int
        var loadNesting: Int
        var evaluateNesting: Int
        var interpreterInputFileId: Cell
        var currentSourceId: Cell
        var currentSourceLen: Int
        var sourceBytes: [UInt8]
        var inPos: Cell
        var inputQueue: [UInt8]
        var loopControlStack: [Cell]
        var whileRepeatStack: [Cell]
        var whileNestStack: [Cell]
        var localFramesDepth: Int
    }
    private var exceptionFrames: [ExceptionFrame] = []
    /// Set by THROW while unwinding to an active CATCH; checked by innerThread / execute.
    internal var throwActive: Bool = false  // TZForthBlock.swift
    /// Text from the most recent ABORT" before THROW -2 (for unhandled -2 display).
    private var lastAbortQuoteText: String = ""
    /// Full REPL line for uncaught kernelThrow (e.g. "? Division by zero"). Cleared after display.
    private var lastKernelThrowMessage: String = ""

    /// ANS §9.3.1 standard throw codes used by kernelThrow.
    enum StdThrow {
        static let stackUnderflow: Cell = -3
        static let stackOverflow: Cell = -4
        static let returnStackUnderflow: Cell = -5
        static let returnStackOverflow: Cell = -6
        static let invalidAddress: Cell = -7
        static let divisionByZero: Cell = -9
        static let zeroLengthName: Cell = -10
        static let undefinedWord: Cell = -13
        static let compileOnly: Cell = -14
        static let uncompletedControl: Cell = -15
        static let invalidToken: Cell = -16
        static let nestingLimit: Cell = -17
        static let illegalArgument: Cell = -20
        static let closedFile: Cell = -67
        static let invalidFileId: Cell = -68
        static let fileIOError: Cell = -70
        static let fileNotFound: Cell = -74
        static let malformedXchar: Cell = -77
    }
    /// Depth of `[` … `]` compile-time interpret brackets (for SLITERAL et al.).
    private var bracketCompileDepth: Int = 0
    /// Interpret-state `[IF]` true-branch nesting (skip `[ELSE]` … `[THEN]` when > 0).
    private var interpretIfTrueDepth: Int = 0
    /// Multi-line interpret/conditional-compilation skip (`[IF]`/`[ELSE]` text scan).
    private var conditionalSkipDepth: Int = 0
    private var conditionalSkipStopAtElse: Bool = false
    /// Discard input through closing " across lines (Hayes toolstest string tail).
    private var conditionalSkipDiscardThroughQuote: Bool = false
    /// Extra source lines consumed by `(` / REFILL during the current FLOAD runInterpreter pass.
    private var floadExtraLinesConsumed: Int = 0
    private var floadLinesToSkip: Int = 0
    private var countFloadInterpreterRefills: Bool = false
    /// RESTORE-INPUT rewound file SOURCE mid-line; keep parsing through following FLOAD lines (Hayes filetest SI2).
    private var floadRestoreInputContinuation: Bool = false

    // ANS Locals word set (13): compile-time names + run-time frame stack (re-entrant).
    private static let MAX_LOCALS_PER_DEF = 32
    private var localCompileNames: [String] = []
    private var localCompileMap: [String: Int] = [:]
    private var localCompileInitCount: Int = 0
    private var localCompileInitReverse: Bool = false
    private var localFrames: [[Cell]] = []
    /// Return-stack depth when each locals frame was created (pop frame only on that word's EXIT).
    private var localFrameReturnDepth: [Int] = []
    private var localInitID: Cell = 0
    private var localFetchID: Cell = 0
    private var localStoreID: Cell = 0

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
        ("*/",      "( n1 n2 n3 -- n4 )", "multiply to double-cell, divide (quotient)"),
        ("2*",      "( x1 -- x2 )",       "shift left one bit (multiply by two)"),
        ("2/",      "( x1 -- x2 )",       "arithmetic shift right one bit (divide by two)"),
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
        ("CURRENT", "( -- addr )",        "compilation wordlist variable address (use GET-CURRENT)"),
        ("WORDLIST", "( -- wid )",         "create a new empty word list"),
        ("FORTH-WORDLIST", "( -- wid )",   "the standard FORTH word list"),
        ("GET-ORDER", "( -- wid1 ... widn n )", "copy the search order"),
        ("SET-ORDER", "( wid1 ... widn n -- )", "set the search order"),
        ("GET-CURRENT", "( -- wid )",      "fetch the compilation word list"),
        ("SET-CURRENT", "( wid -- )",      "set the compilation word list"),
        ("SEARCH-WORDLIST", "( c-addr u wid -- 0 | xt 1 | xt -1 )", "find name in one word list"),
        ("ORDER",   "( -- )",             "display search order and compilation word list"),
        ("PREVIOUS","( -- )",             "remove first word list from search order"),
        ("SOURCE",  "( -- c-addr u )",    "current input source buffer and length"),
        ("PARSE",   "( xchar -- c-addr u )", "parse text delimited by xchar in SOURCE (UTF-8; updates >IN)"),
        ("PAD",     "( -- addr )",        "transient user scratch (1024 bytes); not used by system parsers"),
        ("QUIT",    "( -- )",             "empty return stack, set interpret state, return to outer interpreter"),
        ("SP!",     "( n -- )",           "set data stack pointer (updates both cell and internal)"),
        ("RSP!",    "( n -- )",           "set return stack pointer (updates both cell and internal)"),
        ("POSTPONE","( -- ) name",        "append compilation semantics of next word (immediate)"),
        ("[COMPILE]","( -- ) name",       "force compile of next word even if immediate (immediate)"),
        ("VOCABULARY","( -- ) name",      "ANS compatibility: named word list (thin layer over WORDLIST)"),
        ("FORTH",   "( -- )",             "replace first search-order entry with FORTH-WORDLIST"),
        ("ALSO",    "( -- )",             "duplicate first entry in search order"),
        ("ONLY",    "( -- )",             "set search order to FORTH-WORDLIST only"),
        ("DEFINITIONS","( -- )",          "set compilation word list to first in search order"),
        (">NUMBER", "( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )", "convert string digits to number accumulating in ud"),
        ("ALLOT",   "( n -- )",           "allocate n bytes in dictionary"),
        (",",       "( n -- )",           "compile a cell"),
        ("FILL",    "( addr u b -- )",    "fill u bytes at addr with b"),
        ("MOVE",    "( addr1 addr2 u -- )", "copy u bytes"),
        ("BLANK",   "( c-addr u -- )",    "fill u bytes with blanks (BL)"),
        ("CMOVE",   "( c-addr1 c-addr2 u -- )", "copy u characters c-addr2 -> c-addr1"),
        ("CMOVE>",  "( c-addr1 c-addr2 u -- )", "copy u characters high-to-low"),
        ("COMPARE", "( c-addr1 u1 c-addr2 u2 -- n )", "compare strings (-1/0/1)"),
        ("/STRING", "( c-addr u n -- c-addr' u' )", "adjust string by n characters"),
        ("-TRAILING","( c-addr u -- c-addr' u' )", "remove trailing spaces"),
        ("REPLACES", "( c-addr1 u1 c-addr2 u2 -- )", "define text substitution for %name%"),
        ("SUBSTITUTE","( c-addr1 u1 c-addr2 u2 -- c-addr2 u3 n )", "apply %name% substitutions"),
        ("UNESCAPE", "( c-addr1 u1 c-addr2 -- c-addr2 u2 )", "double each % in string"),
        ("SEARCH",  "( c-addr1 u1 c-addr2 u2 -- c-addr3 u3 flag )", "search for substring"),
        ("SLITERAL","( c-addr u -- )",    "compile string literal (immediate; run-time c-addr u)"),
        ("ALLOCATE","( u -- a-addr ior )","allocate u bytes from heap (ior 0 = success)"),
        ("FREE",    "( a-addr -- ior )",  "free heap block at a-addr"),
        ("RESIZE",  "( a-addr u -- a-addr ior )", "resize heap block to u bytes"),
        ("GROWMEMORYMB","( n -- )",       "grow linear memory to n MB (once per session; no shrink; before ALLOCATE)"),
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
        ("BEGIN-STRUCTURE","( \"name\" -- )", "start structure layout (immediate)"),
        ("END-STRUCTURE","( -- )",          "end structure; create size constant (immediate)"),
        ("+FIELD",  "( u \"name\" -- )",   "add u-byte field at current offset (immediate)"),
        ("FIELD:",  "( \"name\" -- )",     "add cell-aligned field (immediate)"),
        ("CFIELD:", "( \"name\" -- )",     "add 1-char field (immediate)"),
        ("PAGE",    "( -- )",              "clear facility terminal and home cursor"),
        ("AT-XY",   "( u1 u2 -- )",        "facility terminal cursor to column u1 row u2"),
        ("MS",      "( u -- )",            "wait at least u milliseconds"),
        ("TIME&DATE","( -- sec min hr day mon yr )", "local wall-clock components"),
        ("EKEY",    "( -- x )",            "blocking extended keyboard event"),
        ("EKEY?",   "( -- flag )",         "true if extended key event available"),
        ("EKEY>CHAR","( x -- x 0 | char -1 )", "decode event to character"),
        ("EKEY>FKEY","( x -- x 0 | u -1 )", "decode event to K-* function key id"),
        ("EMIT?",   "( -- flag )",         "true when output device can accept a character"),
        ("TYPE",    "( addr len -- )",    "print len characters from addr"),
        ("U.",      "( u -- )",           "print unsigned number"),
        ("H.",      "( u -- )",           "print unsigned as uppercase hex (ignores BASE)"),
        ("ABORT",   "( -- )",             "THROW -1 (catchable; prints Aborted! if uncaught)"),
        ("ABORT\"", "( flag \"text\" -- )", "if flag, type message and THROW -2 (immediate)"),
        ("CATCH",   "( xt -- n )",        "execute xt; push 0 or throw code"),
        ("CATCH-EVALUATE","( c-addr u -- n )", "EVALUATE string; push 0 or throw code (TZForth)"),
        (".ERROR",  "( n -- )",           "type spaced standard message for CATCH/THROW code n (0 = silent)"),
        ("THROW",   "( n -- )",           "raise exception n (0 is no-op)"),
        ("ACCEPT",  "( c-addr +n1 -- +n2 )", "read up to n1 chars from input into buffer"),
        ("<#",      "( -- )",             "begin pictured numeric output"),
        ("#",       "( ud -- ud )",       "add one digit to pictured output"),
        ("#S",      "( ud -- ud )",       "add all remaining digits to pictured"),
        ("#>",      "( ud -- c-addr u )", "end pictured numeric, return string"),
        ("HOLD",    "( char -- )",        "insert char into pictured output"),
        ("SIGN",    "( n -- )",           "insert minus sign if n<0 into pictured"),
        ("S\"",     "( -- c-addr u )",    "compile/interpret \"-delimited string (leaves addr u)"),
        ("C\"",     "( -- c-addr )",      "compile \"-delimited counted string (run-time: addr of length byte)"),
        
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
        ("LOCATE",  "( -- name )",        "alias of SEE — decompile word definition"),
        ("HELP",    "( -- ) name",        "show help for a word"),
        ("' ",      "( -- xt ) name",     "tick: get execution token of name"),
        ("EXECUTE", "( xt -- )",          "execute the word with the given xt"),
        ("EVALUATE","( i*x c-addr u -- j*x )", "interpret the string as Forth source"),
        ("ENVIRONMENT?","( c-addr u -- false | i*x true )", "query environment string"),
        (".ENVIRONMENT","( -- )",           "display all supported ENVIRONMENT? query strings and values"),
        (">NUMBER", "( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )", "convert string digits to number accumulating in ud"),
        ("FIND",    "( c-addr -- c-addr 0 | xt 1 | xt -1 )", "find word from counted string (from WORD)"),
        ("FORGET",  "( -- ) name",        "forget name and all words defined after it"),
        ("FORGET-WORD", "( xt -- )",      "forget using xt ( ' NAME FORGET-WORD )"),
        (">HEADER", "( cfa -- header )",  "find header for word with this code-field address"),
        (">LFA",    "( cfa -- lfa )",     "convert cfa to link field (alias for >HEADER)"),
        (">NFA",    "( cfa -- nfa )",     "convert cfa to name field (flags+len byte at header+8)"),
        (">XID",    "( cfa -- xid | 0 )", "kernel primitive dispatch ID from cfa, or 0 if not a primitive"),
        ("ID.",     "( cfa -- )",         "print the name of the word given its cfa (robust, masks flags from count)"),
        ("VARIABLE","( -- ) name",        "create a variable"),
        ("CONSTANT","( n -- ) name",      "create a constant"),
        ("CREATE",  "( -- ) name",        "create a word that pushes its data field address (for use with DOES>)"),
        ("DOES>",   "( -- )",             "modify last CREATE'd word to execute the following code with data addr on stack (immediate)"),
        ("IMMEDIATE","( -- )",            "mark latest word as immediate"),
        ("TRUE",    "( -- -1 )",          "true flag"),
        ("FALSE",   "( -- 0 )",           "false flag"),
        ("BL",      "( -- 32 )",          "blank character (space)"),
        ("DUMP",    "( addr u -- )",      "hex dump u bytes from addr (16 per line, ASCII gutter)"),
        ("?",       "( addr -- )",        "display the value stored at addr"),
        ("NAME>STRING", "( nt -- c-addr u )", "copy name token name to buffer (valid until next NAME>STRING)"),
        ("NAME>INTERPRET", "( nt -- xt )", "execution token for name token nt (header address)"),
        ("NAME>COMPILE", "( nt -- xt )",   "compilation token for name token nt"),
        ("TRAVERSE-WORDLIST", "( xt wid -- )", "execute xt for each name token in wordlist wid"),
        ("SYNONYM", "( \"new\" \"old\" -- )", "create newname as synonym of oldname"),
        ("[DEFINED]", "( \"name\" -- )",   "compile TRUE if name exists (immediate)"),
        ("[UNDEFINED]", "( \"name\" -- )", "compile TRUE if name does not exist (immediate)"),
        ("N>R",     "( n -- )",           "move n items from data stack to return stack"),
        ("NR>",     "( -- )",             "restore items moved by N>R"),
        ("CS-PICK", "( u -- )",           "pick uth control-flow-stack item during compilation (immediate)"),
        ("CS-ROLL", "( u -- )",           "roll uth control-flow-stack item during compilation (immediate)"),
        ("AHEAD",   "( -- )",             "unresolved forward branch (immediate; use with THEN)"),
        ("CODE",    "( -- ) name",        "start assembler definition (TZForth threaded CODE)"),
        (";CODE",   "( -- )",             "end assembler definition"),
        ("RET",     "( -- )",             "assembler: compile EXIT into CODE body (ASSEMBLER vocab)"),
        ("[IF]",    "( flag -- )",        "conditional compilation (immediate; Core Ext)"),
        ("[ELSE]",  "( -- )",             "else branch for [IF] (immediate)"),
        ("[THEN]",  "( -- )",             "end [IF] (immediate)"),
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
        ("D+",      "( d1 d2 -- d3 )",    "add double-cell numbers"),
        ("D-",      "( d1 d2 -- d3 )",    "subtract double-cell numbers"),
        ("D.",      "( d -- )",           "print signed double in current BASE"),
        ("D.R",     "( d n -- )",         "print signed double right-aligned in width n"),
        ("D<",      "( d1 d2 -- flag )",  "true if d1 < d2 (signed)"),
        ("D=",      "( d1 d2 -- flag )",  "true if d1 = d2"),
        ("D0<",     "( d -- flag )",      "true if d is negative"),
        ("D0=",     "( d -- flag )",      "true if d is zero"),
        ("DU<",     "( ud1 ud2 -- flag )","true if ud1 < ud2 (unsigned)"),
        ("D>S",     "( d -- n )",         "drop high cell of double"),
        ("DABS",    "( d -- d )",         "absolute value of double"),
        ("DNEGATE", "( d -- d )",         "negate double"),
        ("D2*",     "( d -- d )",         "double arithmetic left shift"),
        ("D2/",     "( d -- d )",         "double arithmetic right shift"),
        ("DMIN",    "( d1 d2 -- d )",     "signed double minimum"),
        ("DMAX",    "( d1 d2 -- d )",     "signed double maximum"),
        ("M+",      "( d n -- d )",       "add single n to double d"),
        ("M*/",     "( u1 u2 u3 -- ud )", "u1*u2/u3 as unsigned double"),
        ("2CONSTANT","( d -- ) name",     "create double constant"),
        ("2VARIABLE","( -- ) name",        "create 2-cell variable"),
        ("2LITERAL","( d -- )",           "compile double literal (immediate)"),
        ("2VALUE",  "( d -- ) name",      "create modifiable double value (TO)"),
        ("2ROT",    "( d1 d2 d3 -- d2 d3 d1 )", "rotate third double pair to top"),
        ("(LOCAL)", "( c-addr u -- )",    "declare one local or end sequence (compile-only)"),
        ("LOCALS|", "( -- ) names |",     "declare locals from stack args at run-time (immediate)"),
        ("{:",      "( -- ) {: names | :}", "declare locals with {: args | vals -- outs :} syntax"),
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
        ("CHAR",    "( \"<spaces>name\" -- xchar )", "parse BL-delimited name, return first xchar (UTF-8)"),
        ("WORD",    "( char -- addr )",   "parse input up to delimiter char, return addr of counted string (trailing NUL)"),
        ("COUNT",   "( c-addr -- addr u )", "from counted string addr return char-addr and length"),

        // Core Extensions (6.2)
        (".R",      "( n width -- )",     "print signed number right-justified in width field"),
        ("TO",      "( n -- ) name",      "store n into a VALUE (parsing)"),
        ("PARSE-NAME","( -- c-addr u )",  "parse name from input (skip leading blanks, BL-delimited)"),
        ("HOLDS",   "( c-addr u -- )",    "add string to pictured numeric output (prepend via HOLD)"),
        ("BUFFER:", "( u -- ) name",      "create an aligned buffer of u bytes"),
        ("UNUSED",  "( -- u )",           "bytes remaining in dictionary (HERE to dictionary limit)"),
        (".FREE",   "( -- )",             "print free dictionary bytes remaining (unsigned, like UNUSED U.)"),
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
        (":NONAME", "( C: -- colon-sys ) ( -- xt )", "start anonymous colon definition; ; leaves xt"),
        ("ACTION-OF","( xt1 -- xt2 )",    "current execution token of a deferred word (like DEFER@)"),
        ("MARKER",  "( -- ) name",        "create a restore point for dictionary and search order"),
        ("SAVE-INPUT","( -- x1 ... xn n )","save current input source state for RESTORE-INPUT"),
        ("RESTORE-INPUT","( x1 ... xn n -- flag )","restore input source; flag true if failed"),
        ("SOURCE-ID","( -- id )",         "input source id (-1 terminal, 0 evaluate, 1 file)"),
        ("S\\\"",   "( -- )",             "compile escaped \"-delimited string (leaves c-addr u at run-time)"),
        ("REFILL",  "( -- flag )",        "attempt to refill the input buffer; flag true if successful"),

        // File-Access (ANS word set 11)
        ("R/O",     "( -- fam )",         "read-only file access method"),
        ("W/O",     "( -- fam )",         "write-only file access method"),
        ("R/W",     "( -- fam )",         "read/write file access method"),
        ("BIN",     "( fam -- fam )",     "add binary (non line-oriented) access to fam"),
        ("OPEN-FILE","( c-addr u fam -- fileid ior )", "open a file"),
        ("CLOSE-FILE","( fileid -- ior )", "close a file"),
        ("CREATE-FILE","( c-addr u fam -- fileid ior )", "create/truncate a file"),
        ("DELETE-FILE","( c-addr u -- ior )", "delete a file"),
        ("READ-FILE", "( c-addr u fileid -- u2 ior )", "read u bytes from file"),
        ("WRITE-FILE","( c-addr u fileid -- ior )", "write u bytes to file"),
        ("READ-LINE", "( c-addr u fileid -- u2 flag ior )", "read a line from file"),
        ("WRITE-LINE","( c-addr u fileid -- ior )", "write a line to file (adds newline)"),
        ("FILE-POSITION","( fileid -- ud ior )", "current file position as unsigned double"),
        ("FILE-SIZE", "( fileid -- ud ior )", "file size as unsigned double"),
        ("REPOSITION-FILE","( ud fileid -- ior )", "set file position"),
        ("RESIZE-FILE","( ud fileid -- ior )", "set file size"),
        ("INCLUDE-FILE","( fileid -- )",   "interpret contents of open text file, then close it"),
        ("INCLUDED", "( c-addr u -- )",    "open and interpret named file, then close it"),
        ("INCLUDE", "( -- ) name",         "parse name and INCLUDED (immediate)"),
        ("REQUIRED", "( c-addr u -- )",   "INCLUDED if file spec not yet in INCLUDED-NAMES list"),
        ("REQUIRE", "( -- name )",        "PARSE-NAME REQUIRED (load once per spec string)"),
        ("INCLUDED-NAMES", "( -- addr )", "variable: head of load-once name list (ANS REQUIRED registry)"),
        (".INCLUDED", "( -- )",            "list file specs registered in INCLUDED-NAMES"),
        ("FILE-STATUS","( c-addr u -- x ior )", "file existence status by path spec"),
        ("FLUSH-FILE","( fileid -- ior )",  "flush buffered file data to disk"),
        ("RENAME-FILE","( c-addr1 u1 c-addr2 u2 -- ior )", "rename file"),

        // Block (ANS 10.6.1 + TZForth .blk file extensions)
        ("BLOCK",   "( u -- a-addr )",    "copy block u from current volume to a buffer; return buffer address"),
        ("BUFFER",  "( u -- a-addr )",    "same as BLOCK (buffer for block u of current volume)"),
        ("UPDATE",  "( -- )",             "mark last-accessed block buffer dirty (written on FLUSH)"),
        ("FLUSH",   "( -- )",             "merge dirty buffers and write current volume to disk"),
        ("EMPTY-BUFFERS","( -- )",        "discard buffer cache (dirty slots merged to volume first)"),
        ("SAVE-BUFFERS","( -- )",          "merge dirty buffers of current volume into in-memory copy"),
        ("BLK",     "( -- addr )",        "variable: last block number during BLOCK/LOAD (addr of cell)"),
        ("SCR",     "( -- addr )",        "variable: last block listed by LIST (addr of cell)"),
        ("LOAD",    "( u -- )",           "interpret 16 lines of block u from current volume"),
        ("LIST",    "( u -- )",           "type block u; set SCR"),
        ("THRU",    "( u1 u2 -- )",       "LOAD blocks u1 through u2 inclusive"),
        ("BLOCK-FILE","( -- addr )",      "variable: current volume id (0=none; auto-opens default .blk on first use)"),
        ("CREATE-BLOCK-FILE","( c-addr u n -- bid ior )", "create new .blk with n blocks; does not select—USE-BLOCK-FILE after"),
        ("OPEN-BLOCK-FILE","( c-addr u -- bid ior )", "open existing .blk (cwd-relative, .blk appended); does not select volume"),
        ("USE-BLOCK-FILE","( bid -- )",   "select open volume as current; flush previous; set BLOCK-FILE @"),
        ("CLOSE-BLOCK-FILE","( bid -- ior )", "flush, close volume bid; clear BLOCK-FILE @ if it was current"),
        ("GROW-BLOCK-FILE","( bid n -- ior )", "append n zero-filled blocks to open volume"),
        (".BLOCK-FILES","( -- )",         "list open block volumes (id path block-count open|closed)"),
        ("BLOCK-SIZE","( -- addr )",      "variable: bytes per block (default 1024; SAVE-SETTINGS + restart for pool)"),
        ("DEFAULT-BLOCK-COUNT","( -- addr )", "variable: blocks in a newly auto-created default .blk file"),
        ("BLOCK-BUFFER-COUNT","( -- addr )", "variable: LRU buffer slots (default 4; SAVE-SETTINGS + restart)"),
        (".SETTINGS","( -- )",            "display block/memory settings and how to change them"),
        ("SAVE-SETTINGS","( -- )",         "persist BLOCK-SIZE, buffer count, default block count, memory MB"),

        // Extended-Character (ANS 18.6.1 — UTF-8)
        ("XC-SIZE", "( xchar -- u )",       "bytes to encode xchar in memory"),
        ("X-SIZE",  "( xc-addr u -- u )",   "encoded size of first xchar from leading byte"),
        ("XC@+",    "( xc-addr -- xc-addr' xchar )", "fetch xchar; advance addr past encoding"),
        ("XC!+",    "( xchar xc-addr -- xc-addr' )", "store xchar encoding; return addr after"),
        ("XC!+?",   "( xchar xc-addr u -- xc-addr' u' flag )", "store if buffer has room (-1/0 flag)"),
        ("XC,",     "( xchar -- )",         "append xchar encoding at HERE"),
        ("XCHAR+",  "( xc-addr -- xc-addr' )", "advance addr past one encoded xchar"),
        ("XCHAR-",  "( xc-addr -- xc-addr' )", "retreat to start of previous encoded xchar"),
        ("+X/STRING", "( xc-addr u -- xc-addr' u' )", "skip first xchar in buffer; return remainder"),
        ("X\\STRING-", "( xc-addr u -- xc-addr u' )", "string with all xchars except the last"),
        ("-TRAILING-GARBAGE", "( xc-addr u -- xc-addr u' )", "drop incomplete final xchar from tail"),
        ("[CHAR]",  "( \"<spaces>name\" -- )", "compile first xchar of name as literal (immediate)"),
        ("XEMIT",   "( xchar -- )",         "emit UTF-8 encoding of xchar on terminal"),
        ("XKEY",    "( -- xchar )",        "read one xchar from terminal (blocking UTF-8)"),
        ("XKEY?",   "( -- flag )",         "true when XKEY can complete without blocking"),
        ("EKEY>XCHAR", "( x -- xchar true | x false )", "decode EKEY char event to xchar"),
        ("XHOLD",   "( xchar -- )",         "prepend UTF-8 xchar into pictured numeric output"),
        ("XC-WIDTH", "( xchar -- n )",      "display columns for xchar (monospace em units)"),
        ("X-WIDTH", "( xc-addr u -- n )",  "display columns for bounded UTF-8 xchar string"),

        // New for FLOAD / EDIT / file helpers (cwd + dialog driven by host for sandbox friendliness)
        ("\\",      "( -- )",             "comment to end of line (immediate)"),
        ("\\\\",    "( -- )",             "block comment to next '{' (spans lines; use \\ not single \\ for single-line comments) (immediate)"),
        ("\\S",     "( -- )",             "stop FLOAD/INCLUDE file or remainder of multi-line console paste (immediate)"),
        ("FLOAD",   "( -- ) name|dialog", "load .fth file (auto .fth if no ext in name; relative to cwd or abs/~; named uses host for sandbox scope+chdir; bare opens dialog)"),
        ("EDIT",    "( -- ) name|dialog", "open in system text editor (nav dialog or name; auto .fth fallback for bare names like FLOAD; updates cwd to file's folder; no load/interpret)"),
        ("FILE-ECHO","( -- addr )",       "variable controlling loaded-source echo (FLOAD, INCLUDE, …; use with ON/OFF)"),
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

    // ANS Memory-Allocation heap (grows downward from PNO buffer) + GROWMEMORYMB state
    private var heapBump: Int = 0
    private var usedHeapBlocks: [Int: Int] = [:]
    private var freeHeapBlocks: [(addr: Int, size: Int)] = []
    private var allocateEverUsed: Bool = false
    private var growMemoryAttempted: Bool = false

    /// Facility BEGIN-STRUCTURE / +FIELD compile-time offset accumulator (ANS 10.6.2).
    private var structureOffset: Cell = 0
    private var structureActive: Bool = false
    /// Name parsed by BEGIN-STRUCTURE; consumed by END-STRUCTURE (Hayes facilitytest layout).
    private var structurePendingName: String = ""
    /// ANS Facility terminal buffer (PAGE / AT-XY / cursor EMIT).
    private var facilityTerminal = FacilityTerminal()
    private var terminalRefreshPending = false

    private var executeID: Cell = 0  // captured ID for EXECUTE so POSTPONE can emit LIT xt EXECUTE for immediates
    private var postponeImmID: Cell = 0  // (postpone-imm): compile or execute postponed immediate at run time
    private var postponeCompID: Cell = 0 // (postpone-comp): compile or execute postponed non-immediate at run time
    private var deferredCsPickID: Cell = 0 // deferred CS-PICK for immediate-colon meta definitions
    private var deferredCsRollID: Cell = 0 // deferred CS-ROLL for immediate-colon meta definitions
    private var fetchID: Cell = 0    // ID for @
    private var plusID: Cell = 0     // ID for + (structure field DOES> @ +)
    private var storeID: Cell = 0    // ID for !
    private var twoFetchID: Cell = 0 // ID for 2@ (2VALUE / TO detection)
    private var twoStoreID: Cell = 0 // ID for 2!
    private var sQuoteID: Cell = 0   // runtime for (S") used by S" to embed compact string literals that leave c-addr u
    private var abortQuoteID: Cell = 0  // runtime for (ABORT")
    /// Next offset within STRING_BUFFER for ring allocation (512-byte slots, wraps at 4 KB).
    private var stringBufferAllocOffset: Int = 0
    /// REPLACES / SUBSTITUTE substitution table (name → replacement bytes).
    private var textSubstitutions: [String: [UInt8]] = [:]
    private static let maxSubstitutionTextLen = 255

    // MARK: - Init

    public convenience init() {
        self.init(settings: TZForthSettings.load())
    }

    public init(settings: TZForthSettings) {
        self.settings = settings.sanitizedForBoot()
        let memBytes = max(Self.DEFAULT_MEMORY_BYTES, self.settings.defaultMemoryMB * 1024 * 1024)
        memory = Array(repeating: 0, count: memBytes)

        // Layout fixed buffers (SOURCE, STRING_BUFFER, PAD) then data/return/float stacks above PAD.
        stackBase = (PAD_BUFFER + PAD_BUFFER_SIZE + 7) & ~7
        rstackBase = stackBase + STACK_SIZE * CELL_SIZE
        fstackBase = rstackBase + RSTACK_SIZE * CELL_SIZE

        // Initialize system variables
        writeCell(LATEST, 0)
        writeCell(DP_ADDR, fstackBase + FSTACK_SIZE * CELL_SIZE)   // initial value of the dictionary pointer (stored at DP_ADDR)
        writeCell(STATE, 0)
        writeCell(BASE, 10)
        writeCell(IN, 0)
        searchOrder = [LATEST]
        writeCell(CURRENT, LATEST)

        // Live stack depths live in Swift vars (corruption-proof).
        // We still write the old fixed locations for any future raw memory inspection or "SP @" compatibility.
        dataStackPointer = 1
        returnStackPointer = 1
        floatingStackPointer = 1
        writeCell(SP, 1)
        writeCell(RSP, 1)

        primitives = []
        primitives.reserveCapacity(MAX_BUILTIN_ID)

        registerCorePrimitives()

        // Bootstrap a tiny set of immediate and defining words by hand
        bootstrapMinimalDictionary()

        // Seed the interpreter IP at the QUIT code we just created
        ip = quitCodeAddress

        // Initial logical cwd (host may override via setup or after scoped chdirs)
        logicalCurrentDirectory = FileManager.default.currentDirectoryPath

        self.repositionPnoAndHeap()
        self.captureBlockVariableAddrs()
        self.syncBlockVariablesFromSettings()
        self.registerBlockWords()
        self.registerXCharWords()
        self.registerAssemblerWords()
        self.registerFloatWords()

        // Record kernel boundary after bootstrap + block/xchar/assembler/float subsystems so RESET / resetToSafeState
        // retain ANS Block and TZForth .blk extension words (CREATE/OPEN/USE-BLOCK-FILE, etc.).
        kernelLatest = readCell(LATEST)
        kernelHere = readCell(DP_ADDR)
        dictionaryHighWater = kernelHere

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
            throwInvalidAddress("? Memory read out of range (addr=\(addr))")
            return 0
        }
        // Byte-wise load: Forth heap/allot may leave addresses not 8-byte aligned.
        var value: Cell = 0
        withUnsafeMutableBytes(of: &value) { dest in
            for i in 0..<8 { dest[i] = memory[addr + i] }
        }
        return value
    }

    internal func writeCell(_ addr: Int, _ value: Cell) {  // internal to allow access from TZForthTests.swift extension for ANS validation restore
        if addr < 0 || addr + 8 > memory.count {
            throwInvalidAddress("? Memory write out of range (addr=\(addr))")
            return
        }
        withUnsafeBytes(of: value) { raw in
            let src = raw.bindMemory(to: UInt8.self)
            for i in 0..<8 { memory[addr + i] = src[i] }
        }
    }

    func readByte(_ addr: Int) -> UInt8 {
        if addr < 0 || addr >= memory.count {
            self.throwInvalidAddress("? Memory read out of range (addr=\(addr))")
            return 0
        }
        return memory[addr]
    }

    func writeByte(_ addr: Int, _ value: UInt8) {
        if addr < 0 || addr >= memory.count {
            self.throwInvalidAddress("? Memory write out of range (addr=\(addr))")
            return
        }
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

    internal func pop() -> Cell {  // TZForthBlock.swift
        var s = spGet()
        if s < 1 || s > Cell(STACK_SIZE) {
            tell("? Corrupted data stack pointer (SP=\(s)), auto-recovering\n")
            s = 1
            spSet(1)
        }
        if s <= 1 {
            spSet(1)
            let msg = readCell(STATE) != 0 ? "? Stack underflow while compiling" : "? Stack underflow"
            kernelThrow(StdThrow.stackUnderflow, message: msg)
            return 0
        }
        spSet(s - 1)
        return readCell(stackBase + (s - 2) * 8)
    }

    internal func push(_ v: Cell) {  // TZForthBlock.swift
        var s = spGet()
        if s < 1 || s > Cell(STACK_SIZE) {
            tell("? Corrupted data stack pointer (SP=\(s)), auto-recovering\n")
            s = 1
            spSet(1)
        }
        if s >= Cell(STACK_SIZE) {
            kernelThrow(StdThrow.stackOverflow, message: "? Stack overflow")
            return
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
            rspSet(1)
            let msg = readCell(STATE) != 0 ? "? Return stack underflow while compiling" : "? Return stack underflow"
            kernelThrow(StdThrow.returnStackUnderflow, message: msg)
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
            kernelThrow(StdThrow.returnStackOverflow, message: "? Return stack overflow")
            return
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

    /// ANS unsigned single-cell value (full cell width; 64-bit on this engine).
    private func unsignedCell(_ n: Cell) -> UInt64 {
        UInt64(bitPattern: Int64(n))
    }

    /// ANS single-cell arithmetic wraps at cell width (modulo 2^N); Swift Int traps without &+/&-/ &*.
    private func cellAdd(_ a: Cell, _ b: Cell) -> Cell { a &+ b }
    private func cellSub(_ a: Cell, _ b: Cell) -> Cell { a &- b }

    private func unsignedLess(_ a: Cell, _ b: Cell) -> Bool {
        self.unsignedCell(a) < self.unsignedCell(b)
    }

    private func unsignedGreaterOrEqual(_ a: Cell, _ b: Cell) -> Bool {
        self.unsignedCell(a) >= self.unsignedCell(b)
    }

    /// ANS DO/+LOOP circular arithmetic (gforth `(+loop)` / Forth-2012 rationale A.6.1.0140).
    /// Continue when index+delta has not crossed the boundary between limit-1 and limit.
    private func loopShouldContinue(index: Cell, limit: Cell, delta: Cell) -> Bool {
        if delta == 0 {
            return true
        }
        let oldDiff = index &- limit
        let newDiff = oldDiff &+ delta
        return ((oldDiff ^ newDiff) & (oldDiff ^ delta)) >= 0
    }
    private func cellMul(_ a: Cell, _ b: Cell) -> Cell { a &* b }
    private func cellNegate(_ a: Cell) -> Cell { 0 &- a }

    /// Low cell bits of a signed double-wide value (never traps on overflow).
    private func cellFromInt128(_ v: Int128) -> Cell {
        Cell(Int(Int64(bitPattern: UInt64(truncatingIfNeeded: v))))
    }

    /// Low cell bits of an unsigned double-wide value (never traps on overflow).
    private func cellFromUInt128(_ v: UInt128) -> Cell {
        Cell(Int(Int64(bitPattern: UInt64(truncatingIfNeeded: v))))
    }

    /// Pop the two cells of a double (hi on top, lo below — matches S>D / M* push order in this engine).
    private func popDoubleStack() -> (lo: Cell, hi: Cell) {
        let hi = self.pop()
        let lo = self.pop()
        return (lo, hi)
    }

    private func pushDoubleStack(lo: Cell, hi: Cell) {
        self.push(lo)
        self.push(hi)
    }

    internal func assembleSignedDouble(lo: Cell, hi: Cell) -> Int128 {  // TZForthFloat.swift (D>F)
        let bits = UInt128(self.unsignedCell(lo)) | (UInt128(self.unsignedCell(hi)) << 64)
        return Int128(bitPattern: bits)
    }

    private func assembleUnsignedDouble(lo: Cell, hi: Cell) -> UInt128 {
        (UInt128(self.unsignedCell(hi)) << 64) | UInt128(self.unsignedCell(lo))
    }

    internal func disassembleSignedDouble(_ d: Int128) -> (lo: Cell, hi: Cell) {  // TZForthFloat.swift (F>D)
        let bits = UInt128(bitPattern: d)
        let lo = UInt64(truncatingIfNeeded: bits)
        let hi = UInt64(truncatingIfNeeded: bits >> 64)
        return (Cell(Int64(bitPattern: lo)), Cell(Int64(bitPattern: hi)))
    }

    private func disassembleUnsignedDouble(_ d: UInt128) -> (lo: Cell, hi: Cell) {
        let lo = UInt64(truncatingIfNeeded: d)
        let hi = UInt64(truncatingIfNeeded: d >> 64)
        return (Cell(Int64(bitPattern: lo)), Cell(Int64(bitPattern: hi)))
    }

    /// ANS M*/ ( d u2 u3 -- d ): (d * u2) / u3 with truncating division.
    /// Never forms d * u2 directly — Int128.max * 8 traps in Swift. Uses
    /// (d/u3)*u2 + (d%u3)*u2/u3 with an overflow guard on the quotient term.
    private func mStarDivide(dLo: Cell, dHi: Cell, u2c: Cell, u3c: Cell) -> Int128 {
        let d = self.assembleSignedDouble(lo: dLo, hi: dHi)
        let u2 = Int128(u2c)
        let u3 = Int128(self.unsignedCell(u3c))
        let rem = d % u3
        let tail = (rem * u2) / u3
        let quot = d / u3
        if quot == 0 { return tail }
        let absQ = quot < 0 ? -quot : quot
        let absU2 = u2 < 0 ? -u2 : u2
        if absU2 == 0 { return tail }
        if absQ <= Int128.max / absU2 {
            return quot * u2 + tail
        }
        // Rare: |quot|*|u2| exceeds Int128 — use unsigned magnitudes (Hayes large M*/ cases).
        let neg = (quot < 0) != (u2 < 0)
        let mag = UInt128(bitPattern: absQ) * UInt128(bitPattern: absU2)
            + UInt128(bitPattern: (rem < 0 ? -rem : rem) * absU2 / u3)
        return neg ? -Int128(bitPattern: mag) : Int128(bitPattern: mag)
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

    /// Prepend a byte sequence into pictured numeric output (ANS HOLDS / XHOLD).
    internal func picturedHoldsBytes(_ bytes: [UInt8]) {
        for b in bytes.reversed() {
            if self.pnoPtr > self.pnoBufferAddr {
                self.pnoPtr -= 1
                self.writeByte(self.pnoPtr, b)
            }
        }
    }

    // MARK: - Output

    internal func putkey(_ c: UInt8) {  // TZForthFloat.swift (.FS)
        if self.facilityTerminal.isActive {
            if c == 10 {
                self.facilityTerminal.newline()
            } else {
                self.facilityTerminal.emit(c)
            }
            self.terminalRefreshPending = true
        } else {
            self.onOutput?(String(UnicodeScalar(c)))
        }
    }

    /// Emit a UTF-8 byte sequence to the terminal or `onOutput` (Extended-Character XEMIT).
    internal func emitUtf8Bytes(_ bytes: [UInt8]) {
        if bytes.isEmpty { return }
        if self.facilityTerminal.isActive {
            for b in bytes {
                if b == 10 { self.facilityTerminal.newline() }
                else { self.facilityTerminal.emit(b) }
            }
            self.terminalRefreshPending = true
        } else {
            self.tell(String(bytes: bytes, encoding: .utf8) ?? "")
        }
    }

    private func flushTerminalRefreshIfNeeded() {
        guard self.terminalRefreshPending, self.facilityTerminal.isActive else { return }
        self.terminalRefreshPending = false
        self.onTerminalRefresh?(self.facilityTerminal.render())
    }

    func tell(_ s: String) {
        guard !s.isEmpty else { return }
        onOutput?(s)
    }

    private func fileDisplayName(forFileId fileId: Int) -> String {
        if let path = self.openFiles[fileId]?.path {
            return (path as NSString).lastPathComponent
        }
        return "file \(fileId)"
    }

    private func clearFileLoadErrorTracking() {
        self.fileLoadPendingErrorMessage = ""
        self.fileLoadErrorSite = nil
        self.fileLoadErrorReported = false
    }

    private func isFileLoadOpenFailureMessage(_ message: String) -> Bool {
        message.contains("could not read") || message.contains("could not open")
    }

    private func formatLoadErrorLead(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("?") { return trimmed }
        return "? \(trimmed)"
    }

    /// Emit a load-time fault with filename, line number, and the offending source line.
    private func reportFileLoadError(fileId: Int, line: Int, sourceLine: String, loadLabel: String, message: String, enclosingFileId: Int = 0, enclosingLine: Int = 0, isOpenFailure: Bool = false) {
        // Enclosing CATCH should receive the throw code without duplicate load diagnostics.
        if !self.exceptionFrames.isEmpty { return }
        let trimmed = sourceLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if isOpenFailure {
            if !message.isEmpty {
                self.tell("\(self.formatLoadErrorLead(message))\n")
            }
            if enclosingFileId >= 2, enclosingLine > 0 {
                let outerName = self.fileDisplayName(forFileId: enclosingFileId)
                self.tell("    in \(outerName) line \(enclosingLine):\n")
            }
            if !trimmed.isEmpty {
                self.tell("    \(trimmed)\n")
            }
            return
        }
        let name = self.fileDisplayName(forFileId: fileId)
        if !message.isEmpty {
            self.tell("? \(name) line \(line): \(message)\n")
        }
        if !trimmed.isEmpty {
            self.tell("    \(trimmed)\n")
        }
        if enclosingFileId >= 2, enclosingLine > 0,
           enclosingFileId != fileId || enclosingLine != line {
            let outerName = self.fileDisplayName(forFileId: enclosingFileId)
            self.tell("    (while interpreting \(outerName) line \(enclosingLine))\n")
        }
        self.tell("? \(loadLabel) of \(name) aborted at line \(line)\n")
    }

    /// Report the innermost nested fault once; fall back to the current include loop line.
    private func reportFileLoadErrorOnce(outerFileId: Int, outerLine: Int, outerSourceLine: String, outerLoadLabel: String, pendingMessage: String) {
        if self.fileLoadErrorReported { return }
        if let site = self.fileLoadErrorSite {
            self.reportFileLoadError(
                fileId: site.fileId,
                line: site.line,
                sourceLine: site.sourceLine,
                loadLabel: site.loadLabel,
                message: site.message,
                enclosingFileId: site.enclosingFileId,
                enclosingLine: site.enclosingLine,
                isOpenFailure: site.isOpenFailure
            )
            self.fileLoadErrorReported = true
            return
        }
        if !pendingMessage.isEmpty || self.errorFlag {
            self.reportFileLoadError(
                fileId: outerFileId,
                line: outerLine,
                sourceLine: outerSourceLine,
                loadLabel: outerLoadLabel,
                message: pendingMessage
            )
            self.fileLoadErrorReported = true
        }
    }

    private func abortFileInterpretAfterLine(fileId: Int, line: Int, sourceLine: String, loadLabel: String) {
        self.midFileLoadAborted = true
        let message = self.fileLoadPendingErrorMessage
        self.fileLoadPendingErrorMessage = ""
        if self.throwActive {
            // CATCH will handle the throw; still emit load diagnostics once for the inner fault.
            self.reportFileLoadErrorOnce(
                outerFileId: fileId,
                outerLine: line,
                outerSourceLine: sourceLine,
                outerLoadLabel: loadLabel,
                pendingMessage: message
            )
            self.errorFlag = false
            return
        }
        self.reportFileLoadErrorOnce(
            outerFileId: fileId,
            outerLine: line,
            outerSourceLine: sourceLine,
            outerLoadLabel: loadLabel,
            pendingMessage: message
        )
        self.errorFlag = false
        if !self.exceptionFrames.isEmpty {
            let reportFileId = self.fileLoadErrorSite?.fileId ?? fileId
            let reportLine = self.fileLoadErrorSite?.line ?? line
            let reportLabel = self.fileLoadErrorSite?.loadLabel ?? loadLabel
            let reportName = self.fileDisplayName(forFileId: reportFileId)
            self.kernelThrow(StdThrow.fileIOError, message: "? \(reportLabel) of \(reportName) aborted at line \(reportLine)")
        }
    }

    // MARK: - Input (line-driven from SwiftUI)

    public func feedLine(_ line: String) {
        // Top-level defensive entry point for the host application (ConsoleView, tests, etc.).
        // All serious error conditions inside the engine are now turned into clean
        // "? message" reports + stack resets instead of Swift traps/fatalErrors.
        // This guarantees feedLine always returns normally and leaves the engine
        // ready for the next command.
        validateAndRepairSystemState()
        self.throwActive = false
        self.namedFloadOnCurrentReplLine = false

        // Prepare the SOURCE buffer and >IN for this line (supports SOURCE, PARSE, >IN tracking).
        // Each feedLine (REPL) becomes the "current input source".
        self.currentSourceLen = 0
        let lineBytes = Array(line.utf8)
        let n = min(lineBytes.count, SOURCE_BUFFER_SIZE)
        for i in 0..<n {
            self.writeByte(SOURCE_BUFFER + i, lineBytes[i])
        }
        self.currentSourceLen = n
        self.writeCell(self.IN, 0)
        if self.evaluateNesting > 0 {
            self.currentSourceId = 0
        } else if self.loadNesting > 0 {
            self.currentSourceId = 1
        } else {
            self.currentSourceId = -1
        }

        self.inputQueue.removeAll(keepingCapacity: true)
        for b in line.utf8 { inputQueue.append(b) }
        inputQueue.append(10) // \n

        runInterpreter()

        // Only recover on unhandled faults (errorFlag). Caught THROW leaves throwActive set
        // but must not reset stacks — e.g. ['] fload CATCH during a mid-file line error.
        if errorFlag {
            recoverFromError()
        }

        // Optional per-line debug output (state + stack after each feedLine).
        // Enabled via DEBUG-ON / DEBUG-OFF. Default is off.
        // Changes take effect immediately, including for subsequent lines when
        // DEBUG-ON/OFF inside a loaded file (live flag, checked after each REPL line).
        if debugEnabled {
            let stateStr = readCell(STATE) != 0 ? "compiling" : "interpreting"
            let depth = Int(spGet() - 1)
            tell("[DEBUG] state=\(stateStr)  stack=<\(depth)> \(stackAsString)\n")
        }

        // Ensure a clean IP (0 = top-level sentinel) after each top-level feed in
        // interpret mode. This prevents a dirty IP (leftover from errors, FLOAD
        // recursion, or previous bad threaded runs) from being rpush'ed as the
        // return frame for the *next* command line's colon executions.
        if readCell(STATE) == 0 && !self.isBlockingOnHost {
            ip = 0
        }
        self.flushTerminalRefreshIfNeeded()
    }

    private func resumeBlockingPrimitive(pushValue: Int? = nil) {
        if let v = pushValue {
            self.push(v)
        }
        if self.returnStackPointer > 1 {
            self.ip += 8
            self.innerThread()
        }
        self.runInterpreter()
    }

    /// Called by the host UI (ConsoleView) when the user types a character while
    /// a KEY is waiting (waitingForKey == true). This supplies the character to the
    /// pending KEY and resumes interpretation (outer or threaded) from the suspension point.
    public func provideKey(_ char: Int) {
        if !self.waitingForKey { return }
        if self.waitingForXKey {
            self.xkeyAssembly.append(UInt8(char & 0xff))
            if let cp = self.decodeAssembledXKeyBytes() {
                self.waitingForXKey = false
                self.waitingForKey = false
                self.xkeyAssembly.removeAll(keepingCapacity: true)
                self.push(Cell(cp))
                self.resumeBlockingPrimitive()
            } else {
                self.waitingForKey = true
            }
            return
        }
        self.waitingForKey = false
        self.resumeBlockingPrimitive(pushValue: char)
    }

    /// Called by the host when EKEY is waiting. Supplies an extended keyboard event.
    public func provideExtendedKey(_ event: Int) {
        if !self.waitingForExtendedKey { return }
        self.waitingForExtendedKey = false
        self.resumeBlockingPrimitive(pushValue: event)
    }

    /// Resume after an asynchronous MS delay (invoked from onMsDelayRequested completion).
    public func resumeAfterMs() {
        if !self.waitingForMs { return }
        self.waitingForMs = false
        self.resumeBlockingPrimitive()
    }

    /// Queue an extended key event (used by host pre-buffering and test harness).
    internal func enqueueExtendedKey(_ event: Int) {
        self.extendedKeyQueue.append(event)
    }

    private func dequeueExtendedKey() -> Int? {
        if self.extendedKeyQueue.isEmpty { return nil }
        return self.extendedKeyQueue.removeFirst()
    }

    internal func isCharKeyEvent(_ x: Int) -> Bool {
        (x & (3 << 24)) == (1 << 24)
    }

    private func isFKeyEvent(_ x: Int) -> Bool {
        (x & (3 << 24)) == (2 << 24)
    }

    // MARK: - FLOAD / INCLUDE shared source loading

    /// Decode file bytes with the same tolerance as legacy FLOAD (UTF-8, Latin-1, replacement).
    private func readTextFileBytes(from url: URL) -> Data? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let content: String
        if let utf8 = String(data: data, encoding: .utf8) {
            content = utf8
        } else if let latin = String(data: data, encoding: .isoLatin1) {
            content = latin
        } else {
            content = String(decoding: data, as: UTF8.self)
        }
        return Data(content.utf8)
    }

    /// Open a text file for line-at-a-time interpret (FLOAD / INCLUDED / INCLUDE-FILE).
    private func openTextFileForInterpret(at url: URL) -> (fileid: Cell, ior: Cell) {
        let path = url.path
        guard let data = self.readTextFileBytes(from: url) else {
            return (0, self.FILE_IO_ERROR)
        }
        let fid = self.allocFileId()
        self.openFiles[fid] = FileEntry(
            path: path,
            fam: self.FAM_RDONLY,
            data: data,
            position: 0,
            isOpen: true,
            writeDirty: false
        )
        return (Cell(fid), self.FILE_IO_SUCCESS)
    }

    /// Echo a source line when FILE-ECHO is on (or the line toggles echo).
    private func echoSourceLineIfNeeded(_ raw: String) {
        let echoOn = (self.fileEchoAddr != 0) && (self.readCell(self.fileEchoAddr) != 0)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let isEchoToggle = lower.hasPrefix("file-echo") && (lower.contains("on") || lower.contains("off"))
        if echoOn || isEchoToggle {
            self.tell(raw + "\n")
        }
    }

    private func sourceBufferLineString() -> String {
        var bytes: [UInt8] = []
        for i in 0..<self.currentSourceLen {
            bytes.append(self.readByte(self.SOURCE_BUFFER + i))
        }
        return String(bytes: bytes, encoding: .utf8) ?? String(decoding: bytes, as: UTF8.self)
    }

    /// Per-line cleanup after interpreting one loaded source line (matches feedLine tail).
    private func finishInterpretedLoadLine() {
        if self.errorFlag {
            if self.isInterpretingLoadedFile() {
                self.recoverFromErrorDuringFileLoad()
            } else {
                self.recoverFromError()
            }
        }
        if self.debugEnabled {
            let stateStr = self.readCell(self.STATE) != 0 ? "compiling" : "interpreting"
            let depth = Int(self.spGet() - 1)
            self.tell("[DEBUG] state=\(stateStr)  stack=<\(depth)> \(self.stackAsString)\n")
        }
        if self.readCell(self.STATE) == 0 && !self.isBlockingOnHost {
            self.ip = 0
        }
    }

    // MARK: - FLOAD support (file loading / including source)

    /// Public entry point for the host to load a file after a dialog (or programmatically).
    /// Clears any pending request flag and processes the file's lines.
    @discardableResult
    public func loadFile(_ url: URL) -> Bool {
        fileLoadRequested = false
        fileEditRequested = false
        pendingEditURL = nil
        pendingLoadURL = nil
        return loadFileContents(url)
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
    func resolvedURL(for spec: String) -> URL {
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
        self.pendingFloadSpec = spec
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

    private func performNamedFload(url: URL, spec: String) {
        let ok: Bool
        if let hostLoad = self.onPerformNamedLoad {
            ok = hostLoad(url)
        } else {
            ok = self.loadFileContents(url, registerSpec: spec)
        }
        if !ok && !self.throwActive && !self.midFileLoadAborted {
            self.throwFileNotFound("? FLOAD could not read '\(url.lastPathComponent)' (not found or unreadable)")
        }
    }

    @discardableResult
    private func loadFileContents(_ url: URL, registerSpec: String? = nil) -> Bool {
        // Support FLOAD auto .fth: if the provided url's leaf has no dot, try the literal
        // name first; if it doesn't exist, fall back to name + ".fth". This lets
        // "fload foo" work whether the file is "foo" or "foo.fth".
        let leaf = url.lastPathComponent
        let candidates: [URL] = !leaf.contains(".") ?
            [url, url.deletingLastPathComponent().appendingPathComponent(leaf + ".fth")] :
            [url]

        for target in candidates {
            let (fid, ior) = self.openTextFileForInterpret(at: target)
            guard ior == self.FILE_IO_SUCCESS else { continue }
            self.midFileLoadAborted = false
            self.clearFileLoadErrorTracking()
            self.includeFileInterpret(Int(fid), closeWhenDone: true, loadLabel: "FLOAD")
            if self.midFileLoadAborted || self.throwActive {
                self.pendingFloadSpec = ""
                return false
            }
            let specToRegister = registerSpec ?? self.pendingFloadSpec
            if !specToRegister.isEmpty {
                self.nameJoinSpec(specToRegister)
            } else {
                self.nameJoinSpec(target.lastPathComponent)
            }
            if target.lastPathComponent == "utilities.fth" {
                // Redefine ($") and $" — $" was compiled against the PARSE-based ($") and must be recompiled.
                self.feedLine(": ($\") ( caddr -- caddr' u ) (hayes-quote-parse) ;")
                self.feedLine(": $\" SBUF1 ($\") ;")
                self.feedLine(": $2\" SBUF2 ($\") ;")
            }
            self.pendingFloadSpec = ""
            return true
        }
        self.pendingFloadSpec = ""
        let reportURL = candidates.last ?? url
        let msg = "? FLOAD could not read '\(reportURL.lastPathComponent)' (not found or unreadable)"
        self.throwFileNotFound(msg)
        if self.exceptionFrames.isEmpty {
            tell("  (If the file is in your current directory, type bare `fload` and pick any file in that folder once to authorize it. Then named FLOAD and CHDIR will stick across launches.)\n")
        }
        return false
    }

    // MARK: - File-Access helpers (ANS word set 11)

    func stringFromAddr(_ caddr: Int, _ u: Int) -> String {
        var bytes: [UInt8] = []
        for i in 0..<u { bytes.append(readByte(caddr + i)) }
        return String(bytes: bytes, encoding: .utf8) ?? String(decoding: bytes, as: UTF8.self)
    }

    func pathURLFromCounted(_ caddr: Int, _ u: Int) -> URL {
        let spec = stringFromAddr(caddr, u)
        return resolvedURL(for: spec)
    }

    /// Push a 64-bit file offset as a double-cell (high = 0).
    private func pushUD(_ ud: UInt64) {
        self.push(Cell(Int(ud)))
        self.push(0)
    }

    private func popUD() -> UInt64 {
        _ = self.pop()
        return self.unsignedCell(self.pop())
    }

    private func popSignedDouble() -> Int128 {
        let pair = self.popDoubleStack()
        return self.assembleSignedDouble(lo: pair.lo, hi: pair.hi)
    }

    private func popUnsignedDouble() -> UInt128 {
        let pair = self.popDoubleStack()
        return self.assembleUnsignedDouble(lo: pair.lo, hi: pair.hi)
    }

    private func pushSignedDouble(_ d: Int128) {
        let parts = self.disassembleSignedDouble(d)
        self.pushDoubleStack(lo: parts.lo, hi: parts.hi)
    }

    private func pushUnsignedDouble(_ ud: UInt128) {
        let parts = self.disassembleUnsignedDouble(ud)
        self.pushDoubleStack(lo: parts.lo, hi: parts.hi)
    }

    private func digitValue(_ ch: Character, base: Int) -> Int? {
        if ch >= "0" && ch <= "9" {
            let d = Int(ch.asciiValue! - 48)
            return d < base ? d : nil
        }
        let u = String(ch).uppercased()
        guard let scalar = u.unicodeScalars.first else { return nil }
        let c = scalar.value
        if c >= 65 && c <= 90 {
            let d = 10 + Int(c - 65)
            return d < base ? d : nil
        }
        return nil
    }

    /// ANS 3.4 / 6.1.1320: optional # (decimal), $ (hex), or % (binary) prefix overrides BASE.
    private func parsePrefixedNumericStem(_ name: String, defaultBase: Int) -> (stem: String, base: Int, negative: Bool)? {
        var stem = name
        guard !stem.isEmpty else { return nil }
        var base = defaultBase
        if stem.hasPrefix("#") {
            base = 10
            stem = String(stem.dropFirst())
        } else if stem.hasPrefix("$") {
            base = 16
            stem = String(stem.dropFirst())
        } else if stem.hasPrefix("%") {
            base = 2
            stem = String(stem.dropFirst())
        }
        var negative = false
        if stem.hasPrefix("-") {
            negative = true
            stem = String(stem.dropFirst())
        } else if stem.hasPrefix("+") {
            stem = String(stem.dropFirst())
        }
        guard !stem.isEmpty else { return nil }
        return (stem, base, negative)
    }

    private func parseStemToSignedDouble(stem: String, base: Int, negative: Bool) -> (lo: Cell, hi: Cell)? {
        let b = max(2, min(36, base))
        var ud: UInt128 = 0
        for ch in stem {
            guard let d = self.digitValue(ch, base: b) else { return nil }
            ud = ud * UInt128(b) + UInt128(d)
        }
        var sd = Int128(ud)
        if negative { sd = -sd }
        let parts = self.disassembleSignedDouble(sd)
        return (parts.lo, parts.hi)
    }

    /// Hayes / classic: 'c' is a single-character literal (ASCII value), not tick.
    private func parseCharLiteralToken(_ name: String) -> Int? {
        guard name.count == 3,
              name.first == "'",
              name.last == "'",
              let ch = name.dropFirst().dropLast().first else { return nil }
        return Int(ch.asciiValue ?? UInt8(ch.unicodeScalars.first?.value ?? 0))
    }

    private func parseTextNumber(_ name: String, base defaultBase: Int) -> Int? {
        guard let parsed = self.parsePrefixedNumericStem(name, defaultBase: defaultBase) else { return nil }
        let b = max(2, min(36, parsed.base))
        for ch in parsed.stem {
            guard self.digitValue(ch, base: b) != nil else { return nil }
        }
        if parsed.negative {
            if let v = Int("-\(parsed.stem)", radix: b) { return v }
            guard let mag = UInt64(parsed.stem, radix: b) else { return nil }
            let wrapped = Int(truncatingIfNeeded: mag)
            return 0 &- wrapped
        }
        if let v = Int(parsed.stem, radix: b) { return v }
        guard let u = UInt64(parsed.stem, radix: b) else { return nil }
        return Int(truncatingIfNeeded: u)
    }

    /// ANS 8.3.1: a token ending in '.' (and not a definition) is a double-cell literal.
    private func parseTextDouble(_ name: String, base defaultBase: Int) -> (lo: Cell, hi: Cell)? {
        guard name.hasSuffix(".") else { return nil }
        let withoutDot = String(name.dropLast())
        guard let parsed = self.parsePrefixedNumericStem(withoutDot, defaultBase: defaultBase) else { return nil }
        return self.parseStemToSignedDouble(stem: parsed.stem, base: parsed.base, negative: parsed.negative)
    }

    private func formatSignedDouble(lo: Cell, hi: Cell, base: Cell) -> String {
        let d = self.assembleSignedDouble(lo: lo, hi: hi)
        let b = Int(max(2, min(36, base)))
        if d < 0 {
            return "-" + String(UInt128(-d), radix: b).uppercased()
        }
        return String(UInt128(d), radix: b).uppercased()
    }

    private func compileDoubleLiteral(_ lo: Cell, _ hi: Cell) {
        self.push(self.litID); self.comma()
        self.push(lo); self.comma()
        self.push(self.litID); self.comma()
        self.push(hi); self.comma()
    }

    private func resetLocalCompileState() {
        self.localCompileNames.removeAll(keepingCapacity: true)
        self.localCompileMap.removeAll(keepingCapacity: true)
        self.localCompileInitCount = 0
        self.localCompileInitReverse = false
    }

    private func localNameKey(_ name: String) -> String {
        name.uppercased()
    }

    private func validateLocalName(_ name: String) -> Bool {
        if name.isEmpty { return false }
        if name.hasSuffix(":") || name.hasSuffix("[") || name.hasSuffix("^") { return false }
        if name.count == 1, let c = name.first, !c.isLetter { return false }
        return true
    }

    private func beginLocalName(_ name: String) {
        let key = self.localNameKey(name)
        if !self.validateLocalName(name) {
            self.throwIllegalArgument("? invalid local name \(name)")
            return
        }
        if self.localCompileNames.count >= Self.MAX_LOCALS_PER_DEF {
            self.throwIllegalArgument("? too many locals (max \(Self.MAX_LOCALS_PER_DEF))")
            return
        }
        if self.localCompileNames.contains(where: { self.localNameKey($0) == key }) {
            self.throwIllegalArgument("? duplicate local \(name)")
            return
        }
        self.localCompileNames.append(name)
    }

    private func finalizeLocalCompilation() {
        let n = self.localCompileNames.count
        guard n > 0 else { return }
        for (i, name) in self.localCompileNames.enumerated() {
            self.localCompileMap[self.localNameKey(name)] = i
        }
        self.push(self.litID); self.comma()
        self.push(Cell(n)); self.comma()
        self.push(self.litID); self.comma()
        self.push(Cell(self.localCompileInitCount)); self.comma()
        self.push(self.litID); self.comma()
        self.push(self.localCompileInitReverse ? -1 : 0); self.comma()
        self.push(self.localInitID); self.comma()
    }

    private func compileLocalFetch(_ index: Int) {
        self.push(self.litID); self.comma()
        self.push(Cell(index)); self.comma()
        self.push(self.localFetchID); self.comma()
    }

    private func compileLocalStore(_ index: Int) {
        self.push(self.litID); self.comma()
        self.push(Cell(index)); self.comma()
        self.push(self.localStoreID); self.comma()
    }

    private func endLocalFrame() {
        guard !self.localFrames.isEmpty, !self.localFrameReturnDepth.isEmpty else { return }
        // Nested EXIT (e.g. ALSO-LTWL inside LT35) must not drop the caller's locals frame.
        if self.returnStackPointer != self.localFrameReturnDepth.last { return }
        _ = self.localFrameReturnDepth.removeLast()
        self.localFrames.removeLast()
    }

    private func clearAllLocalFrames() {
        self.localFrames.removeAll(keepingCapacity: true)
        self.localFrameReturnDepth.removeAll(keepingCapacity: true)
    }

    private func localIndexDuringCompile(_ name: String) -> Int? {
        self.localCompileMap[self.localNameKey(name)]
    }

    private func executeDictWord(_ name: String) {
        for wlID in self.searchOrder {
            let hdr = self.findWordInWordlist(wlID, name: name)
            if hdr != 0 {
                let cfa = self.getCFA(hdr)
                let first = self.readCell(Int(cfa))
                self.execute(cfa: cfa, firstCell: first)
                return
            }
        }
        self.kernelThrow(StdThrow.undefinedWord, message: "? \(name)")
    }

    /// Hayes localstest `LOCAL` immediate — parse one local name at compile time.
    private func runHayesLocalDeclImmediate() {
        self.realignInputQueueFromSource()
        let saved = self.readCell(self.STATE)
        self.writeCell(self.STATE, 0)
        self.executeDictWord("BL")
        if self.throwActive || self.errorFlag { return }
        self.executeDictWord("WORD")
        if self.throwActive || self.errorFlag { return }
        self.executeDictWord("COUNT")
        if self.throwActive || self.errorFlag { return }
        self.writeCell(self.STATE, 1)
        self.executeDictWord("(LOCAL)")
        self.writeCell(self.STATE, saved)
    }

    /// Hayes localstest `END-LOCALS` immediate — finalize the local list.
    private func runHayesEndLocalsImmediate() {
        // END-LOCALS is `: END-LOCALS 99 0 (LOCAL) ;` — 99 is a Hayes dummy, not a stack arg.
        // Finalize directly; do not push 99/0 on the data stack (they would survive compile).
        self.localCompileInitCount = self.localCompileNames.count
        self.finalizeLocalCompilation()
    }

    private func allocFileId() -> Int {
        let id = nextFileId
        nextFileId += 1
        return id
    }

    private func famAllowsRead(_ fam: Cell) -> Bool {
        let base = fam & ~FAM_BIN
        return base == FAM_RDONLY || base == FAM_RDWR
    }

    private func famAllowsWrite(_ fam: Cell) -> Bool {
        let base = fam & ~FAM_BIN
        return base == FAM_WRONLY || base == FAM_RDWR
    }

    private func openFileAtPath(_ path: String, fam: Cell, create: Bool) -> (fileid: Cell, ior: Cell) {
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default
        if create {
            fm.createFile(atPath: path, contents: Data(), attributes: nil)
        }
        guard fm.fileExists(atPath: path) else {
            return (0, FILE_IO_ERROR)
        }
        var data = Data()
        if famAllowsRead(fam) {
            do {
                data = try Data(contentsOf: url)
            } catch {
                return (0, FILE_IO_ERROR)
            }
        }
        let fid = allocFileId()
        openFiles[fid] = FileEntry(path: path, fam: fam, data: data, position: 0, isOpen: true, writeDirty: create || famAllowsWrite(fam))
        if create && famAllowsWrite(fam) {
            openFiles[fid]?.writeDirty = true
        }
        return (Cell(fid), FILE_IO_SUCCESS)
    }

    private func closeFileEntry(_ fileId: Int, flush: Bool) -> Cell {
        guard var entry = openFiles[fileId], entry.isOpen else { return FILE_IO_ERROR }
        if flush && entry.writeDirty && famAllowsWrite(entry.fam) {
            do {
                try entry.data.write(to: URL(fileURLWithPath: entry.path))
                entry.writeDirty = false
            } catch {
                return FILE_IO_ERROR
            }
        }
        entry.isOpen = false
        openFiles[fileId] = entry
        return FILE_IO_SUCCESS
    }

    /// Distinguish never-allocated fileid (-68) from CLOSE-FILE'd id (-67).
    private enum FileIdStatus {
        case invalid
        case closed
        case open
    }

    private func fileIdStatus(_ fileId: Int) -> FileIdStatus {
        guard let entry = openFiles[fileId] else { return .invalid }
        return entry.isOpen ? .open : .closed
    }

    private func activeInterpreterFileId() -> Int? {
        if interpreterInputFileId >= 2 { return Int(interpreterInputFileId) }
        if currentSourceId >= 2 { return Int(currentSourceId) }
        return nil
    }

    private func isFileInputSource() -> Bool {
        activeInterpreterFileId() != nil
    }

    /// Read a line into memory buffer; returns (u2, flag, ior). flag false at EOF.
    private func readLineFromFile(_ fileId: Int, buffer: Int, maxLen: Int) -> (u2: Int, flag: Bool, ior: Cell) {
        guard var entry = openFiles[fileId], entry.isOpen, famAllowsRead(entry.fam) else {
            return (0, false, FILE_IO_ERROR)
        }
        if entry.position >= entry.data.count {
            return (0, false, FILE_IO_SUCCESS)
        }
        var lineBytes: [UInt8] = []
        var pos = entry.position
        while pos < entry.data.count && lineBytes.count < maxLen {
            let b = entry.data[pos]
            pos += 1
            if b == 10 { break }
            if b == 13 {
                if pos < entry.data.count && entry.data[pos] == 10 { pos += 1 }
                break
            }
            lineBytes.append(b)
        }
        entry.position = pos
        openFiles[fileId] = entry
        let u2 = min(lineBytes.count, maxLen)
        for i in 0..<u2 {
            writeByte(buffer + i, lineBytes[i])
        }
        return (u2, true, FILE_IO_SUCCESS)
    }

    /// Load the next source line from file into SOURCE/inputQueue. Returns false at EOF.
    private func refillFromFile(_ fileId: Int) -> Bool {
        if self.countFloadInterpreterRefills && self.loadNesting > 0 && self.evaluateNesting == 0 {
            self.floadExtraLinesConsumed += 1
        }
        if let entry = self.openFiles[fileId], entry.isOpen {
            self.currentFileLineStart = entry.position
        } else {
            self.currentFileLineStart = nil
        }
        let (u2, flag, ior) = readLineFromFile(fileId, buffer: SOURCE_BUFFER, maxLen: SOURCE_BUFFER_SIZE)
        if ior != FILE_IO_SUCCESS || !flag { return false }
        currentSourceLen = u2
        writeCell(IN, 0)
        self.throwActive = false
        if self.loadNesting > 0, self.interpreterInputFileId >= 2 {
            self.currentSourceId = self.interpreterInputFileId
        } else if self.evaluateNesting > 0 {
            self.currentSourceId = 0
        } else if self.loadNesting > 0 {
            self.currentSourceId = 1
        } else {
            self.currentSourceId = -1
        }
        inputQueue.removeAll(keepingCapacity: true)
        for i in 0..<u2 {
            inputQueue.append(readByte(SOURCE_BUFFER + i))
        }
        inputQueue.append(10)
        return true
    }

    func pushInputSourceFrame() {
        var sourceBytes: [UInt8] = []
        for i in 0..<currentSourceLen {
            sourceBytes.append(readByte(SOURCE_BUFFER + i))
        }
        inputSourceStack.append(InputSourceFrame(
            sourceId: currentSourceId,
            inPos: readCell(IN),
            sourceLen: currentSourceLen,
            sourceBytes: sourceBytes,
            queue: inputQueue,
            evaluateNesting: evaluateNesting,
            interpreterInputFileId: interpreterInputFileId
        ))
    }

    func popInputSourceFrame() {
        guard let frame = inputSourceStack.popLast() else { return }
        currentSourceId = frame.sourceId
        writeCell(IN, frame.inPos)
        currentSourceLen = frame.sourceLen
        for i in 0..<frame.sourceLen {
            writeByte(SOURCE_BUFFER + i, frame.sourceBytes[i])
        }
        inputQueue = frame.queue
        evaluateNesting = frame.evaluateNesting
        interpreterInputFileId = frame.interpreterInputFileId
    }

    private func includeFileInterpret(_ fileId: Int, closeWhenDone: Bool, loadLabel: String = "INCLUDE-FILE") {
        self.currentIncludeLoadLabel = loadLabel
        switch self.fileIdStatus(fileId) {
        case .invalid:
            self.throwInvalidFileId("? INCLUDE-FILE: invalid fileid")
            return
        case .closed:
            self.throwClosedFile("? INCLUDE-FILE: operation on closed file")
            return
        case .open:
            break
        }
        let isOutermostLoad = self.loadNesting == 0
        pushInputSourceFrame()
        interpreterInputFileId = Cell(fileId)
        currentSourceId = Cell(fileId)
        loadNesting += 1
        if isOutermostLoad {
            self.clearFileLoadErrorTracking()
        }
        self.sourceLoadedByRefill = false
        sourceLoadStop = false
        self.fileInterpretStopStack.append(false)
        self.inSlashSlashComment = false
        self.inParenComment = false
        defer {
            if loadNesting > 0 { loadNesting -= 1 }
            if !self.fileInterpretLineNumberStack.isEmpty {
                self.fileInterpretLineNumber = self.fileInterpretLineNumberStack.removeLast()
            }
            popInputSourceFrame()
            // Only clear when the outermost load ends; nested INCLUDED must not clobber the
            // parent's interpreterInputFileId (Hayes filetest SI2 REFILL after REQUIRED).
            if loadNesting == 0 {
                interpreterInputFileId = 0
                self.fileLoadRequested = false
                self.fileEditRequested = false
                self.directoryPickRequested = false
                self.pendingLoadURL = nil
                self.pendingEditURL = nil
                if !self.throwActive {
                    self.applyHayesBaseRestoreIfPending()
                }
            }
            if closeWhenDone {
                _ = closeFileEntry(fileId, flush: false)
            }
            self.sourceLoadStop = false
            if !self.fileInterpretStopStack.isEmpty {
                _ = self.fileInterpretStopStack.removeLast()
            }
            self.inSlashSlashComment = false
            self.inParenComment = false
            // Orphaned [IF]/[ELSE] text-scan state must not leak into the REPL after a load
            // ends (Hayes toolstest multi-line conditionals can leave depth > 0 on abort).
            self.conditionalSkipDepth = 0
            self.conditionalSkipStopAtElse = false
            self.conditionalSkipDiscardThroughQuote = false
            self.floadExtraLinesConsumed = 0
            self.floadLinesToSkip = 0
            self.countFloadInterpreterRefills = false
            self.floadRestoreInputContinuation = false
            self.interpretIfTrueDepth = 0
        }
        self.midFileLoadAborted = false
        self.fileInterpretLineNumberStack.append(self.fileInterpretLineNumber)
        self.fileInterpretLineNumber = 0
        while refillFromFile(fileId) {
            if self.floadLinesToSkip > 0 {
                self.floadLinesToSkip -= 1
                continue
            }
            // Position after this SOURCE line (start of next line). `(` / REFILL inside
            // runInterpreter must not permanently advance the outer FLOAD line cursor.
            let nextLinePosition = self.openFiles[fileId]?.position ?? 0
            self.sourceLoadedByRefill = false
            self.fileInterpretLineNumber += 1
            let lineNumber = self.fileInterpretLineNumber
            validateAndRepairSystemState()
            let raw = self.sourceBufferLineString()
            if self.exceptionFrames.isEmpty {
                self.echoSourceLineIfNeeded(raw)
            }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // Nested RESTORE-INPUT (Hayes filetest SI2) may repoint SOURCE mid-line; restore
                // this FLOAD line afterward so runInterpreter does not parse the saved input
                // twice (once here, again on the next refill after the file rewind).
                self.floadExtraLinesConsumed = 0
                self.countFloadInterpreterRefills = true
                self.fileLoadEnclosingStack.append(FileLoadCallerFrame(fileId: fileId, line: lineNumber, sourceLine: raw))
                self.pushInputSourceFrame()
                runInterpreter()
                self.countFloadInterpreterRefills = false
                self.floadLinesToSkip = self.floadExtraLinesConsumed
                self.popInputSourceFrame()
                if !self.fileLoadEnclosingStack.isEmpty {
                    self.fileLoadEnclosingStack.removeLast()
                }
                self.finishInterpretedLoadLine()
                self.yieldToHostUIIfNeeded()
            }
            // Undo only forward over-reads from `(` REFILL during this line. RESTORE-INPUT
            // continuation (Hayes filetest SI2) leaves the file where runInterpreter ended.
            if self.floadRestoreInputContinuation {
                self.floadExtraLinesConsumed = 0
                self.floadLinesToSkip = 0
                self.floadRestoreInputContinuation = false
            } else if self.floadExtraLinesConsumed > 0,
                      var entry = self.openFiles[fileId], entry.isOpen,
                      entry.position > nextLinePosition {
                entry.position = nextLinePosition
                self.openFiles[fileId] = entry
            }
            // Hayes ~ / successful ?~~ leaves >IN at end-of-line; drop any stale queue tail.
            if Int(self.readCell(self.IN)) >= self.currentSourceLen {
                self.inputQueue.removeAll(keepingCapacity: true)
            }
            if self.fileInterpretStopStack.last == true {
                // Intentional \\S stop — silent (not an error; REPL prints OK when the load returns).
                break
            }
            if throwActive || errorFlag {
                self.abortFileInterpretAfterLine(fileId: fileId, line: lineNumber, sourceLine: raw, loadLabel: loadLabel)
                break
            }
        }
        self.clearFileLoadErrorTracking()
    }

    // MARK: - INCLUDED-NAMES registry (ANS REQUIRE / REQUIRED)

    private static let INCLUDED_NAMES_NODE_BYTES = 24  // 3 cells: next | str-addr | str-u

    private func readIncludedNamesHead() -> Int {
        guard self.includedNamesVarAddr != 0 else { return 0 }
        return Int(self.readCell(self.includedNamesVarAddr))
    }

    private func writeIncludedNamesHead(_ addr: Int) {
        guard self.includedNamesVarAddr != 0 else { return }
        self.writeCell(self.includedNamesVarAddr, Cell(addr))
    }

    /// save-mem: copy u bytes from c-addr into heap-allocated storage.
    private func saveMem(caddr: Int, u: Int) -> Int? {
        guard u >= 0 else { return nil }
        let (addr, ior) = self.heapAllocateBytes(u)
        guard ior == self.FILE_IO_SUCCESS else { return nil }
        for i in 0..<u {
            self.writeByte(addr + i, self.readByte(caddr + i))
        }
        return addr
    }

    private func namePresent(caddr: Int, u: Int) -> Bool {
        var node = self.readIncludedNamesHead()
        while node != 0 {
            let strAddr = Int(self.readCell(node + 8))
            let strU = Int(self.readCell(node + 16))
            if self.compareCharacterStrings(caddr1: caddr, u1: u, caddr2: strAddr, u2: strU) == 0 {
                return true
            }
            node = Int(self.readCell(node))
        }
        return false
    }

    private func nameJoin(caddr: Int, u: Int) {
        if self.namePresent(caddr: caddr, u: u) { return }
        guard let strAddr = self.saveMem(caddr: caddr, u: u) else { return }
        let (nodeAddr, ior) = self.heapAllocateBytes(Self.INCLUDED_NAMES_NODE_BYTES)
        guard ior == self.FILE_IO_SUCCESS else { return }
        self.writeCell(nodeAddr, Cell(self.readIncludedNamesHead()))
        self.writeCell(nodeAddr + 8, Cell(strAddr))
        self.writeCell(nodeAddr + 16, Cell(u))
        self.writeIncludedNamesHead(nodeAddr)
    }

    private func nameJoinSpec(_ spec: String) {
        let bytes = Array(spec.utf8)
        guard !bytes.isEmpty else { return }
        let slot = self.allocateStringBufferSlot()
        for (i, b) in bytes.enumerated() {
            self.writeByte(slot + i, b)
        }
        self.nameJoin(caddr: slot, u: bytes.count)
    }

    private func displayIncludedNames() {
        self.tell("Included:\n")
        var node = self.readIncludedNamesHead()
        if node == 0 {
            self.tell("  (none)\n")
            return
        }
        var safety = 0
        while node != 0 && safety < 10_000 {
            safety += 1
            let strAddr = Int(self.readCell(node + 8))
            let strU = Int(self.readCell(node + 16))
            self.tell("  ")
            for i in 0..<strU {
                self.putkey(self.readByte(strAddr + i))
            }
            self.tell("\n")
            node = Int(self.readCell(node))
        }
    }

    private func requiredFromSpec(_ caddr: Int, _ u: Int) {
        if self.namePresent(caddr: caddr, u: u) { return }
        self.includedFromSpec(caddr, u)
    }

    private func parseNameFromInput() -> (caddr: Int, u: Int) {
        while !self.inputQueue.isEmpty {
            let b = self.inputQueue.first!
            if b > 32 { break }
            if b == 10 || b == 13 { break }
            _ = self.consumeInput()
        }
        let startPos = Int(self.readCell(self.IN))
        var len = 0
        while !self.inputQueue.isEmpty {
            let b = self.inputQueue.first!
            if b == 32 || b == 10 || b == 13 { break }
            _ = self.consumeInput()
            len += 1
        }
        return (self.SOURCE_BUFFER + startPos, len)
    }

    private func includedFromSpec(_ caddr: Int, _ u: Int) {
        let spec = self.stringFromAddr(caddr, u)
        if let loading = self.currentlyLoadingSpec, loading == spec {
            return
        }
        self.currentlyLoadingSpec = spec
        defer { self.currentlyLoadingSpec = nil }
        self.nameJoin(caddr: caddr, u: u)
        let url = self.pathURLFromCounted(caddr, u)
        let (fid, ior) = self.openTextFileForInterpret(at: url)
        if ior != self.FILE_IO_SUCCESS {
            self.throwFileNotFound("? INCLUDED could not open '\(url.lastPathComponent)'")
            return
        }
        self.includeFileInterpret(Int(fid), closeWhenDone: true, loadLabel: "INCLUDED")
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
        let listURL = self.ensureDirectoryAccess?(newURL) ?? newURL
        let visibleAsDir = fm.fileExists(atPath: listURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
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
        return !inputQueue.isEmpty
    }

    private func getKey() -> Int {
        if inputQueue.isEmpty { return -1 }
        return Int(inputQueue.removeFirst())
    }

    // MARK: - Dictionary creation (very close to the original)

    /// Bytes from HERE (DP) to the dictionary limit (below the pictured-numeric buffer).
    private func dictionaryFreeBytes() -> Cell {
        let here = readCell(DP_ADDR)
        let limit = blockPoolBase > 0 ? blockPoolBase : (pnoBufferAddr > 0 ? pnoBufferAddr : (memory.count - PNO_BUFFER_SIZE))
        return Cell(max(0, limit - here))
    }

    internal func alignHere() {
        var h = readCell(DP_ADDR)
        while (h & 7) != 0 {
            writeByte(h, 0)
            h += 1
        }
        writeCell(DP_ADDR, h)
        self.noteDictionaryAdvance(h)
    }

    // Direct memory versions — these do NOT touch the data stack.
    // Critical during init when building the primitive dictionary.
    private func noteDictionaryAdvance(_ here: Cell) {
        if here > self.dictionaryHighWater {
            self.dictionaryHighWater = here
        }
    }

    /// Clamp a corrupted HERE (DP) without rewinding below the allocated dictionary high-water.
    private func repairHereIfCorrupt() {
        let initialDict = self.rstackBase + self.RSTACK_SIZE * self.CELL_SIZE
        let safeDictStart = (self.kernelHere != 0 ? self.kernelHere : Cell(initialDict))
        let h = self.readCell(self.DP_ADDR)
        if h < safeDictStart || h >= Cell(self.memory.count - 1024) {
            let restore = max(safeDictStart, self.dictionaryHighWater)
            self.writeCell(self.DP_ADDR, restore)
        } else {
            self.noteDictionaryAdvance(h)
        }
    }

    internal func writeCellHere(_ value: Cell) {
        let h = readCell(DP_ADDR)
        writeCell(h, value)
        let next = h + 8
        writeCell(DP_ADDR, next)
        self.noteDictionaryAdvance(next)
    }

    internal func writeByteHere(_ value: UInt8) {
        let h = readCell(DP_ADDR)
        writeByte(h, value)
        let next = h + 1
        writeCell(DP_ADDR, next)
        self.noteDictionaryAdvance(next)
    }

    private func warningsEnabled() -> Bool {
        if self.warningAddr == 0 { return true }
        return self.readCell(self.warningAddr) != 0
    }

    /// F-PC %ALREADY_DEF: warn when a visible name is defined again (suppressed when WARNING is off).
    private func maybeWarnRedefinition(of name: String) {
        guard !name.isEmpty, self.warningsEnabled() else { return }
        if self.findWord(name) != 0 {
            self.tell("\n\(name) isn't unique\n")
        }
    }

    internal func createWord(name: String, immediate: Bool) {
        if !name.isEmpty {
            self.maybeWarnRedefinition(of: name)
        }
        // Dictionary headers must be cell-aligned (Hayes core.fr: HERE 1 ALLOT then CONSTANT).
        alignHere()
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
    internal func comma() {
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

    private func nameForWordlist(_ wlID: Cell) -> String {
        if wlID == self.LATEST { return "FORTH" }
        var link = readCell(self.LATEST)
        var safety = 0
        while link != 0 && safety < 10000 {
            safety += 1
            if !isValidDictionaryLink(link) { break }
            let cfa = getCFA(link)
            let first = readCell(Int(cfa))
            if first == createRuntimeID || first == dodoesID {
                let dataAddr: Cell = (first == dodoesID)
                    ? Cell(Int(cfa) + 16)
                    : readCell(Int(cfa) + 8)
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

    private func findWordInWordlist(_ wlID: Cell, name: String) -> Cell {
        let upper = name.uppercased()
        var link = readCell(Int(wlID))
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
        return 0
    }

    internal func findWord(_ name: String) -> Cell {  // TZForthBlock.swift
        if self.readCell(self.STATE) != 0, self.localIndexDuringCompile(name) != nil {
            return Cell(-1)  // sentinel: compiling local reference (not a real header)
        }
        for wlID in searchOrder {
            let hdr = findWordInWordlist(wlID, name: name)
            if hdr != 0 { return hdr }
        }
        return 0
    }

    /// CFA and action-storage address for a DEFER / VALUE (docol+LIT) or CREATE/DOES> defer.
    private func deferStorage(forName name: String) -> (cfa: Cell, storageAddr: Int)? {
        let hdr = self.findWord(name)
        if hdr == 0 || hdr == Cell(-1) { return nil }
        let cfa = self.getCFA(hdr)
        let first = self.readCell(Int(cfa))
        if first == self.docolID {
            let second = self.readCell(Int(cfa) + 8)
            if second != self.litID { return nil }
            return (cfa, Int(self.readCell(Int(cfa) + 16)))
        }
        if first == self.createRuntimeID || first == self.dodoesID {
            return (cfa, Int(self.readCell(Int(cfa) + 8)))
        }
        return nil
    }

    /// Address of a VALUE / VARIABLE storage cell, if found.
    private func valueStorageAddr(named name: String) -> Int? {
        let hdr = self.findWord(name)
        if hdr == 0 || hdr == Cell(-1) { return nil }
        let cfa = Int(self.getCFA(hdr))
        let first = self.readCell(cfa)
        if first == self.docolID, self.readCell(cfa + 8) == self.litID {
            return Int(self.readCell(cfa + 16))
        }
        if first == self.createRuntimeID {
            return Int(self.readCell(cfa + 8))
        }
        return nil
    }

    /// Walk the FORTH wordlist for a VARIABLE (docol lit addr) even when a same-named
    /// primitive shadows it in findWord (e.g. BLOCK-FILE after registerBlockWords).
    internal func variableDataAddrTraversing(named name: String) -> Cell {
        let upper = name.uppercased()
        var link = self.readCell(self.LATEST)
        var safety = 0
        while link != 0 && safety < 10000 {
            safety += 1
            if !self.isValidDictionaryLink(link) { break }
            let flagsLen = self.readByte(link + 8)
            let namelen = Int(flagsLen & self.MASK_NAMELENGTH)
            if namelen == upper.utf8.count {
                var match = true
                for (i, ch) in upper.utf8.enumerated() {
                    if self.up(self.readByte(link + 9 + i)) != self.up(ch) {
                        match = false
                        break
                    }
                }
                if match {
                    let cfa = Int(self.getCFA(link))
                    if self.readCell(cfa) == self.docolID,
                       self.readCell(cfa + 8) == self.litID {
                        return self.readCell(cfa + 16)
                    }
                }
            }
            link = self.readCell(link)
        }
        return 0
    }

    private func deferStorageFromXt(_ deferXt: Cell) -> Int? {
        if deferXt < Cell(self.MAX_BUILTIN_ID) { return nil }
        let cfa = Int(deferXt)
        let first = self.readCell(cfa)
        if first == self.docolID {
            if self.readCell(cfa + 8) != self.litID { return nil }
            return Int(self.readCell(cfa + 16))
        }
        if first == self.createRuntimeID || first == self.dodoesID {
            return Int(self.readCell(cfa + 8))
        }
        return nil
    }

    private func xtAndFindFlag(fromHeader hdr: Cell) -> (xt: Cell, flag: Cell) {
        let cfa = getCFA(hdr)
        let flagsLen = readByte(Int(hdr) + 8)
        let isImmediate = (flagsLen & FLAG_IMMEDIATE) != 0
        return (cfa, isImmediate ? 1 : -1)
    }

    /// First cell at a CFA when it is a kernel primitive dispatch ID; nil for colon/CREATE words.
    private func primitiveID(atCFA cfa: Cell) -> Cell? {
        let first = readCell(Int(cfa))
        if first < Cell(MAX_BUILTIN_ID) && first != docolID && first != codeEntryID && first != createRuntimeID && first != dodoesID && first != synonymID {
            return first
        }
        return nil
    }

    /// IP at which to start threading a word's CFA (skip DOCOL marker only).
    private func threadedEntryIP(forCFA cfa: Cell) -> Int {
        let addr = Int(cfa)
        let first = self.readCell(addr)
        if first == self.docolID || first == self.codeEntryID { return addr + 8 }
        return addr
    }

    /// Emit a compile-time reference to xt (cfa), following SYNONYM indirection.
    private func emitCompileReference(xt: Cell) {
        var target = xt
        var safety = 0
        while safety < 32 {
            safety += 1
            let first = readCell(Int(target))
            if first == synonymID {
                target = readCell(Int(target) + 8)
                continue
            }
            if let id = primitiveID(atCFA: target) {
                push(id); comma()
            } else if target < Cell(MAX_BUILTIN_ID) && target != docolID {
                push(target); comma()
            } else {
                push(target); comma()
            }
            return
        }
        kernelThrow(StdThrow.nestingLimit, message: "? SYNONYM chain too deep")
    }

    /// Anonymous xt (no dictionary header) that compiles a fixed target cfa when executed.
    private func makeCompileXT(forTargetCfa target: Cell) -> Cell {
        let cfa = readCell(DP_ADDR)
        writeCellHere(docolID)
        writeCellHere(litID)
        writeCellHere(target)
        writeCellHere(compileCfaID)
        writeCellHere(exitID)
        return cfa
    }

    /// True when compiling a definition, including immediate colon bodies while an open : is hidden.
    private func isActiveCompilation() -> Bool {
        if self.readCell(self.STATE) != 0 { return true }
        if self.bracketCompileDepth > 0 { return true }
        if !self.controlFlowStack.isEmpty { return true }
        if !self.whileRepeatStack.isEmpty { return true }
        if !self.caseBranchStack.isEmpty { return true }
        // Immediate colon bodies (e.g. [c+]) temporarily set STATE=0 while : tcm is still open.
        let latest = self.readCell(self.readCell(self.CURRENT))
        if latest != 0 {
            let fl = self.readByte(Int(latest) + 8)
            if (fl & self.FLAG_HIDDEN) != 0 { return true }
        }
        return false
    }

    /// CS-ROLL ( u -- ) shared by immediate and deferred compilation.
    private func performCsRoll(u: Int) {
        if u <= 0 { return }
        // ?DONE / WHILE: TOS is an unresolved forward-branch cell (0); leave it for REPEAT.
        // PT8 AHEAD/BEGIN: TOS is the loop entry (non-zero); roll the AHEAD placeholder up for THEN.
        if u == 1 && self.controlFlowStack.count == 2 {
            let top = self.controlFlowStack[self.controlFlowStack.count - 1]
            if self.readCell(Int(top)) == 0 { return }
        }
        let idx = self.controlFlowStack.count - 1 - u
        if idx < 0 || idx >= self.controlFlowStack.count {
            self.throwIllegalArgument("? CS-ROLL underflow")
            return
        }
        let rolled = self.controlFlowStack.remove(at: idx)
        self.controlFlowStack.append(rolled)
    }

    /// Patch open IF/ELSE/AHEAD forward branches (implicit THEN at `;`).
    /// `branchTo` is the first cell that false branches should reach — the EXIT at word end,
    /// not the address after EXIT (a false IF must still execute EXIT to leave the definition).
    private func patchOpenControlFlowPlaceholders(branchTo here: Cell) {
        while !self.controlFlowStack.isEmpty {
            let placeholder = self.controlFlowStack.removeLast()
            // BEGIN origins share controlFlowStack for CS-PICK but must not be patched as IF/AHEAD.
            if self.whileRepeatStack.contains(placeholder) { continue }
            // Only patch forward-branch placeholder cells (still 0); skip patched slots.
            if self.readCell(Int(placeholder)) != 0 { continue }
            let forwardOffset = here - (placeholder + 8)
            self.writeCell(Int(placeholder), forwardOffset)
        }
    }

    /// u=0 is TOS on the data stack.
    private func peekStackItem(_ u: Int) -> Cell {
        let depth = Int(spGet() - 1)
        if u < 0 || u >= depth { return 0 }
        return readCell(stackBase + (depth - 1 - u) * CELL_SIZE)
    }

    private enum ConditionalSkipResult { case then, elseBranch, pending, error }

    /// Discard .( / .\" bodies during a conditional text scan (no stack effect).
    private func discardParsedWordDuringConditionalSkip(_ word: String) {
        switch word {
        case ".(":
            while !self.inputQueue.isEmpty {
                let c = self.consumeInput() ?? 0
                if c == 41 { break }
            }
        case ".\"":
            _ = self.parseToWordBuffer(using: 34)
        default:
            break
        }
    }

    /// After [THEN]/[ELSE] ends a skip inside a $" / S" string: run one tail token (Hayes `4`),
    /// then discard the rest of the string through its closing quote (so PT10/REFILL never runs).
    private func finishConditionalSkipInStringTail(_ result: ConditionalSkipResult) -> ConditionalSkipResult {
        self.syncInputQueueFromSourceIfNeeded()
        if !self.inputQueue.isEmpty && self.readCell(self.STATE) == 0 && self.bracketCompileDepth == 0 {
            let name = self.parseWord()
            if !name.isEmpty {
                let b = Int(max(2, min(36, self.readCell(self.BASE))))
                if let num = self.parseTextNumber(name, base: b) {
                    self.push(num)
                }
            }
        }
        if !self.discardThroughClosingQuoteIfPresent() {
            self.conditionalSkipDiscardThroughQuote = true
        }
        return result
    }

    /// Scan a double-quote string during conditional skip; recognise [IF]/[ELSE]/[THEN] words.
    private func pumpConditionalSkipInString() -> ConditionalSkipResult? {
        while !self.inputQueue.isEmpty && !self.errorFlag && !self.throwActive {
            while let b = self.inputQueue.first, b <= 32 {
                _ = self.consumeInput()
            }
            if self.inputQueue.isEmpty { return nil }
            if self.inputQueue.first == 34 {
                _ = self.consumeInput()
                return nil
            }
            let word = self.parseWord()
            if word.isEmpty { return nil }
            let w = word.uppercased()
            if w == "[IF]" {
                self.conditionalSkipDepth += 1
            } else if w == "[THEN]" {
                self.conditionalSkipDepth -= 1
                if self.conditionalSkipDepth == 0 {
                    return self.finishConditionalSkipInStringTail(.then)
                }
            } else if w == "[ELSE]" && self.conditionalSkipDepth == 1 && self.conditionalSkipStopAtElse {
                self.conditionalSkipDepth = 0
                return self.finishConditionalSkipInStringTail(.elseBranch)
            }
        }
        return nil
    }

    /// Advance a conditional text scan as far as the current input allows.
    private func pumpConditionalSkip() -> ConditionalSkipResult {
        while self.conditionalSkipDepth > 0 && !self.errorFlag && !self.throwActive {
            self.syncInputQueueFromSourceIfNeeded()
            if self.inputQueue.isEmpty {
                return .pending
            }
            let word = self.parseWord()
            if word.isEmpty {
                return .pending
            }
            if word == "S\"" || word == "$\"" || word == "C\"" || word == "S\\\"" {
                while let b = self.inputQueue.first, b <= 32 {
                    _ = self.consumeInput()
                }
                if self.inputQueue.first == 34 {
                    _ = self.consumeInput()
                    if let r = self.pumpConditionalSkipInString() { return r }
                }
                continue
            }
            self.discardParsedWordDuringConditionalSkip(word)
            let w = word.uppercased()
            if w == "[IF]" {
                self.conditionalSkipDepth += 1
            } else if w == "[THEN]" {
                self.conditionalSkipDepth -= 1
                if self.conditionalSkipDepth == 0 {
                    if self.hasClosingQuoteAhead() {
                        return self.finishConditionalSkipInStringTail(.then)
                    }
                    return .then
                }
            } else if w == "[ELSE]" && self.conditionalSkipDepth == 1 && self.conditionalSkipStopAtElse {
                self.conditionalSkipDepth = 0
                if self.hasClosingQuoteAhead() {
                    return self.finishConditionalSkipInStringTail(.elseBranch)
                }
                return .elseBranch
            }
        }
        if self.conditionalSkipDepth > 0 { return .pending }
        return .then
    }

    /// Hayes FP harness (`ttester.fs`, `fpio-test.4th`): `BASE @` at file start, `BASE !` at end.
    /// `ENVIRONMENT? FLOATING-STACK` can leave 16 on the stack so `BASE !` stores 16; restore when
    /// the saved decimal base remains and BASE was corrupted to the F stack depth.
    private func applyHayesBaseRestoreIfPending() {
        guard self.spGet() == 2 else { return }
        let saved = self.readCell(self.stackBase)
        guard saved >= 2 && saved <= 36 else { return }
        let current = self.readCell(self.BASE)
        if current == saved {
            self.spSet(1)
            return
        }
        guard current == Cell(self.FSTACK_SIZE) else { return }
        self.writeCell(self.BASE, saved)
        self.spSet(1)
    }

    /// Interpret-time `[IF]` flag: nested Hayes/Gforth idiom (`ENVIRONMENT? [IF] [IF] TRUE …`)
    /// can place a preserved value (e.g. `BASE @`) under an inner `[IF]`; do not consume it.
    /// `ENVIRONMENT?` may leave extra cells (e.g. `FLOATING-STACK` depth 16) above the saved value;
    /// the inner `[IF]` must pop those extras instead of leaving them for trailing `BASE !`.
    private func popInterpretIfFlag() -> Cell {
        if self.interpretIfTrueDepth > 0 {
            let s = self.spGet()
            guard s >= 1 else { return self.pop() }
            let top = self.readCell(self.stackBase + Int(s - 1) * 8)
            if top == 0 || top == -1 {
                return self.pop()
            }
            if s == 1 {
                return -1
            }
            let under = self.readCell(self.stackBase + Int(s - 2) * 8)
            if under != 0 && under != -1 {
                _ = self.pop()
                return top != 0 ? -1 : 0
            }
        }
        return self.pop()
    }

    /// Start (or restart) skipping until `[THEN]` or, when allowed, `[ELSE]`.
    private func startConditionalSkip(stopAtElse: Bool) -> ConditionalSkipResult {
        self.conditionalSkipDepth = 1
        self.conditionalSkipStopAtElse = stopAtElse
        return self.pumpConditionalSkip()
    }

    /// Continue a pending multi-line conditional skip on the next source line.
    private func continuePendingConditionalSkip() -> ConditionalSkipResult {
        guard self.conditionalSkipDepth > 0 else { return .then }
        return self.pumpConditionalSkip()
    }

    /// True when unparsed input still contains a closing `"` (Hayes toolstest $" / [THEN] tail).
    private func hasClosingQuoteAhead() -> Bool {
        self.syncInputQueueFromSourceIfNeeded()
        return self.inputQueue.contains(34)
    }

    /// Discard characters through a closing `"` on the current input (may span feedLine/FLOAD lines).
    /// Returns true once the closing quote has been consumed.
    private func discardThroughClosingQuoteIfPresent() -> Bool {
        while !self.inputQueue.isEmpty {
            let b = self.inputQueue.first!
            if b == 34 {
                _ = self.consumeInput()
                return true
            }
            _ = self.consumeInput()
        }
        return false
    }

    private static let environmentQueryCatalog: [String] = [
        "CORE",
        "CORE-EXT",
        "/COUNTED-STRING",
        "ADDRESS-UNIT-BITS",
        "MAX-CHAR",
        "SEARCH-ORDER",
        "WORDLISTS",
        "EXCEPTION",
        "FILE",
        "FILE-ACCESS",
        "FILE-EXT",
        "STRING",
        "MEMORY-ALLOCATION",
        "DOUBLE",
        "LOCALS",
        "#LOCALS",
        "PROGRAMMING-TOOLS",
        "FACILITY",
        "BLOCK",
        "/BLOCK",
        "BLOCK-EXT",
        "EXTENDED-CHARACTER",
        "XCHAR-ENCODING",
        "MAX-XCHAR",
        "XCHAR-MAXMEM",
        "FLOATING",
        "FLOAT-EXT",
        "FLOATING-STACK",
        "MAX-FLOAT",
    ]

    /// ANS ENVIRONMENT? values for a query string, or nil if unsupported.
    private func environmentQueryValues(for query: String) -> [Cell]? {
        switch query.uppercased() {
        case "CORE", "CORE-EXT", "SEARCH-ORDER":
            return [-1]
        case "/COUNTED-STRING", "COUNTED-STRING":
            return [255, -1]
        case "ADDRESS-UNIT-BITS":
            return [8, -1]
        case "MAX-CHAR":
            return [255, -1]
        case "WORDLISTS":
            return [Cell(MAX_VOCABS), -1]
        case "FILE", "FILE-ACCESS", "FILE-EXT", "EXCEPTION", "STRING", "MEMORY-ALLOCATION", "DOUBLE", "LOCALS", "PROGRAMMING-TOOLS", "FACILITY", "BLOCK", "BLOCK-EXT", "EXTENDED-CHARACTER", "FLOATING", "FLOAT-EXT":
            return [-1]
        case "FLOATING-STACK":
            return [Cell(self.FSTACK_SIZE), -1]
        case "MAX-FLOAT":
            let maxBits = Cell(bitPattern: UInt(truncatingIfNeeded: Double.greatestFiniteMagnitude.bitPattern))
            return [maxBits, -1]
        case "XCHAR-ENCODING":
            if self.xcharEncodingAddr != 0 {
                return [Cell(self.xcharEncodingAddr), 5, -1]
            }
            return nil
        case "MAX-XCHAR":
            return [Cell(Self.maxXchar), -1]
        case "XCHAR-MAXMEM":
            return [4, -1]
        case "/BLOCK":
            if self.blockSizeVarAddr != 0 {
                return [self.readCell(self.blockSizeVarAddr), -1]
            }
            return [Cell(self.settings.blockSize), -1]
        case "#LOCALS":
            return [Cell(Self.MAX_LOCALS_PER_DEF), -1]
        default:
            return nil
        }
    }

    /// ANS COMPARE on primitive characters (bytes).
    private func compareCharacterStrings(caddr1: Int, u1: Int, caddr2: Int, u2: Int) -> Cell {
        let minLen = min(u1, u2)
        for i in 0..<minLen {
            let b1 = self.readByte(caddr1 + i)
            let b2 = self.readByte(caddr2 + i)
            if b1 != b2 {
                return b1 < b2 ? -1 : 1
            }
        }
        if u1 == u2 { return 0 }
        return u1 < u2 ? -1 : 1
    }

    private func normalizeSubstitutionName(_ name: String) -> String {
        name.lowercased()
    }

    private func substitutionNameFromMemory(caddr: Int, u: Int) -> String? {
        if u <= 0 { return "" }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(u)
        for i in 0..<u {
            let b = self.readByte(caddr + i)
            if b == 37 { return nil } // '%' in substitution name is ambiguous
            bytes.append(b)
        }
        let raw = String(bytes: bytes, encoding: .utf8)
            ?? String(bytes: bytes, encoding: .ascii)
            ?? ""
        return self.normalizeSubstitutionName(raw)
    }

    private func lookupSubstitutionText(name: String) -> [UInt8]? {
        self.textSubstitutions[self.normalizeSubstitutionName(name)]
    }

    /// ANS CMOVE — copy u chars from c-addr1 to c-addr2, low to high (with overlap propagation).
    private func cmoveAns(caddr1: Int, caddr2: Int, u: Int) {
        if u <= 0 { return }
        let src = caddr1
        let dst = caddr2
        if dst >= src && dst < src + u {
            let offset = dst - src
            var remaining = u
            var from = src
            var to = dst
            while remaining > 0 {
                let chunk = min(remaining, offset)
                for i in 0..<chunk {
                    self.writeByte(to + i, self.readByte(from + i))
                }
                remaining -= chunk
                from += chunk
                to += chunk
            }
            return
        }
        if dst < src {
            for i in 0..<u { self.writeByte(dst + i, self.readByte(src + i)) }
        } else {
            for i in (0..<u).reversed() { self.writeByte(dst + i, self.readByte(src + i)) }
        }
    }

    /// ANS CMOVE> — copy u chars from c-addr1 to c-addr2, high to low.
    private func cmoveFromHighAns(caddr1: Int, caddr2: Int, u: Int) {
        if u <= 0 { return }
        for i in (0..<u).reversed() {
            self.writeByte(caddr2 + i, self.readByte(caddr1 + i))
        }
    }

    /// ANS SUBSTITUTE — left-to-right, non-recursive %name% expansion.
    private func substituteText(srcCaddr: Int, srcLen: Int, destCaddr: Int, destCap: Int) -> (u3: Int, n: Cell)? {
        if srcCaddr == destCaddr { return nil }
        let overlaps = srcLen > 0 && destCap > 0 && srcCaddr < destCaddr + destCap && destCaddr < srcCaddr + srcLen
        let workDest: Int
        let workCap: Int
        if overlaps {
            workCap = max(srcLen, destCap) * 2 + 64
            let alloc = self.heapAllocateBytes(workCap)
            if alloc.ior != 0 || alloc.addr == 0 { return nil }
            workDest = alloc.addr
        } else {
            workDest = destCaddr
            workCap = destCap
        }
        var out = 0
        var subs = 0
        var pos = 0
        let pct: UInt8 = 37
        while pos < srcLen {
            let ch = self.readByte(srcCaddr + pos)
            if ch != pct {
                if out >= workCap { return nil }
                self.writeByte(workDest + out, ch)
                out += 1
                pos += 1
                continue
            }
            if pos + 1 >= srcLen {
                if out >= workCap { return nil }
                self.writeByte(workDest + out, pct)
                out += 1
                pos += 1
                continue
            }
            let next = self.readByte(srcCaddr + pos + 1)
            if next == pct {
                if out >= workCap { return nil }
                self.writeByte(workDest + out, pct)
                out += 1
                pos += 2
                continue
            }
            var end = pos + 1
            while end < srcLen && self.readByte(srcCaddr + end) != pct {
                end += 1
            }
            if end >= srcLen {
                let tailLen = srcLen - pos
                if out + tailLen > workCap { return nil }
                for i in 0..<tailLen {
                    self.writeByte(workDest + out + i, self.readByte(srcCaddr + pos + i))
                }
                out += tailLen
                break
            }
            let nameLen = end - (pos + 1)
            if nameLen == 0 {
                if out >= workCap { return nil }
                self.writeByte(workDest + out, pct)
                out += 1
                pos += 2
                continue
            }
            if let name = self.substitutionNameFromMemory(caddr: srcCaddr + pos + 1, u: nameLen),
               let repl = self.lookupSubstitutionText(name: name) {
                if out + repl.count > workCap { return nil }
                for (i, b) in repl.enumerated() {
                    self.writeByte(workDest + out + i, b)
                }
                out += repl.count
                subs += 1
                pos = end + 1
            } else {
                let span = end + 1 - pos
                if out + span > workCap { return nil }
                for i in 0..<span {
                    self.writeByte(workDest + out + i, self.readByte(srcCaddr + pos + i))
                }
                out += span
                pos = end + 1
            }
        }
        if overlaps {
            if out > destCap {
                _ = self.heapFreeBytes(workDest)
                return nil
            }
            for i in 0..<out {
                self.writeByte(destCaddr + i, self.readByte(workDest + i))
            }
            _ = self.heapFreeBytes(workDest)
        } else if out > destCap {
            return nil
        }
        return (out, Cell(subs))
    }

    /// ANS UNESCAPE — copy src to dest, doubling each % character.
    private func unescapeText(srcCaddr: Int, srcLen: Int, destCaddr: Int) -> Int? {
        var out = 0
        let pct: UInt8 = 37
        for i in 0..<srcLen {
            let ch = self.readByte(srcCaddr + i)
            if ch == pct {
                self.writeByte(destCaddr + out, pct)
                out += 1
            }
            self.writeByte(destCaddr + out, ch)
            out += 1
        }
        return out
    }

    /// ANS SEARCH — first occurrence; empty needle matches at start.
    private func searchCharacterStrings(hayCaddr: Int, hayLen: Int, needleCaddr: Int, needleLen: Int) -> (caddr: Int, u: Int, found: Bool) {
        if needleLen == 0 {
            return (hayCaddr, hayLen, true)
        }
        if hayLen < needleLen {
            return (hayCaddr, hayLen, false)
        }
        let maxStart = hayLen - needleLen
        for pos in 0...maxStart {
            if self.compareCharacterStrings(caddr1: hayCaddr + pos, u1: needleLen, caddr2: needleCaddr, u2: needleLen) == 0 {
                return (hayCaddr + pos, hayLen - pos, true)
            }
        }
        return (hayCaddr, hayLen, false)
    }

    private func alignAddressUnits(_ n: Int) -> Int {
        (n + self.CELL_SIZE - 1) & ~(self.CELL_SIZE - 1)
    }

    func repositionPnoAndHeap() {
        let blockSize = self.effectiveBlockSize()
        let bufferCount = self.effectiveBlockBufferCount()
        let blockPoolBytes = blockSize * bufferCount
        self.pnoBufferAddr = self.memory.count - self.PNO_BUFFER_SIZE
        self.blockPoolBase = self.pnoBufferAddr - blockPoolBytes
        if self.blockPoolBase < self.stackBase {
            self.blockPoolBase = self.stackBase
        }
        self.pnoPtr = self.pnoBufferAddr + self.PNO_BUFFER_SIZE
        self.heapBump = self.blockPoolBase
        self.resizeBlockBufferSlots()
    }

    private func heapFloorAddress() -> Int {
        Int(self.readCell(self.DP_ADDR))
    }

    private func resetHeapState(clearAllocateFlag: Bool) {
        self.usedHeapBlocks.removeAll(keepingCapacity: true)
        self.freeHeapBlocks.removeAll(keepingCapacity: true)
        self.heapBump = self.pnoBufferAddr
        if clearAllocateFlag {
            self.allocateEverUsed = false
        }
    }

    private func memoryAllocationFailed(_ message: String) {
        let trimmed = message.hasSuffix("\n") ? String(message.dropLast()) : message
        self.throwIllegalArgument(trimmed)
    }

    @discardableResult
    private func growMemoryToMegabytes(_ mb: Int) -> Bool {
        if self.growMemoryAttempted {
            self.memoryAllocationFailed("? GROWMEMORYMB already used (once per session)\n")
            return false
        }
        self.growMemoryAttempted = true

        if self.allocateEverUsed {
            self.memoryAllocationFailed("? GROWMEMORYMB not allowed after ALLOCATE\n")
            return false
        }
        if mb < 1 {
            self.memoryAllocationFailed("? GROWMEMORYMB needs at least 1 MB\n")
            return false
        }

        let newSize = mb * 1024 * 1024
        if newSize <= self.memory.count {
            self.memoryAllocationFailed("? GROWMEMORYMB cannot shrink memory\n")
            return false
        }
        if newSize > Self.MAX_MEMORY_BYTES {
            self.memoryAllocationFailed("? GROWMEMORYMB exceeds maximum (\(Self.MAX_MEMORY_BYTES / (1024 * 1024)) MB)\n")
            return false
        }

        self.memory.append(contentsOf: repeatElement(0, count: newSize - self.memory.count))
        self.repositionPnoAndHeap()
        return true
    }

    private func heapAllocateBytes(_ requested: Int) -> (addr: Int, ior: Cell) {
        if requested < 0 {
            return (0, self.FILE_IO_ERROR)
        }
        let userSize = self.alignAddressUnits(requested)
        if userSize == 0 && requested > 0 {
            return (0, self.FILE_IO_ERROR)
        }

        if let idx = self.freeHeapBlocks.firstIndex(where: { $0.size >= userSize }) {
            let block = self.freeHeapBlocks.remove(at: idx)
            self.usedHeapBlocks[block.addr] = userSize
            if block.size > userSize {
                self.freeHeapBlocks.append((block.addr + userSize, block.size - userSize))
            }
            return (block.addr, self.FILE_IO_SUCCESS)
        }

        let total = Self.HEAP_HEADER_BYTES + userSize
        let blockSize = self.alignAddressUnits(total)
        let newBump = self.heapBump - blockSize
        if newBump < self.heapFloorAddress() {
            return (0, self.FILE_IO_ERROR)
        }
        self.heapBump = newBump
        self.writeCell(newBump, Cell(userSize))
        let userAddr = newBump + Self.HEAP_HEADER_BYTES
        self.usedHeapBlocks[userAddr] = userSize
        return (userAddr, self.FILE_IO_SUCCESS)
    }

    private func heapFreeBytes(_ userAddr: Int) -> Cell {
        guard let size = self.usedHeapBlocks.removeValue(forKey: userAddr) else {
            return self.FILE_IO_ERROR
        }
        let header = userAddr - Self.HEAP_HEADER_BYTES
        if header < 0 || self.readCell(header) != Cell(size) {
            return self.FILE_IO_ERROR
        }
        self.freeHeapBlocks.append((userAddr, size))
        return self.FILE_IO_SUCCESS
    }

    private func heapResizeBytes(_ userAddr: Int, newRequested: Int) -> (addr: Int, ior: Cell) {
        guard let oldSize = self.usedHeapBlocks[userAddr] else {
            return (userAddr, self.FILE_IO_ERROR)
        }
        if newRequested < 0 {
            return (userAddr, self.FILE_IO_ERROR)
        }
        let newSize = self.alignAddressUnits(newRequested)
        if newSize == oldSize {
            return (userAddr, self.FILE_IO_SUCCESS)
        }
        if newSize < oldSize {
            self.usedHeapBlocks[userAddr] = newSize
            self.writeCell(userAddr - Self.HEAP_HEADER_BYTES, Cell(newSize))
            let tail = userAddr + newSize
            let tailSize = oldSize - newSize
            if tailSize > 0 {
                self.freeHeapBlocks.append((tail, tailSize))
            }
            return (userAddr, self.FILE_IO_SUCCESS)
        }
        let grown = self.heapAllocateBytes(newSize)
        if grown.ior != self.FILE_IO_SUCCESS {
            return (userAddr, self.FILE_IO_ERROR)
        }
        let copyLen = min(oldSize, newSize)
        for i in 0..<copyLen {
            self.writeByte(grown.addr + i, self.readByte(userAddr + i))
        }
        _ = self.heapFreeBytes(userAddr)
        return (grown.addr, self.FILE_IO_SUCCESS)
    }

    private func displayEnvironmentCatalog() {
        self.tell("Environment:\n")
        for name in Self.environmentQueryCatalog {
            guard let values = self.environmentQueryValues(for: name) else { continue }
            if values == [-1] {
                self.tell("  \(name)\n")
            } else {
                let parts = values.dropLast().map { String($0) }.joined(separator: " ")
                self.tell("  \(name) \(parts)\n")
            }
        }
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
    /// for the purposes of S" C" . " ABORT" etc. string delimiters and word names like S".
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
        return addr >= 0 && addr < memory.count
    }

    internal func getCFA(_ headerAddr: Cell) -> Cell {  // TZForthBlock.swift
        let flagsLen = readByte(Int(headerAddr) + 8)
        var len = Int(flagsLen & MASK_NAMELENGTH) + 1  // +1 for the flags/len byte itself
        while (len & 7) != 0 { len += 1 }
        return headerAddr + Cell(8 + len)
    }

    // MARK: - Primitive registration

    func register(_ name: String, immediate: Bool = false, _ body: @escaping () -> Void) -> Cell {
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

    /// Register a primitive into a specific word list (e.g. ASSEMBLER vocab RET).
    internal func installVocabPrimitive(_ name: String, wordlist wid: Cell, immediate: Bool = false, _ body: @escaping () -> Void) -> Cell {
        let savedCurrent = self.readCell(self.CURRENT)
        self.writeCell(self.CURRENT, wid)
        let id = Cell(self.primitives.count)
        self.primitives.append(body)
        self.primitiveNames[id] = name.uppercased()
        self.createWord(name: name, immediate: immediate)
        self.writeCellHere(id)
        self.writeCellHere(self.exitID)
        self.writeCell(self.CURRENT, savedCurrent)
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

        // EXIT (also releases innermost locals frame when present)
        exitID = Cell(primitives.count)
        primitives.append {
            self.endLocalFrame()
            self.ip = self.rpop()
        }

        // CODE entry marker (first cell at CFA of CODE definitions; body at cfa+8).
        self.codeEntryID = Cell(primitives.count)
        primitives.append {
            self.ip = Int(self.currentCodeAddr) + 8
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

        // Runtime for C" : leave c-addr of the inlined counted string (length byte at c-addr).
        cQuoteID = register("(C\\\")") {
            let strAddr = self.ip
            let len = Int(self.readByte(strAddr))
            self.push(Cell(strAddr))
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
                self.lastAbortQuoteText = String(bytes: (0..<len).map { self.readByte(strAddr + 1 + $0) }, encoding: .utf8) ?? ""
                self.deliverThrow(-2)
                if self.throwActive { return }
            }
            var newIP = self.ip + 1 + len
            while (newIP & 7) != 0 { newIP += 1 }
            self.ip = newIP
        }

        // Now safe to define the rest
        _ = register("EXIT") {
            self.endLocalFrame()
            self.ip = self.rpop()
        }

        dupID = register("DUP")   { let v = self.pop(); self.push(v); self.push(v) }
        dropID = register("DROP")  { _ = self.pop() }
        swapID = register("SWAP")  { let b = self.pop(); let a = self.pop(); self.push(b); self.push(a) }
        _ = register("OVER")  { let b = self.pop(); let a = self.pop(); self.push(a); self.push(b); self.push(a) }

        plusID = register("+")     { let b = self.pop(); let a = self.pop(); self.push(self.cellAdd(a, b)) }
        _ = register("-")     { let b = self.pop(); let a = self.pop(); self.push(self.cellSub(a, b)) }
        _ = register("*")     { let b = self.pop(); let a = self.pop(); self.push(self.cellMul(a, b)) }
        _ = register("/MOD")  {
            let b = self.pop(); let a = self.pop()
            if b == 0 {
                self.throwDivisionByZero()
                return
            }
            self.push(a % b); self.push(a / b)
        }
        _ = register("/")     {
            let b = self.pop(); let a = self.pop()
            if self.throwActive { return }
            if b == 0 { self.throwDivisionByZero(); return }
            self.push(a / b)
        }
        _ = register("*/MOD") {
            let n3 = self.pop(); let n2 = self.pop(); let n1 = self.pop()
            if self.throwActive { return }
            if n3 == 0 { self.throwDivisionByZero(); return }
            let prod = Int128(n1) * Int128(n2)
            let divisor = Int128(n3)
            self.push(self.cellFromInt128(prod % divisor))
            self.push(self.cellFromInt128(prod / divisor))
        }
        _ = register("*/") {
            let n3 = self.pop(); let n2 = self.pop(); let n1 = self.pop()
            if self.throwActive { return }
            if n3 == 0 { self.throwDivisionByZero(); return }
            let prod = Int128(n1) * Int128(n2)
            self.push(self.cellFromInt128(prod / Int128(n3)))
        }
        _ = register("2*") { let a = self.pop(); self.push(a << 1) }
        _ = register("2/") { let a = self.pop(); self.push(a >> 1) }
        _ = register("M*") {
            let b = self.pop(); let a = self.pop()
            self.pushSignedDouble(Int128(a) * Int128(b))
        }
        _ = register("FM/MOD") {
            let n = self.pop()
            let (dLo, dHi) = self.popDoubleStack()
            let d = self.assembleSignedDouble(lo: dLo, hi: dHi)
            if n == 0 { self.throwDivisionByZero(); return }
            let divisor = Int128(n)
            var quot = d / divisor
            var rem = d % divisor
            if rem != 0 && ((d < 0) != (divisor < 0)) {
                quot -= 1
                rem += divisor
            }
            self.push(self.cellFromInt128(rem))
            self.push(self.cellFromInt128(quot))
        }
        _ = register("SM/REM") {
            let n = self.pop()
            let (dLo, dHi) = self.popDoubleStack()
            let d = self.assembleSignedDouble(lo: dLo, hi: dHi)
            if n == 0 { self.throwDivisionByZero(); return }
            let divisor = Int128(n)
            self.push(self.cellFromInt128(d % divisor))
            self.push(self.cellFromInt128(d / divisor))
        }
        _ = register("U<") { let b = self.pop(); let a = self.pop(); let ua = self.unsignedCell(a); let ub = self.unsignedCell(b); self.push( ua < ub ? -1 : 0 ) }
        _ = register("U>") { let b = self.pop(); let a = self.pop(); let ua = self.unsignedCell(a); let ub = self.unsignedCell(b); self.push( ua > ub ? -1 : 0 ) }
        _ = register("UM*") {
            let b = self.pop(); let a = self.pop()
            self.pushUnsignedDouble(UInt128(self.unsignedCell(a)) * UInt128(self.unsignedCell(b)))
        }
        _ = register("UM/MOD") {
            let u = self.pop()
            let (dLo, dHi) = self.popDoubleStack()
            let d = self.assembleUnsignedDouble(lo: dLo, hi: dHi)
            if u == 0 { self.throwDivisionByZero(); return }
            let divisor = UInt128(self.unsignedCell(u))
            let quot = d / divisor
            let rem = d % divisor
            self.push(self.cellFromUInt128(rem))
            self.push(self.cellFromUInt128(quot))
        }
        _ = register("+!") {
            let addr = Int(self.pop()); let n = self.pop()
            let old = self.readCell(addr)
            let newVal = self.cellAdd(old, n)
            if addr == self.IN {
                self.writeInOffset(newVal)
                self.notifyInChanged(storedValue: self.readCell(self.IN), previousValue: old, isStore: false)
            } else {
                self.writeCell(addr, newVal)
            }
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

        self.storeID = register("!") {
            let addr = Int(self.pop())
            let val = self.pop()
            if self.throwActive { return }
            if addr == self.IN {
                let oldIn = self.readCell(self.IN)
                if val == 0 && self.returnStackPointer > 1 {
                    self.inVarZeroedInColon = true
                    self.inVarZeroFetchAfterZero = false
                }
                self.writeInOffset(val)
                if self.throwActive { return }
                self.notifyInChanged(storedValue: self.readCell(self.IN), previousValue: oldIn, isStore: true)
            } else {
                self.writeCell(addr, val)
            }
            if self.throwActive { return }
        }
        fetchID = register("@")     {
            let addr = Int(self.pop())
            if self.throwActive { return }
            if addr == self.IN && self.inVarZeroedInColon {
                self.inVarZeroFetchAfterZero = true
            }
            let val = self.readCell(addr)
            if self.throwActive { return }
            self.push(val)
        }
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
        _ = register("CURRENT") { self.push( Cell( self.CURRENT ) ) }

        // === ANS Forth 2012 Search-Order word set (Section 16) ===

        _ = register("WORDLIST") {
            self.alignHere()
            let head = self.readCell(self.DP_ADDR)
            self.writeCellHere(0)
            self.alignHere()
            self.push(head)
        }

        _ = register("FORTH-WORDLIST") {
            self.push(Cell(self.LATEST))
        }

        _ = register("GET-ORDER") {
            for wl in self.searchOrder.reversed() {
                self.push(wl)
            }
            self.push(Cell(self.searchOrder.count))
        }

        _ = register("SET-ORDER") {
            let n = Int(self.pop())
            // Hayes searchordertest: -1 SET-ORDER is equivalent to ONLY.
            if n == -1 {
                self.searchOrder = [self.LATEST]
                return
            }
            if n < 0 || n > self.MAX_VOCABS {
                self.kernelThrow(StdThrow.illegalArgument, message: "? Invalid search order count")
                return
            }
            // GET-ORDER leaves ( widn .. wid1 n ) with wid1 just below n (first searched).
            var order: [Cell] = []
            for _ in 0..<n {
                order.append(self.pop())
            }
            self.searchOrder = order
        }

        // Internal: prepend a word list to the search order (used by VOCABULARY DOES>).
        _ = register("PUSH-ORDER") {
            if self.searchOrder.count >= self.MAX_VOCABS {
                self.kernelThrow(StdThrow.illegalArgument, message: "? Search order full")
                return
            }
            let wid = self.pop()
            self.searchOrder.insert(wid, at: 0)
        }

        _ = register("GET-CURRENT") {
            self.push(self.readCell(self.CURRENT))
        }

        _ = register("SET-CURRENT") {
            let wid = self.pop()
            self.writeCell(self.CURRENT, wid)
        }

        _ = register("SEARCH-WORDLIST") {
            let wid = self.pop()
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            var start = 0
            var end = u
            while start < end {
                let b = self.readByte(caddr + start)
                if b > 32 { break }
                start += 1
            }
            while end > start {
                let b = self.readByte(caddr + end - 1)
                if b > 32 { break }
                end -= 1
            }
            var nameBytes: [UInt8] = []
            for i in start..<end {
                nameBytes.append(self.readByte(caddr + i))
            }
            let name = String(bytes: nameBytes, encoding: .utf8) ?? ""
            let hdr = self.findWordInWordlist(wid, name: name)
            if hdr == 0 {
                self.push(0)
                return
            }
            let (xt, flag) = self.xtAndFindFlag(fromHeader: hdr)
            self.push(xt)
            self.push(flag)
        }

        _ = register("DEFINITIONS") {
            if self.searchOrder.isEmpty {
                self.searchOrder = [self.LATEST]
            }
            self.writeCell(self.CURRENT, self.searchOrder[0])
        }

        _ = register("ONLY") {
            self.searchOrder = [self.LATEST]
        }

        _ = register("FORTH") {
            if self.searchOrder.isEmpty {
                self.searchOrder = [self.LATEST]
            } else {
                self.searchOrder[0] = self.LATEST
            }
        }

        _ = register("ALSO") {
            if self.searchOrder.count >= self.MAX_VOCABS {
                self.kernelThrow(StdThrow.illegalArgument, message: "? Search order full")
                return
            }
            if self.searchOrder.isEmpty {
                self.searchOrder.append(self.LATEST)
            }
            let top = self.searchOrder[0]
            self.searchOrder.insert(top, at: 0)
        }

        _ = register("PREVIOUS") {
            if self.searchOrder.isEmpty {
                self.kernelThrow(StdThrow.illegalArgument, message: "? Search order empty")
                return
            }
            self.searchOrder.removeFirst()
        }

        _ = register("ORDER") {
            self.validateAndRepairSystemState()
            self.tell("Search order: ")
            for wlID in self.searchOrder {
                let nm = self.nameForWordlist(wlID)
                self.tell(nm + " ")
            }
            self.tell("\nCompilation wordlist: ")
            let cur = self.readCell(self.CURRENT)
            let cnm = self.nameForWordlist(cur)
            self.tell(cnm + "\n")
        }

        // >HEADER ( cfa -- header )  Given a code field address, return the
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

        // >XID ( cfa -- xid | 0 )  kernel primitive dispatch ID stored at cfa, else 0.
        _ = register(">XID") {
            let cfa = self.pop()
            if let id = self.primitiveID(atCFA: cfa) {
                self.push(id)
            } else {
                self.push(0)
            }
        }

        _ = register("]", immediate: false) { self.writeCell(self.STATE, 1) }
        _ = register("[", immediate: true)  {
            self.bracketCompileDepth += 1
            self.writeCell(self.STATE, 0)
        }

        _ = register("IMMEDIATE") {
            let defsHeadCell = self.readCell(self.CURRENT)
            let l = self.readCell(defsHeadCell)
            if l == 0 { self.throwIllegalArgument("? No latest word"); return }
            let fl = self.readByte( Int(l) + 8 )
            self.writeByte( Int(l) + 8 , fl | self.FLAG_IMMEDIATE )
        }

        _ = register("LITERAL", immediate: true) {
            if self.readCell(self.STATE) == 0 { self.kernelThrow(StdThrow.compileOnly, message: "? LITERAL only while compiling"); return }
            let n = self.pop()
            self.push(self.litID); self.comma()
            self.push(n); self.comma()
        }

        _ = register("[CHAR]", immediate: true) {
            if self.readCell(self.STATE) == 0 { self.throwCompileOnly("? [CHAR] only while compiling"); return }
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? [CHAR] needs char"); return }
            let c = Cell( name.utf8.first ?? 0 )
            self.push(self.litID); self.comma()
            self.push(c); self.comma()
        }

        _ = register("[']", immediate: true) {
            if self.readCell(self.STATE) == 0 { self.kernelThrow(StdThrow.compileOnly, message: "? ['] only while compiling"); return }
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? ['] needs name"); return }
            let hdr = self.findWord(name)
            if hdr == 0 { self.kernelThrow(StdThrow.undefinedWord, message: "? ['] ? " + name); return }
            let cfa = self.getCFA(hdr)
            self.push(self.litID); self.comma()
            self.push(cfa); self.comma()
        }

        // [COMPILE] name  (immediate)  Force compilation of the next word's reference even if
        // the word is immediate. (Older form; POSTPONE is preferred in ANS.)
        _ = register("[COMPILE]", immediate: true) {
            if self.readCell(self.STATE) == 0 { self.kernelThrow(StdThrow.compileOnly, message: "? [COMPILE] only while compiling"); return }
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? [COMPILE] needs name"); return }
            let hdr = self.findWord(name)
            if hdr == 0 { self.kernelThrow(StdThrow.undefinedWord, message: "? [COMPILE] ? " + name); return }
            let cfa = self.getCFA(hdr)
            // Always emit a reference (ignore the target's IMMEDIATE flag)
            self.emitCompileReference(xt: cfa)
        }

        // COMPILE, ( xt -- )  Core Ext. Compile the given xt (cfa from ') as if found while compiling.
        _ = register("COMPILE,") {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? COMPILE, only while compiling")
                return
            }
            let xt = self.pop()
            self.emitCompileReference(xt: xt)
        }

        // (COMPILE-CFA) ( xt -- )  internal — compile reference to xt (used by NAME>COMPILE stubs).
        // Internal — only reached from NAME>COMPILE stubs; always emits a compile reference.
        self.compileCfaID = register("(COMPILE-CFA)") {
            let xt = self.pop()
            self.emitCompileReference(xt: xt)
        }

        // POSTPONE name  (immediate)  Append the compilation semantics of the next word.
        // If the word is immediate, this means "compile code that will execute it later"
        // (LIT xt EXECUTE). For non-immediate, same as normal reference emission.
        // Requires executeID (captured at registration of EXECUTE).
        _ = register("POSTPONE", immediate: true) {
            if !self.isActiveCompilation() { self.kernelThrow(StdThrow.compileOnly, message: "? POSTPONE only while compiling"); return }
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? POSTPONE needs name"); return }
            let hdr = self.findWord(name)
            if hdr == 0 { self.kernelThrow(StdThrow.undefinedWord, message: "? POSTPONE ? " + name); return }
            let cfa = self.getCFA(hdr)
            let isImm = (self.readByte(Int(hdr) + 8) & self.FLAG_IMMEDIATE) != 0
            // Defer compilation semantics to run time (fixes GT4/GT5 and other POSTPONE immediates).
            self.push(self.litID); self.comma()
            self.emitCompileReference(xt: cfa)
            if isImm {
                self.push(self.postponeImmID); self.comma()
            } else {
                self.push(self.postponeCompID); self.comma()
            }
        }

        // : and ; are special because they affect STATE and compile DOCOL / EXIT
        _ = register(":") {
            // Read the next word as the name
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? : needs a name"); return }

            self.nonameCompile = false
            self.resetLocalCompileState()
            self.caseBranchStack.removeAll()
            self.controlFlowStack.removeAll()
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

        // :NONAME ( C: -- colon-sys ) ( -- xt )  Core Ext
        // Start an anonymous colon definition. At ; the xt (cfa) is left on the stack.
        _ = register(":NONAME") {
            self.nonameCompile = true
            self.resetLocalCompileState()
            self.caseBranchStack.removeAll()
            self.controlFlowStack.removeAll()
            self.createWord(name: "", immediate: false)
            self.push(self.docolID); self.comma()
            let defsHeadCell = self.readCell(self.CURRENT)
            let l = self.readCell(defsHeadCell)
            let fl = self.readByte(Int(l) + 8)
            self.writeByte(Int(l) + 8, fl | self.FLAG_HIDDEN)
            self.writeCell(self.STATE, 1)
        }

        _ = register(";", immediate: true) {
            let endHere = self.readCell(self.DP_ADDR)
            self.push(self.exitID); self.comma()

            // Implicit THEN: definitions may end with an open IF/ELSE (e.g. coreplus UNS1:
            // IF … BEGIN … REPEAT ;). False branches must land on EXIT, not past it.
            self.patchOpenControlFlowPlaceholders(branchTo: endHere)

            // Unhide (named definitions only; :NONAME stays hidden)
            let defsHeadCell = self.readCell(self.CURRENT)
            let l = self.readCell(defsHeadCell)
            let fl = self.readByte(Int(l) + 8)
            if self.nonameCompile {
                let xt = self.getCFA(l)
                self.push(xt)
                self.nonameCompile = false
            } else {
                self.writeByte(Int(l) + 8, fl & ~self.FLAG_HIDDEN)
            }

            self.writeCell(self.STATE, 0)
            self.loopControlStack.removeAll()  // clean any leftover from unbalanced loops in this def
            self.whileRepeatStack.removeAll()
            self.whileNestStack.removeAll()
            self.caseBranchStack.removeAll()
            self.controlFlowStack.removeAll()
            self.conditionalSkipDepth = 0
            self.conditionalSkipStopAtElse = false
            self.resetLocalCompileState()
        }

        // RECURSE ( -- )  immediate: compile a call to the current definition (for recursion)
        _ = register("RECURSE", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.throwCompileOnly("? RECURSE only allowed while compiling a word")
                return
            }
            let defsHeadCell = self.readCell(self.CURRENT)
            let latest = self.readCell(defsHeadCell)
            if latest == 0 {
                self.throwIllegalArgument("? RECURSE with no current definition")
                return
            }
            let cfa = self.getCFA(latest)
            self.emitCompileReference(xt: cfa)
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
                self.throwInvalidToken("? Bad branch target (ip=\(self.ip) after 0BRANCH)")
            }
        }

        branchID = register("BRANCH") {
            let offset = self.readCell(self.ip)
            self.ip += 8
            self.ip += offset
            if self.ip < 0 || self.ip + 8 > self.memory.count {
                self.throwInvalidToken("? Bad branch target (ip=\(self.ip) after BRANCH)")
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
            self.push(dataAddr)
            // Compiled CFA calls push a return address; resume the caller after pushing addr.
            if self.dispatchedFromInnerThread && self.rspGet() > 1 {
                self.ip = Int(self.rpop())
            }
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
                let stopRsp = Int(self.rspGet())
                self.rpush(0)  // sentinel so the does code's EXIT can return cleanly
                self.innerThread(stopWhenRspAtMost: stopRsp)
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
                self.throwIllegalArgument("? DOES> without a preceding CREATE")
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

        // (MARKER-RESTORE) — internal runtime for MARKER words (storage addr on stack).
        markerRestoreID = register("(MARKER-RESTORE)") {
            let storage = Int(self.pop())
            self.applyMarkerRestore(storage: storage)
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
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? BEGIN only allowed while compiling a word")
                return
            }
            let here = self.readCell(self.DP_ADDR)
            self.whileRepeatStack.append(here)
            // CS-PICK / CS-ROLL need BEGIN origins on the control-flow stack (Hayes toolstest ?REPEAT).
            // patchOpenControlFlowPlaceholders skips whileRepeatStack entries so `;` does not patch them.
            self.controlFlowStack.append(here)
        }

        _ = register("AGAIN", immediate: true) {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? AGAIN only allowed while compiling a word")
                return
            }
            guard !self.whileRepeatStack.isEmpty else {
                self.throwInvalidToken("? AGAIN without BEGIN")
                return
            }
            let dest = self.whileRepeatStack.last!
            self.push(self.branchID); self.comma()          // compile the unconditional branch token
            let here = self.readCell(self.DP_ADDR)
            let offset = dest - (here + 8)                  // offset from after the offset cell
            self.push(offset); self.comma()
        }

        _ = register("UNTIL", immediate: true) {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? UNTIL only allowed while compiling a word")
                return
            }
            guard !self.whileRepeatStack.isEmpty else {
                self.throwInvalidToken("? UNTIL without BEGIN")
                return
            }
            let dest: Cell
            if self.spGet() > 1,
               self.peekStackItem(0) == self.whileRepeatStack.last! {
                dest = self.pop()
            } else {
                dest = self.whileRepeatStack.last!
            }
            self.push(self.zeroBranchID); self.comma()
            let here = self.readCell(self.DP_ADDR)
            let offset = dest - (here + 8)
            self.push(offset); self.comma()
        }

        _ = register("WHILE", immediate: true) {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? WHILE only allowed while compiling a word")
                return
            }
            let repeatDest: Cell
            if !self.whileNestStack.isEmpty {
                repeatDest = self.whileNestStack.removeLast()
            } else if !self.whileRepeatStack.isEmpty {
                repeatDest = self.whileRepeatStack.removeLast()
            } else {
                self.throwInvalidToken("? WHILE without BEGIN")
                return
            }
            self.push(self.zeroBranchID); self.comma()
            let placeholderAddr = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.controlFlowStack.append(placeholderAddr)
            self.whileRepeatStack.append(repeatDest)
            self.whileNestStack.append(self.readCell(self.DP_ADDR))
        }

        _ = register("REPEAT", immediate: true) {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? REPEAT only allowed while compiling a word")
                return
            }
            guard !self.controlFlowStack.isEmpty else {
                self.throwInvalidToken("? REPEAT without WHILE")
                return
            }
            let origPlaceholder = self.controlFlowStack.removeLast()
            guard !self.whileRepeatStack.isEmpty else {
                self.throwInvalidToken("? REPEAT without WHILE")
                return
            }
            let repeatDest = self.whileRepeatStack.removeLast()
            if !self.whileNestStack.isEmpty {
                _ = self.whileNestStack.removeLast()
            }

            self.push(self.branchID); self.comma()
            let here = self.readCell(self.DP_ADDR)
            let backOffset = repeatDest - (here + 8)
            self.push(backOffset); self.comma()

            // WHILE/REPEAT: origPlaceholder is the 0BRANCH offset cell from WHILE.
            // BEGIN/REPEAT (unstructured): origPlaceholder equals repeatDest (loop entry);
            // do not patch the first compiled instruction with a forward offset.
            if origPlaceholder != repeatDest {
                let afterRepeat = self.readCell(self.DP_ADDR)
                let forwardOffset = afterRepeat - (origPlaceholder + 8)
                self.writeCell(Int(origPlaceholder), forwardOffset)
            }
        }

        // === Classic IF / ELSE / THEN (structured conditionals) ===
        // These use the same forward-branch placeholder technique as WHILE/REPEAT.
        // All are immediate and operate on the compile-time data stack.

        _ = register("IF", immediate: true) {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? IF only allowed while compiling a word")
                return
            }
            self.push(self.zeroBranchID); self.comma()
            let placeholderAddr = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.controlFlowStack.append(placeholderAddr)
        }

        _ = register("ELSE", immediate: true) {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? ELSE only allowed while compiling a word")
                return
            }
            guard !self.controlFlowStack.isEmpty else {
                self.throwInvalidToken("? ELSE without IF")
                return
            }
            let ifPlaceholder = self.controlFlowStack.removeLast()
            self.push(self.branchID); self.comma()
            let elsePlaceholder = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.controlFlowStack.append(elsePlaceholder)

            let afterElseBranch = self.readCell(self.DP_ADDR)
            let skipOffset = afterElseBranch - (ifPlaceholder + 8)
            self.writeCell(Int(ifPlaceholder), skipOffset)
        }

        _ = register("THEN", immediate: true) {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? THEN only allowed while compiling a word")
                return
            }
            guard !self.controlFlowStack.isEmpty else {
                self.throwInvalidToken("? THEN without IF/ELSE/AHEAD")
                return
            }
            let placeholder = self.controlFlowStack.removeLast()
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
                self.throwCompileOnly("? CASE only allowed while compiling a word")
                return
            }
            self.caseBranchStack.append(0) // sentinel for ENDCASE
        }

        _ = register("OF", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.throwCompileOnly("? OF only allowed while compiling a word")
                return
            }
            func emitRef(_ name: String) {
                let hdr = self.findWord(name)
                if hdr != 0 {
                    let cfa = self.getCFA(hdr)
                    let first = self.readCell(Int(cfa))
                    let toEmit = (first < Cell(self.MAX_BUILTIN_ID) && first != self.docolID) ? first : cfa
                    self.push(toEmit); self.comma()
                }
            }
            // Case value is compiled before OF (e.g. LIT 1 or R@ LIT 1). Compare selector (under TOS) with value (TOS).
            emitRef("OVER")
            emitRef("SWAP")
            emitRef("=")
            self.push(self.zeroBranchID); self.comma()
            let ph = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.caseBranchStack.append(ph)
            emitRef("DROP")
        }

        _ = register("ENDOF", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.throwCompileOnly("? ENDOF only allowed while compiling a word")
                return
            }
            guard let prevPh = self.caseBranchStack.popLast() else {
                self.throwInvalidToken("? ENDOF without OF")
                return
            }
            self.push(self.branchID); self.comma()
            let newPhAddr = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.caseBranchStack.append(newPhAddr)
            let here = self.readCell(self.DP_ADDR)
            let off = here - (prevPh + 8)
            self.writeCell(Int(prevPh), off)
        }

        _ = register("ENDCASE", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.throwCompileOnly("? ENDCASE only allowed while compiling a word")
                return
            }
            let hdr = self.findWord("DROP")
            if hdr != 0 {
                let cfa = self.getCFA(hdr)
                let first = self.readCell(Int(cfa))
                let toEmit = (first < Cell(self.MAX_BUILTIN_ID) && first != self.docolID) ? first : cfa
                self.push(toEmit); self.comma()
            }
            let here = self.readCell(self.DP_ADDR)
            while let x = self.caseBranchStack.popLast() {
                if x == 0 { break }
                let off = here - (x + 8)
                self.writeCell(Int(x), off)
            }
        }

        // ' (tick) — simplified non-immediate version for now
        _ = register("'") {
            // parseWord() has already normalized any curly/smart quote that the
            // user typed in place of the tick character, so the name we get here
            // for the *target* of tick is clean (or normalized if it contained quotes).
            let name = self.parseWord()
            if name.isEmpty {
                self.throwZeroLengthName("? ' needs a name")
                return
            }

            let hdr = self.findWord(name)
            if hdr == 0 {
                self.kernelThrow(StdThrow.undefinedWord, message: "? \(name) ?")
                return
            }
            let cfa = self.getCFA(hdr)
            self.push(cfa)
        }

        // EXECUTE ( xt -- )
        // xt is normally the cfa from ' / FIND; legacy primitive IDs (< MAX_BUILTIN_ID) still work.
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

        // (postpone-comp) ( xt -- )  Run-time helper for POSTPONE of a non-immediate word.
        self.postponeCompID = register("(postpone-comp)") {
            let xt = self.pop()
            if self.isActiveCompilation() {
                self.emitCompileReference(xt: xt)
            } else if xt < Cell(self.MAX_BUILTIN_ID) {
                self.execute(cfa: xt, firstCell: xt)
            } else {
                let firstCell = self.readCell(Int(xt))
                self.execute(cfa: xt, firstCell: firstCell)
            }
        }

        // (postpone-imm) ( xt -- )  Run-time helper for POSTPONE of an immediate word.
        // When the parent immediate colon word runs during compilation, execute xt's
        // compilation semantics now (e.g. POSTPONE IF inside ?DONE).
        self.postponeImmID = register("(postpone-imm)") {
            let xt = self.pop()
            if xt < Cell(self.MAX_BUILTIN_ID) {
                self.execute(cfa: xt, firstCell: xt)
            } else {
                let firstCell = self.readCell(Int(xt))
                self.execute(cfa: xt, firstCell: firstCell)
            }
        }

        // Deferred CS-PICK / CS-ROLL compiled into immediate-colon meta words (?REPEAT, ?DONE, …).
        self.deferredCsPickID = register("(deferred-cs-pick)") {
            let u = Int(self.pop())
            let idx = self.controlFlowStack.count - 1 - u
            if idx < 0 || idx >= self.controlFlowStack.count {
                self.throwIllegalArgument("? CS-PICK underflow")
                return
            }
            self.push(self.controlFlowStack[idx])
        }

        self.deferredCsRollID = register("(deferred-cs-roll)") {
            self.performCsRoll(u: Int(self.pop()))
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
            let (xt, flag) = self.xtAndFindFlag(fromHeader: hdr)
            self.push(xt)
            self.push(flag)
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
            let savedSourceId = self.currentSourceId
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
            self.evaluateNesting += 1
            self.evaluateSourceAddr = Cell(caddr)
            self.evaluateSourceLen = Cell(u)
            // Hayes/coreext expects SOURCE-ID -1 during EVALUATE of a short string (not 0).
            self.currentSourceId = -1
            if self.blockInterpretActive, self.blkVarAddr != 0 {
                self.writeCell(self.blkVarAddr, 0)
            }
            self.runInterpreter()
            self.evaluateNesting -= 1
            if self.evaluateNesting == 0 {
                self.evaluateSourceAddr = 0
                self.evaluateSourceLen = 0
            }
            // Always restore outer input/source (even on caught THROW) before propagating throwActive.
            self.inputQueue = savedQueue
            self.writeCell(self.IN, savedIN)
            self.currentSourceId = savedSourceId
            self.currentSourceLen = savedSourceLen
            for i in 0..<savedSourceLen {
                self.writeByte(self.SOURCE_BUFFER + i, savedSource[i])
            }
            if self.throwActive { return }
            // Resume the outer REPL line after the evaluated string.
            self.inputQueue.removeAll(keepingCapacity: true)
            self.realignInputQueueFromSource()
            // Propagate caught THROW to enclosing CATCH (do not convert to errorFlag).
            // Uncaught throws already set errorFlag via handleUnhandledThrow.
        }

        // CATCH ( xt -- n | i*x n )  ANS Exception — execute xt; 0 on success, throw code otherwise.
        _ = register("CATCH") {
            let xt = self.pop()
            self.performCatch(xt: xt)
        }

        // CATCH-EVALUATE ( c-addr u -- n )  TZForth — interpret-friendly CATCH around EVALUATE.
        // Use instead of ['] EVALUATE CATCH (which requires compile state for [']).
        // Equivalent interpret phrase: S" text" ' EVALUATE CATCH
        _ = register("CATCH-EVALUATE") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            let hdr = self.findWord("EVALUATE")
            if hdr == 0 {
                self.kernelThrow(StdThrow.undefinedWord, message: "? EVALUATE ?")
                return
            }
            self.push(Cell(caddr))
            self.push(Cell(u))
            self.performCatch(xt: self.getCFA(hdr))
        }

        // .ERROR ( n -- )  TZForth — display standard text for a CATCH/THROW code (0 = no output).
        // Leading/trailing spaces (no CR) so the message can be embedded inline.
        _ = register(".ERROR") {
            let n = self.pop()
            self.displayThrowMessage(n)
        }

        // THROW ( n -- )  ANS Exception — 0 is no-op; non-zero unwinds to nearest CATCH.
        _ = register("THROW") {
            let n = self.pop()
            self.deliverThrow(n)
        }

        // ABORT ( -- )  THROW -1 per Exception word set (uncaught → classic reset).
        _ = register("ABORT") {
            self.deliverThrow(-1)
        }

        // QUIT ( -- )  Empty return stack (to top level), set interpret mode, clear current input.
        // This is the classic "return to outer interpreter" word. Implemented as primitive
        // so it has no return frame of its own to corrupt when it wipes RSP.
        _ = register("QUIT") {
            self.rspSet(1)
            self.writeCell(self.STATE, 0)
            // Mark source fully consumed so post-execute realign does not rewind the line.
            self.writeCell(self.IN, Cell(self.currentSourceLen))
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
            let (udLow, udHigh) = self.popDoubleStack()
            var ud = self.assembleUnsignedDouble(lo: udLow, hi: udHigh)
            let b = max(2, min(36, self.readCell(self.BASE)))
            var i = 0
            while i < u1 {
                let ch = self.readByte(caddr1 + i)
                var d = -1
                if ch >= 48 && ch <= 57 { d = Int(ch) - 48 }
                else if ch >= 65 && ch <= 90 { d = 10 + Int(ch) - 65 }
                else if ch >= 97 && ch <= 122 { d = 10 + Int(ch) - 97 }
                if d < 0 || d >= b { break }
                ud = ud * UInt128(b) + UInt128(d)
                i += 1
            }
            let parts = self.disassembleUnsignedDouble(ud)
            self.pushDoubleStack(lo: parts.lo, hi: parts.hi)
            self.push( Cell(caddr1 + i) )
            self.push( Cell(u1 - i) )
        }

        // ( comment ) — classic and essential
        _ = register("(", immediate: true) {
            // Eat characters until ) ; when parsing from a text file, refill across lines (ANS File-Access).
            // includeFileInterpret restores the file cursor after each line so REFILL here cannot
            // desync the outer FLOAD line loop (Hayes toolstest PT8).
            while true {
                while !self.inputQueue.isEmpty {
                    let c = self.consumeInput() ?? 0
                    if c == 41 {
                        self.inParenComment = false
                        return
                    }
                }
                if let fid = self.activeInterpreterFileId(), self.refillFromFile(fid) {
                    continue
                }
                self.inParenComment = true
                return
            }
        }

        // \ comment to end of line — essential for loading typical .fth source files that use
        // line comments. Immediate so it works while compiling too.
        // Always pin >IN to end-of-line after draining the queue so syncInputQueueFromSource
        // cannot resurrect commented tokens (block lines lack LF; registerBlockWords used to
        // redefine \ and break this).
        _ = register("\\", immediate: true) {
            // `\ s` / `\ S` must stop FLOAD like \S, not comment-out the S (Hayes test.fth guard).
            if self.inputQueueLooksLikeSlashSAfterBackslash() {
                self.applySlashSStop()
                return
            }
            while !self.inputQueue.isEmpty {
                let c = self.consumeInput() ?? 0
                if c == 10 || c == 13 { break }
            }
            self.writeCell(self.IN, Cell(self.currentSourceLen))
            self.inputQueue.removeAll(keepingCapacity: true)
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

        // \S  stops further loading/interpretation of the current source file (FLOAD/INCLUDE),
        // or stops the remainder of a multi-line console submit (paste / Shift-Return block).
        // Drains rest of current line (so anything after \S on the line is ignored).
        // Immediate so it takes effect as soon as seen on a line during load.
        _ = register("\\S", immediate: true) {
            self.applySlashSStop()
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
        onePlusID = register("1+") { let a = self.pop(); self.push(self.cellAdd(a, 1)) }
        _ = register("1-") { let a = self.pop(); self.push(self.cellSub(a, 1)) }
        _ = register("ABS") { let a = self.pop(); self.push(a < 0 ? self.cellNegate(a) : a) }
        _ = register("NEGATE") { let a = self.pop(); self.push(self.cellNegate(a)) }
        _ = register("MIN") { let b = self.pop(); let a = self.pop(); self.push( a < b ? a : b ) }
        _ = register("MAX") { let b = self.pop(); let a = self.pop(); self.push( a > b ? a : b ) }
        _ = register("AND") { let b = self.pop(); let a = self.pop(); self.push( a & b ) }
        _ = register("OR") { let b = self.pop(); let a = self.pop(); self.push( a | b ) }
        _ = register("XOR") { let b = self.pop(); let a = self.pop(); self.push( a ^ b ) }
        _ = register("INVERT") { let a = self.pop(); self.push( ~a ) }
        _ = register("LSHIFT") { let sh = self.pop(); let a = self.pop(); self.push( a << sh ) }
        _ = register("RSHIFT") {
            let sh = self.pop()
            let a = self.pop()
            // ANS: logical right shift (zero-fill MSBs). Swift >> on Int is arithmetic.
            if sh < 0 || sh >= Cell.bitWidth {
                self.push(0)
            } else {
                self.push(Int(UInt(bitPattern: a) >> UInt(sh)))
            }
        }
        _ = register("ARSHIFT") { let sh = self.pop(); let a = self.pop(); self.push( a >> sh ) }

        toR_ID = register(">R") { self.rpush( self.pop() ) }
        rFrom_ID = register("R>") { self.push( self.rpop() ) }
        rAt_ID = register("R@") {
            let rs = self.rspGet()
            if rs < 2 {
                self.kernelThrow(StdThrow.returnStackUnderflow, message: "? Return stack underflow")
                return
            }
            self.push( self.readCell( self.rstackBase + (rs - 2) * 8 ) )
        }
        _ = register("2>R") { let n2 = self.pop(); let n1 = self.pop(); self.rpush(n1); self.rpush(n2) }
        _ = register("2R>") { let n2 = self.rpop(); let n1 = self.rpop(); self.push(n1); self.push(n2) }
        _ = register("2R@") {
            let rs = self.rspGet()
            if rs < 3 {
                self.kernelThrow(StdThrow.returnStackUnderflow, message: "? Return stack underflow")
                return
            }
            let n2 = self.readCell(self.rstackBase + (rs-2)*8 )
            let n1 = self.readCell(self.rstackBase + (rs-3)*8 )
            self.push(n1); self.push(n2)
        }

        _ = register("2DROP") { _ = self.pop(); _ = self.pop() }
        _ = register("2DUP")  { let b = self.pop(); let a = self.pop(); self.push(a); self.push(b); self.push(a); self.push(b) }
        _ = register("2OVER") { let d = self.pop(); let c = self.pop(); let b = self.pop(); let a = self.pop(); self.push(a); self.push(b); self.push(c); self.push(d); self.push(a); self.push(b) }
        _ = register("2SWAP") { let d = self.pop(); let c = self.pop(); let b = self.pop(); let a = self.pop(); self.push(c); self.push(d); self.push(a); self.push(b) }

        _ = register("S>D") { let n = self.pop(); self.push(n); self.push( n < 0 ? -1 : 0 ) }

        // === ANS Forth 2012 Double-Number word set (Section 8) ===

        _ = register("D+") {
            let d2 = self.popSignedDouble()
            let d1 = self.popSignedDouble()
            self.pushSignedDouble(d1 &+ d2)
        }
        _ = register("D-") {
            let d2 = self.popSignedDouble()
            let d1 = self.popSignedDouble()
            self.pushSignedDouble(d1 &- d2)
        }
        _ = register("DNEGATE") {
            self.pushSignedDouble(-self.popSignedDouble())
        }
        _ = register("DABS") {
            self.pushSignedDouble(abs(self.popSignedDouble()))
        }
        _ = register("D2*") {
            self.pushSignedDouble(self.popSignedDouble() << 1)
        }
        _ = register("D2/") {
            self.pushSignedDouble(self.popSignedDouble() >> 1)
        }
        _ = register("D<") {
            let d2 = self.popSignedDouble()
            let d1 = self.popSignedDouble()
            self.push(d1 < d2 ? -1 : 0)
        }
        _ = register("D=") {
            let d2 = self.popSignedDouble()
            let d1 = self.popSignedDouble()
            self.push(d1 == d2 ? -1 : 0)
        }
        _ = register("D0<") {
            self.push(self.popSignedDouble() < 0 ? -1 : 0)
        }
        _ = register("D0=") {
            self.push(self.popSignedDouble() == 0 ? -1 : 0)
        }
        _ = register("DU<") {
            let d2 = self.popUnsignedDouble()
            let d1 = self.popUnsignedDouble()
            self.push(d1 < d2 ? -1 : 0)
        }
        _ = register("DMIN") {
            let d2 = self.popSignedDouble()
            let d1 = self.popSignedDouble()
            self.pushSignedDouble(min(d1, d2))
        }
        _ = register("DMAX") {
            let d2 = self.popSignedDouble()
            let d1 = self.popSignedDouble()
            self.pushSignedDouble(max(d1, d2))
        }
        _ = register("D>S") {
            _ = self.pop()
            // low cell remains as single-cell n (ANS: drop most significant cell)
        }
        _ = register("D.") {
            let hi = self.pop()
            let lo = self.pop()
            let b = self.readCell(self.BASE)
            self.tell(self.formatSignedDouble(lo: lo, hi: hi, base: b))
            self.putkey(32)
        }
        _ = register("D.R") {
            let width = Int(self.pop())
            let hi = self.pop()
            let lo = self.pop()
            let b = self.readCell(self.BASE)
            var s = self.formatSignedDouble(lo: lo, hi: hi, base: b)
            if s.count < width { s = String(repeating: " ", count: width - s.count) + s }
            self.tell(s)
        }
        _ = register("M+") {
            let n = Int128(self.pop())
            let d = self.popSignedDouble()
            self.pushSignedDouble(d + n)
        }
        _ = register("M*/") {
            let u3c = self.pop()
            let u2c = self.pop()
            let (dLo, dHi) = self.popDoubleStack()
            if u3c == 0 {
                self.throwDivisionByZero()
                return
            }
            self.pushSignedDouble(self.mStarDivide(dLo: dLo, dHi: dHi, u2c: u2c, u3c: u3c))
        }
        _ = register("2ROT") {
            let f = self.pop(); let e = self.pop(); let d = self.pop()
            let c = self.pop(); let b = self.pop(); let a = self.pop()
            self.push(c); self.push(d); self.push(e); self.push(f); self.push(a); self.push(b)
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
        _ = register("NIP") { let b = self.pop(); _ = self.pop(); self.push(b) }  // ( x1 x2 -- x2 )

        self.twoFetchID = register("2@") {
            let a = Int(self.pop())
            let w2 = self.readCell(a)
            let w1 = self.readCell(a + 8)
            self.push(w1); self.push(w2)
        }
        self.twoStoreID = register("2!") {
            let a = Int(self.pop())
            let w2 = self.pop()
            let w1 = self.pop()
            self.writeCell(a, w2)
            self.writeCell(a + 8, w1)
        }

        _ = register("CELL+") { let a = self.pop(); self.push(a + 8) }
        _ = register("CELLS") { let n = self.pop(); self.push(n * 8) }
        _ = register("CHAR+") { let a = self.pop(); self.push(a + 1) }
        _ = register("CHARS") { let n = self.pop(); self.push(n ) } // bytes here are 1:1 with cells? for char addr units
        _ = register("-!") { let a = Int(self.pop()); let n = self.pop(); let old = self.readCell(a); self.writeCell(a, old - n) }

        _ = register("WITHIN") {
            let hi = self.pop(); let lo = self.pop(); let n = self.pop()
            let inside: Bool
            if lo == hi {
                inside = false
            } else if self.unsignedLess(lo, hi) {
                inside = self.unsignedGreaterOrEqual(n, lo) && self.unsignedLess(n, hi)
            } else {
                inside = self.unsignedGreaterOrEqual(n, lo) || self.unsignedLess(n, hi)
            }
            self.push(inside ? -1 : 0)
        }

        _ = register("SPACES") { let n = Int(self.pop()); for _ in 0..<n { self.putkey(32) } }
        _ = register("U.") {
            let v = self.pop()
            let b = self.readCell(self.BASE)
            self.tell( self.formatNumber(v, base: b, signed: false) ); self.putkey(32)
        }
        _ = register("H.") {
            let v = self.pop()
            let u = UInt64(bitPattern: Int64(v))
            self.tell(String(u, radix: 16).uppercased())
            self.putkey(32)
        }
        _ = register("U.R") {
            let wid = Int(self.pop())
            let v = self.pop()
            let b = self.readCell(self.BASE)
            var s = self.formatNumber(v, base: b, signed: false)
            if s.count < wid { s = String(repeating: " ", count: wid - s.count) + s }
            self.tell(s)
        }
        _ = register(".R") {
            let wid = Int(self.pop())
            let v = self.pop()
            let b = self.readCell(self.BASE)
            var s = self.formatNumber(v, base: b, signed: true)
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
            let pair = self.popDoubleStack()
            let b = max(2, min(36, self.readCell(self.BASE)))
            var ud = self.assembleUnsignedDouble(lo: pair.lo, hi: pair.hi)
            let digit = ud % UInt128(b)
            ud /= UInt128(b)
            let parts = self.disassembleUnsignedDouble(ud)
            self.pushDoubleStack(lo: parts.lo, hi: parts.hi)
            self.picturedAddDigit(Cell(Int(digit)))
        }
        _ = register("#S") {
            let pair = self.popDoubleStack()
            let b = max(2, min(36, self.readCell(self.BASE)))
            var ud = self.assembleUnsignedDouble(lo: pair.lo, hi: pair.hi)
            repeat {
                let digit = ud % UInt128(b)
                ud /= UInt128(b)
                self.picturedAddDigit(Cell(Int(digit)))
            } while ud != 0
            let parts = self.disassembleUnsignedDouble(ud)
            self.pushDoubleStack(lo: parts.lo, hi: parts.hi)
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
            if self.throwActive { return }
            if b == 0 { self.throwDivisionByZero(); return }
            self.push( a % b )
        }

        _ = register("ALLOT") {
            let n = self.pop()
            let h = self.readCell(self.DP_ADDR)
            let next = h + n
            self.writeCell(self.DP_ADDR, next)
            self.noteDictionaryAdvance(next)
        }

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

        // === ANS Forth 2012 String word set (Section 17) ===

        _ = register("BLANK") {
            let u = Int(self.pop())
            let addr = Int(self.pop())
            for i in 0..<u { self.writeByte(addr + i, 32) }
        }

        // ANS stack: ( c-addr1 c-addr2 u -- ) — copy from c-addr1 to c-addr2.
        _ = register("CMOVE") {
            let u = Int(self.pop())
            let caddr2 = Int(self.pop())
            let caddr1 = Int(self.pop())
            self.cmoveAns(caddr1: caddr1, caddr2: caddr2, u: u)
        }

        _ = register("CMOVE>") {
            let u = Int(self.pop())
            let caddr2 = Int(self.pop())
            let caddr1 = Int(self.pop())
            self.cmoveFromHighAns(caddr1: caddr1, caddr2: caddr2, u: u)
        }

        _ = register("COMPARE") {
            let u2 = Int(self.pop())
            let caddr2 = Int(self.pop())
            let u1 = Int(self.pop())
            let caddr1 = Int(self.pop())
            self.push(self.compareCharacterStrings(caddr1: caddr1, u1: u1, caddr2: caddr2, u2: u2))
        }

        _ = register("/STRING") {
            let n = Int(self.pop())
            let u1 = Int(self.pop())
            let caddr1 = Int(self.pop())
            self.push(Cell(caddr1 + n))
            self.push(Cell(u1 - n))
        }

        _ = register("-TRAILING") {
            let u1 = Int(self.pop())
            let caddr = Int(self.pop())
            if u1 <= 0 {
                self.push(Cell(caddr))
                self.push(0)
                return
            }
            var u2 = u1
            while u2 > 0 && self.readByte(caddr + u2 - 1) == 32 {
                u2 -= 1
            }
            self.push(Cell(caddr))
            self.push(Cell(u2))
        }

        _ = register("SEARCH") {
            let u2 = Int(self.pop())
            let caddr2 = Int(self.pop())
            let u1 = Int(self.pop())
            let caddr1 = Int(self.pop())
            let hit = self.searchCharacterStrings(hayCaddr: caddr1, hayLen: u1, needleCaddr: caddr2, needleLen: u2)
            self.push(Cell(hit.caddr))
            self.push(Cell(hit.u))
            self.push(hit.found ? -1 : 0)
        }

        _ = register("REPLACES") {
            if self.readCell(self.STATE) != 0 {
                self.kernelThrow(StdThrow.compileOnly, message: "? REPLACES not allowed while compiling")
                return
            }
            let nameLen = Int(self.pop())
            let nameCaddr = Int(self.pop())
            let textLen = Int(self.pop())
            let textCaddr = Int(self.pop())
            guard let name = self.substitutionNameFromMemory(caddr: nameCaddr, u: nameLen) else {
                self.kernelThrow(StdThrow.illegalArgument, message: "? REPLACES name contains %")
                return
            }
            if textLen > Self.maxSubstitutionTextLen {
                self.kernelThrow(StdThrow.illegalArgument, message: "? REPLACES text too long")
                return
            }
            var bytes: [UInt8] = []
            bytes.reserveCapacity(textLen)
            for i in 0..<textLen {
                bytes.append(self.readByte(textCaddr + i))
            }
            self.textSubstitutions[self.normalizeSubstitutionName(name)] = bytes
        }

        _ = register("SUBSTITUTE") {
            let destCap = Int(self.pop())
            let destCaddr = Int(self.pop())
            let srcLen = Int(self.pop())
            let srcCaddr = Int(self.pop())
            if let result = self.substituteText(srcCaddr: srcCaddr, srcLen: srcLen, destCaddr: destCaddr, destCap: destCap) {
                self.push(Cell(destCaddr))
                self.push(Cell(result.u3))
                self.push(result.n)
            } else {
                self.push(Cell(destCaddr))
                self.push(0)
                self.push(-1)
            }
        }

        _ = register("UNESCAPE") {
            let destCaddr = Int(self.pop())
            let srcLen = Int(self.pop())
            let srcCaddr = Int(self.pop())
            if let outLen = self.unescapeText(srcCaddr: srcCaddr, srcLen: srcLen, destCaddr: destCaddr) {
                self.push(Cell(destCaddr))
                self.push(Cell(outLen))
            } else {
                self.kernelThrow(StdThrow.illegalArgument, message: "? UNESCAPE destination too small")
            }
        }

        // === ANS Forth 2012 Memory-Allocation word set (Section 14) ===

        _ = register("ALLOCATE") {
            self.allocateEverUsed = true
            let u = Int(self.pop())
            let result = self.heapAllocateBytes(u)
            self.push(Cell(result.addr))
            self.push(result.ior)
        }

        _ = register("FREE") {
            let addr = Int(self.pop())
            self.push(self.heapFreeBytes(addr))
        }

        _ = register("RESIZE") {
            let u = Int(self.pop())
            let addr = Int(self.pop())
            let result = self.heapResizeBytes(addr, newRequested: u)
            self.push(Cell(result.addr))
            self.push(result.ior)
        }

        _ = register("GROWMEMORYMB") {
            let mb = Int(self.pop())
            _ = self.growMemoryToMegabytes(mb)
        }

        // === ANS Forth 2012 Locals word set (Section 13) ===

        self.localInitID = register("(LOCAL-INIT)") {
            let reverse = self.pop() != 0
            let nInit = Int(self.pop())
            let nLocals = Int(self.pop())
            var frame = [Cell](repeating: 0, count: max(0, nLocals))
            if reverse {
                for i in stride(from: nInit - 1, through: 0, by: -1) where i < frame.count {
                    frame[i] = self.pop()
                }
            } else {
                for i in 0..<min(nInit, frame.count) {
                    frame[i] = self.pop()
                }
            }
            self.localFrames.append(frame)
            self.localFrameReturnDepth.append(self.returnStackPointer)
        }

        self.localFetchID = register("(LOCAL@)") {
            let idx = Int(self.pop())
            guard let frame = self.localFrames.last, idx >= 0, idx < frame.count else {
                self.throwIllegalArgument("? (LOCAL@) out of range")
                return
            }
            self.push(frame[idx])
        }

        self.localStoreID = register("(LOCAL!)") {
            let idx = Int(self.pop())
            let val = self.pop()
            guard !self.localFrames.isEmpty, idx >= 0, idx < self.localFrames[self.localFrames.count - 1].count else {
                self.throwIllegalArgument("? (LOCAL!) out of range")
                return
            }
            self.localFrames[self.localFrames.count - 1][idx] = val
        }

        _ = register("(LOCAL)", immediate: true) {
            // Hayes LOCAL / END-LOCALS immediate colon bodies run BL WORD COUNT (LOCAL) in interpret
            // state (see immColonInterpretBody in runInterpreter). (LOCAL) must work there too.
            let depth = Int(self.spGet() - 1)
            if depth <= 0 {
                self.finalizeLocalCompilation()
                return
            }
            let u = Int(self.pop())
            if u == 0 {
                self.finalizeLocalCompilation()
                // Hayes END-LOCALS pushes a dummy count (99) under the 0 before (LOCAL).
                if Int(self.spGet() - 1) > 0 { _ = self.pop() }
            } else {
                guard depth >= 2 else {
                    self.kernelThrow(StdThrow.stackUnderflow)
                    return
                }
                let caddr = Int(self.pop())
                let name = self.stringFromAddr(caddr, u)
                self.beginLocalName(name)
            }
        }

        _ = register("LOCALS|", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.kernelThrow(StdThrow.compileOnly, message: "? LOCALS| undefined in interpret state")
                return
            }
            self.resetLocalCompileState()
            self.localCompileInitReverse = false
            while !self.errorFlag {
                let token = self.parseWord()
                if token.isEmpty { break }
                if token == "|" { break }
                self.beginLocalName(token)
            }
            self.localCompileInitCount = self.localCompileNames.count
            self.finalizeLocalCompilation()
        }

        _ = register("{:", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.kernelThrow(StdThrow.compileOnly, message: "? {: undefined in interpret state")
                return
            }
            self.resetLocalCompileState()
            self.localCompileInitReverse = true
            var phase = 0  // 0=args, 1=vals, 2=skip to :}
            while !self.errorFlag && !self.inputQueue.isEmpty {
                let token = self.parseWord()
                if token.isEmpty { break }
                if token == ":}" { break }
                if token == "|" { phase = 1; continue }
                if token == "--" { phase = 2; continue }
                if phase == 2 { continue }
                self.beginLocalName(token)
                if phase == 0 { self.localCompileInitCount += 1 }
            }
            self.finalizeLocalCompilation()
        }

        _ = register("ALIGN") {
            var h = self.readCell(self.DP_ADDR)
            while (h & 7) != 0 { h += 1 }
            self.writeCell(self.DP_ADDR, h)
        }
        _ = register("ALIGNED") {
            // During BEGIN-STRUCTURE … END-STRUCTURE, ALIGNED aligns the structure
            // offset (Hayes facilitytest: `ALIGNED STRCT3 +FIELD`); leave struct-sys on stack.
            if self.structureActive {
                self.alignStructureOffset()
                return
            }
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
            if first == self.createRuntimeID {
                dataAddr = self.readCell(Int(xt) + 8)
            } else if first == self.dodoesID {
                dataAddr = xt + 16
            } else if first == self.docolID {
                dataAddr = self.readCell(Int(xt) + 16)
            } else {
                dataAddr = self.readCell(Int(xt) + 16)
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
        // at STRING_BUFFER in memory (count byte, chars, trailing NUL), return its addr.
        // This is the general parser needed for strings, names, etc. (e.g. to implement .", S", etc.).
        _ = register("WORD") {
            let delim = UInt8(self.pop() & 0xff)
            let addr = self.parseToWordBuffer(using: delim, ansWord: true)
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
            if self.evaluateNesting > 0 {
                self.push(self.evaluateSourceAddr)
                self.push(self.evaluateSourceLen)
            } else {
                self.push(Cell(self.SOURCE_BUFFER))
                self.push(Cell(self.currentSourceLen))
            }
        }

        // SOURCE-ID ( -- id )  Core Ext — -1 terminal, 0 evaluate string, ≥2 open fileid.
        _ = register("SOURCE-ID") {
            if self.evaluateNesting > 0 {
                self.push(self.currentSourceId)
            } else if self.loadNesting > 0, self.interpreterInputFileId >= 2 {
                self.push(self.interpreterInputFileId)
            } else {
                self.push(self.currentSourceId)
            }
        }

        // SAVE-INPUT ( -- x1 ... xn n )  Core Ext
        _ = register("SAVE-INPUT") {
            var sourceBytes: [UInt8] = []
            for i in 0..<self.currentSourceLen {
                sourceBytes.append(self.readByte(self.SOURCE_BUFFER + i))
            }
            var fileId: Int? = nil
            var fileLineStart: Int? = nil
            var blockFileId: Int? = nil
            var blockNum: Int? = nil
            var blockLine: Int? = nil
            if self.blockInterpretActive {
                blockFileId = self.blockInterpretFileId
                blockNum = self.blockInterpretBlockNum
                blockLine = max(0, self.blockInterpretLine - 1)
            } else if self.evaluateNesting == 0,
                      self.interpreterInputFileId >= 2 {
                fileId = Int(self.interpreterInputFileId)
                fileLineStart = self.currentFileLineStart
            }
            let snap = InputSnapshot(
                sourceId: self.currentSourceId,
                inPos: self.readCell(self.IN),
                sourceLen: self.currentSourceLen,
                sourceBytes: sourceBytes,
                queue: self.inputQueue,
                evaluateNesting: self.evaluateNesting,
                fileId: fileId,
                fileLineStart: fileLineStart,
                fromRefill: self.sourceLoadedByRefill,
                blockFileId: blockFileId,
                blockNum: blockNum,
                blockLine: blockLine
            )
            let handle = Cell(self.inputSnapshots.count)
            self.inputSnapshots.append(snap)
            let savedIn = self.readCell(self.IN)
            if self.evaluateNesting > 0 {
                // EVALUATE string source (ANS table: >IN only).
                self.push(savedIn)
                self.push(1)
            } else if self.blockInterpretActive {
                self.push(savedIn)
                self.push(self.currentSourceId)
                self.push(handle)
                self.push(3)
            } else if self.loadNesting > 0, self.interpreterInputFileId >= 2 {
                self.push(savedIn)
                self.push(self.interpreterInputFileId)
                self.push(handle)
                self.push(3)
            } else {
                self.push(savedIn)
                self.push(self.currentSourceId)
                self.push(handle)
                self.push(3)
            }
        }

        // RESTORE-INPUT ( x1 ... xn n -- flag )  Core Ext — flag true if restore failed.
        _ = register("RESTORE-INPUT") {
            let n = Int(self.pop())
            var args: [Cell] = []
            for _ in 0..<n { args.insert(self.pop(), at: 0) }
            let handle: Int
            let savedIn: Cell
            if n == 1 {
                guard args.count == 1 else {
                    self.push(-1)
                    return
                }
                savedIn = args[0]
                guard let idx = self.inputSnapshots.lastIndex(where: {
                    $0.sourceId == self.currentSourceId && $0.inPos == savedIn
                }) else {
                    self.push(-1)
                    return
                }
                handle = idx
            } else if n == 3 {
                guard args.count == 3,
                      Int(args[2]) >= 0 && Int(args[2]) < self.inputSnapshots.count else {
                    self.push(-1)
                    return
                }
                savedIn = args[0]
                handle = Int(args[2])
            } else {
                self.push(-1)
                return
            }
            let snap = self.inputSnapshots[handle]
            if snap.sourceId != self.currentSourceId {
                self.push(-1)
                return
            }
            if n == 3, args[1] != snap.sourceId {
                self.push(-1)
                return
            }
            if savedIn != snap.inPos {
                self.push(-1)
                return
            }
            var blockRestoreLineTail: [UInt8] = []
            var blockRestoreCrossBlock = false
            if snap.blockFileId != nil, self.blockInterpretActive, snap.evaluateNesting == 0 {
                let currentLine = max(0, self.blockInterpretLine - 1)
                let savedLine = snap.blockLine
                let savedBlock = snap.blockNum
                let crossLineRestore = savedLine != nil && currentLine != savedLine
                let crossBlockRestore = savedBlock != nil && self.blockInterpretBlockNum != savedBlock
                blockRestoreCrossBlock = crossBlockRestore
                if crossLineRestore || crossBlockRestore {
                    blockRestoreLineTail = self.blockRestoreContinuationTail(
                        blockNum: self.blockInterpretBlockNum,
                        line: currentLine
                    )
                } else {
                    let tailStart = Int(self.clampInOffset(self.readCell(self.IN)))
                    if tailStart < self.currentSourceLen {
                        for i in tailStart..<self.currentSourceLen {
                            blockRestoreLineTail.append(self.readByte(self.SOURCE_BUFFER + i))
                        }
                    }
                }
            }
            self.currentSourceLen = snap.sourceLen
            for i in 0..<snap.sourceLen {
                self.writeByte(self.SOURCE_BUFFER + i, snap.sourceBytes[i])
            }
            if snap.evaluateNesting > 0 {
                // Restore evaluate-string content; skip the word after the save point and apply
                // any >IN delta recorded in SI_INC (Hayes coreext SAVE-INPUT / SI1 / RESTORE-INPUT).
                var pos = Int(savedIn)
                while pos < self.currentSourceLen {
                    let b = self.readByte(self.SOURCE_BUFFER + pos)
                    if b > 32 { break }
                    pos += 1
                }
                while pos < self.currentSourceLen {
                    let b = self.readByte(self.SOURCE_BUFFER + pos)
                    if b <= 32 { break }
                    pos += 1
                }
                while pos < self.currentSourceLen {
                    let b = self.readByte(self.SOURCE_BUFFER + pos)
                    if b > 32 { break }
                    pos += 1
                }
                if let siAddr = self.valueStorageAddr(named: "SI_INC") {
                    pos += Int(self.readCell(siAddr))
                }
                self.writeCell(self.IN, Cell(pos))
                self.realignInputQueueFromSource()
            } else {
                self.currentSourceId = snap.sourceId
                let currentIn = Int(self.readCell(self.IN))
                let snapIn = Int(snap.inPos)
                let refillFileRestore = snap.evaluateNesting == 0
                    && self.loadNesting > 0
                    && snap.fromRefill
                if refillFileRestore {
                    // Hayes filetest SI2: always restore the REFILL save point and rewind the file
                    // (even after SAVE-INPUT … EVALUATE … RESTORE-INPUT in the same colon word).
                    self.writeCell(self.IN, savedIn)
                    self.inputQueue = snap.queue
                    self.realignInputQueueFromSource()
                    if let fid = snap.fileId,
                       let lineStart = snap.fileLineStart,
                       var entry = self.openFiles[fid] {
                        entry.position = lineStart
                        self.openFiles[fid] = entry
                        self.interpreterInputFileId = Cell(fid)
                        self.currentFileLineStart = lineStart
                    }
                    self.floadRestoreInputContinuation = true
                } else if snap.blockFileId != nil, self.blockInterpretActive {
                    if !blockRestoreLineTail.isEmpty {
                        let start = self.skipSaveInputTokenIfPresent(
                            in: snap.sourceBytes,
                            from: Int(snap.inPos)
                        )
                        var combined: [UInt8] = []
                        if start < snap.sourceLen {
                            for i in start..<snap.sourceLen {
                                combined.append(snap.sourceBytes[i])
                            }
                        }
                        if blockRestoreCrossBlock,
                           let savedBlock = snap.blockNum,
                           let savedLine = snap.blockLine {
                            self.blockRestoreResumeTail = blockRestoreLineTail
                            self.blockRestoreResumeBlock = self.blockInterpretBlockNum
                            self.blockRestoreResumeLine = max(0, self.blockInterpretLine - 1)
                            self.blockInterpretBlockNum = savedBlock
                            self.blockInterpretLine = savedLine + 1
                        } else if !blockRestoreLineTail.isEmpty {
                            if !combined.isEmpty { combined.append(32) }
                            combined.append(contentsOf: blockRestoreLineTail)
                        }
                        var len = combined.count
                        while len > 0 && combined[len - 1] <= 32 {
                            len -= 1
                        }
                        var trimStart = 0
                        while trimStart < len && combined[trimStart] <= 32 {
                            trimStart += 1
                        }
                        len -= trimStart
                        self.currentSourceLen = len
                        for i in 0..<len {
                            self.writeByte(self.SOURCE_BUFFER + i, combined[trimStart + i])
                        }
                        self.writeCell(self.IN, 0)
                        self.realignBlockInputQueueFromSource()
                    } else {
                        self.writeCell(self.IN, savedIn)
                        self.inputQueue = snap.queue
                        self.realignBlockInputQueueFromSource()
                    }
                } else if currentIn > snapIn {
                    // Same-line parse moved past the save point: keep >IN, restore SOURCE only.
                    self.realignInputQueueFromSource()
                } else {
                    self.writeCell(self.IN, savedIn)
                    self.inputQueue = snap.queue
                    self.realignInputQueueFromSource()
                }
                if snap.evaluateNesting == 0, self.loadNesting > 0 {
                    for qName in ["(\\?)", "(?)"] {
                        if let qAddr = self.valueStorageAddr(named: qName) {
                            self.writeCell(qAddr, 0)
                            break
                        }
                    }
                }
            }
            self.push(0) // success (flag false)
        }

        // REFILL ( -- flag )  Core/File Ext — true when next line loaded from text file input.
        _ = register("REFILL") {
            if self.evaluateNesting > 0 {
                self.push(0)
                return
            }
            if self.blockInterpretActive {
                self.blockRefillInProgress = true
                let ok = self.refillFromBlockSource()
                self.blockRefillInProgress = false
                if ok {
                    self.sourceLoadedByRefill = true
                    self.push(-1)
                    return
                }
            }
            let fid: Int?
            if self.loadNesting > 0, self.interpreterInputFileId >= 2 {
                fid = Int(self.interpreterInputFileId)
            } else {
                fid = self.activeInterpreterFileId()
            }
            if let fid, self.refillFromFile(fid) {
                self.sourceLoadedByRefill = true
                self.push(-1)
            } else {
                self.push(0)
            }
        }

        // PAD ( -- addr )  Transient user scratch (1024 bytes). System parsers use STRING_BUFFER.
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
            if !self.inputQueue.isEmpty {
                let b = self.inputQueue.first!
                if b <= 32 && b != 10 && b != 13 {
                    _ = self.consumeInput()
                }
            }
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
            // Advance >IN past the parsed string and the delimiter (if present).
            var endPos = startPos + len
            if !self.inputQueue.isEmpty {
                let b = self.inputQueue.first!
                if self.peekIsDelim(delim) || b == delim {
                    _ = self.consumeInput()
                    endPos += 1
                }
            }
            let addr = self.SOURCE_BUFFER + startPos
            self.writeCell(self.IN, endPos)
            self.push( Cell(addr) )
            self.push( Cell(len) )
        }

        // Hayes utilities.fth ($") / $" — quote parse with leading-ws skip into a counted buffer.
        _ = register("(hayes-quote-parse)") {
            let dest = Int(self.pop())
            self.realignInputQueueFromSource()
            while let b = self.inputQueue.first, b <= 32 && b != 10 && b != 13 {
                _ = self.consumeInput()
            }
            var collected: [UInt8] = []
            while !self.inputQueue.isEmpty {
                let b = self.inputQueue.first!
                if self.peekIsDelim(34) || b == 34 || b == 10 || b == 13 { break }
                collected.append(self.consumeInput()!)
            }
            if !self.inputQueue.isEmpty {
                _ = self.consumeDelim(34)
            }
            while let first = collected.first, first <= 32 {
                collected.removeFirst()
            }
            let capped = min(collected.count, 255)
            self.writeByte(dest, UInt8(capped))
            for i in 0..<capped {
                self.writeByte(dest + 1 + i, collected[i])
            }
            self.push(Cell(dest + 1))
            self.push(Cell(capped))
        }

        // PARSE-NAME ( -- c-addr u )  Core Ext
        // Skip leading delimiters (chars <= BL), then parse up to BL without consuming the delimiter.
        _ = register("PARSE-NAME") {
            while !self.inputQueue.isEmpty {
                let b = self.inputQueue.first!
                if b > 32 { break }
                if b == 10 || b == 13 { break }
                _ = self.consumeInput()
            }
            let startPos = Int(self.readCell(self.IN))
            var len = 0
            while !self.inputQueue.isEmpty {
                let b = self.inputQueue.first!
                if b == 32 || b == 10 || b == 13 { break }
                _ = self.consumeInput()
                len += 1
            }
            self.push(Cell(self.SOURCE_BUFFER + startPos))
            self.push(Cell(len))
        }

        // UNUSED ( -- u )  Core Ext — bytes from HERE to the dictionary limit (below pictured-numeric buffer).
        _ = register("UNUSED") {
            self.push(self.dictionaryFreeBytes())
        }

        _ = register(".FREE") {
            let free = self.dictionaryFreeBytes()
            let b = self.readCell(self.BASE)
            self.tell(self.formatNumber(free, base: b, signed: false))
            self.putkey(32)
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
                    self.throwInvalidToken("? Bad branch target (ip=\(self.ip)) after ?DO")
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
            let newIndex = self.cellAdd(index, 1)
            if self.loopShouldContinue(index: index, limit: limit, delta: 1) {
                self.rpush(limit)
                self.rpush(newIndex)
                self.ip += backOffset
                if self.ip < 0 || self.ip + 8 > self.memory.count {
                    self.throwInvalidToken("? Bad branch target (ip=\(self.ip)) after (LOOP)")
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
            let newIndex = self.cellAdd(index, delta)
            if self.loopShouldContinue(index: index, limit: limit, delta: delta) {
                self.rpush(limit)
                self.rpush(newIndex)
                self.ip += backOffset
                if self.ip < 0 || self.ip + 8 > self.memory.count {
                    self.throwInvalidToken("? Bad branch target (ip=\(self.ip)) after (+LOOP)")
                }
            } else {
                // fall out, params dropped
            }
        }

        // I -- current loop index (top item on rstack for active DO loop)
        _ = register("I") {
            let rs = self.rspGet()
            if rs < 2 {
                self.kernelThrow(StdThrow.returnStackUnderflow, message: "? Return stack underflow")
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
                self.kernelThrow(StdThrow.returnStackUnderflow, message: "? Return stack underflow")
                return
            }
            self.push( self.readCell( self.rstackBase + (rs - 4) * 8 ) )
        }

        // UNLOOP -- drop the current loop's limit+index from rstack (no branch)
        let unloopID = register("UNLOOP") {
            let rs = self.rspGet()
            if rs < 3 {
                self.kernelThrow(StdThrow.returnStackUnderflow, message: "? Return stack underflow")
                return
            }
            self.rspSet(rs - 2)
        }

        // LEAVE -- compile-time: emit unconditional branch to after the matching LOOP (patched by LOOP)
        _ = register("LEAVE", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.throwCompileOnly("? LEAVE only allowed while compiling a word")
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
                self.throwCompileOnly("? DO only allowed while compiling a word")
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
                self.throwCompileOnly("? ?DO only allowed while compiling a word")
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
                self.throwCompileOnly("? LOOP only allowed while compiling a word")
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
                self.throwCompileOnly("? +LOOP only allowed while compiling a word")
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
            let spec = self.parseWordForHostParsing()
            if spec.isEmpty {
                // Bare FLOAD mid-include is never used by test suites; ignore to avoid dialogs.
                if self.loadNesting > 0 { return }
                // Swallow stray bare FLOAD on the same REPL line after a named FLOAD
                // (e.g. reparsed tail token after `fload runfptests.fth`).
                if self.namedFloadOnCurrentReplLine { return }
                self.fileLoadRequested = true
                self.onFileLoadRequested?()
                return
            }
            self.resolveAndLoadFile(spec: spec)
            guard let url = self.pendingLoadURL else { return }
            self.pendingLoadURL = nil
            // Snapshot console-line tail (`FLOAD file.fth HERE .`) before nested loads can
            // disturb inputSourceStack (long Hayes suites with SAVE-INPUT / CATCH).
            let replFload = self.loadNesting == 0
            let resumeIn = self.readCell(self.IN)
            let resumeTail = replFload ? self.unparsedInputTailBytes(from: Int(resumeIn)) : []
            self.performNamedFload(url: url, spec: spec)
            if replFload, !resumeTail.isEmpty {
                self.restoreUnparsedInputTail(in: resumeIn, tail: resumeTail)
            }
            if self.throwActive { return }
            if self.loadNesting == 0 {
                self.namedFloadOnCurrentReplLine = true
            }
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
            self.facilityTerminal.deactivate()
            self.terminalRefreshPending = false
            self.clearScreenRequested = true
        }

        _ = register("WORDS") {
            self.validateAndRepairSystemState()

            let filter = self.parseWord().uppercased()

            // Collect kernel (internal) words vs user-defined words from *current vocabulary only*.
            // Kernel = everything that existed at the end of bootstrap (kernelLatest).
            var kernelWords: [(name: String, header: Cell)] = []
            var userWords:   [(name: String, header: Cell)] = []

            let listHead = self.readCell(self.CURRENT)
            var link = self.readCell(listHead)
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

        // MARKER ( "name" -- )  Core Ext — save dict/search-order landmark; execution restores state.
        _ = register("MARKER") {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? MARKER needs a name"); return }
            let savedHere = self.readCell(self.DP_ADDR)
            let savedCurrent = self.readCell(self.CURRENT)
            let n = self.searchOrder.count
            var heads: [Cell] = []
            var wls: [Cell] = []
            for wl in self.searchOrder {
                wls.append(wl)
                heads.append(self.readCell(wl))
            }
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            let litSlot = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.push(self.markerRestoreID); self.comma()
            self.push(self.exitID); self.comma()
            let storageAddr = self.readCell(self.DP_ADDR)
            self.writeCell(Int(litSlot), storageAddr)
            self.writeCellHere(savedHere)
            self.writeCellHere(savedCurrent)
            self.writeCellHere(Cell(n))
            for h in heads { self.writeCellHere(h) }
            for wl in wls { self.writeCellHere(wl) }
        }

        _ = register("FORGET") {
            // The user-facing, classic "FORGET NAME" parsing word.
            // (The high-level >LFA-based version is available as FORGET-WORD for teaching.)
            self.validateAndRepairSystemState()

            let name = self.parseWord().uppercased()
            if name.isEmpty {
                self.throwZeroLengthName("? FORGET needs a name")
                return
            }

            let listHead = self.readCell(self.CURRENT)
            var link = self.readCell(listHead)
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
                        self.throwIllegalArgument("? Cannot FORGET kernel word '\(name)'")
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
                    self.writeCell(listHead, newLatest)
                    self.writeCell(self.DP_ADDR, link)   // reclaim memory from this header forward (set the DP value back)
                    self.dictionaryHighWater = link

                    // Extra defensive repair after modifying critical system variables.
                    self.validateAndRepairSystemState()
                    return
                }
                prev = link
                link = self.readCell(link)
            }
            self.kernelThrow(StdThrow.undefinedWord, message: "? \(name) ?")
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
                self.kernelThrow(StdThrow.undefinedWord, message: "? \(lookupName) ?")
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
            self.seeWord(self.parseWord(), usageWord: "SEE")
        }

        _ = register("LOCATE") {
            self.seeWord(self.parseWord(), usageWord: "LOCATE")
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

        // ANS-VALIDATE — run the 2012 ANS Forth validation tests (Core + Block subsystem spot-checks:
        // Core Ext, File-Access, String, Facility, Exception, Memory, Double, Locals, Programming-Tools;
        // ported from TestTZForth FTEST, originally TestLBForth.swift) and write ANS-VALIDATE.txt
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
            // Write beside TZForth/TestTZForth.swift (tracked ANS-VALIDATE.txt in the Xcode
            // project folder). Excluded from the app bundle so regeneration stays writable.
            var outBase = self.logicalCurrentDirectory.isEmpty ? FileManager.default.currentDirectoryPath : self.logicalCurrentDirectory
            let fm2 = FileManager.default
            let subDir = URL(fileURLWithPath: outBase).appendingPathComponent("TZForth")
            let directTest = URL(fileURLWithPath: outBase).appendingPathComponent("TestTZForth.swift")
            let subTest = subDir.appendingPathComponent("TestTZForth.swift")
            let subEngine = subDir.appendingPathComponent("TZForth.swift")
            if fm2.fileExists(atPath: subTest.path) || fm2.fileExists(atPath: subEngine.path) {
                outBase = subDir.path
            } else if fm2.fileExists(atPath: directTest.path) {
                outBase = outBase
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
            self.shutdownBlockSubsystem()
            self.quitRequested = true
            self.onQuitRequested?()
        }

        // DUMP ( addr u -- )  ANS Programming-Tools — hex dump of u address units (bytes).
        _ = register("DUMP") {
            let byteCount = Int(self.pop())
            let start = Int(self.pop())
            if byteCount <= 0 { return }
            let bytesPerLine = 16
            var offset = 0
            while offset < byteCount {
                let lineAddr = start + offset
                let lineLen = min(bytesPerLine, byteCount - offset)
                var line = String(format: "%08X  ", lineAddr)
                var ascii = ""
                for i in 0..<lineLen {
                    let addr = lineAddr + i
                    let b: UInt8
                    if addr < 0 || addr >= self.memory.count {
                        self.throwInvalidAddress("? DUMP out of range (addr=\(addr))")
                        return
                    }
                    b = self.memory[addr]
                    line += String(format: "%02X", b)
                    line += (i == 7) ? "  " : " "
                    if b >= 32 && b < 127 {
                        ascii.append(Character(UnicodeScalar(b)))
                    } else {
                        ascii.append(".")
                    }
                }
                if lineLen < bytesPerLine {
                    let missing = bytesPerLine - lineLen
                    for i in 0..<missing {
                        line += "   "
                        if i == 7 - lineLen && lineLen <= 7 { line += " " }
                    }
                }
                self.tell(line + " |" + ascii + "|\n")
                offset += lineLen
            }
        }

        // ? ( addr -- )  ANS Programming-Tools — display value at addr.
        _ = register("?") {
            let addr = Int(self.pop())
            let n = self.readCell(addr)
            let b = self.readCell(self.BASE)
            self.tell(self.formatNumber(n, base: b, signed: true))
            self.putkey(32)
        }

        // NAME>STRING ( nt -- c-addr u )  nt is the header address (link field).
        _ = register("NAME>STRING") {
            let nt = Int(self.pop())
            let flagsLen = self.readByte(nt + 8)
            let len = Int(flagsLen & self.MASK_NAMELENGTH)
            let slot = self.allocateStringBufferSlot()
            for i in 0..<len {
                self.writeByte(slot + i, self.readByte(nt + 9 + i))
            }
            self.push(Cell(slot))
            self.push(Cell(len))
        }

        // NAME>INTERPRET ( nt -- xt )  xt is the cfa.
        _ = register("NAME>INTERPRET") {
            let nt = self.pop()
            self.push(self.getCFA(nt))
        }

        // NAME>COMPILE ( nt -- xt )  immediate → cfa; non-immediate → hidden compile stub.
        _ = register("NAME>COMPILE") {
            let nt = self.pop()
            let cfa = self.getCFA(nt)
            let flagsLen = self.readByte(Int(nt) + 8)
            if (flagsLen & self.FLAG_IMMEDIATE) != 0 {
                self.push(cfa)
            } else {
                self.push(self.makeCompileXT(forTargetCfa: cfa))
            }
        }

        // TRAVERSE-WORDLIST ( xt wid -- )  xt ( wid *u n -- wid *u n f )
        _ = register("TRAVERSE-WORDLIST") {
            let wid = Int(self.pop())
            let xt = self.pop()
            self.push(Cell(wid))
            var link = self.readCell(wid)
            var safety = 0
            while link != 0 && safety < 10000 {
                safety += 1
                if !self.isValidDictionaryLink(link) { break }
                let flagsLen = self.readByte(Int(link) + 8)
                if (flagsLen & self.FLAG_HIDDEN) != 0 {
                    link = self.readCell(link)
                    continue
                }
                let namelen = Int(flagsLen & self.MASK_NAMELENGTH)
                if namelen == 0 {
                    link = self.readCell(link)
                    continue
                }
                self.push(link)
                let savedIp = self.ip
                let savedRsp = self.rspGet()
                let first = self.readCell(Int(xt))
                self.execute(cfa: xt, firstCell: first)
                self.ip = savedIp
                self.rspSet(savedRsp)
                if self.throwActive || self.errorFlag { return }
                let continueFlag = self.pop()
                if continueFlag == 0 { break }
                link = self.readCell(link)
            }
        }

        // SYNONYM ( "newname" "oldname" -- )
        self.synonymID = register("(SYNONYM)") {
            let target = self.readCell(Int(self.currentCodeAddr) + 8)
            let first = self.readCell(Int(target))
            self.execute(cfa: target, firstCell: first)
        }

        _ = register("SYNONYM") {
            let newName = self.parseWord()
            let oldName = self.parseWord()
            if newName.isEmpty || oldName.isEmpty {
                self.throwZeroLengthName("? SYNONYM needs newname and oldname")
                return
            }
            let hdr = self.findWord(oldName)
            if hdr == 0 {
                self.kernelThrow(StdThrow.undefinedWord, message: "? SYNONYM ? \(oldName)")
                return
            }
            let oldCfa = self.getCFA(hdr)
            let oldFlags = self.readByte(Int(hdr) + 8)
            let isImm = (oldFlags & self.FLAG_IMMEDIATE) != 0
            self.createWord(name: newName, immediate: isImm)
            self.writeCellHere(self.synonymID)
            self.writeCellHere(oldCfa)
            self.writeCellHere(self.exitID)
        }

        // [DEFINED] ( "<spaces>name" -- flag )  immediate — skip following text if name absent.
        _ = register("[DEFINED]", immediate: true) {
            let compiling = self.isActiveCompilation()
            let name = self.parseWord()
            if compiling {
                if self.findWord(name) == 0 {
                    let r = self.startConditionalSkip(stopAtElse: true)
                    if r == .error {
                        self.throwUncompletedControl("? [IF] unresolved conditional compilation")
                    }
                } else {
                    self.push(-1)
                }
            } else {
                self.push(self.findWord(name) != 0 ? -1 : 0)
            }
        }

        // [UNDEFINED] ( "<spaces>name" -- flag )  immediate — skip following text if name present.
        _ = register("[UNDEFINED]", immediate: true) {
            let compiling = self.isActiveCompilation()
            let name = self.parseWord()
            if compiling {
                if self.findWord(name) != 0 {
                    let r = self.startConditionalSkip(stopAtElse: true)
                    if r == .error {
                        self.throwUncompletedControl("? [IF] unresolved conditional compilation")
                    }
                } else {
                    self.push(-1)
                }
            } else {
                self.push(self.findWord(name) == 0 ? -1 : 0)
            }
        }

        // N>R ( n -- ) / NR> ( -- )  Programming-Tools stack block transfer.
        _ = register("N>R") {
            let n = Int(self.pop())
            if n < 0 {
                self.throwIllegalArgument("? N>R negative count")
                return
            }
            var items: [Cell] = []
            for _ in 0..<n { items.append(self.pop()) }
            for item in items.reversed() { self.rpush(item) }
            self.rpush(Cell(n))
        }

        _ = register("NR>") {
            let rs = self.rspGet()
            if rs < 2 {
                self.kernelThrow(StdThrow.returnStackUnderflow, message: "? NR> return stack underflow")
                return
            }
            let n = Int(self.rpop())
            if n < 0 || rs - 1 < Cell(n) {
                self.throwIllegalArgument("? NR> mismatch with N>R")
                return
            }
            var items: [Cell] = []
            for _ in 0..<n { items.append(self.rpop()) }
            for item in items.reversed() { self.push(item) }
        }

        // CS-PICK / CS-ROLL — control-flow stack is the data stack during compilation.
        _ = register("CS-PICK", immediate: true) {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? CS-PICK only while compiling")
                return
            }
            let u = Int(self.pop())
            let idx = self.controlFlowStack.count - 1 - u
            if idx < 0 || idx >= self.controlFlowStack.count {
                self.push(self.litID); self.comma()
                self.push(Cell(u)); self.comma()
                self.push(self.deferredCsPickID); self.comma()
                return
            }
            self.push(self.controlFlowStack[idx])
        }

        _ = register("CS-ROLL", immediate: true) {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? CS-ROLL only while compiling")
                return
            }
            let u = Int(self.pop())
            let idx = self.controlFlowStack.count - 1 - u
            if u <= 0 { return }
            if idx < 0 || idx >= self.controlFlowStack.count {
                self.push(self.litID); self.comma()
                self.push(Cell(u)); self.comma()
                self.push(self.deferredCsRollID); self.comma()
                return
            }
            self.performCsRoll(u: u)
        }

        // AHEAD ( -- )  unconditional forward branch placeholder (resolved by THEN).
        _ = register("AHEAD", immediate: true) {
            if !self.isActiveCompilation() {
                self.throwCompileOnly("? AHEAD only while compiling")
                return
            }
            self.push(self.branchID); self.comma()
            let placeholderAddr = self.readCell(self.DP_ADDR)
            self.push(0); self.comma()
            self.controlFlowStack.append(placeholderAddr)
        }

        // CODE / ;CODE / RET — registered in registerAssemblerWords() after bootstrap (needs ASSEMBLER vocab).
        // [IF] / [ELSE] / [THEN] — conditional compilation and interpret-time conditional execution.
        _ = register("[IF]", immediate: true) {
            let compiling = self.isActiveCompilation()
            let flag: Cell
            if compiling {
                flag = self.pop()
            } else {
                flag = self.popInterpretIfFlag()
            }
            if compiling {
                if flag == 0 {
                    let r = self.startConditionalSkip(stopAtElse: true)
                    if r == .error {
                        self.throwUncompletedControl("? [IF] unresolved conditional compilation")
                    }
                }
            } else if flag == 0 {
                let r = self.startConditionalSkip(stopAtElse: true)
                if r == .error {
                    self.throwUncompletedControl("? [IF] unresolved conditional compilation")
                }
            } else {
                self.interpretIfTrueDepth += 1
            }
        }
        _ = register("[ELSE]", immediate: true) {
            let compiling = self.isActiveCompilation()
            if compiling {
                let r = self.startConditionalSkip(stopAtElse: false)
                if r == .error {
                    self.throwUncompletedControl("? [IF] unresolved conditional compilation")
                }
            } else if self.interpretIfTrueDepth > 0 {
                self.interpretIfTrueDepth -= 1
                let r = self.startConditionalSkip(stopAtElse: false)
                if r == .error {
                    self.throwUncompletedControl("? [IF] unresolved conditional compilation")
                }
            } else {
                let r = self.startConditionalSkip(stopAtElse: false)
                if r == .error {
                    self.throwUncompletedControl("? [IF] unresolved conditional compilation")
                }
            }
        }
        _ = register("[THEN]", immediate: true) {
            if self.readCell(self.STATE) == 0 && self.bracketCompileDepth == 0 && self.interpretIfTrueDepth > 0 {
                self.interpretIfTrueDepth -= 1
            }
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
                    self.lastAbortQuoteText = String(bytes: (0..<len).map { self.readByte(saddr + $0) }, encoding: .utf8) ?? ""
                    self.deliverThrow(-2)
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
        _ = register("ENVIRONMENT?") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            var q: [UInt8] = []
            for i in 0..<u {
                q.append(self.readByte(caddr + i))
            }
            let query = String(bytes: q, encoding: .utf8) ?? ""
            if let values = self.environmentQueryValues(for: query) {
                for v in values { self.push(v) }
            } else {
                self.push(0)
            }
        }

        _ = register(".ENVIRONMENT") {
            self.displayEnvironmentCatalog()
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
            // parseToWordBuffer consumed the closing quote via inputQueue; resync queue from >IN
            // so realign-before-execute on the next word does not re-offer the string body (e.g. 222).
            self.inputQueue.removeAll(keepingCapacity: true)
            self.realignInputQueueFromSource()
        }

        // SLITERAL ( c-addr u -- ) immediate — compile (S") + inline string; interpret undefined.
        _ = register("SLITERAL", immediate: true) {
            let compiling = self.readCell(self.STATE) != 0 || self.bracketCompileDepth > 0
            if !compiling {
                self.throwCompileOnly("? SLITERAL undefined in interpret state")
                return
            }
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            self.push(self.sQuoteID); self.comma()
            self.writeByteHere(UInt8(u))
            for i in 0..<u {
                self.writeByteHere(self.readByte(caddr + i))
            }
            self.alignHere()
        }

        // C"  immediate — ANS compile: parse ccc, compile (C") + inline counted string.
        // Run-time (and our interpret extension): leave c-addr only (count is at c-addr).
        _ = register("C\"", immediate: true) {
            let caddr = self.parseToWordBuffer(using: 34)
            var len = Int( self.readByte( Int(caddr) ) )
            var saddr = Int(caddr) + 1
            if len > 0 && self.readByte(saddr) <= 32 {
                saddr += 1
                len -= 1
            }
            if self.readCell(self.STATE) != 0 {
                self.push(self.cQuoteID); self.comma()
                self.writeByteHere(UInt8(len))
                for i in 0..<len {
                    self.writeByteHere( self.readByte(saddr + i) )
                }
                self.alignHere()
            } else {
                // Interpret: counted string already in STRING_BUFFER from parseToWordBuffer.
                // Normalize leading separator (same rule as S") in place, then leave c-addr.
                if len > 0 && self.readByte(saddr) <= 32 {
                    saddr += 1
                    len -= 1
                    self.writeByte(Int(caddr), UInt8(len))
                    for i in 0..<len {
                        self.writeByte(Int(caddr) + 1 + i, self.readByte(saddr + i))
                    }
                    self.writeByte(Int(caddr) + 1 + len, 0)
                }
                self.push(Cell(caddr))
            }
        }

        // S\"  immediate — escaped string. Compile: (S") + inline string.
        // Forth 2012 / Hayes filetest: interpret leaves ( c-addr u ) like S".
        _ = register("S\\\"", immediate: true) {
            let (saddr, len) = self.parseEscapedStringToBuffer()
            if self.readCell(self.STATE) != 0 {
                self.push(self.sQuoteID); self.comma()
                self.writeByteHere(UInt8(len))
                for i in 0..<len {
                    self.writeByteHere(self.readByte(Int(saddr) + i))
                }
                self.alignHere()
            } else {
                self.push(saddr)
                self.push(Cell(len))
            }
            self.inputQueue.removeAll(keepingCapacity: true)
            self.realignInputQueueFromSource()
        }

        // Simple CONSTANT (enough for education)
        _ = register("CONSTANT") {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? CONSTANT needs a name"); return }
            let value = self.pop()
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            self.push(value); self.comma()
            self.push(self.exitID); self.comma()
        }

        _ = register("2CONSTANT") {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? 2CONSTANT needs a name"); return }
            let dhi = self.pop()
            let dlo = self.pop()
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            self.push(dlo); self.comma()
            self.push(self.litID); self.comma()
            self.push(dhi); self.comma()
            self.push(self.exitID); self.comma()
        }

        _ = register("2LITERAL", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.throwCompileOnly("? 2LITERAL only while compiling")
                return
            }
            let dhi = self.pop()
            let dlo = self.pop()
            self.compileDoubleLiteral(dlo, dhi)
        }

        // VARIABLE (very simple)
        _ = register("VARIABLE") {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? VARIABLE needs a name"); return }
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

        _ = register("2VARIABLE") {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? 2VARIABLE needs a name"); return }
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            let dataAddr = self.readCell(self.DP_ADDR) + 16
            self.push(dataAddr); self.comma()
            self.push(self.exitID); self.comma()
            self.writeCell(self.DP_ADDR, self.readCell(self.DP_ADDR) + 16)
        }

        // DEFER ( "<spaces>name" -- )  Core Ext
        // Manual docol + LIT + storage + @ EXECUTE style (efficient, ' gives cfa).
        // (We also support high-level CREATE/DOES> defers via updated DEFER!/IS logic.)
        _ = register("DEFER") {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? DEFER needs a name"); return }
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
            if name.isEmpty { self.throwZeroLengthName("? VALUE needs a name"); return }
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

        _ = register("2VALUE") {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? 2VALUE needs a name"); return }
            let dhi = self.pop()
            let dlo = self.pop()
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            let valCellAddr = self.readCell(self.DP_ADDR) + 24
            self.push(valCellAddr); self.comma()
            self.push(self.twoFetchID); self.comma()
            self.push(self.exitID); self.comma()
            self.writeCell(self.DP_ADDR, self.readCell(self.DP_ADDR) + 16)
            self.writeCell(Int(valCellAddr), dhi)
            self.writeCell(Int(valCellAddr) + 8, dlo)
        }

        // DEFER! ( xt2 xt1 -- )  Core Ext
        // Set the word represented by defer-xt1 to execute xt2.
        _ = register("DEFER!") {
            let deferXt = self.pop()
            let newXt = self.pop()
            if deferXt < Cell(self.MAX_BUILTIN_ID) {
                self.throwIllegalArgument("? DEFER! on a primitive"); return
            }
            let cfa = Int(deferXt)
            let first = self.readCell(cfa)
            var storageAddr: Int = 0
            if first == self.docolID {
                // old docol + LIT <storage> style (VALUE, old DEFER)
                let second = self.readCell(cfa + 8)
                if second != self.litID {
                    self.throwIllegalArgument("? DEFER! target does not look like a DEFER or VALUE"); return
                }
                storageAddr = Int( self.readCell(cfa + 16) )
            } else if first == self.createRuntimeID || first == self.dodoesID {
                // CREATE or DOES> child (standard high-level DEFER using CREATE DOES>)
                // storage / behavior cell is the second cell after the runtime ID
                storageAddr = Int( self.readCell(cfa + 8) )
            } else {
                self.throwIllegalArgument("? DEFER! target is not a supported defer or value"); return
            }
            self.writeCell(storageAddr, newXt)
        }

        // ACTION-OF ( "<spaces>name" -- xt ) / compile: parse name, append ( -- xt ) for defer action.
        _ = register("ACTION-OF", immediate: true) {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? ACTION-OF needs a name"); return }
            guard let target = self.deferStorage(forName: name) else {
                self.throwIllegalArgument("? ACTION-OF target is not a DEFER"); return
            }
            if self.readCell(self.STATE) != 0 {
                self.push(self.litID); self.comma(); self.push(target.cfa); self.comma()
                self.emitCompileReference(xt: self.getCFA(self.findWord("DEFER@")))
            } else if let storage = self.deferStorageFromXt(target.cfa) {
                self.push(self.readCell(storage))
            } else {
                self.push(0)
            }
        }

        // DEFER@ ( xt1 -- xt2 )  Core Ext
        // Return the xt that the defer xt1 currently executes.
        _ = register("DEFER@") {
            let deferXt = self.pop()
            if deferXt < Cell(self.MAX_BUILTIN_ID) {
                self.throwIllegalArgument("? DEFER@ on a primitive"); return
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

        // IS ( xt "<spaces>name" -- )  Core Ext — immediate parsing word (DEFER! semantics).
        _ = register("IS", immediate: true) {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? IS needs a name"); return }
            guard let target = self.deferStorage(forName: name) else {
                self.kernelThrow(StdThrow.undefinedWord, message: "? IS ? " + name)
                return
            }
            if self.readCell(self.STATE) != 0 {
                self.push(self.litID); self.comma(); self.push(target.cfa); self.comma()
                self.emitCompileReference(xt: self.getCFA(self.findWord("DEFER!")))
            } else {
                let newXt = self.pop()
                self.push(newXt)
                self.push(target.cfa)
                let deferHdr = self.findWord("DEFER!")
                self.execute(cfa: self.getCFA(deferHdr), firstCell: self.docolID)
            }
        }

        // TO ( n "<name>" -- ) / ( d "<name>" -- ) — immediate; VALUE, 2VALUE, and locals
        _ = register("TO", immediate: true) {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? TO needs a name"); return }

            if let idx = self.localIndexDuringCompile(name) {
                if self.readCell(self.STATE) == 0 {
                    self.throwCompileOnly("? TO local undefined in interpret state")
                    return
                }
                self.compileLocalStore(idx)
                return
            }

            let hdr = self.findWord(name)
            if hdr == 0 || hdr == Cell(-1) {
                self.kernelThrow(StdThrow.undefinedWord, message: "? TO ? " + name)
                return
            }
            let cfa = self.getCFA(hdr)
            let first = self.readCell(Int(cfa))
            guard first == self.docolID else {
                self.throwIllegalArgument("? TO target is not a VALUE"); return
            }
            let second = self.readCell(Int(cfa) + 8)
            guard second == self.litID else {
                self.throwIllegalArgument("? TO target does not look like a VALUE or FVALUE"); return
            }
            let storageAddr = Int(self.readCell(Int(cfa) + 16))
            let fourth = self.readCell(Int(cfa) + 24)
            if self.readCell(self.STATE) != 0 {
                self.push(self.litID); self.comma(); self.push(Cell(storageAddr)); self.comma()
                if fourth == self.twoFetchID {
                    self.push(self.twoStoreID); self.comma()
                } else if fourth == self.fvalueFetchID {
                    self.push(self.fvalueStoreID); self.comma()
                } else {
                    self.push(self.storeID); self.comma()
                }
            } else if fourth == self.twoFetchID {
                let dhi = self.pop()
                let dlo = self.pop()
                self.writeCell(storageAddr, dhi)
                self.writeCell(storageAddr + 8, dlo)
            } else if fourth == self.fvalueFetchID {
                self.writeFloat(storageAddr, self.fpop())
            } else {
                let n = self.pop()
                self.writeCell(storageAddr, n)
            }
        }

        // CREATE ( "<spaces>name" -- )  ANS 2012
        // Create a word "name" whose execution semantics are to push its data-field address.
        // The data field starts at the current HERE after CREATE (user can then , ALLOT etc.).
        // Used together with DOES> for defining words.
        _ = register("CREATE") {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? CREATE needs a name"); return }
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
                self.throwCompileOnly("? DOES> only allowed while compiling a word")
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

        registerFacilityWords()
        registerFileAccessWords()
        // registerBlockWords() is called after bootstrap in init (needs VARIABLE cells).
    }

    // MARK: - Facility terminal buffer (ANS 10.6.1 PAGE / AT-XY)

    private struct FacilityTerminal {
        static let defaultCols = 80
        static let defaultRows = 25

        var cols: Int = defaultCols
        var rows: Int = defaultRows
        private(set) var cells: [UInt8] = Array(repeating: 32, count: defaultCols * defaultRows)
        private(set) var isActive = false
        var cursorCol = 0
        var cursorRow = 0

        mutating func page() {
            self.isActive = true
            self.cells = Array(repeating: 32, count: self.cols * self.rows)
            self.cursorCol = 0
            self.cursorRow = 0
        }

        mutating func deactivate() {
            self.isActive = false
            self.cursorCol = 0
            self.cursorRow = 0
        }

        mutating func atXY(col: Int, row: Int) {
            self.isActive = true
            self.cursorCol = min(max(col, 0), self.cols - 1)
            self.cursorRow = min(max(row, 0), self.rows - 1)
        }

        mutating func emit(_ byte: UInt8) {
            guard self.isActive else { return }
            let idx = self.cursorRow * self.cols + self.cursorCol
            if idx >= 0 && idx < self.cells.count {
                self.cells[idx] = byte
            }
            self.advanceCursor()
        }

        mutating func newline() {
            guard self.isActive else { return }
            self.cursorCol = 0
            self.cursorRow += 1
            if self.cursorRow >= self.rows {
                self.scrollUp()
            }
        }

        private mutating func advanceCursor() {
            self.cursorCol += 1
            if self.cursorCol >= self.cols {
                self.cursorCol = 0
                self.cursorRow += 1
                if self.cursorRow >= self.rows {
                    self.scrollUp()
                }
            }
        }

        private mutating func scrollUp() {
            guard self.rows > 1 else {
                self.cursorRow = 0
                return
            }
            for r in 0..<(self.rows - 1) {
                let dst = r * self.cols
                let src = (r + 1) * self.cols
                for c in 0..<self.cols {
                    self.cells[dst + c] = self.cells[src + c]
                }
            }
            let last = (self.rows - 1) * self.cols
            for c in 0..<self.cols {
                self.cells[last + c] = 32
            }
            self.cursorRow = self.rows - 1
        }

        func render() -> String {
            var lines: [String] = []
            lines.reserveCapacity(self.rows)
            for r in 0..<self.rows {
                let start = r * self.cols
                let slice = self.cells[start..<(start + self.cols)]
                lines.append(String(bytes: slice, encoding: .ascii) ?? String(repeating: " ", count: self.cols))
            }
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Facility word registrations (ANS word set 10 — structures)

    private func alignStructureOffset() {
        while (self.structureOffset & 7) != 0 {
            self.structureOffset += 1
        }
    }

    /// Patch the latest CREATE word to DOES> @ + (field offset stored in its data cell).
    private func patchLatestCreateWithDoesFetchPlus() {
        let defsHeadCell = self.readCell(self.CURRENT)
        let latest = self.readCell(defsHeadCell)
        if latest == 0 {
            self.throwIllegalArgument("? +FIELD without CREATE")
            return
        }
        let cfa = self.getCFA(latest)
        let doesStart = self.readCell(self.DP_ADDR)
        self.push(self.docolID); self.comma()
        self.push(self.fetchID); self.comma()
        self.push(self.plusID); self.comma()
        self.push(self.exitID); self.comma()
        let doesCodeAddr = doesStart
        self.writeCell(Int(cfa), self.dodoesID)
        self.writeCell(Int(cfa) + 8, doesCodeAddr)
    }

    /// ANS +FIELD — ( u "<spaces>name" -- ) immediate; create offset field word, advance structure size.
    private func addStructureField(size: Cell, name: String) {
        if name.isEmpty {
            self.throwZeroLengthName("? +FIELD needs a name")
            return
        }
        let offset = self.structureOffset
        self.createWord(name: name, immediate: false)
        let dataAddr = self.readCell(self.DP_ADDR) + 16
        self.push(self.createRuntimeID); self.comma()
        self.push(dataAddr); self.comma()
        self.writeCell(dataAddr, offset)
        self.writeCell(self.DP_ADDR, dataAddr + 8)
        self.patchLatestCreateWithDoesFetchPlus()
        self.structureOffset += size
    }

    /// ANS END-STRUCTURE — create size constant from accumulated structure offset.
    private func finishStructure(name: String) {
        if name.isEmpty {
            self.throwZeroLengthName("? END-STRUCTURE needs a name")
            return
        }
        let size = self.structureOffset
        self.createWord(name: name, immediate: false)
        self.push(self.docolID); self.comma()
        self.push(self.litID); self.comma()
        self.push(size); self.comma()
        self.push(self.exitID); self.comma()
        self.structureOffset = 0
        self.structureActive = false
    }

    private func registerFacilityConstant(_ name: String, _ value: Cell) {
        self.createWord(name: name, immediate: false)
        self.push(self.docolID); self.comma()
        self.push(self.litID); self.comma()
        self.push(value); self.comma()
        self.push(self.exitID); self.comma()
    }

    private func registerFacilityWords() {
        _ = register("BEGIN-STRUCTURE", immediate: true) {
            let name = self.parseWord()
            if name.isEmpty {
                self.throwZeroLengthName("? BEGIN-STRUCTURE needs a name")
                return
            }
            self.structurePendingName = name
            self.structureOffset = 0
            self.structureActive = true
            // struct-sys placeholder (consumed by END-STRUCTURE per ANS usage).
            self.push(0)
        }

        _ = register("END-STRUCTURE", immediate: true) {
            if self.spGet() > 1 {
                _ = self.pop()
            }
            let name = self.structurePendingName
            if name.isEmpty {
                self.throwZeroLengthName("? END-STRUCTURE without BEGIN-STRUCTURE name")
                return
            }
            self.finishStructure(name: name)
            self.structurePendingName = ""
        }

        _ = register("+FIELD", immediate: true) {
            let size = self.pop()
            if self.throwActive { return }
            let name = self.parseWord()
            self.addStructureField(size: size, name: name)
        }

        _ = register("FIELD:", immediate: true) {
            self.alignStructureOffset()
            let name = self.parseWord()
            self.addStructureField(size: 8, name: name)
        }

        _ = register("CFIELD:", immediate: true) {
            let name = self.parseWord()
            self.addStructureField(size: 1, name: name)
        }

        _ = register("PAGE") {
            self.facilityTerminal.page()
            self.clearScreenRequested = true
            self.terminalRefreshPending = true
            self.flushTerminalRefreshIfNeeded()
        }

        _ = register("AT-XY") {
            let row = Int(self.pop())
            let col = Int(self.pop())
            if self.throwActive { return }
            self.facilityTerminal.atXY(col: col, row: row)
        }

        _ = register("MS") {
            let ms = max(0, Int(self.pop()))
            if let cb = self.onMsDelayRequested {
                self.waitingForMs = true
                cb(ms) { self.resumeAfterMs() }
                return
            }
            if ms > 0 {
                Thread.sleep(forTimeInterval: Double(ms) / 1000.0)
            }
        }

        _ = register("TIME&DATE") {
            let now = Date()
            let cal = Calendar.current
            let sec = cal.component(.second, from: now)
            let min = cal.component(.minute, from: now)
            let hr = cal.component(.hour, from: now)
            let day = cal.component(.day, from: now)
            let mon = cal.component(.month, from: now)
            let yr = cal.component(.year, from: now)
            self.push(Cell(sec))
            self.push(Cell(min))
            self.push(Cell(hr))
            self.push(Cell(day))
            self.push(Cell(mon))
            self.push(Cell(yr))
        }

        _ = register("EKEY") {
            if let ev = self.dequeueExtendedKey() {
                self.push(ev)
                return
            }
            self.waitingForExtendedKey = true
            return
        }

        _ = register("EKEY?") {
            self.push(self.extendedKeyQueue.isEmpty ? 0 : -1)
        }

        _ = register("EKEY>CHAR") {
            let x = Int(self.pop())
            if self.isCharKeyEvent(x) {
                self.push(x & 0xFF)
                self.push(-1)
            } else {
                self.push(x)
                self.push(0)
            }
        }

        _ = register("EKEY>FKEY") {
            let x = Int(self.pop())
            if self.isFKeyEvent(x) {
                self.push(x & 0xFFFFFF)
                self.push(-1)
            } else {
                self.push(x)
                self.push(0)
            }
        }

        _ = register("EMIT?") {
            self.push(-1)
        }

        let fk = TZForth.FacilityFKey.self
        self.registerFacilityConstant("K-LEFT", Cell(fk.left))
        self.registerFacilityConstant("K-RIGHT", Cell(fk.right))
        self.registerFacilityConstant("K-UP", Cell(fk.up))
        self.registerFacilityConstant("K-DOWN", Cell(fk.down))
        self.registerFacilityConstant("K-HOME", Cell(fk.home))
        self.registerFacilityConstant("K-END", Cell(fk.end))
        self.registerFacilityConstant("K-PRIOR", Cell(fk.prior))
        self.registerFacilityConstant("K-NEXT", Cell(fk.next))
        self.registerFacilityConstant("K-INSERT", Cell(fk.insert))
        self.registerFacilityConstant("K-DELETE", Cell(fk.delete))
        self.registerFacilityConstant("K-F1", Cell(fk.f1))
        self.registerFacilityConstant("K-F2", Cell(fk.f2))
        self.registerFacilityConstant("K-F3", Cell(fk.f3))
        self.registerFacilityConstant("K-F4", Cell(fk.f4))
        self.registerFacilityConstant("K-F5", Cell(fk.f5))
        self.registerFacilityConstant("K-F6", Cell(fk.f6))
        self.registerFacilityConstant("K-F7", Cell(fk.f7))
        self.registerFacilityConstant("K-F8", Cell(fk.f8))
        self.registerFacilityConstant("K-F9", Cell(fk.f9))
        self.registerFacilityConstant("K-F10", Cell(fk.f10))
        self.registerFacilityConstant("K-F11", Cell(fk.f11))
        self.registerFacilityConstant("K-F12", Cell(fk.f12))
        self.registerFacilityConstant("K-SHIFT-MASK", Cell(fk.shiftMask))
        self.registerFacilityConstant("K-CTRL-MASK", Cell(fk.ctrlMask))
        self.registerFacilityConstant("K-ALT-MASK", Cell(fk.altMask))
    }

    // MARK: - File-Access word registrations (ANS word set 11)

    private func registerFileAccessWords() {
        _ = register("R/O") { self.push(self.FAM_RDONLY) }
        _ = register("W/O") { self.push(self.FAM_WRONLY) }
        _ = register("R/W") { self.push(self.FAM_RDWR) }
        _ = register("BIN") { self.push(self.pop() | self.FAM_BIN) }

        _ = register("OPEN-FILE") {
            let fam = self.pop()
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            let url = self.pathURLFromCounted(caddr, u)
            let (fid, ior) = self.openFileAtPath(url.path, fam: fam, create: false)
            self.push(fid)
            self.push(ior)
        }

        _ = register("CREATE-FILE") {
            let fam = self.pop()
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            let url = self.pathURLFromCounted(caddr, u)
            let (fid, ior) = self.openFileAtPath(url.path, fam: fam, create: true)
            self.push(fid)
            self.push(ior)
        }

        _ = register("CLOSE-FILE") {
            let fileId = Int(self.pop())
            self.push(self.closeFileEntry(fileId, flush: true))
        }

        _ = register("DELETE-FILE") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            let url = self.pathURLFromCounted(caddr, u)
            do {
                try FileManager.default.removeItem(at: url)
                self.push(self.FILE_IO_SUCCESS)
            } catch {
                self.push(self.FILE_IO_ERROR)
            }
        }

        _ = register("RENAME-FILE") {
            let u2 = Int(self.pop())
            let caddr2 = Int(self.pop())
            let u1 = Int(self.pop())
            let caddr1 = Int(self.pop())
            let from = self.pathURLFromCounted(caddr1, u1)
            let to = self.pathURLFromCounted(caddr2, u2)
            do {
                try FileManager.default.moveItem(at: from, to: to)
                self.push(self.FILE_IO_SUCCESS)
            } catch {
                self.push(self.FILE_IO_ERROR)
            }
        }

        _ = register("READ-FILE") {
            let fileId = Int(self.pop())
            let u1 = Int(self.pop())
            let caddr = Int(self.pop())
            guard u1 >= 0, u1 <= self.memory.count,
                  var entry = self.openFiles[fileId], entry.isOpen, self.famAllowsRead(entry.fam) else {
                self.push(0); self.push(self.FILE_IO_ERROR); return
            }
            let avail = max(0, entry.data.count - entry.position)
            let n = min(u1, avail)
            for i in 0..<n {
                self.writeByte(caddr + i, entry.data[entry.position + i])
            }
            entry.position += n
            self.openFiles[fileId] = entry
            self.push(Cell(n))
            self.push(self.FILE_IO_SUCCESS)
        }

        _ = register("WRITE-FILE") {
            let fileId = Int(self.pop())
            let u1 = Int(self.pop())
            let caddr = Int(self.pop())
            guard u1 >= 0, u1 <= self.memory.count,
                  var entry = self.openFiles[fileId], entry.isOpen, self.famAllowsWrite(entry.fam) else {
                self.push(self.FILE_IO_ERROR); return
            }
            let needed = entry.position + u1
            if needed > entry.data.count {
                let addCount = needed - entry.data.count
                if addCount > 0 {
                    entry.data.append(contentsOf: repeatElement(UInt8(0), count: addCount))
                }
            }
            for i in 0..<u1 {
                entry.data[entry.position + i] = self.readByte(caddr + i)
            }
            entry.position += u1
            entry.writeDirty = true
            self.openFiles[fileId] = entry
            self.push(self.FILE_IO_SUCCESS)
        }

        _ = register("READ-LINE") {
            let fileId = Int(self.pop())
            let u1 = Int(self.pop())
            let caddr = Int(self.pop())
            let (u2, flag, ior) = self.readLineFromFile(fileId, buffer: caddr, maxLen: u1)
            self.push(Cell(u2))
            self.push(flag ? -1 : 0)
            self.push(ior)
        }

        _ = register("WRITE-LINE") {
            let fileId = Int(self.pop())
            let u1 = Int(self.pop())
            let caddr = Int(self.pop())
            guard var entry = self.openFiles[fileId], entry.isOpen, self.famAllowsWrite(entry.fam) else {
                self.push(self.FILE_IO_ERROR); return
            }
            let needed = entry.position + u1 + 1
            if needed > entry.data.count {
                entry.data.append(contentsOf: repeatElement(UInt8(0), count: needed - entry.data.count))
            }
            for i in 0..<u1 {
                entry.data[entry.position + i] = self.readByte(caddr + i)
            }
            entry.data[entry.position + u1] = 10
            entry.position += u1 + 1
            entry.writeDirty = true
            self.openFiles[fileId] = entry
            self.push(self.FILE_IO_SUCCESS)
        }

        _ = register("FILE-POSITION") {
            let fileId = Int(self.pop())
            guard let entry = self.openFiles[fileId], entry.isOpen else {
                self.push(0); self.push(0); self.push(self.FILE_IO_ERROR); return
            }
            self.pushUD(UInt64(entry.position))
            self.push(self.FILE_IO_SUCCESS)
        }

        _ = register("FILE-SIZE") {
            let fileId = Int(self.pop())
            guard fileId != 0, let entry = self.openFiles[fileId], entry.isOpen else {
                self.push(0); self.push(0); self.push(self.FILE_IO_ERROR); return
            }
            self.pushUD(UInt64(entry.data.count))
            self.push(self.FILE_IO_SUCCESS)
        }

        _ = register("REPOSITION-FILE") {
            let fileId = Int(self.pop())
            let ud = self.popUD()
            guard var entry = self.openFiles[fileId], entry.isOpen else {
                self.push(self.FILE_IO_ERROR); return
            }
            let pos = Int(ud)
            if pos < 0 || pos > entry.data.count {
                self.push(self.FILE_IO_ERROR); return
            }
            entry.position = pos
            self.openFiles[fileId] = entry
            self.push(self.FILE_IO_SUCCESS)
        }

        _ = register("RESIZE-FILE") {
            let fileId = Int(self.pop())
            let ud = self.popUD()
            guard var entry = self.openFiles[fileId], entry.isOpen, self.famAllowsWrite(entry.fam) else {
                self.push(self.FILE_IO_ERROR); return
            }
            let newSize = Int(ud)
            if newSize < 0 {
                self.push(self.FILE_IO_ERROR); return
            }
            if newSize > entry.data.count {
                entry.data.append(contentsOf: repeatElement(UInt8(0), count: newSize - entry.data.count))
            } else if newSize < entry.data.count {
                entry.data = entry.data.prefix(newSize)
            }
            if entry.position > newSize { entry.position = newSize }
            entry.writeDirty = true
            self.openFiles[fileId] = entry
            self.push(self.FILE_IO_SUCCESS)
        }

        _ = register("FILE-STATUS") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            let path = self.pathURLFromCounted(caddr, u).path
            let exists = FileManager.default.fileExists(atPath: path)
            self.push(exists ? 0 : -1)
            self.push(exists ? self.FILE_IO_SUCCESS : self.FILE_IO_ERROR)
        }

        _ = register("FLUSH-FILE") {
            let fileId = Int(self.pop())
            self.push(self.flushFileEntry(fileId))
        }

        _ = register("INCLUDE-FILE") {
            let fileId = Int(self.pop())
            self.includeFileInterpret(fileId, closeWhenDone: true)
            if self.throwActive { return }
        }

        _ = register("INCLUDED") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            self.includedFromSpec(caddr, u)
        }

        _ = register("INCLUDE", immediate: true) {
            let name = self.parseWord()
            if name.isEmpty { self.throwZeroLengthName("? INCLUDE needs a name"); return }
            let bytes = Array(name.utf8)
            let slot = self.allocateStringBufferSlot()
            for (i, b) in bytes.enumerated() {
                self.writeByte(slot + i, b)
            }
            self.includedFromSpec(slot, bytes.count)
        }

        _ = register("REQUIRED") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            self.requiredFromSpec(caddr, u)
        }

        _ = register("REQUIRE") {
            let (caddr, u) = self.parseNameFromInput()
            if u == 0 {
                self.throwZeroLengthName("? REQUIRE needs a name")
                return
            }
            self.requiredFromSpec(caddr, u)
        }

        _ = register(".INCLUDED") {
            self.displayIncludedNames()
        }
    }

    private func flushFileEntry(_ fileId: Int) -> Cell {
        guard var entry = openFiles[fileId], entry.isOpen, entry.writeDirty else { return FILE_IO_SUCCESS }
        do {
            try entry.data.write(to: URL(fileURLWithPath: entry.path))
            entry.writeDirty = false
            openFiles[fileId] = entry
            return FILE_IO_SUCCESS
        } catch {
            return FILE_IO_ERROR
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

        self.feedLine(": >NFA >HEADER 8 + ;   ( cfa -- nfa )")

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

        // Search-Order compatibility: VOCABULARY is a thin layer over WORDLIST (ANS 2012).
        // Executing a vocab prepends its word list to the search order.
        // WORDLIST uses the CREATE data field as the list head; DROP discards the duplicate wid.
        self.feedLine(": VOCABULARY CREATE WORDLIST DROP DOES> PUSH-ORDER ;")
        self.feedLine("VOCABULARY EDITOR")
        self.feedLine("VOCABULARY ASSEMBLER")

        // file-echo variable (user can do: file-echo ON   or   file-echo OFF ).
        // Controls whether FLOAD / INCLUDE / INCLUDE-FILE echo each source line as it loads.
        // Created via the VARIABLE word so it appears in WORDS / SEE / FORGET etc.
        // Default is 0 (off) because the data cell lives in the zeroed memory area.
        self.feedLine("VARIABLE FILE-ECHO")
        self.feedLine("VARIABLE WARNING")
        self.feedLine("-1 WARNING !")
        self.feedLine("VARIABLE INCLUDED-NAMES")
        self.feedLine("VARIABLE BLOCK-SIZE")
        self.feedLine("VARIABLE DEFAULT-BLOCK-COUNT")
        self.feedLine("VARIABLE BLOCK-BUFFER-COUNT")
        self.feedLine("VARIABLE BLK")
        self.feedLine("VARIABLE BLOCK-FILE")
        self.feedLine("VARIABLE SCR")
        self.feedLine(": C/L BLOCK-SIZE @ 16 / ;")
        self.feedLine(": ERASE 0 FILL ;")  // high-level so SEE shows source (0 FILL)
        self.feedLine(": HOLDS ( c-addr u -- ) BEGIN DUP WHILE 1- 2DUP + C@ HOLD REPEAT 2DROP ;")
        self.feedLine(": BUFFER: CREATE ALLOT ALIGN ;")

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

        self.warningAddr = 0
        let hdrWarn = self.findWord("WARNING")
        if hdrWarn != 0 {
            let cfa = self.getCFA(hdrWarn)
            if self.readCell(Int(cfa)) == self.docolID {
                if self.readCell(Int(cfa) + 8) == self.litID {
                    self.warningAddr = self.readCell(Int(cfa) + 16)
                }
            }
        }
        if self.warningAddr != 0 {
            self.writeCell(self.warningAddr, -1)
        }

        let hdrIn = self.findWord("INCLUDED-NAMES")
        if hdrIn != 0 {
            let cfa = self.getCFA(hdrIn)
            if self.readCell(Int(cfa)) == self.docolID {
                if self.readCell(Int(cfa) + 8) == self.litID {
                    self.includedNamesVarAddr = self.readCell(Int(cfa) + 16)
                }
            }
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

    func runInterpreter() {
        validateAndRepairSystemState()
        errorFlag = false

        while ((!inputQueue.isEmpty || self.conditionalSkipDiscardThroughQuote || self.pendingRestoredFloadRefill())
               && !errorFlag && !exitReq && !throwActive) {
            if self.inputQueue.isEmpty && self.pendingRestoredFloadRefill() {
                if !self.tryRefillInterpreterFileInput() { break }
            }
            if self.conditionalSkipDiscardThroughQuote {
                self.syncInputQueueFromSourceIfNeeded()
                if self.discardThroughClosingQuoteIfPresent() {
                    self.conditionalSkipDiscardThroughQuote = false
                } else {
                    break
                }
                continue
            }
            if self.conditionalSkipDepth > 0 {
                let skipResult = self.continuePendingConditionalSkip()
                if skipResult == .pending { break }
                if self.throwActive || self.errorFlag { break }
                continue
            }
            if readCell(STATE) == 0 && inputQueue.isEmpty {
                self.syncInputQueueFromSourceIfNeeded()
            }
            let name = parseWord()
            if name.isEmpty {
                if self.tryRefillInterpreterFileInput() { continue }
                break
            }

            if name.uppercased() == "BASE", self.readCell(self.STATE) == 0,
               self.peekNextParsedWord() == "!", self.spGet() == 1, self.loadNesting > 0 {
                self.push(10)
            }

            // Hayes prelimtest.fth: before `n >IN +!`, >IN must point at the first decoy
            // character (past inter-word whitespace). Only advance for !/+! storing into >IN.
            if readCell(STATE) == 0 && (name == "+!" || name == "!") {
                let depth = Int(self.spGet() - 1)
                if depth >= 1 {
                    let addrOnStack = Int(self.readCell(self.stackBase + (depth - 1) * 8))
                    if addrOnStack == self.IN {
                        while let b = inputQueue.first, b <= 32 && b != 10 && b != 13 {
                            _ = self.consumeInput()
                        }
                    }
                }
            }
            if name == "]" && self.bracketCompileDepth > 0 {
                self.bracketCompileDepth -= 1
            }

            if self.readCell(self.STATE) != 0 {
                let upper = name.uppercased()
                if upper == "LOCAL" || upper == "END-LOCALS" {
                    let probe = self.findWord(name)
                    if probe > 0,
                       (self.readByte(Int(probe) + 8) & self.FLAG_IMMEDIATE) != 0 {
                        if upper == "LOCAL" {
                            self.runHayesLocalDeclImmediate()
                        } else {
                            self.runHayesEndLocalsImmediate()
                        }
                        if self.throwActive { break }
                        continue
                    }
                }
            }

            let hdr = findWord(name)
            if hdr == Cell(-1) {
                if let idx = self.localIndexDuringCompile(name) {
                    if self.readCell(self.STATE) != 0 {
                        self.compileLocalFetch(idx)
                    } else {
                        self.kernelThrow(StdThrow.undefinedWord, message: "? local \(name) undefined in interpret state")
                        if throwActive { break }
                    }
                } else {
                    self.kernelThrow(StdThrow.undefinedWord, message: "? \(name)")
                    if throwActive { break }
                }
            } else if hdr != 0 {
                let cfa = getCFA(hdr)
                let first = readCell(Int(cfa))

                let compiling = readCell(STATE) != 0
                let immediate = (readByte(Int(hdr) + 8) & FLAG_IMMEDIATE) != 0

                if compiling && !immediate {
                    if first == synonymID {
                        let target = readCell(Int(cfa) + 8)
                        emitCompileReference(xt: target)
                    } else {
                        emitCompileReference(xt: cfa)
                    }
                } else {
                    // Execute — realign queue so parsing words inside xt (FLOAD under CATCH, etc.)
                    // can see tokens after the word just parsed (e.g. `safe-fload myfile.fth`).
                    if !compiling {
                        self.realignInputQueueFromSource()
                    }
                    // Hayes localstest helpers LOCAL / END-LOCALS parse names at compile time; their
                    // bodies must run in interpret mode. ?REPEAT / ?DONE need compile state (POSTPONE).
                    let immLocalHelper = name.uppercased() == "LOCAL" || name.uppercased() == "END-LOCALS"
                    let immColonInterpretBody = compiling && immediate && first == self.docolID && immLocalHelper
                    let savedCompileState = immColonInterpretBody ? self.readCell(self.STATE) : nil
                    if immColonInterpretBody {
                        self.realignInputQueueFromSource()
                        self.writeCell(self.STATE, 0)
                    }
                    // Immediate colon definitions (?REPEAT etc.) interpret their bodies even while compiling.
                    // ANS: STATE stays true during compilation (including inside immediate colon bodies).
                    // Only t6in-style `0 >IN !` inside a colon should restore the outer parse offset.
                    let watchInZero = !compiling && first == self.docolID
                    let savedOuterIn = watchInZero ? self.readCell(self.IN) : nil
                    let savedOuterQueue = watchInZero ? self.inputQueue : []
                    if watchInZero {
                        self.inVarZeroedInColon = false
                        self.inVarZeroFetchAfterZero = false
                    }
                    execute(cfa: cfa, firstCell: first)
                    if let saved = savedCompileState {
                        self.writeCell(self.STATE, saved)
                        // WORD/COUNT inside LOCAL advance >IN via consumeInput; do not rewind queue.
                    }
                    // Hayes filetest SI2: RESTORE-INPUT inside a colon may replace SOURCE; restore the
                    // enclosing FLOAD line snapshot so this runInterpreter pass does not parse it,
                    // unless RESTORE-INPUT is continuing the outer parse on a later file line.
                    if watchInZero,
                       !self.floadRestoreInputContinuation,
                       !self.blockInterpretActive,
                       self.loadNesting > 0,
                       self.evaluateNesting == 0,
                       self.inputSourceStack.count >= 2,
                       let lineFrame = self.inputSourceStack.last {
                        var sourceChanged = self.currentSourceLen != lineFrame.sourceLen
                        if !sourceChanged {
                            for i in 0..<lineFrame.sourceLen {
                                if self.readByte(self.SOURCE_BUFFER + i) != lineFrame.sourceBytes[i] {
                                    sourceChanged = true
                                    break
                                }
                            }
                        }
                        if sourceChanged {
                            self.currentSourceLen = lineFrame.sourceLen
                            for i in 0..<lineFrame.sourceLen {
                                self.writeByte(self.SOURCE_BUFFER + i, lineFrame.sourceBytes[i])
                            }
                            // Line snapshot was taken at line start; mark this FLOAD line finished.
                            self.writeCell(self.IN, Cell(lineFrame.sourceLen))
                            self.inputQueue.removeAll(keepingCapacity: true)
                        }
                    }
                    if watchInZero,
                       self.inVarZeroedInColon,
                       let saved = savedOuterIn,
                       self.returnStackPointer <= 1,
                       self.inputQueue == savedOuterQueue,
                       self.inVarZeroFetchAfterZero {
                        self.writeCell(self.IN, saved)
                        self.realignInputQueueFromSource()
                    } else if watchInZero,
                              self.inVarZeroedInColon,
                              self.returnStackPointer <= 1,
                              !self.inVarZeroFetchAfterZero {
                        self.realignInputQueueFromSource()
                    } else if watchInZero, let saved = savedOuterIn, !self.inputQueue.isEmpty {
                        let nowIn = self.readCell(self.IN)
                        // Hayes ?~~ skips backward; ~ sets >IN to end-of-line — resync queue.
                        if (nowIn < saved && nowIn > 0) || nowIn >= Cell(self.currentSourceLen) {
                            self.realignInputQueueFromSource()
                        }
                    }
                    if throwActive { break }
                    if self.isBlockingOnHost {
                        // A blocking input/delay word (KEY / EKEY / MS) has suspended.
                        break
                    }
                }
            } else if let charLit = self.parseCharLiteralToken(name) {
                if self.readCell(self.STATE) != 0 {
                    self.push(litID); self.comma()
                    self.push(Cell(charLit)); self.comma()
                } else {
                    self.push(Cell(charLit))
                }
            } else {
                // Try number, respecting current BASE (supports 2..36, signs, letters A-Z).
                // ANS Double-Number 8.3.1: a token ending in '.' becomes a double-cell literal.
                let b = Int(max(2, min(36, self.readCell(self.BASE))))
                if let d = self.parseTextDouble(name, base: b) {
                    if self.readCell(self.STATE) != 0 {
                        self.compileDoubleLiteral(d.lo, d.hi)
                    } else {
                        self.push(d.lo)
                        self.push(d.hi)
                    }
                } else if let f = self.parseTextFloat(name) {
                    if self.readCell(self.STATE) != 0 {
                        self.compileFloatLiteral(f)
                    } else {
                        self.fpush(f)
                    }
                } else if let num = self.parseTextNumber(name, base: b) {
                    if readCell(STATE) != 0 {
                        let nextWord = self.peekNextParsedWord()
                        if self.wordNeedsCompileTimeStackArg(nextWord) {
                            self.push(Cell(num))
                        } else {
                            self.push(litID); self.comma()
                            self.push(num); self.comma()
                        }
                    } else {
                        push(num)
                    }
                } else {
                    let msg = readCell(STATE) != 0 ? "? \(name) ?  (while compiling)" : "? \(name)"
                    kernelThrow(StdThrow.undefinedWord, message: msg)
                    if throwActive { break }
                }
            }
        }

        // Classic Forth behavior: after successfully interpreting a complete *interactive*
        // (top-level REPL) line in interpret mode, print "OK" followed by newline.
        // During loaded-source interpret (loadNesting > 0), we never emit per-line OKs --
        // only explicit FILE-ECHO source lines (if enabled) + whatever regular output the
        // interpreted source actually produces (., TYPE, EMIT, etc.).
        //
        // (No leading space so that after ".s" or CR it doesn't look indented,
        // and after "." we get the single space that "." already emitted.)
        //
        // Do not print OK if we suspended for a blocking input word like KEY;
        // the OK will be printed when the line is resumed and completed after provideKey.
        if !errorFlag && readCell(STATE) == 0 && !self.isBlockingOnHost && loadNesting == 0 && evaluateNesting == 0 {
            tell("OK\n")
        }

        // Do not clear errorFlag or do stack/STATE recovery here.
        // The caller (feedLine) will see errorFlag and call recoverFromError(),
        // which does a complete job (drain queue + abort partial definitions + reset).
    }

    /// Keep >IN within the current SOURCE line (Hayes ?~~ can add negative deltas).
    func clampInOffset(_ value: Cell) -> Cell {
        let n = Int(value)
        if n < 0 { return 0 }
        if n > self.currentSourceLen { return Cell(self.currentSourceLen) }
        return value
    }

    private func writeInOffset(_ value: Cell) {
        self.writeCell(self.IN, self.clampInOffset(value))
    }

    /// Called when the >IN offset variable is modified (! / +!) so the byte queue matches SOURCE.
    /// Hayes prelimtest uses >IN +! / SOURCE >IN ! inside colon words (?~~, Error, ~).
    private func notifyInChanged(storedValue: Cell, previousValue: Cell, isStore: Bool) {
        if storedValue != previousValue {
            let evalRestart = isStore && storedValue == 0 && previousValue > 0 && self.evaluateNesting > 0
            if storedValue != 0 || evalRestart {
                self.realignInputQueueFromSource()
                self.adjustHayesTildeSkipIfNeeded()
            }
        }
    }

    /// Hayes ?~~ does `2* >IN +!` (-2). With TZForth >IN at the first unparsed byte, that can
    /// land on the first `~` of `?~~` (or the penultimate char of ?T~ / ?F~). Advance to the
    /// trailing `~` so the next token is `~` (end-of-line skip), not undefined `~~`.
    private func adjustHayesTildeSkipIfNeeded() {
        let pos = Int(self.readCell(self.IN))
        guard pos >= 0 && pos < self.currentSourceLen else { return }
        let ch = self.readByte(self.SOURCE_BUFFER + pos)
        if ch == 126 {
            if pos + 1 < self.currentSourceLen,
               self.readByte(self.SOURCE_BUFFER + pos + 1) == 126 {
                self.writeCell(self.IN, Cell(pos + 1))
                self.realignInputQueueFromSource()
            }
            return
        }
        guard pos + 1 < self.currentSourceLen else { return }
        if self.readByte(self.SOURCE_BUFFER + pos + 1) == 126 {
            self.writeCell(self.IN, Cell(pos + 1))
            self.realignInputQueueFromSource()
        }
    }

    /// Rebuild the byte queue from SOURCE at >IN (unparsed tail of the current line).
    func realignInputQueueFromSource() {
        let pos = Int(self.clampInOffset(self.readCell(self.IN)))
        self.inputQueue.removeAll(keepingCapacity: true)
        guard pos < self.currentSourceLen else { return }
        for i in pos..<self.currentSourceLen {
            self.inputQueue.append(self.readByte(self.SOURCE_BUFFER + i))
        }
        if self.inputQueue.last != 10 {
            self.inputQueue.append(10)
        }
    }

    /// True when `\` was just parsed and the rest of this line is only `S`/`s` (Hayes `\S` stop).
    private func inputQueueLooksLikeSlashSAfterBackslash() -> Bool {
        var idx = 0
        while idx < self.inputQueue.count {
            let b = self.inputQueue[idx]
            if b == 10 || b == 13 { break }
            if b > 32 { break }
            idx += 1
        }
        guard idx < self.inputQueue.count else { return false }
        let b = self.inputQueue[idx]
        guard b == 83 || b == 115 else { return false } // S or s
        idx += 1
        while idx < self.inputQueue.count {
            let c = self.inputQueue[idx]
            if c == 10 || c == 13 { return true }
            if c > 32 { return false }
            idx += 1
        }
        return true
    }

    /// Bytes from >IN through end of current SOURCE (unparsed tail of this line).
    private func unparsedInputTailBytes(from pos: Int) -> [UInt8] {
        guard pos < self.currentSourceLen else { return [] }
        var bytes: [UInt8] = []
        for i in pos..<self.currentSourceLen {
            bytes.append(self.readByte(self.SOURCE_BUFFER + i))
        }
        return bytes
    }

    /// Re-offer an unparsed tail after a synchronous REPL FLOAD returns.
    private func restoreUnparsedInputTail(in: Cell, tail: [UInt8]) {
        self.writeCell(self.IN, `in`)
        self.inputQueue.removeAll(keepingCapacity: true)
        for b in tail { self.inputQueue.append(b) }
        if self.inputQueue.last != 10 && self.inputQueue.last != 13 {
            self.inputQueue.append(10)
        }
    }

    /// Let the host repaint during long nested FLOAD (same feedLine, main-thread interpret).
    private func yieldToHostUIIfNeeded() {
        guard self.onOutput != nil, Thread.isMainThread else { return }
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0))
    }

    /// Move the active interpreter file to EOF (F-PC \\S: seqhandle endfile).
    private func seekActiveInterpreterFileToEnd() {
        guard let fid = self.activeInterpreterFileId(),
              var entry = self.openFiles[fid], entry.isOpen else { return }
        entry.position = entry.data.count
        self.openFiles[fid] = entry
    }

    /// Shared \\S / `\ s` stop (ANS / F-PC model):
    /// - IBRESET / ignore rest of line: pin >IN at #TIB end, drain input queue
    /// - endfile: seek active load file to EOF (no further REFILL lines)
    /// - loadline off: fileInterpretStopStack marks innermost includeFileInterpret done
    /// Does not alter STATE (compile/interpret preserved across nested FLOAD).
    private func applySlashSStop() {
        while !self.inputQueue.isEmpty {
            let c = self.consumeInput() ?? 0
            if c == 10 || c == 13 { break }
        }
        self.writeCell(self.IN, Cell(self.currentSourceLen))
        self.inputQueue.removeAll(keepingCapacity: true)
        if self.loadNesting > 0, !self.fileInterpretStopStack.isEmpty {
            self.seekActiveInterpreterFileToEnd()
            self.fileInterpretStopStack[self.fileInterpretStopStack.count - 1] = true
        } else {
            self.replBatchStop = true
        }
    }

    /// SOURCE already holds the line at currentFileLineStart; advance the file cursor past it before REFILL.
    private func advanceInterpreterFilePastCurrentLineIfNeeded() {
        guard self.floadRestoreInputContinuation else { return }
        guard let fid = self.activeInterpreterFileId(),
              var entry = self.openFiles[fid], entry.isOpen,
              let lineStart = self.currentFileLineStart,
              entry.position == lineStart else { return }
        var pos = lineStart
        while pos < entry.data.count {
            let b = entry.data[pos]
            pos += 1
            if b == 10 { break }
            if b == 13 {
                if pos < entry.data.count && entry.data[pos] == 10 { pos += 1 }
                break
            }
        }
        entry.position = pos
        self.openFiles[fid] = entry
    }

    /// True when RESTORE-INPUT left the file mid-T{ and more lines remain to load.
    private func pendingRestoredFloadRefill() -> Bool {
        guard self.floadRestoreInputContinuation else { return false }
        guard self.inputQueue.isEmpty else { return false }
        guard self.loadNesting > 0, self.evaluateNesting == 0, self.readCell(self.STATE) == 0 else { return false }
        let pos = Int(self.readCell(self.IN))
        guard pos >= self.currentSourceLen else { return false }
        guard let fid = self.activeInterpreterFileId(),
              let entry = self.openFiles[fid], entry.isOpen,
              entry.position < entry.data.count else { return false }
        return true
    }

    /// Load the next file line when RESTORE-INPUT continued parsing past the outer FLOAD line (Hayes filetest SI2).
    private func tryRefillInterpreterFileInput() -> Bool {
        guard self.pendingRestoredFloadRefill() else { return false }
        guard let fid = self.activeInterpreterFileId() else { return false }
        self.advanceInterpreterFilePastCurrentLineIfNeeded()
        if self.refillFromFile(fid) {
            self.sourceLoadedByRefill = true
            return true
        }
        return false
    }

    /// When the byte queue is empty but >IN has not reached SOURCE end, refill the queue
    /// from SOURCE. Needed for parsing words (FLOAD, EDIT, …) invoked via EXECUTE/CATCH
    /// while the outer line still has unparsed tokens (e.g. `safe-fload myfile.fth`).
    private func syncInputQueueFromSourceIfNeeded() {
        guard self.inputQueue.isEmpty else { return }
        let pos = Int(self.readCell(self.IN))
        if pos >= self.currentSourceLen {
            if self.tryRefillInterpreterFileInput() { return }
        }
        // Hayes filetest SI2: RESTORE-INPUT inside a colon on this FLOAD line may replace
        // SOURCE; do not keep parsing the restored buffer here (next REFILL will handle it).
        if !self.floadRestoreInputContinuation,
           self.loadNesting > 0,
           self.inputSourceStack.count >= 2,
           let lineFrame = self.inputSourceStack.last {
            if self.currentSourceLen != lineFrame.sourceLen {
                return
            }
            for i in 0..<lineFrame.sourceLen {
                if self.readByte(self.SOURCE_BUFFER + i) != lineFrame.sourceBytes[i] {
                    return
                }
            }
        }
        guard pos < self.currentSourceLen else { return }
        self.realignInputQueueFromSource()
    }

    /// Parse the next word from SOURCE at >IN (used when the byte queue is empty).
    private func parseWordFromSourceAtIn() -> String {
        var pos = Int(self.readCell(self.IN))
        while pos < self.currentSourceLen {
            let b = self.readByte(self.SOURCE_BUFFER + pos)
            if b > 32 { break }
            pos += 1
        }
        if pos >= self.currentSourceLen {
            self.writeCell(self.IN, Cell(pos))
            return ""
        }
        var word: [UInt8] = []
        while pos < self.currentSourceLen {
            let b = self.readByte(self.SOURCE_BUFFER + pos)
            if b <= 32 { break }
            word.append(b)
            pos += 1
        }
        self.writeCell(self.IN, Cell(pos))
        var result = String(bytes: word, encoding: .utf8) ?? ""
        if !result.isEmpty {
            result = result.map { ch -> Character in
                switch ch {
                case "\u{2018}", "\u{2019}", "\u{201A}", "\u{201B}", "`", "\u{00B4}": return "'"
                default: return ch
                }
            }.reduce(into: "") { $0.append($1) }
        }
        return result
    }

    /// Parse the next name for TZForth parsing words (FLOAD, EDIT, …) that may run
    /// under EXECUTE/CATCH while the rest of the REPL line remains in SOURCE.
    private func parseWordForHostParsing() -> String {
        self.syncInputQueueFromSourceIfNeeded()
        let fromQueue = self.parseWord()
        if !fromQueue.isEmpty { return fromQueue }
        return self.parseWordFromSourceAtIn()
    }

    /// Peek the next word without consuming input (for compile-time stack-arg lookahead).
    private func peekNextParsedWord() -> String {
        let savedQueue = self.inputQueue
        let savedIn = self.readCell(self.IN)
        self.syncInputQueueFromSourceIfNeeded()
        let word = self.parseWord()
        self.inputQueue = savedQueue
        self.writeCell(self.IN, savedIn)
        return word
    }

    /// Immediates that take their numeric argument from the compile-time stack (not LIT).
    private func wordNeedsCompileTimeStackArg(_ word: String) -> Bool {
        switch word.uppercased() {
        case "CS-PICK", "CS-ROLL", "LITERAL", "COMPILE,":
            return true
        default:
            return false
        }
    }

    internal func parseWord() -> String {
        // ( ... ) comments can span lines during FLOAD when `)` is not on the `(` line.
        if self.inParenComment {
            while !self.inputQueue.isEmpty {
                let c = self.consumeInput() ?? 0
                if c == 41 {
                    self.inParenComment = false
                    break
                }
            }
            if self.inParenComment {
                return ""
            }
        }

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
    internal func consumeInput() -> UInt8? {
        if inputQueue.isEmpty { return nil }
        let b = inputQueue.removeFirst()
        let pos = readCell(IN)
        writeCell(IN, pos + 1)
        return b
    }

    /// Allocate the next 512-byte slot in the STRING_BUFFER ring (wraps at 4 KB).
    private func allocateStringBufferSlot() -> Int {
        let base = self.STRING_BUFFER + self.stringBufferAllocOffset
        self.stringBufferAllocOffset += self.STRING_BUFFER_SLOT_SIZE
        if self.stringBufferAllocOffset >= self.STRING_BUFFER_SIZE {
            self.stringBufferAllocOffset = 0
        }
        return base
    }

    // Helper used by WORD and CHAR (and string parsers). Consumes from inputQueue
    // (which receives appended lines from feedLine for REPL, or refillFromFile for loaded files).
    // Skips leading exact delims, collects until delim or line-end, builds counted string
    // (len byte + chars + trailing NUL) in the next STRING_BUFFER slot. Returns c-addr.
    // The trailing delim (if any) is left in queue. Transient — ring may reuse slots.
    internal func parseToWordBuffer(using delim: UInt8, ansWord: Bool = false) -> Cell {
        var collected: [UInt8] = []

        // Skip leading delimiters (exact ascii or smart-double for ")
        while !self.inputQueue.isEmpty {
            if !self.consumeDelim(delim) {
                break
            }
        }
        if ansWord || delim == 32 {
            // ANS WORD: skip leading spaces before the token (Hayes prelimtest MSG ab).
            while let b = self.inputQueue.first, b <= 32 && b != 10 && b != 13 {
                _ = self.consumeInput()
            }
        }

        // Collect chars until delimiter or line end. ANS WORD (ansWord) skips leading
        // spaces above but still collects interior spaces until the delimiter (Hayes
        // prelimtest .MSG( Pass #11: ... .MSG) and MSG ab) ).
        while !self.inputQueue.isEmpty {
            let b = self.inputQueue.first!
            if self.peekIsDelim(delim) || b == delim || b == 10 || b == 13 {
                break
            }
            if !ansWord && delim == 32 && b <= 32 {
                break
            }
            collected.append(self.consumeInput()!)
        }

        // Consume a closing delim if present (supports smart doubles for ")
        _ = self.consumeDelim(delim)

        let slot = self.allocateStringBufferSlot()
        let len = min(collected.count, self.STRING_BUFFER_MAX_COUNTED_CHARS)
        self.writeByte(slot, UInt8(len))
        for (i, b) in collected.prefix(len).enumerated() {
            self.writeByte(slot + 1 + i, b)
        }
        self.writeByte(slot + 1 + len, 0)
        return Cell(slot)
    }

    /// Parse an ANS S\" escaped string into STRING_BUFFER. Returns (char-addr, length).
    private func parseEscapedStringToBuffer() -> (Cell, Int) {
        // Skip opening double-quote (ascii or smart)
        while !self.inputQueue.isEmpty {
            if !self.consumeDelim(34) { break }
        }
        // Skip leading spaces before the string body (matches S" / WORD rules; Hayes SSQ*).
        while let b = self.inputQueue.first, b <= 32 && b != 10 && b != 13 {
            _ = self.consumeInput()
        }

        var collected: [UInt8] = []
        while !self.inputQueue.isEmpty {
            let b = self.inputQueue.first!
            if self.peekIsDelim(34) || b == 34 {
                _ = self.consumeDelim(34)
                break
            }
            if b == 10 || b == 13 { break }
            let ch = self.consumeInput()!
            if ch == 92 { // backslash escape
                guard let next = self.consumeInput() else { break }
                switch next {
                case 97: collected.append(7)   // \a BEL
                case 98: collected.append(8)   // \b BS
                case 101: collected.append(27) // \e ESC
                case 102: collected.append(12) // \f FF
                case 108: collected.append(10) // \l LF
                case 109: collected.append(13); collected.append(10) // \m CR/LF
                case 110: collected.append(10) // \n newline (LF here)
                case 113, 34: collected.append(34) // \q or \"
                case 114: collected.append(13) // \r CR
                case 116: collected.append(9)  // \t tab
                case 118: collected.append(11) // \v VT
                case 122: collected.append(0)  // \z NUL
                case 92: collected.append(92)  // \\
                case 120: // \xHH
                    var hex = ""
                    for _ in 0..<2 {
                        guard let hb = self.consumeInput() else { break }
                        hex.append(Character(UnicodeScalar(hb)))
                    }
                    if hex.count == 2, let val = UInt8(hex, radix: 16) {
                        collected.append(val)
                    }
                default:
                    collected.append(next)
                }
            } else {
                collected.append(ch)
            }
        }

        let slot = self.allocateStringBufferSlot()
        let len = min(collected.count, self.STRING_BUFFER_MAX_COUNTED_CHARS)
        self.writeByte(slot, UInt8(len))
        for (i, b) in collected.prefix(len).enumerated() {
            self.writeByte(slot + 1 + i, b)
        }
        self.writeByte(slot + 1 + len, 0)
        return (Cell(slot + 1), len)
    }

    /// Restore dictionary and search order from a MARKER storage block.
    private func applyMarkerRestore(storage: Int) {
        let savedHere = self.readCell(storage)
        let savedCurrent = self.readCell(storage + 8)
        let n = Int(self.readCell(storage + 16))
        if savedHere < self.kernelHere {
            self.throwIllegalArgument("? MARKER cannot restore past kernel")
            return
        }
        let headsBase = storage + 24
        let wlsBase = headsBase + n * self.CELL_SIZE
        var newOrder: [Cell] = []
        for i in 0..<n {
            let head = self.readCell(headsBase + i * self.CELL_SIZE)
            let wl = self.readCell(wlsBase + i * self.CELL_SIZE)
            self.writeCell(Int(wl), head)
            newOrder.append(wl)
        }
        self.searchOrder = newOrder
        self.writeCell(self.CURRENT, savedCurrent)
        self.writeCell(self.DP_ADDR, savedHere)
        self.dictionaryHighWater = savedHere
        self.validateAndRepairSystemState()
    }

    private func captureExceptionFrame(dataStackDepth: Cell, savedIp: Int) -> ExceptionFrame {
        self.syncInputQueueFromSourceIfNeeded()
        var sourceBytes: [UInt8] = []
        for i in 0..<self.currentSourceLen {
            sourceBytes.append(self.readByte(self.SOURCE_BUFFER + i))
        }
        var returnDepth = self.rspGet()
        // CATCH inside a colon started by execute: never unwind below that word's return frame.
        if self.dispatchedFromInnerThread && self.innerThreadStopRsp >= 0 {
            let minRsp = Cell(self.innerThreadStopRsp + 1)
            if returnDepth < minRsp { returnDepth = minRsp }
        }
        return ExceptionFrame(
            dataStackDepth: dataStackDepth,
            returnStackDepth: returnDepth,
            savedIp: savedIp,
            state: self.readCell(self.STATE),
            inputSourceStackDepth: self.inputSourceStack.count,
            loadNesting: self.loadNesting,
            evaluateNesting: self.evaluateNesting,
            interpreterInputFileId: self.interpreterInputFileId,
            currentSourceId: self.currentSourceId,
            currentSourceLen: self.currentSourceLen,
            sourceBytes: sourceBytes,
            inPos: self.readCell(self.IN),
            inputQueue: self.inputQueue,
            loopControlStack: self.loopControlStack,
            whileRepeatStack: self.whileRepeatStack,
            whileNestStack: self.whileNestStack,
            localFramesDepth: self.localFrames.count
        )
    }

    private func restoreExceptionFrame(_ frame: ExceptionFrame) {
        while self.inputSourceStack.count > frame.inputSourceStackDepth {
            self.popInputSourceFrame()
        }
        self.loadNesting = frame.loadNesting
        self.evaluateNesting = frame.evaluateNesting
        self.interpreterInputFileId = frame.interpreterInputFileId
        self.currentSourceId = frame.currentSourceId
        self.currentSourceLen = frame.currentSourceLen
        self.writeCell(self.IN, frame.inPos)
        for i in 0..<frame.currentSourceLen {
            self.writeByte(self.SOURCE_BUFFER + i, frame.sourceBytes[i])
        }
        self.inputQueue = frame.inputQueue
        self.loopControlStack = frame.loopControlStack
        self.whileRepeatStack = frame.whileRepeatStack
        self.whileNestStack = frame.whileNestStack
        while self.localFrames.count > frame.localFramesDepth {
            self.localFrames.removeLast()
        }
        while self.localFrameReturnDepth.count > frame.localFramesDepth {
            self.localFrameReturnDepth.removeLast()
        }
        self.writeCell(self.STATE, frame.state)
        self.rspSet(frame.returnStackDepth)
        self.ip = frame.savedIp
        self.waitingForKey = false
        self.exitReq = false
    }

    /// ANS CATCH core — execute xt under an exception frame; 0 or throw code on stack.
    private func performCatch(xt: Cell) {
        let stackDepth = self.spGet()
        let savedIp = self.ip
        let fromInnerThread = self.dispatchedFromInnerThread
        self.syncInputQueueFromSourceIfNeeded()
        self.exceptionFrames.append(self.captureExceptionFrame(dataStackDepth: stackDepth, savedIp: savedIp))
        let frameIndex = self.exceptionFrames.count - 1
        self.throwActive = false
        if xt < Cell(self.MAX_BUILTIN_ID) {
            self.execute(cfa: xt, firstCell: xt)
        } else {
            let firstCell = self.readCell(Int(xt))
            self.execute(cfa: xt, firstCell: firstCell)
        }
        // Success when our frame is still present — xt finished without unwinding to this CATCH
        // (includes xt that caught its own throws internally). deliverThrow removes our frame
        // when this CATCH receives the throw.
        if self.exceptionFrames.count > frameIndex {
            let frame = self.exceptionFrames.popLast()!
            if fromInnerThread {
                // Inner CATCH inside xt may have run deliverThrow and repointed ip; resume
                // this colon definition at the instruction after CATCH.
                self.ip = savedIp
                self.push(0)
            } else {
                self.rspSet(frame.returnStackDepth)
                self.ip = savedIp
                self.push(0)
            }
        }
        self.throwActive = false
    }

    /// Raise a standard (or user) throw from kernel code. Caught → CATCH receives code only.
    /// Uncaught → handleUnhandledThrow prints lastKernelThrowMessage and resets.
    internal func kernelThrow(_ code: Cell, message: String? = nil) {
        if let message, !message.isEmpty {
            lastKernelThrowMessage = message
        } else if lastKernelThrowMessage.isEmpty {
            lastKernelThrowMessage = messageForThrowCode(code) ?? "? THROW \(code)"
        }
        deliverThrow(code)
    }

    /// Standard REPL text for a throw code (ANS §9.3.1 and TZForth kernel codes). nil = unknown code.
    private func messageForThrowCode(_ code: Cell) -> String? {
        switch code {
        case -1: return "Aborted!"
        case -2:
            return lastAbortQuoteText.isEmpty ? "? ABORT\"" : lastAbortQuoteText
        case StdThrow.stackUnderflow: return "? Stack underflow"
        case StdThrow.stackOverflow: return "? Stack overflow"
        case StdThrow.returnStackUnderflow: return "? Return stack underflow"
        case StdThrow.returnStackOverflow: return "? Return stack overflow"
        case StdThrow.invalidAddress: return "? Invalid memory address"
        case StdThrow.divisionByZero: return "? Division by zero"
        case StdThrow.zeroLengthName: return "? Attempt to use zero-length string as name"
        case StdThrow.undefinedWord: return "? undefined word"
        case StdThrow.compileOnly: return "? compile-only word in interpret state"
        case StdThrow.uncompletedControl: return "? uncompleted control structure"
        case StdThrow.invalidToken: return "? invalid execution token"
        case StdThrow.nestingLimit: return "? nesting limit exceeded"
        case StdThrow.illegalArgument: return "? illegal argument"
        case StdThrow.closedFile: return "? Operation on closed file"
        case StdThrow.invalidFileId: return "? Invalid file-id"
        case StdThrow.fileIOError: return "? File I/O exception"
        case StdThrow.fileNotFound: return "? File not found"
        case StdThrow.malformedXchar: return "? Malformed xchar"
        default: return nil
        }
    }

    /// Type the standard message for a CATCH/THROW result (0 = success, no output).
    /// Surrounds the text with spaces so callers can embed it inline without a line break.
    private func displayThrowMessage(_ code: Cell) {
        if code == 0 { return }
        let msg = messageForThrowCode(code) ?? "? THROW \(code)"
        tell(" " + msg + " ")
    }

    private func throwDivisionByZero() {
        kernelThrow(StdThrow.divisionByZero, message: "? Division by zero")
    }

    /// Invalid or unencodable extended character (ANS Extended-Character, throw code -77).
    func throwMalformedXchar() {
        self.kernelThrow(StdThrow.malformedXchar, message: "? Malformed xchar")
    }

    /// Compile-only / interpret-state misuse (ANS -14). Caught throw leaves STATE unchanged.
    internal func throwCompileOnly(_ message: String) {
        kernelThrow(StdThrow.compileOnly, message: message)
    }

    private func throwInvalidToken(_ message: String) {
        kernelThrow(StdThrow.invalidToken, message: message)
    }

    private func throwUncompletedControl(_ message: String) {
        kernelThrow(StdThrow.uncompletedControl, message: message)
    }

    internal func throwInvalidAddress(_ message: String) {  // TZForthFloat.swift
        kernelThrow(StdThrow.invalidAddress, message: message)
    }

    internal func throwZeroLengthName(_ message: String) {
        kernelThrow(StdThrow.zeroLengthName, message: message)
    }

    private func throwIllegalArgument(_ message: String) {
        kernelThrow(StdThrow.illegalArgument, message: message)
    }

    private func throwFileNotFound(_ message: String) {
        kernelThrow(StdThrow.fileNotFound, message: message)
    }

    func throwInvalidFileId(_ message: String) {
        kernelThrow(StdThrow.invalidFileId, message: message)
    }

    private func throwClosedFile(_ message: String) {
        kernelThrow(StdThrow.closedFile, message: message)
    }

    private func throwFileIOError(_ message: String) {
        kernelThrow(StdThrow.fileIOError, message: message)
    }

    /// ANS THROW / ABORT delivery. n=0 is a no-op. Caught throws restore the CATCH frame.
    private func deliverThrow(_ n: Cell) {
        if n == 0 { return }
        if self.exceptionFrames.isEmpty {
            self.handleUnhandledThrow(n)
            return
        }
        let frame = self.exceptionFrames.removeLast()
        self.restoreExceptionFrame(frame)
        var restoreRsp = frame.returnStackDepth
        if self.innerThreadStopRsp >= 0 {
            let minRsp = Cell(self.innerThreadStopRsp + 1)
            if restoreRsp < minRsp { restoreRsp = minRsp }
        }
        self.rspSet(restoreRsp)
        self.spSet(frame.dataStackDepth)
        self.push(n)
        self.throwActive = true
    }

    private func handleUnhandledThrow(_ n: Cell) {
        let message: String
        if n == -2 && !self.lastAbortQuoteText.isEmpty {
            message = self.lastAbortQuoteText
        } else if n == -1 {
            message = "Aborted!"
        } else if !self.lastKernelThrowMessage.isEmpty {
            message = self.lastKernelThrowMessage
        } else {
            message = "? THROW \(n)"
        }
        if self.isInterpretingLoadedFile() {
            // Defer to reportFileLoadError so the user sees filename + line number.
            self.fileLoadPendingErrorMessage = message
            if self.isFileLoadOpenFailureMessage(message), let caller = self.fileLoadEnclosingStack.last {
                let loadLabel = message.contains("INCLUDED") ? "INCLUDED" : "FLOAD"
                self.fileLoadErrorSite = FileLoadErrorSite(
                    fileId: 0,
                    line: 0,
                    sourceLine: caller.sourceLine,
                    loadLabel: loadLabel,
                    message: message,
                    enclosingFileId: caller.fileId,
                    enclosingLine: caller.line,
                    isOpenFailure: true
                )
            } else if self.interpreterInputFileId >= 2 {
                let enclosing: FileLoadCallerFrame
                if self.fileLoadEnclosingStack.count >= 2 {
                    enclosing = self.fileLoadEnclosingStack[self.fileLoadEnclosingStack.count - 2]
                } else {
                    enclosing = FileLoadCallerFrame(fileId: 0, line: 0, sourceLine: "")
                }
                self.fileLoadErrorSite = FileLoadErrorSite(
                    fileId: Int(self.interpreterInputFileId),
                    line: self.fileInterpretLineNumber,
                    sourceLine: self.sourceBufferLineString(),
                    loadLabel: self.currentIncludeLoadLabel,
                    message: message,
                    enclosingFileId: enclosing.fileId,
                    enclosingLine: enclosing.line
                )
            }
        } else {
            self.tell(message + "\n")
        }
        self.lastKernelThrowMessage = ""
        self.clearAllLocalFrames()
        // resetRuntimeState() clears loadNesting; preserve active file-load context so
        // later lines in the same FLOAD still see nesting and \S can set sourceLoadStop.
        let savedLoadNesting = self.loadNesting
        let savedInterpreterInputFileId = self.interpreterInputFileId
        let savedCurrentSourceId = self.currentSourceId
        self.resetRuntimeState()
        if savedLoadNesting > 0 {
            self.loadNesting = savedLoadNesting
            self.interpreterInputFileId = savedInterpreterInputFileId
            self.currentSourceId = savedCurrentSourceId
        }
        self.errorFlag = true
        self.throwActive = true
    }

    private func execute(cfa: Cell, firstCell: Cell) {
        if self.throwActive { return }
        // If the first cell at the CFA is a small primitive ID, we dispatch directly.
        // Otherwise we treat the CFA as a threaded code address (colon definition).
        if firstCell < Cell(MAX_BUILTIN_ID), let body = primitives[Int(firstCell)] {
            // For primitives that are not DOCOL we just call them.
            // DOCOL is special: it sets up threading.
            if firstCell == docolID || firstCell == codeEntryID {
                // Colon definition (DOCOL) or CODE definition (codeEntryID): thread the body.
                let stopRsp = Int(self.rspGet())
                rpush(ip)
                ip = self.threadedEntryIP(forCFA: cfa)
                if ip < 0 || ip + 8 > memory.count {
                    throwInvalidToken("? Bad definition target (cfa=\(cfa))")
                } else {
                    innerThread(stopWhenRspAtMost: stopRsp)
                    if throwActive { return }
                }
            } else {
                self.currentCodeAddr = cfa
                self.dispatchedFromInnerThread = false
                body()
                if throwActive { return }
            }
        } else {
            // Not a primitive ID — assume threaded code
            let stopRsp = Int(self.rspGet())
            rpush(ip)
            ip = Int(cfa)
            if ip < 0 || ip + 8 > memory.count {
                throwInvalidToken("? Bad execution target (cfa=\(cfa))")
            } else {
                innerThread(stopWhenRspAtMost: stopRsp)
                if throwActive { return }
            }
        }
    }

    private func innerThread(stopWhenRspAtMost: Int? = nil) {
        if let threshold = stopWhenRspAtMost {
            self.innerThreadStopRsp = threshold
        }
        // Classic indirect-threaded / token-threaded inner interpreter
        var safety = 0
        let SAFETY_LIMIT = 2_000_000
        while safety < SAFETY_LIMIT && !errorFlag && !exitReq && !throwActive {
            safety += 1

            let instrAddr = ip
            let cell = readCell(ip)
            ip += 8

            if errorFlag { break }

            // Hard IP bounds check — prevents following corrupted threaded code or wild branches
            // into completely invalid regions. readCell would catch it too, but this gives a clearer message.
            if ip < 0 || ip + 8 > memory.count {
                throwInvalidToken("? Invalid instruction pointer (ip=\(ip)) — possible corrupted threaded code or bad branch")
                break
            }

            if cell >= 0 && cell < Cell(primitives.count),
               let f = primitives[Int(cell)] {
                self.currentCodeAddr = Cell(instrAddr)
                self.dispatchedFromInnerThread = true
                f()
                self.dispatchedFromInnerThread = false
                if throwActive { break }
                if self.innerThreadStopRsp >= 0 && Int(self.rspGet()) <= self.innerThreadStopRsp {
                    self.innerThreadStopRsp = -1
                    break
                }
                if self.isBlockingOnHost {
                    // Blocking primitive (KEY / EKEY / MS): rewind IP; host resumes via provide* / resumeAfterMs.
                    ip -= 8
                    break
                }
            } else if cell < Cell(MAX_BUILTIN_ID) {
                // A small integer that is not a registered primitive ID.
                // This usually means a branch or call landed on a data literal
                // (e.g. the "1" or "-16" in your looper example) and tried to
                // execute it as code. We turn it into a clean error instead of
                // a fatal array subscript trap.
                throwInvalidToken("? Invalid executable token \(cell) (not a registered primitive; possible bad branch offset)")
                break
            } else {
                // Threaded call to another word's CFA (colon, CREATE, or DOES> child).
                rpush(ip)
                ip = self.threadedEntryIP(forCFA: cell)
                if ip < 0 || ip + 8 > memory.count {
                    throwInvalidToken("? Bad threaded call target (ip=\(ip))")
                    break
                }
            }

            if ip == 0 { break }   // safety
        }

        if safety >= SAFETY_LIMIT && !errorFlag && !throwActive {
            kernelThrow(StdThrow.nestingLimit, message: "? Execution limit exceeded (possible infinite loop or very deep recursion)")
        }
    }

    /// SEE / LOCATE — parse name, decompile definition, append HELP line if available.
    private func seeWord(_ rawName: String, usageWord: String) {
        self.validateAndRepairSystemState()
        let name = rawName.uppercased()
        if name.isEmpty {
            self.tell("\(usageWord) <name>\n")
            return
        }
        let hdr = self.findWord(name)
        if hdr == 0 {
            self.kernelThrow(StdThrow.undefinedWord, message: "? \(name) ?")
            return
        }
        self.printDecompiled(name: name, hdr: hdr)
        if let info = Self.primitiveHelp[name] {
            self.tell("\(name)  \(info.stack)  \(info.desc)\n")
        }
    }

    /// Shared decompiler used by both SEE and HELP.
    /// Prints ": NAME body ;", "CODE NAME body ;CODE", or primitive form.
    private func printDecompiled(name: String, hdr: Cell) {
        let cfa = self.getCFA(hdr)
        var ip = Int(cfa)

        let first = self.readCell(ip)
        let isCodeWord = first == self.codeEntryID

        if isCodeWord {
            self.tell("CODE " + name + " ")
        } else if first == self.docolID {
            self.tell(": " + name + " ")
        } else if first < Cell(self.MAX_BUILTIN_ID) {
            if let pname = self.primitiveNames[first] {
                self.tell(pname + " (primitive) ;\n")
            } else {
                self.tell("primitive ID " + String(first) + " ;\n")
            }
            return
        } else {
            self.tell("???\n")
            return
        }

        if first == self.docolID || first == self.codeEntryID {
            ip += 8
        }

        var safety = 0
        let MAX_CELLS = 4096
        while safety < MAX_CELLS {
            safety += 1

            if ip + 8 > self.memory.count { break }

            let cell = self.readCell(ip)
            ip += 8

            if cell == self.exitID {
                if isCodeWord {
                    self.tell("RET ")
                }
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

            if cell == self.flitID {
                if ip + 8 <= self.memory.count {
                    let bits = self.readCell(ip)
                    ip += 8
                    let shown = self.formatFloatForDecompile(bits)
                    self.tell("FLIT \(shown) ")
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

            if cell == self.cQuoteID {
                self.tell("C\" ")
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

        if isCodeWord {
            self.tell(";CODE\n")
        } else {
            self.tell(";\n")
        }
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
            dictionaryHighWater = kernelHere
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

        self.warningAddr = 0
        let hdrWarn = self.findWord("WARNING")
        if hdrWarn != 0 {
            let cfa = self.getCFA(hdrWarn)
            if self.readCell(Int(cfa)) == self.docolID {
                if self.readCell(Int(cfa) + 8) == self.litID {
                    self.warningAddr = self.readCell(Int(cfa) + 16)
                }
            }
        }
        if self.warningAddr != 0 {
            self.writeCell(self.warningAddr, -1)
        }

        self.includedNamesVarAddr = 0
        let hdrIn = self.findWord("INCLUDED-NAMES")
        if hdrIn != 0 {
            let cfa = self.getCFA(hdrIn)
            if self.readCell(Int(cfa)) == self.docolID {
                if self.readCell(Int(cfa) + 8) == self.litID {
                    self.includedNamesVarAddr = self.readCell(Int(cfa) + 16)
                }
            }
        }
        if self.includedNamesVarAddr != 0 {
            self.writeCell(self.includedNamesVarAddr, 0)
        }

        // Reset to FORTH vocabulary
        searchOrder = [LATEST]
        writeCell(CURRENT, LATEST)
    }

    // MARK: - Session environment snapshot (ANS-VALIDATE / harness cleanup)

    /// Kernel/session settings that ANS-VALIDATE (and similar harnesses) may touch.
    /// Captured before validation and restored afterward so the user's REPL is unchanged.
    internal struct SessionEnvironmentSnapshot {
        var fileEcho: Cell = 0
        var base: Cell = 10
        var includedNamesHead: Cell = 0
        var debugEnabled: Bool = false
        var growMemoryAttempted: Bool = false
        var allocateEverUsed: Bool = false
        var memoryByteCount: Int = 0
        var inputSnapshotCount: Int = 0
    }

    /// SAVE-INPUT snapshots paired with SessionEnvironmentSnapshot (private InputSnapshot type).
    private var sessionInputSnapshotsBackup: [InputSnapshot] = []

    /// Snapshot user dictionary bytes [kernelHere, here) for ANS-VALIDATE restore.
    /// Pointer restore (LATEST/HERE) alone is not enough: validation tests can scribble on
    /// link fields below the saved HERE (e.g. after FLOAD TEST / Hayes), breaking search.
    internal func captureValidationDictionaryBytes(upTo here: Cell) -> [UInt8] {
        let from = Int(self.kernelHere != 0 ? self.kernelHere : (self.rstackBase + self.RSTACK_SIZE * self.CELL_SIZE))
        let to = Int(here)
        guard from < to, to <= self.memory.count else { return [] }
        return Array(self.memory[from..<to])
    }

    /// Restore bytes captured by captureValidationDictionaryBytes(upTo:).
    internal func restoreValidationDictionaryBytes(_ bytes: [UInt8], upTo here: Cell) {
        let from = Int(self.kernelHere != 0 ? self.kernelHere : (self.rstackBase + self.RSTACK_SIZE * self.CELL_SIZE))
        let to = Int(here)
        guard from < to, bytes.count == to - from else { return }
        for i in 0..<bytes.count {
            self.memory[from + i] = bytes[i]
        }
    }

    /// Snapshot kernel variables and session flags (FILE-ECHO, BASE, memory growth, etc.).
    internal func captureSessionEnvironment() -> SessionEnvironmentSnapshot {
        var snap = SessionEnvironmentSnapshot()
        if self.fileEchoAddr != 0 {
            snap.fileEcho = self.readCell(self.fileEchoAddr)
        }
        snap.base = self.readCell(self.BASE)
        if self.includedNamesVarAddr != 0 {
            snap.includedNamesHead = self.readCell(self.includedNamesVarAddr)
        }
        snap.debugEnabled = self.debugEnabled
        snap.growMemoryAttempted = self.growMemoryAttempted
        snap.allocateEverUsed = self.allocateEverUsed
        snap.memoryByteCount = self.memory.count
        snap.inputSnapshotCount = self.inputSnapshots.count
        self.sessionInputSnapshotsBackup = self.inputSnapshots
        return snap
    }

    /// Restore kernel variables and session flags captured by captureSessionEnvironment().
    internal func restoreSessionEnvironment(_ snap: SessionEnvironmentSnapshot) {
        if self.fileEchoAddr != 0 {
            self.writeCell(self.fileEchoAddr, snap.fileEcho)
        }
        self.writeCell(self.BASE, snap.base)
        if self.includedNamesVarAddr != 0 {
            self.writeCell(self.includedNamesVarAddr, snap.includedNamesHead)
        }
        self.debugEnabled = snap.debugEnabled
        self.growMemoryAttempted = snap.growMemoryAttempted
        self.allocateEverUsed = snap.allocateEverUsed
        self.inputSnapshots = self.sessionInputSnapshotsBackup

        if self.memory.count > snap.memoryByteCount {
            self.memory.removeLast(self.memory.count - snap.memoryByteCount)
            self.repositionPnoAndHeap()
        }
        self.resetHeapState(clearAllocateFlag: !snap.allocateEverUsed)
        if self.blockPoolBase > 0 {
            self.heapBump = self.blockPoolBase
        }
    }

    /// Non-fatal post-restore checks for harness logging (FILE-ECHO, BASE, memory, etc.).
    internal func sessionEnvironmentRestoreWarnings(expected snap: SessionEnvironmentSnapshot) -> [String] {
        var warnings: [String] = []
        if self.fileEchoAddr != 0 && self.readCell(self.fileEchoAddr) != snap.fileEcho {
            warnings.append("WARNING: FILE-ECHO not restored (got \(self.readCell(self.fileEchoAddr)), expected \(snap.fileEcho))")
        }
        if self.readCell(self.BASE) != snap.base {
            warnings.append("WARNING: BASE not restored (got \(self.readCell(self.BASE)), expected \(snap.base))")
        }
        if self.debugEnabled != snap.debugEnabled {
            warnings.append("WARNING: debug state not restored")
        }
        if self.growMemoryAttempted != snap.growMemoryAttempted {
            warnings.append("WARNING: GROWMEMORYMB session flag not restored")
        }
        if self.memory.count != snap.memoryByteCount {
            warnings.append("WARNING: memory size not restored (got \(self.memory.count), expected \(snap.memoryByteCount))")
        }
        if self.inputSnapshots.count != snap.inputSnapshotCount {
            warnings.append("WARNING: SAVE-INPUT snapshot count not restored")
        }
        return warnings
    }

    /// Resets only runtime execution state (stacks, IP, flags, queues, debug, KEY/FLOAD
    /// pending, loop controls, comment state). Does *not* touch the dictionary.
    /// Useful for test harnesses that want to clean between steps while leaving
    /// previously loaded/defined words intact. For a user-visible full reset (incl.
    /// clearing all user words), use resetToSafeState().
    public func resetRuntimeState() {
        spSet(1)
        rspSet(1)
        self.fspSet(1)
        ip = 0
        commandAddress = 0
        errorFlag = false
        exitReq = false
        writeCell(STATE, 0)
        inputQueue.removeAll(keepingCapacity: true)
        debugEnabled = false   // return to clean default
        clearScreenRequested = false
        facilityTerminal.deactivate()
        terminalRefreshPending = false
        waitingForKey = false
        waitingForExtendedKey = false
        waitingForMs = false
        waitingForXKey = false
        xkeyAssembly.removeAll(keepingCapacity: true)
        extendedKeyQueue.removeAll(keepingCapacity: true)
        fileLoadRequested = false
        fileEditRequested = false
        pendingEditURL = nil
        pendingLoadURL = nil
        pendingFloadSpec = ""
        currentlyLoadingSpec = nil
        namedFloadOnCurrentReplLine = false
        loopControlStack.removeAll()
        whileRepeatStack.removeAll()
        whileNestStack.removeAll()
        caseBranchStack.removeAll()
        controlFlowStack.removeAll()
        self.clearAllLocalFrames()
        self.exceptionFrames.removeAll()
        self.throwActive = false
        self.lastAbortQuoteText = ""
        self.bracketCompileDepth = 0
        self.interpretIfTrueDepth = 0
        self.conditionalSkipDepth = 0
        self.conditionalSkipStopAtElse = false
        self.conditionalSkipDiscardThroughQuote = false
        self.inSlashSlashComment = false
        self.inParenComment = false
        self.sourceLoadStop = false
        self.fileInterpretStopStack.removeAll(keepingCapacity: true)
        self.replBatchStop = false
        self.loadNesting = 0
        self.evaluateNesting = 0
        self.evaluateSourceAddr = 0
        self.evaluateSourceLen = 0
        self.interpreterInputFileId = -1
        self.inputSourceStack.removeAll(keepingCapacity: true)
        self.inputSnapshots.removeAll(keepingCapacity: true)
        self.floadRestoreInputContinuation = false
        self.floadExtraLinesConsumed = 0
        self.floadLinesToSkip = 0
        self.countFloadInterpreterRefills = false
        self.blockInterpretActive = false
        self.blockLoadDepth = 0
        self.midFileLoadAborted = false
        // pictured state
        self.pnoPtr = self.pnoBufferAddr + self.PNO_BUFFER_SIZE
        writeCell(IN, 0)
        self.currentSourceId = -1
        searchOrder = [LATEST]
        writeCell(CURRENT, LATEST)
        self.currentSourceLen = 0
    }

    public func resetToSafeState() {
        validateAndRepairSystemState()   // extra belt-and-suspenders

        // Clean runtime state first (stacks, flags, etc.).
        resetRuntimeState()

        // Full dictionary reset to initial state (user words + their data space gone).
        restoreKernelDictionary()
        self.resetHeapState(clearAllocateFlag: true)
        if self.includedNamesVarAddr != 0 {
            self.writeCell(self.includedNamesVarAddr, 0)
        }

        // Leave IP wherever it is; the next feedLine will start fresh parsing from
        // whatever input arrives next. (A real high-level QUIT now exists via bootstrap.)
    }

    /// File-load line error: stop this file at the first fault, but preserve CATCH frames
    /// so `['] FLOAD … CATCH` can recover. Does not call resetRuntimeState.
    private func recoverFromErrorDuringFileLoad() {
        self.inputQueue.removeAll(keepingCapacity: true)
        self.loopControlStack.removeAll()
        self.whileRepeatStack.removeAll()
        self.whileNestStack.removeAll()
        self.controlFlowStack.removeAll()
        self.conditionalSkipDepth = 0
        self.conditionalSkipStopAtElse = false
        self.interpretIfTrueDepth = 0
        self.inSlashSlashComment = false
        self.inParenComment = false
        self.waitingForKey = false
        self.spSet(1)
        self.rspSet(1)
        self.clearAllLocalFrames()
        self.throwActive = false
        self.writeCell(self.IN, Cell(self.currentSourceLen))

        if self.readCell(self.STATE) != 0 {
            let defsHeadCell = self.readCell(self.CURRENT)
            let latest = self.readCell(defsHeadCell)
            if latest != 0 {
                let fl = self.readByte(Int(latest) + 8)
                self.writeByte(Int(latest) + 8, fl & ~self.FLAG_HIDDEN)
            }
            self.writeCell(self.STATE, 0)
        }

        // Leave exceptionFrames intact for enclosing CATCH (e.g. safe FLOAD wrappers).
        self.errorFlag = true
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
        waitingForXKey = false
        xkeyAssembly.removeAll(keepingCapacity: true)
        fileLoadRequested = false
        fileEditRequested = false
        pendingEditURL = nil
        pendingLoadURL = nil
        loopControlStack.removeAll()
        whileRepeatStack.removeAll()
        whileNestStack.removeAll()
        controlFlowStack.removeAll()
        self.conditionalSkipDepth = 0
        self.conditionalSkipStopAtElse = false
        self.interpretIfTrueDepth = 0
        self.inSlashSlashComment = false
        self.inParenComment = false
        if !self.isInterpretingLoadedFile() {
            self.sourceLoadStop = false
        }
        self.pnoPtr = self.pnoBufferAddr + self.PNO_BUFFER_SIZE
        if !self.isInterpretingLoadedFile() {
            self.currentSourceLen = 0
        }
        searchOrder = [LATEST]
        writeCell(CURRENT, LATEST)

        let wasLoading = self.isInterpretingLoadedFile()
        // Do not zero loadNesting here; includeFileInterpret's defer (or its error path) will
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
        self.clearAllLocalFrames()
        self.repairHereIfCorrupt()
        let b = readCell(BASE)
        if b < 2 || b > 36 { writeCell(BASE, 10) }
        writeCell(IN, 0)

        ip = 0
        commandAddress = 0
        self.throwActive = false
        if !wasLoading {
            self.exceptionFrames.removeAll()
        }

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
    func validateAndRepairSystemState() {
        let spv = spGet()
        if spv < 1 || spv > Cell(STACK_SIZE) {
            spSet(1)
        }

        let rspv = rspGet()
        if rspv < 1 || rspv > Cell(RSTACK_SIZE) {
            rspSet(1)
        }

        self.repairHereIfCorrupt()
        // If the dictionary chain looks completely broken, reset the FORTH head (LATEST cell) to kernel
        // (never below kernel; preserves core words on corruption recovery).
        let l = readCell(LATEST)
        if l != 0 && !isValidDictionaryLink(l) {
            writeCell(LATEST, kernelLatest != 0 ? kernelLatest : 0)
        }
        // CURRENT may legitimately hold FORTH-WORDLIST (0); only repair an empty search order.
        if searchOrder.isEmpty {
            searchOrder = [LATEST]
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
        if self.pnoPtr < self.pnoBufferAddr || self.pnoPtr > self.pnoBufferAddr + self.PNO_BUFFER_SIZE {
            self.pnoPtr = self.pnoBufferAddr + self.PNO_BUFFER_SIZE
        }
        // Do not reset >IN here — seeWord/LOCATE and other mid-line words must keep the
        // current parse offset; zeroing >IN plus realignInputQueueFromSource() rewinds the line.
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
        let listHead = readCell(CURRENT)
        var link = readCell(listHead)
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
    // These sources and runner allow the ANS-VALIDATE word to run ANS + Block subsystem spot-checks
    // (Core, Core Ext, File-Access, String, Exception, Memory, Double, Locals, Programming-Tools)
    // from inside the interpreter and write results to ANS-VALIDATE.txt next to TestTZForth.swift.
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
