import SwiftUI
import AppKit   // for NSApplication.terminate when BYE is executed
import Foundation  // for FileManager (current dir for NSOpenPanel)
import UniformTypeIdentifiers  // for allowedContentTypes (replaces deprecated allowedFileTypes)

//
// Public Domain Statement
//
// This software is released into the public domain.
// 
// TZForth is free and unencumbered software dedicated to the public domain.
// 
// ConsoleView.swift provides the AppKit/SwiftUI host for the TZForth engine.
// The driven engine (TZForth) respects Leif Bruder's public-domain lbForth origins internally.
// See TZForth.swift for full credit and the original model link.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
//

extension Notification.Name {
    static let clearConsole = Notification.Name("ClearConsole")
    static let resetForth   = Notification.Name("ResetForth")
    /// Tools menu: bare EDIT (file picker → TextEdit).
    static let toolsEdit = Notification.Name("ToolsEdit")
    /// Tools menu: bare FLOAD (file picker → load).
    static let toolsFload = Notification.Name("ToolsFload")
    /// Tools menu: CHDIR (folder picker).
    static let toolsChdir = Notification.Name("ToolsChdir")
    /// Tools menu: AUTOLOAD → VIEW AutoLoad Folder (Finder on Resources/AutoLoad)
    static let toolsViewAutoloadFolder = Notification.Name("ToolsViewAutoloadFolder")
    /// Tools menu: LIBRARY → VIEW Library Folder (Finder on Resources/Library)
    static let toolsViewLibraryFolder = Notification.Name("ToolsViewLibraryFolder")
    /// Tools menu: DOCS → VIEW Documents Folder (Finder on Resources/docs)
    static let toolsViewDocsFolder = Notification.Name("ToolsViewDocsFolder")
    /// File menu / ⌘N — new untitled editor buffer.
    static let fileNew = Notification.Name("FileNew")
    /// File menu / ⌘O — open file in SZ-EDITOR.
    static let fileOpen = Notification.Name("FileOpen")
    /// File menu / ⌘S — save (while editor session active).
    static let fileSave = Notification.Name("FileSave")
    /// File menu / ⌘W — close editor session (not quit app).
    static let fileClose = Notification.Name("FileClose")
}

let consoleMessage = "=== TZForth (based on Leif Bruder's lbForth) ===\n\n"

/// A reusable console view that mimics the classic Forth REPL feel.
/// This version drives the real TZForth engine (Leif Bruder's public-domain lbForth model).
struct ConsoleView: View {
    @State private var consoleText = consoleMessage
    @State private var commandHistory: [String] = []
    @State private var historyIndex = -1
    @State private var isRecallingHistory = false
    @FocusState private var isFocused: Bool

    // The real Forth engine (TZForth; Leif Bruder / lbForth origins internally)
    @State private var forth = TZForth(settings: TZForthSettings.load())

    /// Marks the length of consoleText after the last engine output.
    /// Only text typed by the user *after* this point can be treated as new commands.
    /// This prevents engine newlines (from .s, errors, etc.) from causing the
    /// command detector to re-interpret previous output or old lines.
    @State private var protectedLength = 0

    /// Snapshot of consoleText through protectedLength. User edits must not alter this prefix.
    @State private var protectedSnapshot = ""

    /// Suppresses re-entrancy when reverting a delete that crossed the protected boundary.
    @State private var isRevertingProtectedEdit = false

    /// When true, onChange must not revert consoleText (startup / AutoLoad / engine output).
    @State private var isProgrammaticConsoleAppend = false

    /// Tracks how much of the current user input (relative to protectedLength) has already
    /// been consumed as key data while waitingForKey. Used to compute delta new keystrokes
    /// on each onChange so we can feed them immediately to KEY without requiring a line commit.
    @State private var lastKeyConsumedUserLength = 0

    /// Flag to ignore the onChange that results from our own text mutation when eating
    /// a key char (removeLast) so we don't re-process or trigger normal line logic.
    @State private var isConsumingKeyChar = false

    /// The currently active security-scoped directory URL (from bookmark). We keep the scope
    /// active for the session so that named FLOAD/EDIT inside that dir (using constructed
    /// file URLs) and handing off to external editors via NSWorkspace can succeed with
    /// write access. Stopped on disappear or when switching dirs.
    @State private var currentScopedDirectory: URL? = nil

    /// Underlying AppKit text view used to keep the insertion point scrolled into view.
    @State private var consoleTextView: NSTextView? = nil

    /// Prevents duplicate Return handling when both AppKit and SwiftUI key paths fire.
    @State private var isHandlingReturn = false

    /// Prevents nested/duplicate KEY delivery when both SwiftUI and AppKit see the same key.
    @State private var isDeliveringBlockingKey = false

    /// Incremented to request moving the caret to end-of-document (after commit/output).
    @State private var pinCaretRequest = 0

    /// True while the facility terminal (SZ-EDITOR PAGE paint) owns the console.
    /// Disables soft word-wrap so fixed-width editor rows are not re-broken by the window.
    @State private var facilityPaintActive = false

