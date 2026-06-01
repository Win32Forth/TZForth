import Foundation
import AppKit

public class GrokForthInterpreter {
    
    internal var dataStack: [Int] = []
    internal var returnStack: [Int] = []        // for loops
    
    internal var dictionary: [String: [String]] = [:]
    internal var constants: [String: Int] = [:]
    internal var memory: [Int: Int] = [0: 10]
    internal var nextAddress = 1000
    internal var base = 10
    internal var outputBuffer = ""
    
    internal var wordOrder: [String] = []           // definition order for FORGET
    public var clearScreenRequested = false
    
    /// Current working directory used by FLOAD for relative paths
    internal var currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    
    /// When set, causes the current source file (via interpret/FLOAD) to stop processing.
    /// Used by \S
    internal var stopSourceLoading = false
    
    internal var compileState: CompileState? = nil
    internal let logger: ((String) -> Void)?
    
    public init(logger: ((String) -> Void)? = nil) {
        self.logger = logger
    }
    
    public func evaluate(_ input: String) -> String {
        outputBuffer = ""
        stopSourceLoading = false
        let tokens = tokenize(input)
        guard !tokens.isEmpty else { return " ok" }
        
        do {
            try processTokens(tokens)
            let result = outputBuffer.isEmpty ? " ok" : outputBuffer + " ok"
            outputBuffer = ""
            stopSourceLoading = false
            return result
        } catch let error as ForthError {
            dataStack.removeAll()
            returnStack.removeAll()
            stopSourceLoading = false
            return "\(error.errorDescription)\n ok"
        } catch {
            dataStack.removeAll()
            returnStack.removeAll()
            stopSourceLoading = false
            return "Error\n ok"
        }
    }
    
    internal func push(_ value: Int) {
        dataStack.append(value)
    }
    
    internal func pop() throws -> Int {
        guard !dataStack.isEmpty else { throw ForthError.stackUnderflow }
        return dataStack.removeLast()
    }
    
    // MARK: - Reset and Special Words
    
    /// Full interpreter reset (used by RESET word)
    func reset() {
        dataStack.removeAll()
        returnStack.removeAll()
        dictionary.removeAll()
        wordOrder.removeAll()
        constants.removeAll()
        memory = [0: 10]
        nextAddress = 1000
        base = 10
        clearScreenRequested = true
        outputBuffer = ""
    }
    
    /// ANS Forth style FORGET: removes the word and all subsequently defined words
    func forget(_ name: String) throws {
        let upperName = name.uppercased()
        
        guard let index = wordOrder.firstIndex(of: upperName) else {
            throw ForthError.unknownWord(upperName)
        }
        
        // Remove this word and everything defined after it
        let toRemove = Array(wordOrder[index...])
        
        for word in toRemove {
            dictionary.removeValue(forKey: word)
            constants.removeValue(forKey: word)
        }
        
        wordOrder.removeSubrange(index...)
    }
    
    // MARK: - File Loading (FLOAD)
    
    /// Internal interpreter used by FLOAD and nested loads.
    /// Does not reset outputBuffer or append " ok".
    internal func interpret(_ source: String) {
        stopSourceLoading = false
        let tokens = tokenize(source)
        do {
            try processTokens(tokens)
        } catch let error as ForthError {
            outputBuffer += "\n\(error.errorDescription)\n"
        } catch {
            outputBuffer += "\nError during interpretation\n"
        }
        stopSourceLoading = false
    }
    
    /// Load and interpret a Forth source file.
    /// Supports both absolute paths and paths relative to currentDirectory.
    /// Can be called recursively (nested FLOAD).
    func fload(_ filename: String) {
        let expanded = (filename as NSString).expandingTildeInPath
        var finalName = expanded
        
        // If no extension is specified (no dot in last path component), assume .fth
        let lastComponent = (finalName as NSString).lastPathComponent
        if !lastComponent.contains(".") {
            finalName += ".fth"
        }
        
        let url: URL
        if finalName.hasPrefix("/") {
            url = URL(fileURLWithPath: finalName)
        } else {
            url = currentDirectory.appendingPathComponent(finalName)
        }
        
        // Save current directory and switch to the directory of the file being loaded.
        // This allows relative FLOADs inside the file to work correctly.
        let previousDirectory = currentDirectory
        currentDirectory = url.deletingLastPathComponent()
        
        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            interpret(source)
            outputBuffer += "\n[Loaded: \(url.lastPathComponent)]\n"
        } catch {
            outputBuffer += "\nFLOAD error: Cannot open file '\(filename)'\n"
        }
        
