import SwiftUI
import AppKit   // for NSApplication.terminate when BYE is executed

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
                // Hook the Forth output callback
                forth.onOutput = { text in
                    DispatchQueue.main.async {
                        consoleText += text
                        protectedLength = consoleText.count
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
        var lines = consoleText.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return }
        
        let lastIndex = lines.count - 1
        
        if lastIndex > 0 && lines[lastIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines[lastIndex - 1] = ""
        } else {
            lines[lastIndex] = ""
        }
        
        consoleText = lines.joined(separator: "\n")
    }
}

#Preview {
    ConsoleView()
        .frame(width: 700, height: 500)
}