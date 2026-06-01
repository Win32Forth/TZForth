import SwiftUI

struct ContentView: View {
    @State private var interpreter = GrokForthInterpreter()
    @State private var consoleText = "=== GrokForth Ready ===\n\n"
    @State private var commandHistory: [String] = []
    @State private var historyIndex = -1
    @State private var isRecallingHistory = false
    @FocusState private var isFocused: Bool
    
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .onAppear {
                isFocused = true
            }
    }
    
    private func checkForCommandExecution(_ text: String) {
        guard !isRecallingHistory else { return }
        
        let lines = text.components(separatedBy: .newlines)
        guard let lastLine = lines.last else { return }
        
        let trimmedLast = lastLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLast.isEmpty && lines.count >= 2 {
            let previousLine = lines[lines.count - 2].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !previousLine.isEmpty && !previousLine.hasPrefix("===") {
                // Copy to front of history (duplicates allowed)
                commandHistory.append(previousLine)
                
                if commandHistory.count > 20 {
                    commandHistory.removeFirst()
                }
                
                let result = interpreter.evaluate(previousLine)
                
                DispatchQueue.main.async {
                    if interpreter.clearScreenRequested {
                        // CLS was executed — clear the console
                        consoleText = "=== GrokForth Ready ===\n\n"
                        interpreter.clearScreenRequested = false
                    } else if !result.isEmpty {
                        consoleText += result + "\n\n"
                    } else {
                        consoleText += "\n"
                    }
                    historyIndex = -1
                }
            }
        }
    }
    
    private func handleDelete() {
        var lines = consoleText.components(separatedBy: .newlines)
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
