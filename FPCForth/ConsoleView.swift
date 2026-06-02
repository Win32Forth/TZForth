import SwiftUI
import AppKit   // for NSApplication.terminate when BYE is executed
import Foundation  // for FileManager (current dir for NSOpenPanel)
import UniformTypeIdentifiers  // for allowedContentTypes (replaces deprecated allowedFileTypes)

extension Notification.Name {
    static let clearConsole = Notification.Name("ClearConsole")
    static let resetForth   = Notification.Name("ResetForth")
}

/// A reusable console view that mimics the classic Forth REPL feel.
/// This version drives the real LBForth engine (Leif Bruder's public-domain model).
struct ConsoleView: View {
    @State private var consoleText = "=== FPCForth (lbForth model) ===\n\n"
    @State private var commandHistory: [String] = []
    @State private var historyIndex = -1
    @State private var isRecallingHistory = false
    @FocusState private var isFocused: Bool

    // The real Forth engine (Leif Bruder / lbForth style)
    @State private var forth = LBForth()

    /// Marks the length of consoleText after the last engine output.
    /// Only text typed by the user *after* this point can be treated as new commands.
    /// This prevents engine newlines (from .s, errors, etc.) from causing the
    /// command detector to re-interpret previous output or old lines.
    @State private var protectedLength = 0

    /// Tracks how much of the current user input (relative to protectedLength) has already
    /// been consumed as key data while waitingForKey. Used to compute delta new keystrokes
    /// on each onChange so we can feed them immediately to KEY without requiring a line commit.
    @State private var lastKeyConsumedUserLength = 0

    /// Flag to ignore the onChange that results from our own text mutation when eating
    /// a key char (removeLast) so we don't re-process or trigger normal line logic.
    @State private var isConsumingKeyChar = false

    var body: some View {
        TextEditor(text: $consoleText)
            .font(.system(size: 16, design: .monospaced))
            .foregroundColor(.black)
            .background(Color.white)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
            .onChange(of: consoleText) { _, newValue in
                checkForCommandExecution(newValue)
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
                handleDelete()
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
                        protectedLength = consoleText.count
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
                consoleText = "=== FPCForth (lbForth model) ===\n\n"
                protectedLength = consoleText.count
                forth.clearScreenRequested = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetForth)) { _ in
                forth.resetToSafeState()
                consoleText = "=== FPCForth (lbForth model) ===\n\n"
                protectedLength = consoleText.count
                forth.clearScreenRequested = false
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .onAppear {
                isFocused = true

                // Establish a useful starting directory (~/Documents or last-used) instead of
                // the sandbox container path. This makes the FLOAD/EDIT dialogs, CHDIR reports,
                // relative FLOAD/EDIT names, and DIR start in a place the user can actually use.
                setupInitialWorkingDirectory()

                // Hook the Forth output callback
                forth.onOutput = { text in
                    DispatchQueue.main.async {
                        consoleText += text
                        protectedLength = consoleText.count
                        handlePostFeedActions()
                    }
                }

                // Hook BYE so the host app can quit when the user types BYE in Forth
                forth.onQuitRequested = {
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(nil)
                    }
                }

                // Initially everything (the banner) is "protected" output
                protectedLength = consoleText.count
                lastKeyConsumedUserLength = 0
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
                        protectedLength = consoleText.count
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
                    // Skip pure numeric lines (e.g. key values printed by ".") or output-like.
                    if t.allSatisfy({ $0.isNumber || $0.isWhitespace }) { return false }
                    return true
                }

