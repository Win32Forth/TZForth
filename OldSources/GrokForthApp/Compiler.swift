import Foundation

extension GrokForthInterpreter {
    
    func processTokens(_ tokens: [String]) throws {
        print("DEBUG TOKENS: \(tokens)")
        var ip = 0
        while ip < tokens.count {
            if stopSourceLoading {
                break
            }
            let token = tokens[ip]
            
            // \S stops loading the current source file (used inside FLOAD)
            if token == "\\S" {
                stopSourceLoading = true
                ip += 1
                continue
            }
            
            // Handle .( immediately (even during compilation) - it is an immediate parsing word
            if token.hasPrefix("\u{01}.(") {
                try handleStrings(token)
                ip += 1
                continue
            }
            
            // COMPILE MODE
            if compileState != nil {
                if token == ";" {
                    try endColonDefinition()
                    ip += 1
                    continue
                } else if token != ":" {
                    compileState?.tokens.append(token)
                }
                ip += 1
                continue
            }
            
            // INTERPRET MODE
            ip += 1
            
            if token == ":" { try startColonDefinition(tokens, &ip); continue }
            if token == "VARIABLE" { try defineVariable(tokens, &ip); continue }
            if token == "CONSTANT" || token == "VALUE" { try defineConstant(tokens, &ip); continue }
            
            // Special words (CLS, RESET, FORGET)
            if token == "CLS" {
                clearScreenRequested = true
                continue
            }
            if token == "RESET" {
                reset()
                // The UI will detect clearScreenRequested and redisplay
                // the initial "=== GrokForth Ready ===" message.
                continue
            }
            if token == "FORGET" {
                try forgetWord(tokens, &ip)
                continue
            }
            if token == "HELP" {
                try helpWord(tokens, &ip)
                continue
            }
            if token == "FLOAD" {
                try floadWord(tokens, &ip)
                continue
            }
            if token == "CHDIR" {
                try chdirWord(tokens, &ip)
                continue
            }
            if token == "DIR" || token == "LS" {
                try dirWord(tokens, &ip)
                continue
            }
            if token == "MKDIR" {
                try mkdirWord(tokens, &ip)
                continue
            }
            if token == "EDIT" {
                try editWord(tokens, &ip)
                continue
            }
            
            // Memory & Base
            if token == "@" { let addr = try pop(); push(memory[addr] ?? 0); continue }
            if token == "!" { let addr = try pop(); let val = try pop(); memory[addr] = val; continue }
            if token == "BASE" { push(0) }   // address of base cell
            if token == "HEX" { base = 16 }
            if token == "DECIMAL" { base = 10 }
            if token == "OCTAL" { base = 8 }
            if token == "BINARY" { base = 2 }

            if token == ".S" {
                outputBuffer += "<\(dataStack.count)> \(dataStack.reversed().map(String.init).joined(separator: " ")) "
                continue
            }
            
            if let num = Int(token, radix: base) { push(num); continue }
            if let body = dictionary[token] { try runUserWord(body); continue }

            // Memory
            if ["@", "!", "+!", "C@", "C!", ",", "C,", "ALLOT", "HERE"].contains(token) {
                try handleMemory(token)
                continue
            }
            
            // Stack
            if ["DUP", "DROP", "SWAP", "OVER", "ROT", "-ROT", "NIP", "TUCK", "PICK", "ROLL",
                "2DUP", "2DROP", "2SWAP", "2OVER", ">R", "R>", "R@", "2>R", "2R>", "2R@", "DEPTH"].contains(token) {
                try handleStack(token)
                continue
            }
            
            // String literals and output
            if token.hasPrefix("\u{01}") || token == "TYPE" || token == "EMIT" {
                try handleStrings(token)   // for S" and ."
                continue
            }
            if ["TYPE", "EMIT", "CR", "SPACE", "SPACES", ".", "U.", "\\S"].contains(token) {
                try handleOutput(token)
                continue
            }
            
            // Miscellaneous / Bitwise / System
            if ["TRUE", "FALSE", "DEPTH", "WITHIN", "AND", "OR", "XOR", "INVERT", "NOT",
                "LSHIFT", "RSHIFT", "ARSHIFT", "BL", "CHAR"].contains(token) {
                try handleMiscellaneous(token)
                continue
            }

            // Control Flow
            if ["IF", "ELSE", "THEN", "DO", "?DO", "LOOP", "UNLOOP", "LEAVE", "BEGIN", "UNTIL", "AGAIN"].contains(token) {
                try handleControl(token, tokens: tokens, ip: &ip)
                continue
            }
            
            // Literals and user words
            if let num = Int(token, radix: base) { push(num); continue }
            if let body = dictionary[token] { try runUserWord(body); continue }
            
            switch token {
            // Arithmetic
            case "+":  let b = try pop(); let a = try pop(); push(a + b)
            case "-":  let b = try pop(); let a = try pop(); push(a - b)
            case "*":  let b = try pop(); let a = try pop(); push(a * b)
            case "/":  let b = try pop(); let a = try pop(); push(b != 0 ? a / b : 0)
            case "MOD": let b = try pop(); let a = try pop(); push(b != 0 ? a % b : 0)
                
            case "1+": let v = try pop(); push(v + 1)
            case "1-": let v = try pop(); push(v - 1)        // ← Added
                
            case "ABS": let v = try pop(); push(abs(v))
            case "NEGATE": let v = try pop(); push(-v)
                    
            // Comparisons
            case "=":  let b = try pop(); let a = try pop(); push(a == b ? -1 : 0)
            case "<>": let b = try pop(); let a = try pop(); push(a != b ? -1 : 0)
            case "<":  let b = try pop(); let a = try pop(); push(a < b ? -1 : 0)
            case ">":  let b = try pop(); let a = try pop(); push(a > b ? -1 : 0)   // ← Added
            case "<=": let b = try pop(); let a = try pop(); push(a <= b ? -1 : 0)
            case ">=": let b = try pop(); let a = try pop(); push(a >= b ? -1 : 0)
            case "0=": let v = try pop(); push(v == 0 ? -1 : 0)
            case "0<": let v = try pop(); push(v < 0 ? -1 : 0)
            case "0>": let v = try pop(); push(v > 0 ? -1 : 0)
                    
            // More useful words
            case "MIN": let b = try pop(); let a = try pop(); push(min(a, b))
            case "MAX": let b = try pop(); let a = try pop(); push(max(a, b))
            case "AND": let b = try pop(); let a = try pop(); push(a & b)
            case "OR":  let b = try pop(); let a = try pop(); push(a | b)
            case "XOR": let b = try pop(); let a = try pop(); push(a ^ b)
            case "INVERT": push(~(try pop()))
            case "NOT": push(try pop() == 0 ? -1 : 0)
            // Stack (expanded)
            case "NIP":   let b = try pop(); _ = try pop(); push(b)
            case "TUCK":  let b = try pop(); let a = try pop(); push(b); push(a); push(b)
            case "PICK":  let n = try pop();
                guard n >= 0 && n < dataStack.count else { throw ForthError.stackUnderflow }; push(dataStack[dataStack.count - 1 - n])
            case ">R":    let v = try pop(); returnStack.append(v)
            case "R>":    let v = returnStack.removeLast(); push(v)
            case "R@":    push(returnStack.last ?? 0)

            // Output (strings)
            case ".\"":   // handled by tokenizer
                break
            case "S\"":   // handled by tokenizer
                break

            case ".S": outputBuffer += "<\(dataStack.count)> \(dataStack.reversed().map(String.init).joined(separator: " ")) "
                
            // === FULL CONDITIONALS ===
            case "IF": try handleIf(tokens, &ip)
            case "ELSE", "THEN": break
                    
            // === ADVANCED LOOPS ===
            case "LOOP": try doLoop()
            case "LEAVE":
                guard returnStack.count >= 3 else { throw ForthError.stackUnderflow }
                returnStack.removeLast(3)   // discard loop params
                // find end of loop (simple skip for now)
                while ip < tokens.count && tokens[ip] != "LOOP" { ip += 1 }
                ip += 1
                continue
            case "UNLOOP":
                guard returnStack.count >= 3 else { throw ForthError.stackUnderflow }
                returnStack.removeLast(3)
                continue
            case "I":
                guard returnStack.count >= 3 else { throw ForthError.stackUnderflow }
                push(returnStack[returnStack.count - 1])
                continue

            case "WORDS": listWords()
            case "SEE": try seeWord(tokens, &ip)
            case "HELP": try helpWord(tokens, &ip)
            case "FLOAD": try floadWord(tokens, &ip)
            case "CHDIR": try chdirWord(tokens, &ip)
            case "DIR": try dirWord(tokens, &ip)
            case "LS": try dirWord(tokens, &ip)
            case "MKDIR": try mkdirWord(tokens, &ip)
            case "EDIT": try editWord(tokens, &ip)
            default:
                throw ForthError.unknownWord(token)
            }
        }
    }
    
