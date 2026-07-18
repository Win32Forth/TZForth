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

    /// Incremented to request moving the caret to end-of-document (after commit/output).
    @State private var pinCaretRequest = 0

    var body: some View {
        ConsoleTextView(
            text: $consoleText,
            isFocused: $isFocused,
            pinCaretRequest: $pinCaretRequest,
            onReturnPressed: { handleReturnKey() },
            onFacilityKeyDown: { event in
                guard forth.waitingForExtendedKey else { return false }
                guard let fkeyId = Self.facilityFKeyId(from: event) else { return false }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(fkeyId))
                return true
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
                // Engine/startup output must not be treated as illegal edits of protected text.
                if isProgrammaticConsoleAppend {
                    checkForCommandExecution(newValue)
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
                if forth.waitingForExtendedKey {
                    forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.up))
                    return .handled
                }
                recallHistory(up: true)
                return .handled
            }
            .onKeyPress(.downArrow) {
                if forth.waitingForExtendedKey {
                    forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.down))
                    return .handled
                }
                recallHistory(up: false)
                return .handled
            }
            .onKeyPress(.leftArrow) {
                guard forth.waitingForExtendedKey else { return .ignored }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.left))
                return .handled
            }
            .onKeyPress(.rightArrow) {
                guard forth.waitingForExtendedKey else { return .ignored }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.right))
                return .handled
            }
            .onKeyPress(.home) {
                guard forth.waitingForExtendedKey else { return .ignored }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.home))
                return .handled
            }
            .onKeyPress(.end) {
                guard forth.waitingForExtendedKey else { return .ignored }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.end))
                return .handled
            }
            .onKeyPress(.pageUp) {
                guard forth.waitingForExtendedKey else { return .ignored }
                forth.provideExtendedKey(TZForth.makeFKeyEvent(TZForth.FacilityFKey.prior))
                return .handled
            }
            .onKeyPress(.pageDown) {
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
                        self.consoleText = consoleMessage + screen
                        if !screen.hasSuffix("\n") {
                            self.consoleText += "\n"
                        }
                        self.markProtectedThroughEndOfText()
                        self.keepCursorVisible(followPrompt: true)
                    }
                    if Thread.isMainThread {
                        applyTerminal()
                    } else {
                        DispatchQueue.main.async(execute: applyTerminal)
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
            forth.provideKey(10)
            lastKeyConsumedUserLength = 0
            if consoleText.last == "\n" {
                isConsumingKeyChar = true
                consoleText.removeLast()
                markProtectedThroughEndOfText()
                lastKeyConsumedUserLength = 0
            }
            return true
        }

        if forth.waitingForExtendedKey {
            forth.provideExtendedKey(TZForth.makeCharKeyEvent(10, mods: 0))
            lastKeyConsumedUserLength = 0
            if consoleText.last == "\n" {
                isConsumingKeyChar = true
                consoleText.removeLast()
                markProtectedThroughEndOfText()
                lastKeyConsumedUserLength = 0
            }
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
        
        // Special per-keystroke handling for blocking KEY: feed individual characters
        // (including Return) as soon as they are typed, without waiting for a line commit.
        // This allows KEY to truly wait for a single key (not a whole line), and lets
        // the user press Return itself as the key value.
        if forth.waitingForKey {
            if isConsumingKeyChar {
                isConsumingKeyChar = false
                return
            }
            if userPortion.count > lastKeyConsumedUserLength {
                let newPart = String(userPortion.dropFirst(lastKeyConsumedUserLength))
                if let keyChar = newPart.last {
                    let scalar = keyChar.unicodeScalars.first?.value ?? 0
                    forth.provideKey(Int(scalar))
                    lastKeyConsumedUserLength = userPortion.count
                    // Eat the newly typed chars from the visible text so they don't sit as
                    // a pending command line that would later trigger the empty-last-line feed.
                    if consoleText.count >= newPart.count {
                        isConsumingKeyChar = true
                        consoleText.removeLast(newPart.count)
                        markProtectedThroughEndOfText()
                        lastKeyConsumedUserLength = 0
                    }
                }
            }
            // We handled the key input; no need to run the normal line-commit logic for this change.
            return
        }

        if forth.waitingForExtendedKey {
            if isConsumingKeyChar {
                isConsumingKeyChar = false
                return
            }
            if userPortion.count > lastKeyConsumedUserLength {
                let newPart = String(userPortion.dropFirst(lastKeyConsumedUserLength))
                if let keyChar = newPart.last {
                    let scalar = keyChar.unicodeScalars.first?.value ?? 0
                    forth.provideExtendedKey(TZForth.makeCharKeyEvent(Int(scalar), mods: 0))
                    lastKeyConsumedUserLength = userPortion.count
                    if consoleText.count >= newPart.count {
                        isConsumingKeyChar = true
                        consoleText.removeLast(newPart.count)
                        markProtectedThroughEndOfText()
                        lastKeyConsumedUserLength = 0
                    }
                }
            }
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

    private func showDirectoryPickDialog() {
        let requested = forth.directoryPickRequested
        forth.directoryPickRequested = false
        forth.fileLoadRequested = false
        forth.fileEditRequested = false
        forth.pendingEditURL = nil
        forth.pendingLoadURL = nil
        guard requested else { return }

        let startDirPath = forth.logicalCurrentDirectory.isEmpty
            ? FileManager.default.currentDirectoryPath
            : forth.logicalCurrentDirectory
        let startDir = URL(fileURLWithPath: startDirPath)
        activateLastDirectoryScope(parent: startDir)

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
        let startDirPath = forth.logicalCurrentDirectory.isEmpty ? FileManager.default.currentDirectoryPath : forth.logicalCurrentDirectory
        let startDir = URL(fileURLWithPath: startDirPath)
        activateLastDirectoryScope(parent: startDir)

        let panel = NSOpenPanel()
        panel.title = "FLOAD Forth Source"
        panel.message = "Select a .fth file (or text file) to load and interpret/compile."
        panel.prompt = "Load"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        // Start the panel at the logical dir (the one reported by "chdir" and used for
        // relative named FLOAD). After successful pick we still chdir + bookmark the parent.
        panel.directoryURL = startDir
        panel.allowedContentTypes = [
            UTType(filenameExtension: "fth") ?? .plainText,
            UTType(filenameExtension: "fs") ?? .plainText,
            .plainText,
            UTType(filenameExtension: "forth") ?? .plainText
        ]
        // Note: allowedContentTypes provides the type filter. To allow picking files outside these
        // extensions (previous allowsOtherFileTypes behavior), the panel still permits navigation;
        // users can typically choose "All Files" in the type dropdown or the types act as suggestions.

        panel.begin { result in
            if result == .OK, let url = panel.url {
                let parent = url.deletingLastPathComponent()
                let accessing = url.startAccessingSecurityScopedResource()

                DispatchQueue.main.async {
                    // Create a security-scoped bookmark for the *directory* so that on future
                    // launches we can re-acquire scoped access for named FLOAD/EDIT relative
                    // to this dir (and the initial cwd / panel default).
                    do {
                        let bookmark = try parent.bookmarkData(options: [.withSecurityScope],
                                                               includingResourceValuesForKeys: nil,
                                                               relativeTo: nil)
                        UserDefaults.standard.set(bookmark, forKey: "LastFLOADDirectoryBookmark")
                    } catch {
                        // Fallback to path only (less reliable across launches)
                        UserDefaults.standard.set(parent.path, forKey: "LastFLOADDirectory")
                    }

                    // Activate the dir scope (using bookmark) + chdir. This is crucial so that
                    // subsequent named operations and external EDIT handoff have proper access.
                    activateLastDirectoryScope(parent: parent)

                    self.forth.loadFile(url)
                    if self.currentScopedDirectory != nil {
                        self.forth.onOutput?("(sandbox: directory access authorized via \(parent.lastPathComponent))\n")
                    }

                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
            // Cancel: flag already cleared; no load.
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
        // - same when executed from inside colon defs or loaded source.
        if forth.directoryPickRequested {
            showDirectoryPickDialog()
        }
        if forth.fileLoadRequested {
            showFileLoadDialog()
        }
        handlePendingLoadIfNeeded()
        handlePendingEditIfNeeded()
        if forth.fileEditRequested {
            showFileEditDialog()
        }
    }

    private func handlePendingEditIfNeeded() {
        guard let url = forth.pendingEditURL else { return }
        forth.pendingEditURL = nil

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
        // Activate the (bookmarked) dir scope first. This is required so that the subsequent
        // startAccessing on the (constructed) file URL succeeds and the scope can be transferred
        // to the external editor via NSWorkspace.open for write access.
        activateLastDirectoryScope(parent: parent)

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
            // Opportunistically bookmark the dir if we have access right now.
            do {
                let bookmark = try parent.bookmarkData(options: [.withSecurityScope],
                                                       includingResourceValuesForKeys: nil,
                                                       relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "LastFLOADDirectoryBookmark")
            } catch {}
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
            let restorePath = savedLogicalCwd.isEmpty ? savedProcessCwd : savedLogicalCwd
            if restorePath != forth.logicalCurrentDirectory {
                activateLastDirectoryScope(parent: URL(fileURLWithPath: restorePath))
            }
        }

        // Activate the (bookmarked) dir scope first. This makes subsequent access (including
        // Data for load, and later EDIT handoff) work for files inside the dir.
        // Note: we pass the pre-correction parent for activate's path set (it will use bookmark anyway).
        let preParent = url.deletingLastPathComponent()
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

        // Ensure the current (logical) directory has its security scope active (from bookmark).
        // Use logicalCurrentDirectory so the panel starts in the place the user sees via "chdir"
        // / the initial report / named FLOAD resolution (~/Downloads, project dir, etc.).
        let startDirPath = forth.logicalCurrentDirectory.isEmpty ? FileManager.default.currentDirectoryPath : forth.logicalCurrentDirectory
        let startDir = URL(fileURLWithPath: startDirPath)
        activateLastDirectoryScope(parent: startDir)

        let panel = NSOpenPanel()
        panel.title = "EDIT File in Text Editor"
        panel.message = "Select a source (or text) file to open in the system default editor (e.g. TextEdit). The current directory will be changed to the file's folder."
        panel.prompt = "Edit"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        // Start from the logical dir (consistent with FLOAD and with what "chdir" reports).
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
                    // Same side effects as named EDIT handling and as FLOAD dialog:
                    // persist last dir (for next launch via bookmark for sandbox scope), chdir (current session + relatives), open editor.
                    do {
                        let bookmark = try parent.bookmarkData(options: [.withSecurityScope],
                                                               includingResourceValuesForKeys: nil,
                                                               relativeTo: nil)
                        UserDefaults.standard.set(bookmark, forKey: "LastFLOADDirectoryBookmark")
                    } catch {
                        UserDefaults.standard.set(parent.path, forKey: "LastFLOADDirectory")
                    }
                    // Activate dir scope so that NSWorkspace.open can grant write access to editor.
                    activateLastDirectoryScope(parent: parent)

                    // To properly hand off write access to an external editor in a sandboxed app,
                    // create a security-scoped bookmark for the *file* (while we have access from the panel)
                    // and open a freshly resolved scoped URL.
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

                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
            // Cancel: flag cleared; nothing to edit.
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

/// NSTextView that can intercept function keys for EKEY while the Forth engine is waiting.
private final class FacilityConsoleTextView: NSTextView {
    var onFacilityKeyDown: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if onFacilityKeyDown?(event) == true {
            return
        }
        super.keyDown(with: event)
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
    var onReturnPressed: () -> Bool
    var onFacilityKeyDown: ((NSEvent) -> Bool)?
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
        if abs(textView.frame.height - targetHeight) > 0.5 {
            var frame = textView.frame
            frame.size.height = targetHeight
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

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return parent.onReturnPressed()
            }
            return false
        }
    }
}

#Preview {
    ConsoleView()
        .frame(width: 700, height: 500)
}
