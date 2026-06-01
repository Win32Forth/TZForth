import Foundation

extension GrokForthInterpreter {
    
    func handleControl(_ token: String, tokens: [String], ip: inout Int) throws {
        switch token {
        // === IF / ELSE / THEN ===
        case "IF":
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
            
        case "ELSE":
            // Skip to THEN (when IF was true)
            var depth = 0
            while ip < tokens.count {
                let t = tokens[ip]
                if t == "IF" { depth += 1 }
                else if t == "THEN" {
                    if depth == 0 { ip += 1; break }
                    depth -= 1
                }
                ip += 1
            }
            
        case "THEN":
            break  // no-op at runtime
            
        // === DO / LOOP ===
        case "DO":
            let start = try pop()
            let limit = try pop()
            returnStack.append(ip)      // jump back address
            returnStack.append(limit)
            returnStack.append(start)
            
        case "LOOP":
            guard returnStack.count >= 3 else { throw ForthError.stackUnderflow }
            var index = returnStack.removeLast()
            let limit = returnStack.removeLast()
            let jumpAddr = returnStack.removeLast()
            index += 1
            if index < limit {
                returnStack.append(jumpAddr)
                returnStack.append(limit)
                returnStack.append(index)
                ip = jumpAddr
            }
            
        case "I":
            guard returnStack.count >= 3 else { throw ForthError.stackUnderflow }
            push(returnStack[returnStack.count - 1])

        // === More Control Flow ===
        case "UNLOOP":
            guard returnStack.count >= 3 else { throw ForthError.stackUnderflow }
            returnStack.removeLast(3)   // discard limit, index, and jump address

        case "LEAVE":
            guard returnStack.count >= 3 else { throw ForthError.stackUnderflow }
            returnStack.removeLast(3)   // exit loop early
            // skip to after LOOP
            while ip < tokens.count && tokens[ip] != "LOOP" && tokens[ip] != "+LOOP" {
                ip += 1
            }
            ip += 1

        case "?DO":
            let start = try pop()
            let limit = try pop()
            if start == limit {
                // skip loop body
                var depth = 0
                while ip < tokens.count {
                    let t = tokens[ip]
                    if t == "DO" || t == "?DO" { depth += 1 }
                    else if t == "LOOP" || t == "+LOOP" {
                        if depth == 0 { ip += 1; break }
                        depth -= 1
                    }
                    ip += 1
                }
            } else {
                returnStack.append(ip)
                returnStack.append(limit)
                returnStack.append(start)
            }

        // === BEGIN Loops ===
        case "BEGIN":
            returnStack.append(ip)
            
        case "UNTIL":
            let flag = try pop()
            if flag == 0 {
                ip = returnStack.removeLast()
            }
            
        case "AGAIN":
            ip = returnStack.removeLast()
            
        default:
            break
        }
    }
}