    var body: some View {
        consoleRoot
            .onReceive(NotificationCenter.default.publisher(for: .fileNew)) { _ in
                handleFileNew()
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileOpen)) { _ in
                handleFileOpen()
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileSave)) { _ in
                handleFileSave()
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileClose)) { _ in
                handleFileClose()
            }
    }

    /// Split from `body` so the Swift type checker can finish (menu + KEY modifiers are heavy).
    @ViewBuilder
    private var consoleRoot: some View {
        ConsoleTextView(
            text: $consoleText,
            isFocused: $isFocused,
            pinCaretRequest: $pinCaretRequest,
            // UTF-16 index of first user-editable character (same boundary as backspace protect).
            editableStartUTF16: (protectedSnapshot as NSString).length,
            disableSoftWrap: facilityPaintActive,
            // While KEY/EKEY is blocking, refuse all NSTextView text mutations — keys are
            // delivered only via onBlockingKeyDown / handleReturnKey (never via typing into
            // the console string, which used to strip facility-screen characters).
            isBlockingKeyboardInput: { forth.waitingForKey || forth.waitingForExtendedKey },
            onReturnPressed: { handleReturnKey() },
            onFacilityKeyDown: { event in
                guard forth.waitingForExtendedKey else { return false }
                guard let fkeyId = Self.facilityFKeyId(from: event) else { return false }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(fkeyId))
                return true
            },
            onBlockingKeyDown: { event in
                // While KEY is waiting (e.g. SZ-EDITOR loop), deliver keys exclusively here.
                guard forth.waitingForKey else { return false }
                // Let Cmd- shortcuts (Quit, Copy, …) reach the system.
                if event.modifierFlags.contains(.command) { return false }
                guard let code = Self.blockingKeyCode(from: event) else {
                    // Swallow unknown keys so NSTextView cannot edit the facility paint.
                    return true
                }
                return deliverBlockingKey(code)
            }
        ) { textView in
            DispatchQueue.main.async {
                consoleTextView = textView
            }
        }
            .focused($isFocused)
            .onDisappear {
                if let scoped = currentScopedDirectory {
                    scoped.stopAccessingSecurityScopedResource()
                    currentScopedDirectory = nil
                }
            }
            .onChange(of: consoleText) { oldValue, newValue in
                if isRevertingProtectedEdit {
                    isRevertingProtectedEdit = false
                    return
                }
                // Engine/startup/facility output must not be treated as user keystrokes
                // or as illegal edits of the protected prefix.
                if isProgrammaticConsoleAppend {
                    keepCursorVisible()
                    return
                }
                // Facility PAGE/AT-XY paint replaces the whole console body each frame.
                // It does *not* preserve the previous protectedSnapshot prefix, so the
                // normal "revert protected edit" logic must not run — that was undoing
                // every SZ-REDRAW after the first (typed chars in the buffer + "*" on
                // the status line, but the painted screen never showed the new text).
                if forth.isFacilityTerminalActive {
                    keepCursorVisible()
                    return
                }
                if newValue.count < protectedLength
                    || (!protectedSnapshot.isEmpty && !newValue.hasPrefix(protectedSnapshot)) {
                    isRevertingProtectedEdit = true
                    consoleText = oldValue
                    return
                }
                checkForCommandExecution(newValue)
                keepCursorVisible()
            }
            .onKeyPress(.upArrow) {
                if forth.waitingForKey {
                    _ = deliverBlockingKey(16) // up
                    return .handled
                }
                if forth.waitingForExtendedKey {
                    forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.up))
                    return .handled
                }
                recallHistory(up: true)
                return .handled
            }
            .onKeyPress(.downArrow) {
                if forth.waitingForKey {
                    _ = deliverBlockingKey(14) // down
                    return .handled
                }
                if forth.waitingForExtendedKey {
                    forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.down))
                    return .handled
                }
                recallHistory(up: false)
                return .handled
            }
            .onKeyPress(.leftArrow) {
                if forth.waitingForKey {
                    _ = deliverBlockingKey(2) // left
                    return .handled
                }
                if forth.waitingForExtendedKey {
                    forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.left))
                    return .handled
                }
                // Normal editing: AppKit moveLeft is clamped in ConsoleTextView.doCommandBy
                // so the caret cannot enter protected output / previous lines.
                return .ignored
            }
            .onKeyPress(.rightArrow) {
                if forth.waitingForKey {
                    _ = deliverBlockingKey(6) // right
                    return .handled
                }
                guard forth.waitingForExtendedKey else { return .ignored }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.right))
                return .handled
            }
            .onKeyPress(.home) {
                // While KEY waits, AppKit keyDown maps Home / Ctrl-Home (needs modifiers).
                if forth.waitingForKey { return .ignored }
                guard forth.waitingForExtendedKey else { return .ignored }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.home))
                return .handled
            }
            .onKeyPress(.end) {
                if forth.waitingForKey { return .ignored }
                guard forth.waitingForExtendedKey else { return .ignored }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.end))
                return .handled
            }
            .onKeyPress(.pageUp) {
                if forth.waitingForKey {
                    _ = deliverBlockingKey(23) // PgUp
                    return .handled
                }
                guard forth.waitingForExtendedKey else { return .ignored }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.prior))
                return .handled
            }
            .onKeyPress(.pageDown) {
                if forth.waitingForKey {
                    _ = deliverBlockingKey(24) // PgDn
                    return .handled
                }
                guard forth.waitingForExtendedKey else { return .ignored }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.next))
                return .handled
            }
            .onKeyPress(phases: .down) { press in
                guard forth.waitingForExtendedKey else { return .ignored }
                if let ev = facilityKeyEvent(from: press) {
                    forth.provideExtendedKey(ev)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.delete) {
                if forth.waitingForKey {
                    _ = deliverBlockingKey(8) // BS for editor / KEY consumers
                    return .handled
                }
                if handleDelete() {
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.return) {
                handleReturnKey() ? .handled : .ignored
            }
            // Listen for menu commands from the Tools menu (defined at App level)
            .onReceive(NotificationCenter.default.publisher(for: .clearConsole)) { _ in
                // Full wipe (including banner) — same as Forth CLS.
                consoleText = ""
                markProtectedThroughEndOfText()
                forth.clearScreenRequested = false
                keepCursorVisible(followPrompt: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetForth)) { _ in
                forth.resetToSafeState()
                // RESET restores a clean REPL banner; CLS alone leaves the window empty.
                consoleText = consoleMessage
                markProtectedThroughEndOfText()
                forth.clearScreenRequested = false
                keepCursorVisible(followPrompt: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .toolsEdit)) { _ in
                forth.fileEditRequested = true
                showFileEditDialog()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toolsFload)) { _ in
                forth.fileLoadRequested = true
                showFileLoadDialog()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toolsChdir)) { _ in
                forth.directoryPickRequested = true
                showDirectoryPickDialog()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toolsViewAutoloadFolder)) { _ in
                revealAutoloadFolderInFinder()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toolsViewLibraryFolder)) { _ in
                revealLibraryFolderInFinder()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toolsViewDocsFolder)) { _ in
                revealDocsFolderInFinder()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .onAppear {
                isFocused = true

                // Establish a useful starting directory (~/Documents or last-used) instead of
                // the sandbox container path. This makes the FLOAD/EDIT dialogs, CHDIR reports,
                // relative FLOAD/EDIT names, and DIR start in a place the user can actually use.
                setupInitialWorkingDirectory()

                // Show the effective starting dir immediately so user knows what "chdir" would report
                // and where bare FLOAD panel will start / named FLOAD will resolve from by default.
                // (This is before the onOutput hook, so direct append + protect.)
                let initDir = forth.logicalCurrentDirectory
                if !initDir.isEmpty {
                    consoleText += "Current directory: \(initDir)\n"
                    markProtectedThroughEndOfText()
                }

                // Hook the Forth output callback
                forth.onOutput = { text in
                    let applyOutput = {
                        isProgrammaticConsoleAppend = true
                        pinCaretRequest += 1
                        consoleText += text
                        markProtectedThroughEndOfText()
                        isProgrammaticConsoleAppend = false
                        keepCursorVisible(followPrompt: true)
                        handlePostFeedActions()
                    }
                    // Apply synchronously on the main thread so a trailing keepCursorVisible
                    // (e.g. from commitEmptyLine) does not scroll before " OK" is appended.
                    if Thread.isMainThread {
                        applyOutput()
                    } else {
                        DispatchQueue.main.async(execute: applyOutput)
                    }
                }

                forth.onMsDelayRequested = { ms, completion in
                    let delay = DispatchTimeInterval.milliseconds(max(0, ms))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: completion)
                }

                forth.onTerminalRefresh = { screen in
                    let applyTerminal = {
                        self.facilityPaintActive = true
                        self.isProgrammaticConsoleAppend = true
                        self.consoleText = consoleMessage + screen
                        if !screen.hasSuffix("\n") {
                            self.consoleText += "\n"
                        }
                        self.markProtectedThroughEndOfText()
                        self.lastKeyConsumedUserLength = 0
                        self.keepCursorVisible(followPrompt: true)
                        // Reverse-video the Facility cursor cell (editor insert point).
                        self.applyFacilityCursorHighlight()
                        // Keep the flag set until the next turn so any deferred
                        // SwiftUI onChange still treats this as engine output.
                        DispatchQueue.main.async {
                            self.isProgrammaticConsoleAppend = false
                            // Attributes can be cleared when SwiftUI rebinds the string;
                            // re-apply once the text view has caught up.
                            self.applyFacilityCursorHighlight()
                        }
                    }
                    if Thread.isMainThread {
                        applyTerminal()
                    } else {
                        DispatchQueue.main.async(execute: applyTerminal)
                    }
                }

                forth.onClearScreen = {
                    let applyClear = {
                        self.facilityPaintActive = false
                        self.isProgrammaticConsoleAppend = true
                        self.consoleText = ""
                        self.markProtectedThroughEndOfText()
                        self.lastKeyConsumedUserLength = 0
                        self.forth.clearScreenRequested = false
                        self.keepCursorVisible(followPrompt: true)
                        DispatchQueue.main.async {
                            self.isProgrammaticConsoleAppend = false
                        }
                    }
                    if Thread.isMainThread {
                        applyClear()
                    } else {
                        DispatchQueue.main.async(execute: applyClear)
                    }
                }

                // Hook BYE so the host app can quit when the user types BYE in Forth
                forth.onQuitRequested = {
                    forth.shutdownBlockSubsystem()
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(nil)
                    }
                }

                // Hook CHDIR so we can persist a security bookmark for the new dir (if the
                // current scope covers it) and activate it. This makes named FLOAD/DIR after
                // a CHDIR to a subdir (or the current dir) succeed without "not found".
                forth.onDirectoryChanged = { [self] dirURL in
                    self.applyDirectoryChange(dirURL)
                }

                forth.ensureDirectoryAccess = { [self] url in
                    self.activateLastDirectoryScope(parent: url)
                    return self.directoryURLWithActiveScope(for: url)
                }

                forth.onPerformNamedLoad = { [self] url in
                    self.performScopedNamedLoad(url: url)
                }

                // Initially protect the banner (+ current directory line).
                markProtectedThroughEndOfText()
                lastKeyConsumedUserLength = 0
                keepCursorVisible(followPrompt: true)

                // Product boot after the first frame commits. Running AutoLoad synchronously
                // inside onAppear can lose @State console appends (protected-text revert /
                // SwiftUI batching). Next main-queue turn is reliable.
                DispatchQueue.main.async {
                    self.isProgrammaticConsoleAppend = true
                    self.forth.runAutoLoadIfPresent()
                    self.markProtectedThroughEndOfText()
                    self.isProgrammaticConsoleAppend = false
                    self.keepCursorVisible(followPrompt: true)
                }
            }
    }
    
    private func markProtectedThroughEndOfText() {
        protectedLength = consoleText.count
        protectedSnapshot = consoleText
    }

    private func markProtected(through length: Int) {
        protectedLength = length
        protectedSnapshot = String(consoleText.prefix(length))
    }

    /// Requests that the AppKit text view keep the insertion point visible.
    /// Scrolling is scheduled on the NSTextView directly and again from updateNSView after sync.
    private func keepCursorVisible(followPrompt: Bool = false) {
        if followPrompt {
            pinCaretRequest += 1
        }
        if let textView = consoleTextView {
            ConsoleTextView.scheduleScrollToInsertionPoint(in: textView)
        }
    }

    /// Deliver one KEY value while the engine is waiting. Nested/duplicate callers (SwiftUI
    /// + AppKit for the same physical key) are collapsed so the editor sees a single stroke.
    @discardableResult
    private func deliverBlockingKey(_ code: Int) -> Bool {
        guard forth.waitingForKey else { return false }
        if isDeliveringBlockingKey { return true }
        isDeliveringBlockingKey = true
        forth.provideKey(code)
        lastKeyConsumedUserLength = 0
        // Keep the gate closed until the next turn so a second path for the *same*
        // physical key (e.g. onKeyPress + keyDown) does not insert twice. Key repeat
        // and the next distinct key arrive on a later turn after this clears.
        DispatchQueue.main.async {
            isDeliveringBlockingKey = false
        }
        return true
    }

    /// Reverse-video the Facility cursor cell so the editor insert point is obvious.
    /// Facility rows are fixed-width lines (`forth.facilityCols`) joined by newlines after the banner.
    ///
    /// Always clear prior highlights first: when the cursor moves without scrolling,
    /// the painted screen string is often identical, so NSTextView does not replace
    /// the storage — only re-applying attributes would leave a "trail" of old cells.
    private func applyFacilityCursorHighlight() {
        guard let textView = consoleTextView, let storage = textView.textStorage else { return }

        let full = NSRange(location: 0, length: storage.length)
        if full.length > 0 {
            storage.removeAttribute(.backgroundColor, range: full)
            // Restore default ink after a prior reverse-video cell.
            storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: full)
        }

        guard forth.isFacilityTerminalActive else { return }

        let bannerLen = (consoleMessage as NSString).length
        let cols = max(1, forth.facilityCols)
        let row = forth.facilityCursorRow
        let col = min(max(0, forth.facilityCursorCol), cols - 1)
        // Each rendered line is `cols` ASCII bytes + '\n' (except we may have added a trailing \n).
        let loc = bannerLen + row * (cols + 1) + col
        guard loc >= 0 && loc < storage.length else { return }

        let range = NSRange(location: loc, length: 1)
        storage.addAttribute(.backgroundColor, value: NSColor.controlAccentColor, range: range)
        storage.addAttribute(.foregroundColor, value: NSColor.white, range: range)
    }

    /// REPL Return: always submit the full current input, never split the line at the caret.
    @discardableResult
    private func handleReturnKey() -> Bool {
        guard !isHandlingReturn else { return true }
        isHandlingReturn = true
        defer {
            DispatchQueue.main.async {
                isHandlingReturn = false
            }
        }

        if forth.waitingForKey {
            // Enter → CR (13). Do *not* mutate consoleText: provideKey runs SZ-REDRAW and
            // onTerminalRefresh owns the paint. Stripping a trailing newline here deleted a
            // character from the facility screen on every Return.
            _ = deliverBlockingKey(13)
            return true
        }

        if forth.waitingForExtendedKey {
            forth.provideExtendedKey(TZForth.makeCharKeyEvent(13, mods: 0))
            lastKeyConsumedUserLength = 0
            return true
        }

        commitUserInput()
        return true
    }

    private func filteredCommandLines(from userPortion: String, dropTrailingEmpty: Bool) -> [String] {
        var lines = userPortion.components(separatedBy: .newlines)
        if dropTrailingEmpty,
           let last = lines.last,
           last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.removeLast()
        }
        return lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { raw in
                let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty && !t.hasPrefix("===") else { return false }
                if t == "OK" || t.hasSuffix(" OK") { return false }
                return true
            }
    }

    /// Submit all pending user input (single line or multi-line paste). Never splits at caret.
    private func commitUserInput() {
        guard !isRecallingHistory else { return }

        lastKeyConsumedUserLength = 0
        let userPortion = String(consoleText.dropFirst(protectedLength))

        if userPortion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            commitEmptyLine()
            return
        }

        let candidateLines = filteredCommandLines(from: userPortion, dropTrailingEmpty: false)
        if candidateLines.isEmpty {
            commitEmptyLine()
            return
        }

        finalizeCommittedInputLine()
        dispatchCandidateLines(candidateLines)
    }

    /// End the committed command line before engine output so responses start on the next line.
    private func finalizeCommittedInputLine() {
        pinCaretRequest += 1
        if !consoleText.hasSuffix("\n") {
            consoleText += "\n"
        }
        markProtectedThroughEndOfText()
    }

    private func commitEmptyLine() {
        markProtected(through: consoleText.count)
        pinCaretRequest += 1
        DispatchQueue.main.async {
            forth.feedLine("")
            // onOutput (now synchronous on main) has already appended " OK\n".

            applyClearScreenIfRequested()

            if !consoleText.hasSuffix("\n") {
                consoleText += "\n"
                markProtectedThroughEndOfText()
            }
            keepCursorVisible(followPrompt: true)
        }
    }

    /// CLS clears the entire console window (including the startup banner).
    /// PAGE / facility terminal uses its own buffer refresh path.
    private func applyClearScreenIfRequested() {
        guard forth.clearScreenRequested else { return }
        if forth.isFacilityTerminalActive {
            forth.clearScreenRequested = false
            return
        }
        isProgrammaticConsoleAppend = true
        consoleText = ""
        markProtectedThroughEndOfText()
        lastKeyConsumedUserLength = 0
        isProgrammaticConsoleAppend = false
        forth.clearScreenRequested = false
    }

    private func dispatchCandidateLines(_ candidateLines: [String]) {
        for lineToSend in candidateLines {
            if !forth.waitingForKey {
                commandHistory.append(lineToSend)
                if commandHistory.count > 30 {
                    commandHistory.removeFirst()
                }
            }
        }
        historyIndex = -1

        // FLOAD runs synchronously on the main queue; further feedLine calls are queued behind it.
        // Tell the user immediately so a missing OK is not mistaken for a hung REPL.
        if forth.isLoadingSource && !forth.waitingForKey {
            consoleText += "(command queued — file load still running)\n"
            markProtectedThroughEndOfText()
            pinCaretRequest += 1
        }

        DispatchQueue.main.async {
            forth.clearReplBatchStop()
            for lineToSend in candidateLines {
                if forth.waitingForKey {
                    if lineToSend == candidateLines.last, let first = lineToSend.first {
                        let scalar = first.unicodeScalars.first?.value ?? 0
                        forth.provideKey(Int(scalar))
                    }
                    markProtectedThroughEndOfText()
                } else {
                    forth.feedLine(lineToSend)
                    markProtectedThroughEndOfText()
                    handlePostFeedActions()
                    if forth.replBatchStopRequested {
                        break
                    }
                }

                applyClearScreenIfRequested()
            }

            if !consoleText.hasSuffix("\n") {
                consoleText += "\n"
                markProtectedThroughEndOfText()
            }
            keepCursorVisible(followPrompt: true)
        }
    }

    private func checkForCommandExecution(_ fullText: String) {
        guard !isRecallingHistory else { return }
        
        // Only consider text the user has typed since the last engine output.
        // This protects us from newlines that come from .s, error messages, etc.
        guard fullText.count > protectedLength else { return }
        let userPortion = String(fullText.dropFirst(protectedLength))
        
        // Blocking KEY/EKEY are delivered only via keyDown / handleReturnKey / onKeyPress.
        // Never treat console text mutations as keystrokes: after provideKey the facility
        // screen is rewritten, and removeLast on that paint was deleting display characters
        // and re-feeding garbage (same letter repeating, Enter "deletes", etc.).
        if forth.waitingForKey || forth.waitingForExtendedKey {
            return
        }
        
        // Multi-line paste ending with a newline: commit without requiring Return.
        let lines = userPortion.components(separatedBy: .newlines)
        guard let lastLine = lines.last else { return }
        let trimmedLast = lastLine.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedLast.isEmpty && lines.count >= 2 {
            lastKeyConsumedUserLength = 0
            markProtected(through: fullText.count)
            finalizeCommittedInputLine()

            let candidateLines = filteredCommandLines(from: userPortion, dropTrailingEmpty: true)
            if candidateLines.isEmpty {
                commitEmptyLine()
            } else {
                dispatchCandidateLines(candidateLines)
            }
        }

        // Catch FLOAD/EDIT *Requested (dialog forms) or pending*URL (named FLOAD/EDIT) that were
        // triggered by code execution inside a feedLine (e.g. "EDIT" or "FLOAD" with no name,
        // or named FLOAD/EDIT inside a colon def or loaded source) even if no fresh typing occurred.
        handlePostFeedActions()
    }

    private func setupInitialWorkingDirectory() {
        // The app is sandboxed (see the container path in FileManager), so its process
        // currentDirectoryPath starts in ~/Library/Containers/TZForth.TZForth/Data .
        // We seed it to the last user-chosen directory (via bookmark for persistent
        // sandbox access) or fall back to ~/Documents. This makes named FLOAD/EDIT
        // and panels start in a useful place and have the necessary security scope.
        //
        // Bookmarks are created on successful dialog picks so that future launches
        // (and thus named loads relative to that dir) can re-gain scoped access
        // without re-prompting the user every time.
        if let bookmarkData = UserDefaults.standard.data(forKey: "LastFLOADDirectoryBookmark") {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmarkData,
                                       options: .withSecurityScope,
                                       relativeTo: nil,
                                       bookmarkDataIsStale: &isStale),
               !isStale {
                // Use the centralized activator so it sets currentScopedDirectory and chdir.
                // We pass the resolved URL as "parent" (it is the dir).
                activateLastDirectoryScope(parent: resolved)
                return
            }

        }
        // Fallback
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let docs = home.appendingPathComponent("Documents")
        let downloads = home.appendingPathComponent("Downloads")
        let desktop = home.appendingPathComponent("Desktop")

        // Build priority list of "likely right place" defaults. We set *logicalCurrentDirectory*
        // to the chosen one (the string path) *even if* sandbox fileExists/chdir can't see it yet.
        // This directly addresses "default directory never the right place": on launch (or after
        // clearing state) the REPL will report and resolve relative FLOAD/CHDIR/DIR from a useful
        // user location like ~/Downloads (where many .fth files live) or the project dir.
        // A real grant (one bare `fload` + pick) is still required for Data/scope, but at least
        // the paths line up and `chdir` (improved below) can move the logical view immediately.
        var target = home
        let env = ProcessInfo.processInfo.environment

        // Highest priority: Xcode build environment (when launched from Xcode scheme, this is
        // usually the project dir containing the sources).
        if let proj = env["PROJECT_DIR"] ?? env["SRCROOT"] ?? env["PWD"] {
            let p = URL(fileURLWithPath: proj)
            target = p
        } else {
            // Common dev layout for *this* project.
            let tzGuess = docs.appendingPathComponent("XCodeProjects/TZForth")
            if fm.fileExists(atPath: tzGuess.path) {
                target = tzGuess
            } else {
                // Also try the plain TZForth dir under Documents (some users put it there).
                let plainTZ = docs.appendingPathComponent("TZForth")
                if fm.fileExists(atPath: plainTZ.path) {
                    target = plainTZ
                }
            }
        }

        // Now layer in standard user locations that frequently contain Forth sources or the
        // specific file the user is trying to FLOAD (e.g. ~/Downloads/Forthing.fth). We prefer
        // a location that is visible to us if possible; otherwise we still use the first
        // high-value one for *logical* so that the reported default + named FLOAD resolution
        // start in the place the user actually keeps their .fth files.
        let highValue: [URL] = [target, downloads, docs, desktop, home]
        if let firstVisible = highValue.first(where: { fm.fileExists(atPath: $0.path) }) {
            target = firstVisible
        } else if fm.fileExists(atPath: downloads.path) {
            target = downloads
        } else if fm.fileExists(atPath: docs.path) {
            target = docs
        } else {
            // Fall back to Downloads for logical even if not "visible" — very common location
            // for user .fth files (Forthing.fth etc.). chdir/DIR/relative FLOAD will then be
            // against the right path string from the very first prompt.
            target = downloads
        }

        _ = fm.changeCurrentDirectoryPath(target.path)
        forth.logicalCurrentDirectory = target.path
        // Best effort to persist bookmark for the seeded dir so that named FLOAD of files
        // in that dir (Downloads, Documents, project, etc.) can succeed on first launch
        // without a prior bare dialog. This will only succeed if the sandbox grants allow it.
        do {
            let bookmark = try target.bookmarkData(options: [.withSecurityScope],
                                                   includingResourceValuesForKeys: nil,
                                                   relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: "LastFLOADDirectoryBookmark")
            UserDefaults.standard.set(target.path, forKey: "LastFLOADDirectory")
            activateLastDirectoryScope(parent: target)
        } catch {
            // Named FLOAD may require an initial bare FLOAD (dialog) to authorize the dir.
            // Still leave logical set to our best guess (often ~/Downloads or the project dir)
            // so "chdir" reports the right place and named FLOAD constructs the correct URL.
            forth.logicalCurrentDirectory = target.path
        }
    }

    /// Reveal Contents/Resources/AutoLoad/ in Finder (bundle seed / zip-customize location).
    private func revealAutoloadFolderInFinder() {
        guard let dir = TZForth.bundleAutoloadDirectoryURL() else {
            isProgrammaticConsoleAppend = true
            consoleText += "? Tools → AUTOLOAD: no Resources/AutoLoad in this app bundle\n"
            markProtectedThroughEndOfText()
            isProgrammaticConsoleAppend = false
            return
        }
        NSWorkspace.shared.open(dir)
    }

    /// Reveal Contents/Resources/Library/ in Finder.
    private func revealLibraryFolderInFinder() {
        if let dir = TZForth.bundleLibraryDirectoryURL() {
            NSWorkspace.shared.open(dir)
            return
        }
        // Create empty Library in bundle is not possible; show message.
        isProgrammaticConsoleAppend = true
        consoleText += "? Tools → LIBRARY: no Resources/Library in this app bundle (rebuild with TZForth/Library/)\n"
        markProtectedThroughEndOfText()
        isProgrammaticConsoleAppend = false
    }

    /// Reveal Contents/Resources/docs/ in Finder (RTF manuals for TextEdit).
    private func revealDocsFolderInFinder() {
        if let dir = TZForth.bundleDocsDirectoryURL() {
            NSWorkspace.shared.open(dir)
            return
        }
        isProgrammaticConsoleAppend = true
        consoleText += "? Tools → DOCS: no Resources/docs in this app bundle (rebuild with TZForth/Docs/)\n"
        markProtectedThroughEndOfText()
        isProgrammaticConsoleAppend = false
    }

    private func showDirectoryPickDialog() {
        let requested = forth.directoryPickRequested
        forth.directoryPickRequested = false
        forth.fileLoadRequested = false
        forth.fileEditRequested = false
        forth.pendingEditURL = nil
        forth.pendingLoadURL = nil
        guard requested else { return }

        // FROMLIB CHDIR: panel may start at Resources/Library without changing session cwd.
        // Cancel → leave session cwd as-is. OK → permanently adopt the chosen folder.
        let overrideStart = forth.fileDialogStartDirectoryOverride
        forth.fileDialogStartDirectoryOverride = nil
        let startDirPath = overrideStart
            ?? (forth.logicalCurrentDirectory.isEmpty
                ? FileManager.default.currentDirectoryPath
                : forth.logicalCurrentDirectory)
        let startDir = URL(fileURLWithPath: startDirPath)
        if overrideStart == nil {
            // Normal bare CHDIR: activate any existing bookmark for the session start dir.
            activateLastDirectoryScope(parent: startDir)
        }
        // Override start (e.g. Library): do not rewrite session scope/cwd before the pick.

        let panel = NSOpenPanel()
        panel.title = "CHDIR — Choose Directory"
        panel.message = "Select a folder for the current working directory. This authorizes TZForth to list (DIR) and access files there."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = startDir

        panel.begin { result in
            if result == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    self.applyDirectoryChange(url)
                    self.forth.onOutput?("Current directory: \(self.forth.logicalCurrentDirectory)\n")
                    if self.currentScopedDirectory != nil {
                        self.forth.onOutput?("(sandbox: directory access authorized)\n")
                    } else {
                        self.forth.onOutput?("(sandbox: use bare `fload` and pick a file in this folder to authorize reads)\n")
                    }
                }
            }
            // Cancel: session cwd / scope left unchanged (including FROMLIB CHDIR).
        }
    }

    private func showFileLoadDialog() {
        let requested = forth.fileLoadRequested
        forth.fileLoadRequested = false
        forth.fileEditRequested = false
        forth.directoryPickRequested = false
        forth.pendingEditURL = nil
        forth.pendingLoadURL = nil
        guard requested else { return }

        // Ensure the current (logical) directory has its security scope active (from bookmark).
        // Use logicalCurrentDirectory (which our improved seeding + chdir logic keeps pointed
        // at the "right place" like ~/Downloads or the project dir) so the panel starts where
        // the user expects, even if the process cwd is still the sandbox container.
        // FROMLIB bare FLOAD: panel starts in Library; session CHDIR must not stick after cancel or load.
        let preserveCwd = forth.preserveSessionCwdAfterFileOp || forth.fileDialogStartDirectoryOverride != nil
        let savedLogical = forth.logicalCurrentDirectory
        let savedProcess = FileManager.default.currentDirectoryPath
        forth.preserveSessionCwdAfterFileOp = false
        let startDirPath = forth.fileDialogStartDirectoryOverride
            ?? (forth.logicalCurrentDirectory.isEmpty ? FileManager.default.currentDirectoryPath : forth.logicalCurrentDirectory)
        forth.fileDialogStartDirectoryOverride = nil
        let startDir = URL(fileURLWithPath: startDirPath)
        if !preserveCwd {
            activateLastDirectoryScope(parent: startDir)
        }

        let panel = NSOpenPanel()
        panel.title = "FLOAD Forth Source"
        panel.message = "Select a .fth file (or text file) to load and interpret/compile."
        panel.prompt = "Load"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        panel.directoryURL = startDir
        panel.allowedContentTypes = [
            UTType(filenameExtension: "fth") ?? .plainText,
            UTType(filenameExtension: "fs") ?? .plainText,
            .plainText,
            UTType(filenameExtension: "forth") ?? .plainText
        ]

        panel.begin { result in
            if result == .OK, let url = panel.url {
                let parent = url.deletingLastPathComponent()
                let accessing = url.startAccessingSecurityScopedResource()

                DispatchQueue.main.async {
                    if preserveCwd {
                        // FROMLIB bare FLOAD: do not permanently change session CHDIR, but
                        // nested FLOAD/INCLUDED must resolve next to the picked file
                        // (e.g. Editor/SZ-EDITOR.fth → FLOAD sz-host.fth).
                        self.forth.logicalCurrentDirectory = parent.path
                        _ = FileManager.default.changeCurrentDirectoryPath(parent.path)
                        self.forth.loadFile(url)
                        self.restoreSessionDirectory(logical: savedLogical, process: savedProcess)
                    } else {
                        do {
                            let bookmark = try parent.bookmarkData(options: [.withSecurityScope],
                                                                   includingResourceValuesForKeys: nil,
                                                                   relativeTo: nil)
                            UserDefaults.standard.set(bookmark, forKey: "LastFLOADDirectoryBookmark")
                        } catch {
                            UserDefaults.standard.set(parent.path, forKey: "LastFLOADDirectory")
                        }
                        activateLastDirectoryScope(parent: parent)
                        self.forth.loadFile(url)
                        if self.currentScopedDirectory != nil {
                            self.forth.onOutput?("(sandbox: directory access authorized via \(parent.lastPathComponent))\n")
                        }
                    }
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } else if preserveCwd {
                DispatchQueue.main.async {
                    self.restoreSessionDirectory(logical: savedLogical, process: savedProcess)
                }
            }
        }
    }

    /// Restore logical + process cwd after a FROMLIB file dialog or named EDIT.
    private func restoreSessionDirectory(logical: String, process: String) {
        if !logical.isEmpty {
            forth.logicalCurrentDirectory = logical
        }
        let proc = process.isEmpty ? logical : process
        if !proc.isEmpty {
            _ = FileManager.default.changeCurrentDirectoryPath(proc)
        }
    }

    // MARK: - File menu (New / Open / Save / Close → SZ-EDITOR)

    /// ⌘S / File → Save. While the edit KEY loop is waiting, inject save (code 19).
    private func handleFileSave() {
        guard forth.isSZEditorLoaded() else {
            appendHostNote("? SZ-EDITOR not loaded (check AutoLoad)\n")
            return
        }
        if forth.waitingForKey && forth.szEditorSessionActive {
            _ = deliverBlockingKey(19) // SZ-CTRL-S / save
            return
        }
        appendHostNote("? Save: open a file in SZ-EDITOR first (File → Open or SZEDIT)\n")
    }

    /// ⌘W / File → Close. Leaves the editor (not the app). Inject quit-editor (code 17).
    private func handleFileClose() {
        if forth.waitingForKey && forth.szEditorSessionActive {
            _ = deliverBlockingKey(17) // SZ-DO-QUIT path
            return
        }
        // Not in editor: ignore (⌘W must not quit the app; ⌘Q does that).
    }

    /// ⌘N / File → New. Empty untitled buffer; starts editor if needed.
    private func handleFileNew() {
        guard forth.isSZEditorLoaded() else {
            appendHostNote("? SZ-EDITOR not loaded (check AutoLoad)\n")
            return
        }
        if forth.waitingForKey && forth.szEditorSessionActive {
            if !confirmDiscardOrSaveIfDirty(action: "create a new file") { return }
            _ = deliverBlockingKey(31) // SZ-CMD-NEW
            return
        }
        if forth.waitingForKey {
            appendHostNote("? New: finish the current KEY wait first\n")
            return
        }
        DispatchQueue.main.async {
            // Body words live in EDITOR (only SZEDIT is in FORTH).
            self.forth.feedLineInEditorVocabulary("SZ-EDIT-NEW")
            self.markProtectedThroughEndOfText()
            self.keepCursorVisible(followPrompt: true)
        }
    }

    /// ⌘O / File → Open…. Panel, then edit (or reload buffer if already editing).
    private func handleFileOpen() {
        guard forth.isSZEditorLoaded() else {
            appendHostNote("? SZ-EDITOR not loaded (check AutoLoad)\n")
            return
        }
        if forth.waitingForKey && forth.szEditorSessionActive {
            if !confirmDiscardOrSaveIfDirty(action: "open another file") { return }
            presentEditorOpenPanel { url in
                self.forth.pendingEditorPath = url.path
                _ = self.deliverBlockingKey(30) // SZ-CMD-OPEN
            }
            return
        }
        if forth.waitingForKey {
            appendHostNote("? Open: finish the current KEY wait first\n")
            return
        }
        presentEditorOpenPanel { url in
            self.forth.pendingEditorPath = url.path
            DispatchQueue.main.async {
                // Body words live in EDITOR (only SZEDIT is in FORTH).
                self.forth.feedLineInEditorVocabulary("SZ-HOST-OPEN-EDIT")
                self.markProtectedThroughEndOfText()
                self.keepCursorVisible(followPrompt: true)
            }
        }
    }

    private func appendHostNote(_ s: String) {
        isProgrammaticConsoleAppend = true
        consoleText += s
        markProtectedThroughEndOfText()
        isProgrammaticConsoleAppend = false
        keepCursorVisible(followPrompt: true)
    }

    /// If dirty, ask Save / Don't Save / Cancel. Returns false if Cancel or if Save was chosen
    /// (save is injected via KEY; user should invoke Open/New again after save completes).
    private func confirmDiscardOrSaveIfDirty(action: String) -> Bool {
        guard forth.isSZEditorDirty() else { return true }
        let alert = NSAlert()
        alert.messageText = "The buffer has unsaved changes."
        alert.informativeText = "Do you want to save before you \(action)?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // Inject save into the KEY loop; do not continue open/new in the same gesture.
            if forth.waitingForKey && forth.szEditorSessionActive {
                _ = deliverBlockingKey(19)
            }
            return false
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    private func presentEditorOpenPanel(onPick: @escaping (URL) -> Void) {
        // FROMLIB SZEDIT / host may set fileDialogStartDirectoryOverride (e.g. Library).
        let startDirPath: String
        if let override = forth.fileDialogStartDirectoryOverride, !override.isEmpty {
            forth.fileDialogStartDirectoryOverride = nil
            startDirPath = override
        } else if !forth.logicalCurrentDirectory.isEmpty {
            startDirPath = forth.logicalCurrentDirectory
        } else {
            startDirPath = FileManager.default.currentDirectoryPath
        }
        let startDir = URL(fileURLWithPath: startDirPath)
        activateLastDirectoryScope(parent: startDir)

        let panel = NSOpenPanel()
        panel.title = "Open — SZ-EDITOR"
        panel.message = "Choose a text file to edit."
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = startDir
        panel.allowedContentTypes = [
            UTType(filenameExtension: "fth") ?? .plainText,
            UTType(filenameExtension: "txt") ?? .plainText,
            UTType(filenameExtension: "fs") ?? .plainText,
            .plainText,
        ]
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            DispatchQueue.main.async {
                onPick(url)
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }

    /// Bare SZEDIT / SZ-HOST-REQUEST-OPEN → same open panel as File → Open.
    private func handleSZEditorOpenRequestIfNeeded() {
        guard forth.szEditorOpenRequested else { return }
        forth.szEditorOpenRequested = false
        guard forth.isSZEditorLoaded() else {
            appendHostNote("? SZ-EDITOR not loaded (check AutoLoad)\n")
            forth.fileDialogStartDirectoryOverride = nil
            return
        }
        if forth.waitingForKey {
            appendHostNote("? SZEDIT: finish the current KEY wait first\n")
            forth.fileDialogStartDirectoryOverride = nil
            return
        }
        presentEditorOpenPanel { url in
            self.forth.pendingEditorPath = url.path
            DispatchQueue.main.async {
                self.forth.feedLineInEditorVocabulary("SZ-HOST-OPEN-EDIT")
                self.markProtectedThroughEndOfText()
                self.keepCursorVisible(followPrompt: true)
            }
        }
    }

    private func handlePostFeedActions() {
        // Defer host dialogs until the outermost FLOAD/INCLUDED finishes. onOutput fires on
        // every tell() during a long load; without this guard a stray bare FLOAD at the end of
        // the same REPL line would pop the file panel when the final OK is printed.
        guard !forth.isLoadingSource else { return }

        // Unified handling after a feedLine (or empty) so that FLOAD/EDIT/CHDIR (dialog or named forms)
        // that were executed during interpretation get serviced promptly. This covers:
        // - bare "fload" / "edit" / "chdir" (set *Requested flag -> show dialog)
        // - "fload foo" / "edit foo" (named; sets pendingLoadURL / pendingEditURL)
        // - bare "szedit" / "fromlib szedit" (szEditorOpenRequested → SZ-EDITOR panel)
        // - same when executed from inside colon defs or loaded source.
        if forth.directoryPickRequested {
            showDirectoryPickDialog()
        }
        if forth.fileLoadRequested {
            showFileLoadDialog()
        }
        if forth.viewLibraryRequested {
            forth.viewLibraryRequested = false
            revealLibraryFolderInFinder()
        }
        handlePendingLoadIfNeeded()
        handlePendingEditIfNeeded()
        if forth.fileEditRequested {
            showFileEditDialog()
        }
        handleSZEditorOpenRequestIfNeeded()
    }

    private func handlePendingEditIfNeeded() {
        guard let url = forth.pendingEditURL else { return }
        forth.pendingEditURL = nil
        let preserveCwd = forth.preserveSessionCwdAfterFileOp
        forth.preserveSessionCwdAfterFileOp = false
        let savedLogical = forth.logicalCurrentDirectory
        let savedProcess = FileManager.default.currentDirectoryPath

        // Support EDIT convention like FLOAD: for names without dot in leaf, if the exact file
        // doesn't exist but "name.fth" does, use the .fth version. This lets "EDIT Forthing"
        // open "Forthing.fth" after a "fload Forthing".
        var target = url
        let leaf = url.lastPathComponent
        if !leaf.contains(".") {
            let alt = url.deletingLastPathComponent().appendingPathComponent(leaf + ".fth")
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) && fm.fileExists(atPath: alt.path) {
                target = alt
            }
        }

        let parent = target.deletingLastPathComponent()
        if !preserveCwd {
            // Activate the (bookmarked) dir scope first. This is required so that the subsequent
            // startAccessing on the (constructed) file URL succeeds and the scope can be transferred
            // to the external editor via NSWorkspace.open for write access.
            activateLastDirectoryScope(parent: parent)
        }

        // For *named* EDIT the URL was resolved from a path spec (possibly with ~), not from a
        // fresh panel pick, so we may not have a brand-new security scope for it. We still
        // attempt start/stop for consistency. NSWorkspace.open will launch the user's editor
        // (TextEdit by default for text/.fth) on the file; the editor itself gets access.
        let accessing = target.startAccessingSecurityScopedResource()
        // To properly hand off write access to an external editor in a sandboxed app,
        // create a security-scoped bookmark for the *file* (while we have access) and
        // open a freshly resolved scoped URL. This is more reliable than opening the
        // plain constructed target URL.
        var opened = false
        if accessing {
            if !preserveCwd {
                // Opportunistically bookmark the dir if we have access right now.
                do {
                    let bookmark = try parent.bookmarkData(options: [.withSecurityScope],
                                                           includingResourceValuesForKeys: nil,
                                                           relativeTo: nil)
                    UserDefaults.standard.set(bookmark, forKey: "LastFLOADDirectoryBookmark")
                } catch {}
            }
            do {
                let fileBM = try target.bookmarkData(options: [.withSecurityScope],
                                                     includingResourceValuesForKeys: nil,
                                                     relativeTo: nil)
                var stale = false
                if let scopedFile = try? URL(resolvingBookmarkData: fileBM,
                                             options: .withSecurityScope,
                                             relativeTo: nil,
                                             bookmarkDataIsStale: &stale),
                   !stale {
                    if scopedFile.startAccessingSecurityScopedResource() {
                        NSWorkspace.shared.open(scopedFile)
                        scopedFile.stopAccessingSecurityScopedResource()
                        opened = true
                    }
                }
            } catch {}
        }
        if !opened {
            NSWorkspace.shared.open(target)
        }
        if accessing {
            target.stopAccessingSecurityScopedResource()
        }
        if preserveCwd {
            restoreSessionDirectory(logical: savedLogical, process: savedProcess)
        }
    }

    /// Named FLOAD: activate sandbox scope, resolve case, and load synchronously (returns success).
    @discardableResult
    private func performScopedNamedLoad(url: URL) -> Bool {
        // Chdir to the loaded file's folder so relative INCLUDED/FLOAD inside that file resolve,
        // then restore the pre-load directory when the load returns (e.g. test.fth → fp/runfptests.fth
        // must not leave cwd stuck in fp/).
        let savedLogicalCwd = forth.logicalCurrentDirectory
        let savedProcessCwd = FileManager.default.currentDirectoryPath
        defer {
            forth.logicalCurrentDirectory = savedLogicalCwd
            let restorePath = savedLogicalCwd.isEmpty ? savedProcessCwd : savedLogicalCwd
            if !restorePath.isEmpty {
                _ = FileManager.default.changeCurrentDirectoryPath(restorePath)
            }
            // Re-activate user bookmark scope only for non-bundle session dirs.
            if !restorePath.isEmpty, !forth.pathIsInsideAppBundle(restorePath) {
                activateLastDirectoryScope(parent: URL(fileURLWithPath: restorePath))
            }
        }

        let preParent = url.deletingLastPathComponent()

        // App-bundle sources (Resources/AutoLoad, Library, docs, …) are always readable by
        // this process — no security-scoped bookmark. Nested FLOAD from AutoLoad boot must
        // not demand "bare FLOAD to authorize" for files next to autoload.fth.
        if forth.pathIsInsideAppBundle(url.path) || forth.pathIsInsideAppBundle(preParent.path) {
            var target = url
            let leaf = url.lastPathComponent
            if let real = realURLForLeaf(leaf, inDirectory: preParent.path) {
                target = real
            } else if !leaf.contains(".") {
                if let realFth = realURLForLeaf(leaf + ".fth", inDirectory: preParent.path) {
                    target = realFth
                }
            }
            let parent = target.deletingLastPathComponent()
            forth.logicalCurrentDirectory = parent.path
            _ = FileManager.default.changeCurrentDirectoryPath(parent.path)
            let loaded = forth.loadFile(target)
            return loaded && !forth.errorFlag
        }

        // Activate the (bookmarked) dir scope first. This makes subsequent access (including
        // Data for load, and later EDIT handoff) work for files inside the dir.
        // Note: we pass the pre-correction parent for activate's path set (it will use bookmark anyway).
        activateLastDirectoryScope(parent: preParent)

        // The URL from the engine was resolved using cwd at the exact time the "fload <name>"
        // command was fed. If a previous bare fload's async chdir hadn't run yet, or due to
        // case differences (user typed lower "forthing.fth" but file is "Forthing.fth"), the
        // target may not exist or have wrong case for scope/Data.
        // After activate (which now aggressively starts direct scope on preParent + hardens
        // bookmark when possible), ensure direct scope on the exact target dir before we
        // attempt directory listing for case correction (realURLForLeaf) or Data load.
        let dirForTarget = preParent
        let dirAccessing = dirForTarget.startAccessingSecurityScopedResource()
        if dirAccessing {
            // Make currentScoped the precise one so later stops are correct, and bookmark harden.
            if let old = currentScopedDirectory, old != dirForTarget {
                old.stopAccessingSecurityScopedResource()
            }
            currentScopedDirectory = dirForTarget
            // While we have direct, try (re)bookmark the exact dir for persistence.
            do {
                let bm = try dirForTarget.bookmarkData(options: [.withSecurityScope],
                                                       includingResourceValuesForKeys: nil,
                                                       relativeTo: nil)
                UserDefaults.standard.set(bm, forKey: "LastFLOADDirectoryBookmark")
            } catch {}
        }

        // After (re)activating, do case-insensitive lookup in the target dir to get a
        // real-cased target URL for the leaf (or .fth variant).
        var target = url
        let leaf = url.lastPathComponent
        let lookupDir = dirForTarget.path
        if let real = realURLForLeaf(leaf, inDirectory: lookupDir) {
            target = real
        } else if !leaf.contains(".") {
            if let realFth = realURLForLeaf(leaf + ".fth", inDirectory: lookupDir) {
                target = realFth
            }
        }

        let parent = target.deletingLastPathComponent()

        // For *named* FLOAD the URL was resolved in-engine from a path spec (possibly with ~ or
        // relative to current cwd at FLOAD time), not from a fresh panel pick. We must call
        // startAccessingSecurityScopedResource here so the subsequent Data(contentsOf:) inside
        // loadFileContents succeeds in a sandboxed app.
        let fileAccessing = target.startAccessingSecurityScopedResource()
        let loaded = self.forth.loadFile(target)
        if loaded {
            // On successful load, ensure we have a bookmark for this exact dir (now that we
            // have direct scope from above or ancestor, bookmarkData should succeed).
            do {
                let bookmark = try parent.bookmarkData(options: [.withSecurityScope],
                                                       includingResourceValuesForKeys: nil,
                                                       relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "LastFLOADDirectoryBookmark")
            } catch {}
        }
        if fileAccessing {
            target.stopAccessingSecurityScopedResource()
        }
        // Do *not* stop dirAccessing here: if we acquired direct scope on the load dir we want
        // it to remain active (like ancestor scopes) for the rest of the session so that
        // subsequent named FLOADs/EDITs/DIR in the same tree keep working without re-auth.
        // onDisappear or next dir change will clean up the currentScoped.
        return loaded && !self.forth.errorFlag
    }

    private func handlePendingLoadIfNeeded() {
        guard let url = forth.pendingLoadURL else { return }
        forth.pendingLoadURL = nil
        _ = performScopedNamedLoad(url: url)
    }

    /// Activate (or re-activate) the security scope for the last bookmarked directory.
    /// This ensures that constructed file URLs inside that directory have the necessary
    /// access for Data(contentsOf:) and especially for NSWorkspace.open(...) to grant
    /// the external editor write access. We keep the dir scope active across operations
    /// (stopped only on dir change or view disappear).
    private func activateLastDirectoryScope(parent: URL) {
        // Always persist the path for display / fallback.
        UserDefaults.standard.set(parent.path, forKey: "LastFLOADDirectory")

        // First, if we have a (possibly ancestor) bookmark, resolve + start it to gain
        // covering scope. This may allow later direct start on the requested subdir.
        var ancestorStarted = false
        if let bookmarkData = UserDefaults.standard.data(forKey: "LastFLOADDirectoryBookmark") {
            var isStale = false
            do {
                let scopedDir = try URL(resolvingBookmarkData: bookmarkData,
                                        options: .withSecurityScope,
                                        relativeTo: nil,
                                        bookmarkDataIsStale: &isStale)
                if !isStale {
                    if let old = currentScopedDirectory, old != scopedDir {
                        old.stopAccessingSecurityScopedResource()
                    }
                    if scopedDir.startAccessingSecurityScopedResource() {
                        currentScopedDirectory = scopedDir
                        ancestorStarted = true
                    }
                }
            } catch {
                // stale or bad bookmark; will fall back below
            }
        }

        // Now always try to acquire *direct* scope on the exact requested dir (the one
        // passed as parent). If an ancestor scope is active this often succeeds and gives
        // us a precise currentScoped + lets us create a bookmark for *this* dir so that
        // future launches default exactly here (solving "default directory never the right place").
        let requested = parent
        var directStarted = false
        if requested.startAccessingSecurityScopedResource() {
            if let old = currentScopedDirectory, old != requested {
                old.stopAccessingSecurityScopedResource()
            }
            currentScopedDirectory = requested
            directStarted = true
        }

        // chdir to the requested (best effort; scope from ancestor or direct should allow ops)
        _ = FileManager.default.changeCurrentDirectoryPath(requested.path)

        // If we now have direct scope on requested, (re)bookmark it so Last points exactly
        // here and next launch will resolve the bookmark for this precise dir.
        if directStarted {
            do {
                let bm = try requested.bookmarkData(options: [.withSecurityScope],
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil)
                UserDefaults.standard.set(bm, forKey: "LastFLOADDirectoryBookmark")
            } catch {}
        } else if ancestorStarted {
            // We have covering scope but couldn't pin direct on requested (e.g. subdir listing
            // still works under ancestor). Opportunistically try bookmark for requested while
            // ancestor scope is live; this often yields a usable bookmark for the sub.
            do {
                let bm = try requested.bookmarkData(options: [.withSecurityScope],
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil)
                UserDefaults.standard.set(bm, forKey: "LastFLOADDirectoryBookmark")
            } catch {}
        }

        // Prefer a canonical listable path when security scope covers this directory.
        if let accessible = directoryURLWithActiveScope(for: requested) {
            forth.logicalCurrentDirectory = accessible.path
        } else {
            forth.logicalCurrentDirectory = requested.path
        }

        // If we had no bookmark originally and no direct start succeeded, try a last-chance
        // bookmark create (may still fail without any grant).
        if !ancestorStarted && !directStarted {
            // No prior bm and no direct: fall back to path-only logical (already set).
            // Try create anyway (in case implicit access appeared).
            do {
                let bm = try requested.bookmarkData(options: [.withSecurityScope],
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil)
                UserDefaults.standard.set(bm, forKey: "LastFLOADDirectoryBookmark")
                // Re-activate to pick up the one we just made (will hit the has-bm path).
                activateLastDirectoryScope(parent: requested)
            } catch {
                // No grant yet; named FLOAD from here will need a bare dialog first.
            }
        }
    }

    /// Apply host-side effects after a Forth CHDIR: activate sandbox scope, persist bookmark,
    /// and normalize logicalCurrentDirectory to a path that is actually listable.
    private func applyDirectoryChange(_ dirURL: URL) {
        activateLastDirectoryScope(parent: dirURL)
        if let accessible = directoryURLWithActiveScope(for: dirURL) {
            forth.logicalCurrentDirectory = accessible.path
            UserDefaults.standard.set(accessible.path, forKey: "LastFLOADDirectory")
            if currentScopedDirectory != nil {
                do {
                    let bookmark = try accessible.bookmarkData(options: [.withSecurityScope],
                                                               includingResourceValuesForKeys: nil,
                                                               relativeTo: nil)
                    UserDefaults.standard.set(bookmark, forKey: "LastFLOADDirectoryBookmark")
                } catch {}
            }
        } else {
            UserDefaults.standard.set(dirURL.path, forKey: "LastFLOADDirectory")
        }
    }

    /// Returns a directory URL that can be listed with the current security scope active.
    private func directoryURLWithActiveScope(for requested: URL) -> URL? {
        // let fm = FileManager.default
        let reqLower = requested.path.lowercased()

        if let scoped = currentScopedDirectory {
            let scopedLower = scoped.path.lowercased()
            if reqLower == scopedLower {
                return scoped
            }
            if reqLower.hasPrefix(scopedLower + "/") {
                let relative = String(requested.path.dropFirst(scoped.path.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let candidate = scoped.appendingPathComponent(relative)
                if canListDirectory(at: candidate) {
                    return candidate
                }
            }
        }

        if canListDirectory(at: requested) {
            return requested
        }

        return nil
    }

    private func canListDirectory(at url: URL) -> Bool {
        (try? FileManager.default.contentsOfDirectory(at: url,
                                                    includingPropertiesForKeys: nil,
                                                    options: [.skipsHiddenFiles])) != nil
    }

    /// Case-insensitive lookup for a file by leaf name in the given directory.
    /// Returns the URL with the real on-disk case (from directory enumeration) if a match is found.
    /// This ensures we pass correctly-cased URLs to Data(contentsOf:) and startAccessing for
    /// security scope, and handles user typing "forthing" when the file on disk is "Forthing.fth".
    private func realURLForLeaf(_ leaf: String, inDirectory dirPath: String) -> URL? {
        let fm = FileManager.default
        let dirURL = URL(fileURLWithPath: dirPath)
        guard let items = try? fm.contentsOfDirectory(at: dirURL,
                                                       includingPropertiesForKeys: [.nameKey],
                                                       options: [.skipsHiddenFiles]) else {
            return nil
        }
        let lower = leaf.lowercased()
        for item in items {
            if item.lastPathComponent.lowercased() == lower {
                return item
            }
        }
        return nil
    }

    private func showFileEditDialog() {
        let requested = forth.fileEditRequested
        forth.fileEditRequested = false
        forth.fileLoadRequested = false
        forth.directoryPickRequested = false
        forth.pendingEditURL = nil
        forth.pendingLoadURL = nil
        guard requested else { return }

        // FROMLIB bare EDIT: panel starts in Library; always restore session CHDIR after (OK or Cancel).
        let preserveCwd = forth.preserveSessionCwdAfterFileOp || forth.fileDialogStartDirectoryOverride != nil
        let savedLogical = forth.logicalCurrentDirectory
        let savedProcess = FileManager.default.currentDirectoryPath
        forth.preserveSessionCwdAfterFileOp = false
        let startDirPath = forth.fileDialogStartDirectoryOverride
            ?? (forth.logicalCurrentDirectory.isEmpty ? FileManager.default.currentDirectoryPath : forth.logicalCurrentDirectory)
        forth.fileDialogStartDirectoryOverride = nil
        let startDir = URL(fileURLWithPath: startDirPath)
        if !preserveCwd {
            activateLastDirectoryScope(parent: startDir)
        }

        let panel = NSOpenPanel()
        panel.title = "EDIT File in Text Editor"
        panel.message = preserveCwd
            ? "Select a library source file to open in the system default editor (e.g. TextEdit)."
            : "Select a source (or text) file to open in the system default editor (e.g. TextEdit). The current directory will be changed to the file's folder."
        panel.prompt = "Edit"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        panel.directoryURL = startDir
        panel.allowedContentTypes = [
            UTType(filenameExtension: "fth") ?? .plainText,
            UTType(filenameExtension: "fs") ?? .plainText,
            .plainText,
            UTType(filenameExtension: "forth") ?? .plainText,
            .text,
            UTType.item
        ]

        panel.begin { result in
            if result == .OK, let url = panel.url {
                let parent = url.deletingLastPathComponent()
                let accessing = url.startAccessingSecurityScopedResource()

                DispatchQueue.main.async {
                    if preserveCwd {
                        var opened = false
                        do {
                            let fileBM = try url.bookmarkData(options: [.withSecurityScope],
                                                              includingResourceValuesForKeys: nil,
                                                              relativeTo: nil)
                            var stale = false
                            if let scopedFile = try? URL(resolvingBookmarkData: fileBM,
                                                         options: .withSecurityScope,
                                                         relativeTo: nil,
                                                         bookmarkDataIsStale: &stale),
                               !stale {
                                if scopedFile.startAccessingSecurityScopedResource() {
                                    NSWorkspace.shared.open(scopedFile)
                                    scopedFile.stopAccessingSecurityScopedResource()
                                    opened = true
                                }
                            }
                        } catch {}
                        if !opened {
                            NSWorkspace.shared.open(url)
                        }
                        self.forth.editFile(url)
                        self.restoreSessionDirectory(logical: savedLogical, process: savedProcess)
                    } else {
                        do {
                            let bookmark = try parent.bookmarkData(options: [.withSecurityScope],
                                                                   includingResourceValuesForKeys: nil,
                                                                   relativeTo: nil)
                            UserDefaults.standard.set(bookmark, forKey: "LastFLOADDirectoryBookmark")
                        } catch {
                            UserDefaults.standard.set(parent.path, forKey: "LastFLOADDirectory")
                        }
                        activateLastDirectoryScope(parent: parent)
                        var opened = false
                        do {
                            let fileBM = try url.bookmarkData(options: [.withSecurityScope],
                                                              includingResourceValuesForKeys: nil,
                                                              relativeTo: nil)
                            var stale = false
                            if let scopedFile = try? URL(resolvingBookmarkData: fileBM,
                                                         options: .withSecurityScope,
                                                         relativeTo: nil,
                                                         bookmarkDataIsStale: &stale),
                               !stale {
                                if scopedFile.startAccessingSecurityScopedResource() {
                                    NSWorkspace.shared.open(scopedFile)
                                    scopedFile.stopAccessingSecurityScopedResource()
                                    opened = true
                                }
                            }
                        } catch {}
                        if !opened {
                            NSWorkspace.shared.open(url)
                        }
                        self.forth.editFile(url)
                    }
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } else if preserveCwd {
                DispatchQueue.main.async {
                    self.restoreSessionDirectory(logical: savedLogical, process: savedProcess)
                }
            }
        }
    }
    
    private func handleDelete() -> Bool {
        // No user-editable content remains; backspace must not eat protected output.
        consoleText.count <= protectedLength
    }
    
    private func recallHistory(up: Bool) {
        guard !commandHistory.isEmpty else { return }
        
        if up {
            historyIndex = min(historyIndex + 1, commandHistory.count - 1)
        } else {
            historyIndex = max(historyIndex - 1, -1)
        }
        
        guard historyIndex >= 0 else {
            clearCurrentInputLine()
            keepCursorVisible(followPrompt: true)
            return
        }
        
        let selectedCommand = commandHistory[commandHistory.count - 1 - historyIndex]
        insertTextSimulated(selectedCommand)
    }
    
    private func insertTextSimulated(_ text: String) {
        isRecallingHistory = true
        clearCurrentInputLine()
        
        Task {
            for character in text {
                await MainActor.run {
                    consoleText += String(character)
                }
                try? await Task.sleep(for: .milliseconds(6))
            }
            await MainActor.run {
                isRecallingHistory = false
                keepCursorVisible(followPrompt: true)
            }
        }
    }
    
    private func clearCurrentInputLine() {
        // Truncate back to the last engine output (protectedLength). This removes any
        // current/partial user input (including partial history attempts) so the recalled
        // command cleanly replaces the editable area without corrupting previous output
        // lines or protected state. Much more reliable than trying to edit the last
        // visual line, especially after FLOAD (which can add many echoed lines + OKs).
        if consoleText.count > protectedLength {
            consoleText = String(consoleText.prefix(protectedLength))
        }
    }

    private func facilityKeyMods(_ modifiers: EventModifiers) -> Int {
        var m = 0
        if modifiers.contains(.shift) { m |= TZForth.FacilityFKey.shiftMask }
        if modifiers.contains(.control) { m |= TZForth.FacilityFKey.ctrlMask }
        if modifiers.contains(.option) { m |= TZForth.FacilityFKey.altMask }
        return m
    }

    /// Map AppKit function-key Unicode (NSF*FunctionKey) or keyCode to a K-* id (without masks).
    private static func facilityFKeyBaseId(functionUnicode: UInt32) -> Int? {
        let fk = TZForth.FacilityFKey.self
        switch functionUnicode {
        case 0xF700: return fk.up
        case 0xF701: return fk.down
        case 0xF702: return fk.left
        case 0xF703: return fk.right
        case 0xF704: return fk.f1
        case 0xF705: return fk.f2
        case 0xF706: return fk.f3
        case 0xF707: return fk.f4
        case 0xF708: return fk.f5
        case 0xF709: return fk.f6
        case 0xF70A: return fk.f7
        case 0xF70B: return fk.f8
        case 0xF70C: return fk.f9
        case 0xF70D: return fk.f10
        case 0xF70E: return fk.f11
        case 0xF70F: return fk.f12
        case 0xF727: return fk.insert
        case 0xF728: return fk.delete
        case 0xF729: return fk.home
        case 0xF72B: return fk.end
        case 0xF72C: return fk.prior
        case 0xF72D: return fk.next
        default: return nil
        }
    }

    private static func facilityFKeyBaseId(keyCode: UInt16) -> Int? {
        let fk = TZForth.FacilityFKey.self
        switch keyCode {
        case 123: return fk.left
        case 124: return fk.right
        case 126: return fk.up
        case 125: return fk.down
        case 115: return fk.home
        case 119: return fk.end
        case 116: return fk.prior
        case 121: return fk.next
        case 114: return fk.insert
        case 117: return fk.delete
        case 122: return fk.f1
        case 120: return fk.f2
        case 99: return fk.f3
        case 118: return fk.f4
        case 96: return fk.f5
        case 97: return fk.f6
        case 98: return fk.f7
        case 100: return fk.f8
        case 101: return fk.f9
        case 109: return fk.f10
        case 103: return fk.f11
        case 111: return fk.f12
        default: return nil
        }
    }

    private static func facilityKeyModsFromNSEventFlags(_ flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.shift) { m |= TZForth.FacilityFKey.shiftMask }
        if flags.contains(.control) { m |= TZForth.FacilityFKey.ctrlMask }
        if flags.contains(.option) { m |= TZForth.FacilityFKey.altMask }
        return m
    }

    /// Full K-* id (base + shift/ctrl/alt masks) from an AppKit key event.
    private static func facilityFKeyId(from event: NSEvent) -> Int? {
        let mods = facilityKeyModsFromNSEventFlags(event.modifierFlags)
        if let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first,
           let base = facilityFKeyBaseId(functionUnicode: scalar.value) {
            return base | mods
        }
        if let base = facilityFKeyBaseId(keyCode: event.keyCode) {
            return base | mods
        }
        return nil
    }

    private func facilityKeyEvent(from press: KeyPress) -> Int? {
        let mods = facilityKeyMods(press.modifiers)
        if press.characters.count == 1, let scalar = press.characters.unicodeScalars.first {
            let v = scalar.value
            if let base = Self.facilityFKeyBaseId(functionUnicode: v) {
                return TZForth.makeFKeyEvent(base | mods)
            }
            let code = Int(v)
            if code >= 32 || code == 9 {
                return TZForth.makeCharKeyEvent(code, mods: mods)
            }
        }
        if press.key == .delete {
            return TZForth.makeFKeyEvent(TZForth.FacilityFKey.delete | mods)
        }
        return nil
    }
}

/// NSTextView that can intercept function keys for EKEY while the Forth engine is waiting,
/// and raw keyDown for blocking KEY (editor / KEY loops).
private final class FacilityConsoleTextView: NSTextView {
    var onFacilityKeyDown: ((NSEvent) -> Bool)?
    var onBlockingKeyDown: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if onFacilityKeyDown?(event) == true {
            return
        }
        if onBlockingKeyDown?(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    /// Capture Ctrl-S / Ctrl-Q before the system or text system consumes them.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onBlockingKeyDown?(event) == true {
            return true
        }
        if onFacilityKeyDown?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// TextKit maps keyboard navigation to the extra end-of-document line fragment, but mouse
    /// clicks in that row often land on the previous line. Snap clicks on the caret row to EOF.
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let end = (string as NSString).length
        var caretRect = firstRect(forCharacterRange: NSRange(location: end, length: 0), actualRange: nil)
        if caretRect.width == 0, caretRect.height == 0,
           let layoutManager, let textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let extraRect = layoutManager.extraLineFragmentRect
            if extraRect.height > 0,
               layoutManager.extraLineFragmentTextContainer === textContainer {
                let origin = textContainerOrigin
                let inset = textContainerInset
                caretRect = NSRect(
                    x: extraRect.minX + origin.x + inset.width,
                    y: extraRect.minY + origin.y + inset.height,
                    width: max(extraRect.width, 1),
                    height: extraRect.height
                )
            }
        }
        if caretRect.height > 0 {
            let lineHeight = layoutManager?.defaultLineHeight(for: font ?? NSFont.systemFont(ofSize: 16)) ?? 16
            let bandHeight = max(caretRect.height, lineHeight)
            let lineBand = NSRect(
                x: bounds.minX,
                y: caretRect.minY - 1,
                width: bounds.width,
                height: bandHeight + 2
            )
            if lineBand.contains(point) {
                setSelectedRange(NSRange(location: end, length: 0))
                scrollRangeToVisible(NSRange(location: end, length: 0))
                window?.makeFirstResponder(self)
                return
            }
        }
        super.mouseDown(with: event)
    }
}

/// AppKit-backed console editor. SwiftUI TextEditor does not reliably scroll to the
/// insertion point when text is appended programmatically (engine output, OK lines, etc.).
private struct ConsoleTextView: NSViewRepresentable {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @Binding var pinCaretRequest: Int
    /// First UTF-16 index the user may place the caret in (engine/protected output is before this).
    var editableStartUTF16: Int
    /// When true (SZ-EDITOR / PAGE facility paint), do not soft-wrap lines — each facility
    /// row is a fixed-width string; wrapping at the window edge fakes broken line breaks.
    var disableSoftWrap: Bool = false
    /// When true, refuse all text mutations (KEY/EKEY loops own the keyboard).
    var isBlockingKeyboardInput: () -> Bool = { false }
    var onReturnPressed: () -> Bool
    var onFacilityKeyDown: ((NSEvent) -> Bool)?
    /// When KEY is blocking, raw NSEvent → provideKey (Ctrl/BS/printable).
    var onBlockingKeyDown: ((NSEvent) -> Bool)?
    var onTextViewReady: (NSTextView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white

        let textView = FacilityConsoleTextView()
        textView.onFacilityKeyDown = { event in
            context.coordinator.parent.onFacilityKeyDown?(event) ?? false
        }
        textView.onBlockingKeyDown = { event in
            context.coordinator.parent.onBlockingKeyDown?(event) ?? false
        }
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        scrollView.documentView = textView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.textColor = .black
        textView.backgroundColor = .white
        textView.drawsBackground = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        textView.string = text
        let end = (text as NSString).length
        textView.setSelectedRange(NSRange(location: end, length: 0))

        Self.applySoftWrapPolicy(disableSoftWrap, to: textView, scrollView: scrollView)

        context.coordinator.textView = textView
        onTextViewReady(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? FacilityConsoleTextView else { return }
        context.coordinator.parent = self
        textView.onFacilityKeyDown = { event in
            context.coordinator.parent.onFacilityKeyDown?(event) ?? false
        }
        textView.onBlockingKeyDown = { event in
            context.coordinator.parent.onBlockingKeyDown?(event) ?? false
        }

        Self.applySoftWrapPolicy(disableSoftWrap, to: textView, scrollView: scrollView)

        var shouldScroll = false
        let needsPinCaret = context.coordinator.lastHandledPinCaretRequest != pinCaretRequest
        if needsPinCaret {
            context.coordinator.lastHandledPinCaretRequest = pinCaretRequest
        }

        if textView.string != text {
            let oldString = textView.string
            let selected = textView.selectedRange()
            context.coordinator.isProgrammaticUpdate = true
            textView.string = text
            context.coordinator.isProgrammaticUpdate = false

            let end = (text as NSString).length
            let oldEnd = (oldString as NSString).length

            if needsPinCaret {
                textView.setSelectedRange(NSRange(location: end, length: 0))
                shouldScroll = true
            } else if text.hasPrefix(oldString), end > oldEnd, selected.location >= oldEnd {
                // Suffix appends while caret was at end: follow new output.
                textView.setSelectedRange(NSRange(location: end, length: 0))
                shouldScroll = true
            } else if selected.location <= end {
                textView.setSelectedRange(selected)
                shouldScroll = true
            } else {
                textView.setSelectedRange(NSRange(location: end, length: 0))
                shouldScroll = true
            }

            Self.resizeTextViewToFitContent(textView)
        } else if needsPinCaret {
            let end = (text as NSString).length
            textView.setSelectedRange(NSRange(location: end, length: 0))
            shouldScroll = true
            Self.resizeTextViewToFitContent(textView)
        }

        if shouldScroll {
            Self.scheduleScrollToInsertionPoint(in: textView)
        }

        if isFocused, let window = scrollView.window, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }
    }

    /// Soft-wrap policy for the console:
    /// - Facility/editor paint: no wrap (fixed-width rows; wrap fakes extra line breaks).
    /// - Normal REPL: wrap to scroll-view width (comfortable long output).
    fileprivate static func applySoftWrapPolicy(
        _ disableSoftWrap: Bool,
        to textView: NSTextView,
        scrollView: NSScrollView
    ) {
        guard let container = textView.textContainer else { return }
        if disableSoftWrap {
            scrollView.hasHorizontalScroller = true
            scrollView.autohidesScrollers = true
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.height]
            container.widthTracksTextView = false
            // Huge width ⇒ each newline is one visual row (no mid-line wrap).
            let huge = CGFloat.greatestFiniteMagnitude
            container.containerSize = NSSize(width: huge, height: huge)
            textView.minSize = NSSize(width: 0, height: 0)
            textView.maxSize = NSSize(width: huge, height: huge)
        } else {
            scrollView.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            container.widthTracksTextView = true
            let w = max(scrollView.contentSize.width, 1)
            container.containerSize = NSSize(width: w, height: .greatestFiniteMagnitude)
            textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        }
    }

    /// Scroll after layout catches up (needed when WORDS / many OK lines grow the document).
    fileprivate static func scheduleScrollToInsertionPoint(in textView: NSTextView) {
        DispatchQueue.main.async {
            resizeTextViewToFitContent(textView)
            scrollToShowInsertionPoint(in: textView)
            // Large appends (WORDS) may need a second layout pass before geometry is final.
            DispatchQueue.main.async {
                resizeTextViewToFitContent(textView)
                scrollToShowInsertionPoint(in: textView)
            }
        }
    }

    /// Programmatic `string =` updates do not always grow the document view; fix before scrolling.
    private static func resizeTextViewToFitContent(_ textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        var contentBottom = usedRect.maxY
        let extraRect = layoutManager.extraLineFragmentRect
        if extraRect.height > 0, layoutManager.extraLineFragmentTextContainer === textContainer {
            contentBottom = max(contentBottom, extraRect.maxY)
        }

        let inset = textView.textContainerInset
        let targetHeight = max(contentBottom + inset.height * 2, textView.enclosingScrollView?.contentSize.height ?? 0)
        var frame = textView.frame
        var changed = false
        if abs(frame.size.height - targetHeight) > 0.5 {
            frame.size.height = targetHeight
            changed = true
        }
        // When soft-wrap is off, grow width to the used text so horizontal scroll works.
        if textView.isHorizontallyResizable {
            let targetWidth = max(usedRect.maxX + inset.width * 2, textView.enclosingScrollView?.contentSize.width ?? 0)
            if abs(frame.size.width - targetWidth) > 0.5 {
                frame.size.width = targetWidth
                changed = true
            }
        }
        if changed {
            textView.frame = frame
        }
    }

    /// Keep the caret on screen; when at end-of-document, pin the scroll view to the bottom.
    fileprivate static func scrollToShowInsertionPoint(in textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = textView.enclosingScrollView else { return }

        layoutManager.ensureLayout(for: textContainer)

        let range = textView.selectedRange()
        let length = (textView.string as NSString).length
        let atEnd = range.location >= length

        if atEnd {
            scrollToDocumentBottom(
                textView: textView,
                scrollView: scrollView,
                layoutManager: layoutManager,
                textContainer: textContainer
            )
        } else if length > 0 {
            textView.scrollRangeToVisible(NSRange(location: range.location, length: max(range.length, 1)))
        }
    }

    /// Pin the clip view to the true document bottom (caret row included).
    private static func scrollToDocumentBottom(
        textView: NSTextView,
        scrollView: NSScrollView,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) {
        layoutManager.ensureLayout(for: textContainer)

        var contentBottom = layoutManager.usedRect(for: textContainer).maxY
        let extraRect = layoutManager.extraLineFragmentRect
        if extraRect.height > 0, layoutManager.extraLineFragmentTextContainer === textContainer {
            contentBottom = max(contentBottom, extraRect.maxY)
        }

        let origin = textView.textContainerOrigin
        let inset = textView.textContainerInset
        let documentBottom = contentBottom + origin.y + inset.height
        let docHeight = max(documentBottom, textView.frame.maxY)

        let clipView = scrollView.contentView
        let clipHeight = clipView.bounds.height
        let targetY = max(0, docHeight - clipHeight)

        if abs(clipView.bounds.origin.y - targetY) > 0.5 {
            clipView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(clipView)
        }

        if length(of: textView) > 0 {
            textView.scrollRangeToVisible(NSRange(location: length(of: textView), length: 0))
        }
    }

    private static func length(of textView: NSTextView) -> Int {
        (textView.string as NSString).length
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ConsoleTextView
        weak var textView: NSTextView?
        var isProgrammaticUpdate = false
        var lastHandledPinCaretRequest = 0

        init(parent: ConsoleTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate, let textView else { return }
            parent.text = textView.string
        }

        /// Allow free selection anywhere (so Copy works on history). Only refuse edits
        /// that would change the protected engine-output prefix — and refuse *all* edits
        /// while KEY/EKEY is blocking (editor owns the keyboard).
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if parent.isBlockingKeyboardInput() {
                return false
            }
            let minLoc = min(max(0, parent.editableStartUTF16), (textView.string as NSString).length)
            if affectedCharRange.location < minLoc {
                return false
            }
            return true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Return is owned by onReturnPressed (and blocking keyDown for KEY loops).
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return parent.onReturnPressed()
            }

            // While KEY/EKEY waits, do not let NSTextView Emacs bindings steal arrows/up/down.
            // (keyDown → onBlockingKeyDown should already have consumed them; this is backup.)
            if parent.isBlockingKeyboardInput() {
                return true
            }

            // While the caret is on the *input* line (at/after editableStart), do not let
            // left/up navigation walk into protected history. Free movement is allowed when
            // the user has clicked into history to select text for Copy.
            let minLoc = min(max(0, parent.editableStartUTF16), (textView.string as NSString).length)
            let sel = textView.selectedRange()
            let caretInInputLine = sel.length == 0 && sel.location >= minLoc

            if caretInInputLine {
                if commandSelector == #selector(NSResponder.moveLeft(_:))
                    || commandSelector == #selector(NSResponder.moveBackward(_:)) {
                    if sel.location <= minLoc {
                        return true // stay at start of input
                    }
                    textView.setSelectedRange(NSRange(location: sel.location - 1, length: 0))
                    return true
                }
                if commandSelector == #selector(NSResponder.moveWordLeft(_:))
                    || commandSelector == #selector(NSResponder.moveWordBackward(_:))
                    || commandSelector == #selector(NSResponder.moveToBeginningOfLine(_:))
                    || commandSelector == #selector(NSResponder.moveToLeftEndOfLine(_:))
                    || commandSelector == #selector(NSResponder.moveToBeginningOfParagraph(_:))
                    || commandSelector == #selector(NSResponder.moveUp(_:))
                    || commandSelector == #selector(NSResponder.pageUp(_:))
                    || commandSelector == #selector(NSResponder.moveToBeginningOfDocument(_:)) {
                    textView.setSelectedRange(NSRange(location: minLoc, length: 0))
                    return true
                }
            }

            return false
        }
    }
}