            // Always advance protected synchronously for this return commit.
            // This ensures the (possibly empty) line is marked as processed before async
            // dispatch/output, preventing re-collection races.
            protectedLength = fullText.count

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
                            protectedLength = consoleText.count
                        } else {
                            forth.feedLine(lineToSend)
                            // Advance protected to cover the command line sync. This helps with suspended
                            // commands (like KEY) so that subsequent onChanges for key supply don't re-include
                            // previous command lines in candidates.
                            protectedLength = consoleText.count
                            handlePostFeedActions()
                        }

                        if forth.clearScreenRequested {
                            consoleText = "=== FPCForth (lbForth model) ===\n\n"
                            protectedLength = consoleText.count
                            lastKeyConsumedUserLength = 0
                            forth.clearScreenRequested = false
                        }
                    }

                    // Ensure the cursor ends up on a fresh line after the whole paste/block.
                    DispatchQueue.main.async {
                        if !consoleText.hasSuffix("\n") {
                            consoleText += "\n"
                            protectedLength = consoleText.count
                        }
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
                        consoleText = "=== FPCForth (lbForth model) ===\n\n"
                        protectedLength = consoleText.count
                        lastKeyConsumedUserLength = 0
                        forth.clearScreenRequested = false
                    }

                    // Ensure the cursor ends up on a fresh line.
                    DispatchQueue.main.async {
                        if !consoleText.hasSuffix("\n") {
                            consoleText += "\n"
                            protectedLength = consoleText.count
                        }
                    }
                }
            }
        }

        // Catch FLOAD/EDIT *Requested (dialog forms) or pendingEditURL (named EDIT) that were
        // triggered by code execution inside a feedLine (e.g. "EDIT" or "FLOAD" with no name,
        // or named EDIT inside a colon def or loaded source) even if no fresh typing occurred.
        handlePostFeedActions()
    }

    private func setupInitialWorkingDirectory() {
        // The app is sandboxed (see the container path in FileManager), so its process
        // currentDirectoryPath starts in ~/Library/Containers/PhotoBubba.FPCForth/Data .
        // We seed it to ~/Documents (or the last directory from which the user did a
        // bare "fload" or "edit" via dialog in a previous run). This makes:
        //   - CHDIR (no arg) and DIR report / start from a visible, useful place
        //   - "fload foo.fth" / "edit foo" (with name) resolve relative to that place
        //   - the NSOpenPanel for bare "fload" / "edit" <return> start in a convenient folder
        //     so you can easily reach Documents/XCodeProjects/FPCForth/OldSources/tcom25
        //
        // We also chdir on successful dialog loads/edits and on explicit CHDIR.
        let fm = FileManager.default
        var target: URL
        if let savedPath = UserDefaults.standard.string(forKey: "LastFLOADDirectory"),
           fm.fileExists(atPath: savedPath) {
            target = URL(fileURLWithPath: savedPath)
        } else {
            let home = fm.homeDirectoryForCurrentUser
            let docs = home.appendingPathComponent("Documents")
            target = fm.fileExists(atPath: docs.path) ? docs : home
        }
        _ = fm.changeCurrentDirectoryPath(target.path)
        // (If the chdir is blocked by sandbox for the saved path we still proceed;
        // the panel below will still get a reasonable directoryURL from whatever cwd we have.)
    }

    private func showFileLoadDialog() {
        let requested = forth.fileLoadRequested
        forth.fileLoadRequested = false
        forth.fileEditRequested = false
        forth.pendingEditURL = nil
        guard requested else { return }

        let panel = NSOpenPanel()
        panel.title = "FLOAD Forth Source"
        panel.message = "Select a .fth file (or text file) to load and interpret/compile."
        panel.prompt = "Load"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        // Use whatever the (seeded + CHDIR-updated) process cwd is. After a successful
        // dialog load we chdir to the chosen dir so the next panel + CHDIR + relatives follow it.
        panel.directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
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
                    // Persist the chosen dir so the *next launch* will start the panel / cwd there.
                    // Also chdir now so this session's CHDIR reports, relative FLOAD names,
                    // DIR listings, and the *next* bare fload panel all reflect where the user
                    // just browsed to.
                    UserDefaults.standard.set(parent.path, forKey: "LastFLOADDirectory")
                    _ = FileManager.default.changeCurrentDirectoryPath(parent.path)

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
        // - "fload foo" / "edit foo" (named; for EDIT sets pendingEditURL)
        // - same when executed from inside colon defs or loaded source.
        if forth.fileLoadRequested {
            showFileLoadDialog()
        }
        handlePendingEditIfNeeded()
        if forth.fileEditRequested {
            showFileEditDialog()
        }
    }

    private func handlePendingEditIfNeeded() {
        guard let url = forth.pendingEditURL else { return }
        forth.pendingEditURL = nil

        let parent = url.deletingLastPathComponent()
        // Persist + chdir so that this session's CHDIR/DIR/relative loads + next bare EDIT/FLOAD
        // panel all start from the folder of the just-edited file. (Matches what dialog path does.)
        UserDefaults.standard.set(parent.path, forKey: "LastFLOADDirectory")
        _ = FileManager.default.changeCurrentDirectoryPath(parent.path)

        // For *named* EDIT the URL was resolved from a path spec (possibly with ~), not from a
        // fresh panel pick, so we may not have a brand-new security scope for it. We still
        // attempt start/stop for consistency. NSWorkspace.open will launch the user's editor
        // (TextEdit by default for text/.fth) on the file; the editor itself gets access.
        let accessing = url.startAccessingSecurityScopedResource()
        NSWorkspace.shared.open(url)
        if accessing {
            url.stopAccessingSecurityScopedResource()
        }
    }

    private func showFileEditDialog() {
        let requested = forth.fileEditRequested
        forth.fileEditRequested = false
        forth.fileLoadRequested = false
        forth.pendingEditURL = nil
        guard requested else { return }

        let panel = NSOpenPanel()
        panel.title = "EDIT File in Text Editor"
        panel.message = "Select a source (or text) file to open in the system default editor (e.g. TextEdit). The current directory will be changed to the file's folder."
        panel.prompt = "Edit"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        // Start from the (seeded/CHDIR-updated) cwd, just like FLOAD. Broader content types so
        // it's easy to pick any text/source while still allowing "All Files" navigation.
        panel.directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
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
                    // persist last dir (for next launch), chdir (current session + relatives), open editor.
                    UserDefaults.standard.set(parent.path, forKey: "LastFLOADDirectory")
                    _ = FileManager.default.changeCurrentDirectoryPath(parent.path)

                    NSWorkspace.shared.open(url)

                    self.forth.editFile(url)

                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
            // Cancel: flag cleared; nothing to edit.
        }
    }
    
    private func handleDelete() {
        let lines = consoleText.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return }
        
        let lastIndex = lines.count - 1
        let currentLine = lines[lastIndex]
        
        // Prevent deleting into previous output when on a fresh empty prompt line
        if currentLine.isEmpty && lastIndex > 0 {
            let prevLine = lines[lastIndex - 1].trimmingCharacters(in: .whitespacesAndNewlines)
            if prevLine.hasPrefix("===") || prevLine.isEmpty {
                return  // Block delete to protect output
            }
        }
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

#Preview {
    ConsoleView()
        .frame(width: 700, height: 500)
}