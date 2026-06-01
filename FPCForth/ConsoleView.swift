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
            }
    }
    
    private func checkForCommandExecution(_ fullText: String) {
        guard !isRecallingHistory else { return }
        
        // Only consider text the user has typed since the last engine output.
        // This protects us from newlines that come from .s, error messages, etc.
        guard fullText.count > protectedLength else { return }
        let userPortion = String(fullText.dropFirst(protectedLength))
        
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
                .filter { !$0.isEmpty && !$0.hasPrefix("===") }

            guard !candidateLines.isEmpty else { return }

            for lineToSend in candidateLines {
                commandHistory.append(lineToSend)
                if commandHistory.count > 30 {
                    commandHistory.removeFirst()
                }
            }

            historyIndex = -1

            DispatchQueue.main.async {
                for lineToSend in candidateLines {
                    forth.feedLine(lineToSend)

                    if forth.clearScreenRequested {
                        consoleText = "=== FPCForth (lbForth model) ===\n\n"
                        protectedLength = consoleText.count
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