// MARK: - Blocking KEY event mapping (SZ-EDITOR / KEY loops)

extension ConsoleView {
    /// Map an NSEvent to a KEY code while waitingForKey. Returns nil to pass through.
    fileprivate static func blockingKeyCode(from event: NSEvent) -> Int? {
        // Never treat Command as Control — Cmd-Q must still quit the app if user chooses.
        if event.modifierFlags.contains(.command) {
            return nil
        }

        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let ctrl = mods.contains(.control)

        // Prefer navigation keys by keyCode (reliable on macOS).
        switch event.keyCode {
        case 123: return 2    // Left
        case 124: return 6    // Right
        case 125: return 14   // Down
        case 126: return 16   // Up
        case 51:  return 8    // Backspace
        case 117: return 4    // Forward delete → Ctrl-D (delete under cursor)
        case 36, 76: return 13 // Return / Enter
        case 115: return ctrl ? 28 : 1   // Home / Ctrl-Home (line / file start)
        case 119: return ctrl ? 29 : 5   // End  / Ctrl-End  (line / file end)
        case 116: return 23   // Page Up
        case 121: return 24   // Page Down
        default: break
        }

        // Control+letter → ASCII control 1..26 (before raw characters, which may be empty).
        // Do not map Ctrl-B/F/N/P (2/6/14/16): editor motion is arrow keys only.
        if ctrl,
           let ch = event.charactersIgnoringModifiers?.lowercased().unicodeScalars.first {
            let v = Int(ch.value)
            if v >= 97 && v <= 122 {
                let code = v - 96
                if code == 2 || code == 6 || code == 14 || code == 16 {
                    return nil
                }
                return code
            }
        }

        // Plain characters (no Command). Ignore Option-only specials for now.
        if let s = event.charactersIgnoringModifiers ?? event.characters,
           let ch = s.unicodeScalars.first {
            let v = Int(ch.value)
            if mods.contains(.control) {
                // Already handled letters; other control combos
                if v > 0 && v < 32 { return v }
                return nil
            }
            if v == 8 || v == 127 || v == 9 || v == 10 || v == 13 { return v }
            if v >= 32 && v < 127 { return v }
        }
        return nil
    }
}

#Preview {
    ConsoleView()
        .frame(width: 700, height: 500)
}
