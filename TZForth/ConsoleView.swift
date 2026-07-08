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
    @State private var forth = TZForth()

    /// Marks the length of consoleText after the last engine output.
    /// Only text typed by the user *after* this point can be treated as new commands.
    /// This prevents engine newlines (from .s, errors, etc.) from causing the
    /// command detector to re-interpret previous output or old lines.
    @State private var protectedLength = 0

    /// Snapshot of consoleText through protectedLength. User edits must not alter this prefix.
    @State private var protectedSnapshot = ""

    /// Suppresses re-entrancy when reverting a delete that crossed the protected boundary.
    @State private var isRevertingProtectedEdit = false

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

    var body: some View {
        ConsoleTextView(text: $consoleText, isFocused: $isFocused) { textView in
            consoleTextView = textView
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
                recallHistory(up: true)
                return .handled
            }
            .onKeyPress(.downArrow) {
                recallHistory(up: false)
                return .handled
            }
            .onKeyPress(.delete) {
                if handleDelete() {
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.return) {
                if forth.waitingForKey {
                    // Supply the newline character (10) directly to KEY.
                    // .handled attempts to prevent the TextEditor from inserting a visible newline/line commit,
                    // so the user can use Return itself as the key value for KEY (e.g. key . <return> <return>).
                    forth.provideKey(10)
                    lastKeyConsumedUserLength = 0
                    // As belt-and-suspenders, if a \n was still inserted, eat it immediately so it
                    // doesn't create a committed empty line that would later be fed as a command.
                    if consoleText.last == "\n" {
                        isConsumingKeyChar = true
                        consoleText.removeLast()
                        markProtectedThroughEndOfText()
                        lastKeyConsumedUserLength = 0
                    }
                    return .handled
                }

                // Normal (non-KEY) case: if we're at an "empty prompt" (no new user-typed content
                // since the last protected output), treat this Return as an empty-line commit.
                // Suppress the newline insertion (.handled) to avoid adding arbitrary blank lines
                // to the console text. Manually feed an empty line so the engine prints "OK".
                // The onOutput from the engine will append "OK\n", giving the acknowledgment
                // without an extra user-inserted blank line.
                let userPortion = String(consoleText.dropFirst(protectedLength))
                let lastLine = userPortion.components(separatedBy: .newlines).last ?? ""
                let trimmed = lastLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    forth.feedLine("")
                    lastKeyConsumedUserLength = 0
                    return .handled
                }

                return .ignored
            }
            // Listen for menu commands from the Tools menu (defined at App level)
            .onReceive(NotificationCenter.default.publisher(for: .clearConsole)) { _ in
                consoleText = consoleMessage
                markProtectedThroughEndOfText()
                forth.clearScreenRequested = false
                keepCursorVisible(followPrompt: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetForth)) { _ in
                forth.resetToSafeState()
                consoleText = consoleMessage
                markProtectedThroughEndOfText()
                forth.clearScreenRequested = false
                keepCursorVisible(followPrompt: true)
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
                    DispatchQueue.main.async {
                        consoleText += text
                        markProtectedThroughEndOfText()
                        keepCursorVisible(followPrompt: true)
                        handlePostFeedActions()
                    }
                }

                // Hook BYE so the host app can quit when the user types BYE in Forth
                forth.onQuitRequested = {
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(nil)
                    }
                }

                // Hook CHDIR so we can persist a security bookmark for the new dir (if the
                // current scope covers it) and activate it. This makes named FLOAD after
                // a CHDIR to a subdir (or the current dir) succeed without "not found".
                forth.onDirectoryChanged = { [self] dirURL in
                    DispatchQueue.main.async {
                        do {
                            let bookmark = try dirURL.bookmarkData(options: [.withSecurityScope],
                                                                   includingResourceValuesForKeys: nil,
                                                                   relativeTo: nil)
                            UserDefaults.standard.set(bookmark, forKey: "LastFLOADDirectoryBookmark")
                            UserDefaults.standard.set(dirURL.path, forKey: "LastFLOADDirectory")
                            self.activateLastDirectoryScope(parent: dirURL)
                        } catch {
                            // No covering scope for this chdir target (e.g. chdir before any dialog);
                            // still remember the path for logicalCurrentDirectory and future resolves.
                            UserDefaults.standard.set(dirURL.path, forKey: "LastFLOADDirectory")
                            self.activateLastDirectoryScope(parent: dirURL)
                        }
                    }
                }

                // Initially everything (the banner) is "protected" output
                markProtectedThroughEndOfText()
                lastKeyConsumedUserLength = 0
                keepCursorVisible(followPrompt: true)
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

    /// Scrolls the NSTextView so the insertion point stays visible after text grows.
    /// When followPrompt is true, move the caret to end-of-document first (engine output / prompt).
    private func keepCursorVisible(followPrompt: Bool = false) {
        guard let textView = consoleTextView else { return }
        DispatchQueue.main.async {
            if followPrompt {
                let end = (textView.string as NSString).length
                textView.setSelectedRange(NSRange(location: end, length: 0))
            }
            textView.scrollRangeToVisible(textView.selectedRange())
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
        
        // Reset for normal command mode
        lastKeyConsumedUserLength = 0
        
        let lines = userPortion.components(separatedBy: .newlines)
        guard let lastLine = lines.last else { return }
        
        let trimmedLast = lastLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLast.isEmpty && lines.count >= 2 {
            // Collect all non-empty logical lines the user has typed since the last
            // engine output. This makes pasting a multi-line definition (or any
            // multi-line text) feed each line individually, so the new per-line
            // [DEBUG] state+stack output appears after every logical line.
            let candidateLines = lines.dropLast()   // drop the current empty line
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { raw in
                    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty && !t.hasPrefix("===") else { return false }
                    if t == "OK" || t.hasSuffix(" OK") { return false }
                    // Do not skip pure-numeric lines here: user commands like "1 2 3" or "123"
                    // are valid (push numbers), and would be incorrectly filtered.
                    // Numeric *outputs* from "." are typically "N OK" or "3 2 1 OK" which are
                    // already caught by the hasSuffix(" OK") rule above.
                    return true
                }

            // Always advance protected synchronously for this return commit.
            // This ensures the (possibly empty) line is marked as processed before async
            // dispatch/output, preventing re-collection races.
            markProtected(through: fullText.count)

            if !candidateLines.isEmpty {
                for lineToSend in candidateLines {
                    // Do not pollute command history with single-char responses supplied to a waiting KEY.
                    if !forth.waitingForKey {
                        commandHistory.append(lineToSend)
                        if commandHistory.count > 30 {
                            commandHistory.removeFirst()
                        }
                    }
                }

                historyIndex = -1

                DispatchQueue.main.async {
                    for lineToSend in candidateLines {
                        if forth.waitingForKey {
                            // Only treat the *last* line in this batch as the key supplier.
                            // Earlier lines in the list may be stale previous command lines that were
                            // included due to async protected lag; we must not re-provide from them.
                            if lineToSend == candidateLines.last {
                                // KEY is blocked waiting for a character. Use the first character
                                // of what the user just typed as the key value. This makes KEY
                                // behave in a classic blocking way from the user's perspective.
                                if let first = lineToSend.first {
                                    // Use unicode scalar for proper support of non-ASCII keys (e.g. curly quotes for testing)
                                    let scalar = first.unicodeScalars.first?.value ?? 0
                                    forth.provideKey(Int(scalar))
                                }
                            }
                            // Mark this supply line as consumed immediately so it doesn't get re-collected
                            // and re-fed as a command in later onChanges (due to async protected updates).
                            markProtectedThroughEndOfText()
                        } else {
                            forth.feedLine(lineToSend)
                            // Advance protected to cover the command line sync. This helps with suspended
                            // commands (like KEY) so that subsequent onChanges for key supply don't re-include
                            // previous command lines in candidates.
                            markProtectedThroughEndOfText()
                            handlePostFeedActions()
                        }

                        if forth.clearScreenRequested {
                            consoleText = consoleMessage
                            markProtectedThroughEndOfText()
                            lastKeyConsumedUserLength = 0
                            forth.clearScreenRequested = false
                        }
                    }

                    // Ensure the cursor ends up on a fresh line after the whole paste/block.
                    DispatchQueue.main.async {
                        if !consoleText.hasSuffix("\n") {
                            consoleText += "\n"
                            markProtectedThroughEndOfText()
                        }
                        keepCursorVisible(followPrompt: true)
                    }
                }
            } else {
                // Empty return on the prompt (nothing new to execute since last output).
                // Feed an empty line so the engine prints "OK" (interpreting empty input
                // as "nothing to do" in interpret mode). This gives the user the expected
                // acknowledgment instead of a silent extra newline.
                DispatchQueue.main.async {
                    forth.feedLine("")

                    handlePostFeedActions()

                    if forth.clearScreenRequested {
                        consoleText = consoleMessage
                        markProtectedThroughEndOfText()
                        lastKeyConsumedUserLength = 0
                        forth.clearScreenRequested = false
                    }

                    // Ensure the cursor ends up on a fresh line.
                    DispatchQueue.main.async {
                        if !consoleText.hasSuffix("\n") {
                            consoleText += "\n"
                            markProtectedThroughEndOfText()
                        }
                        keepCursorVisible(followPrompt: true)
                    }
                }
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

    private func showFileLoadDialog() {
        let requested = forth.fileLoadRequested
        forth.fileLoadRequested = false
        forth.fileEditRequested = false
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

                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
            // Cancel: flag already cleared; no load.
        }
    }

    private func handlePostFeedActions() {
        // Unified handling after a feedLine (or empty) so that FLOAD/EDIT (dialog or named forms)
        // that were executed during interpretation get serviced promptly. This covers:
        // - bare "fload" / "edit" (set *Requested flag -> show dialog)
        // - "fload foo" / "edit foo" (named; sets pendingLoadURL / pendingEditURL)
        // - same when executed from inside colon defs or loaded source.
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

    private func handlePendingLoadIfNeeded() {
        guard let url = forth.pendingLoadURL else { return }
        forth.pendingLoadURL = nil

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
        self.forth.loadFile(target)
        if !self.forth.errorFlag {
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

        // Always set logical to the requested target (do not rely on fm.currentDirectoryPath
        // which can remain the container or previous even when scope allows access to requested).
        forth.logicalCurrentDirectory = requested.path

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
}

/// AppKit-backed console editor. SwiftUI TextEditor does not reliably scroll to the
/// insertion point when text is appended programmatically (engine output, OK lines, etc.).
private struct ConsoleTextView: NSViewRepresentable {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var onTextViewReady: (NSTextView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

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

        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        context.coordinator.textView = textView
        onTextViewReady(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        if textView.string != text {
            let oldString = textView.string
            let selected = textView.selectedRange()
            context.coordinator.isProgrammaticUpdate = true
            textView.string = text
            context.coordinator.isProgrammaticUpdate = false

            let end = (text as NSString).length
            let oldEnd = (oldString as NSString).length

            // Suffix appends (engine OK lines, WORDS output, startup directory line) must
            // move the caret to the new end. Preserving the old index leaves the cursor on
            // the directory line or above freshly appended output.
            if text.hasPrefix(oldString), end > oldEnd, selected.location >= oldEnd {
                textView.setSelectedRange(NSRange(location: end, length: 0))
            } else if selected.location <= end {
                textView.setSelectedRange(selected)
            } else {
                textView.setSelectedRange(NSRange(location: end, length: 0))
            }
            textView.scrollRangeToVisible(textView.selectedRange())
        }

        if isFocused, let window = scrollView.window, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ConsoleTextView
        weak var textView: NSTextView?
        var isProgrammaticUpdate = false

        init(parent: ConsoleTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate, let textView else { return }
            parent.text = textView.string
        }
    }
}

#Preview {
    ConsoleView()
        .frame(width: 700, height: 500)
}