    // MARK: - All Helper Functions (now included here)
    private func handleIf(_ tokens: [String], _ ip: inout Int) throws {
        let flag = try pop()
        if flag == 0 {
            var depth = 0
            while ip < tokens.count {
                let t = tokens[ip]
                if t == "IF" { depth += 1 }
                else if t == "THEN" {
                    if depth == 0 { ip += 1; break }
                    depth -= 1
                } else if t == "ELSE" && depth == 0 {
                    ip += 1
                    break
                }
                ip += 1
            }
        }
    }
    
    private func doLoop() throws {
        guard returnStack.count >= 3 else { throw ForthError.stackUnderflow }
        var index = returnStack.removeLast()
        let limit = returnStack.removeLast()
        let jumpAddr = returnStack.removeLast()
        index += 1
        if index < limit {
            returnStack.append(jumpAddr)
            returnStack.append(limit)
            returnStack.append(index)
        }
    }

    private func startColonDefinition(_ tokens: [String], _ ip: inout Int) throws {
        guard ip < tokens.count else { throw ForthError.unknownWord(":") }
        let name = tokens[ip]
        ip += 1
        compileState = CompileState(name: name, tokens: [])
        logger?("COMPILE: \(name)")
    }
    
    private func endColonDefinition() throws {
        guard let state = compileState else { return }
        dictionary[state.name] = state.tokens
        if !wordOrder.contains(state.name) {
            wordOrder.append(state.name)
        }
        logger?("COMPILED \(state.name)  body: \(state.tokens)")
        compileState = nil
    }
    