        // Restore previous directory after loading (supports proper nesting)
        currentDirectory = previousDirectory
    }
    
    // MARK: - Directory Commands (CHDIR / DIR)
    
    /// Change current directory.
    /// If path is nil or empty, just display the current directory.
    func chdir(_ path: String?) {
        if let path = path, !path.isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            let newURL: URL
            
            if expanded.hasPrefix("/") {
                newURL = URL(fileURLWithPath: expanded)
            } else {
                newURL = currentDirectory.appendingPathComponent(expanded)
            }
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: newURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                currentDirectory = newURL
                outputBuffer += "Current directory: \(currentDirectory.path)\n"
            } else {
                outputBuffer += "CHDIR error: '\(path)' is not a directory\n"
            }
        } else {
            // No argument — just show current directory
            outputBuffer += "Current directory: \(currentDirectory.path)\n"
        }
    }
    
    /// List directory contents, optionally filtered by a wildcard pattern (MS-DOS style).
    func dir(_ pattern: String?) {
        let url = currentDirectory
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
            
            outputBuffer += "\nDirectory of \(url.path)\n\n"
            
            var count = 0
            
            for fileURL in contents.sorted(by: { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }) {
                let name = fileURL.lastPathComponent
                let displayName = name
                
                // Apply filter if provided
                if let pattern = pattern, !pattern.isEmpty {
                    if !matchesWildcard(pattern, in: name) {
                        continue
                    }
                }
                
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir)
                
                let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
                let size = resourceValues?.fileSize ?? 0
                
                if isDir.boolValue {
                    outputBuffer += " \(displayName.padding(toLength: 30, withPad: " ", startingAt: 0)) <DIR>\n"
                } else {
                    let sizeStr = String(size).padding(toLength: 12, withPad: " ", startingAt: 0)
                    outputBuffer += " \(displayName.padding(toLength: 30, withPad: " ", startingAt: 0)) \(sizeStr)\n"
                }
                count += 1
            }
            
            outputBuffer += "\n \(count) file(s)\n\n"
            
        } catch {
            outputBuffer += "DIR error: Cannot read directory '\(url.path)'\n"
        }
    }
    
    /// Simple MS-DOS style wildcard matcher (* and ? supported)
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
    
    // MARK: - Directory Creation
    
    /// Create a new directory (MKDIR).
    /// Supports relative paths, absolute paths, and ~ expansion.
    /// Creates intermediate directories if needed.
    func mkdir(_ path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        let url: URL
        
        if expanded.hasPrefix("/") {
            url = URL(fileURLWithPath: expanded)
        } else {
            url = currentDirectory.appendingPathComponent(expanded)
        }
        
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            outputBuffer += "Directory created: \(url.path)\n"
        } catch {
            outputBuffer += "MKDIR error: Cannot create directory '\(path)'\n"
        }
    }
    
    // MARK: - EDIT command (opens file in TextEdit)
    
    /// EDIT [<filename>]
    /// - Opens the file in macOS TextEdit.
    /// - If no extension is given, appends ".fth".
    /// - Creates the file (empty) if it does not exist.
    /// - Uses the current GrokForth directory for relative paths.
    func edit(_ filename: String?) {
        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        
        if let filename = filename, !filename.isEmpty {
            let expanded = (filename as NSString).expandingTildeInPath
            var finalName = expanded
            
            // If no dot in the last path component, assume .fth
            let lastComponent = (finalName as NSString).lastPathComponent
            if !lastComponent.contains(".") {
                finalName += ".fth"
            }
            
            let fileURL: URL
            if finalName.hasPrefix("/") {
                fileURL = URL(fileURLWithPath: finalName)
            } else {
                fileURL = currentDirectory.appendingPathComponent(finalName)
            }
            
            // Create the file if it doesn't exist
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    try "".write(to: fileURL, atomically: true, encoding: .utf8)
                    outputBuffer += "Created new file: \(fileURL.lastPathComponent)\n"
                } catch {
                    outputBuffer += "EDIT error: Could not create file '\(filename)'\n"
                    return
                }
            }
            
            // Open the specific file in TextEdit
            NSWorkspace.shared.open([fileURL], withApplicationAt: textEditURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.outputBuffer += "EDIT error: \(error.localizedDescription)\n"
                    }
                }
            }
            
            outputBuffer += "Opening \(fileURL.lastPathComponent) in TextEdit...\n"
            
        } else {
            // No filename given — just launch TextEdit
            NSWorkspace.shared.openApplication(at: textEditURL, configuration: NSWorkspace.OpenConfiguration())
            outputBuffer += "Launching TextEdit...\n"
        }
    }
}

// MARK: - Internal Types
internal struct CompileState {
    let name: String
    var tokens: [String] = []
}