    private func defineVariable(_ tokens: [String], _ ip: inout Int) throws {
        guard ip < tokens.count else { return }
        let name = tokens[ip]
        ip += 1
        let addr = nextAddress
        memory[addr] = 0
        nextAddress += 1
        dictionary[name] = [String(addr)]
        if !wordOrder.contains(name) {
            wordOrder.append(name)
        }
        logger?("VARIABLE \(name) @ \(addr)")
    }
    
    private func defineConstant(_ tokens: [String], _ ip: inout Int) throws {
        guard ip < tokens.count else { return }
        let name = tokens[ip]
        ip += 1
        let value = try pop()
        constants[name] = value
        dictionary[name] = [String(value)]   // so SEE and WORDS see it
        if !wordOrder.contains(name) {
            wordOrder.append(name)
        }
        logger?("CONSTANT \(name) = \(value)")
    }
    
    private func runUserWord(_ body: [String]) throws {
        try processTokens(body)
    }
        
    private func seeWord(_ tokens: [String], _ ip: inout Int) throws {
        guard ip < tokens.count else { return }
        let name = tokens[ip].uppercased()
        ip += 1
        appendDefinition(of: name)
    }

    /// Shared helper used by both SEE and HELP for user-defined words
    internal func appendDefinition(of name: String) {
        let upper = name.uppercased()
        if let body = dictionary[upper] {
            outputBuffer += ": \(upper) \(body.joined(separator: " ")) ;\n"
            return
        }
        
        // Fall back to primitive documentation for SEE
        if let info = Self.primitiveLookup[upper] {
            outputBuffer += "\(upper)  \(info.stack)  \(info.desc)\n"
            return
        }
        
        outputBuffer += "\(upper) ?\n"
    }
    
    /// Implements ANS FORGET semantics using wordOrder
    private func forgetWord(_ tokens: [String], _ ip: inout Int) throws {
        guard ip < tokens.count else {
            throw ForthError.unknownWord("FORGET")
        }
        let name = tokens[ip]
        ip += 1
        try forget(name)
    }
    
    /// HELP <word> - shows documentation for a specific word
    private func helpWord(_ tokens: [String], _ ip: inout Int) throws {
        guard ip < tokens.count else {
            outputBuffer += "HELP <word>\n"
            return
        }
        let name = tokens[ip]
        ip += 1
        help(for: name)
    }
    
    /// FLOAD <filename> - load and interpret a Forth source file.
    /// Supports both absolute and relative paths.
    private func floadWord(_ tokens: [String], _ ip: inout Int) throws {
        guard ip < tokens.count else {
            outputBuffer += "FLOAD <filename>\n"
            return
        }
        let filename = tokens[ip]
        ip += 1
        fload(filename)
    }
    
    /// CHDIR [<path>] - change directory or display current directory
    private func chdirWord(_ tokens: [String], _ ip: inout Int) throws {
        if ip < tokens.count {
            let path = tokens[ip]
            ip += 1
            chdir(path)
        } else {
            chdir(nil)
        }
    }
    
    /// DIR [<filespec>] - list directory contents with optional wildcard filter
    private func dirWord(_ tokens: [String], _ ip: inout Int) throws {
        if ip < tokens.count {
            let pattern = tokens[ip]
            ip += 1
            dir(pattern)
        } else {
            dir(nil)
        }
    }
    
    /// MKDIR <directory> - create a new directory (supports relative and absolute paths)
    private func mkdirWord(_ tokens: [String], _ ip: inout Int) throws {
        guard ip < tokens.count else {
            outputBuffer += "MKDIR <directory>\n"
            return
        }
        let path = tokens[ip]
        ip += 1
        mkdir(path)
    }
    
    /// EDIT [<filename>] - open file in TextEdit (creates .fth file if needed)
    private func editWord(_ tokens: [String], _ ip: inout Int) throws {
        if ip < tokens.count {
            let filename = tokens[ip]
            ip += 1
            edit(filename)
        } else {
            edit(nil)
        }
    }
}
