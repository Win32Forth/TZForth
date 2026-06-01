import Foundation

extension GrokForthInterpreter {
    func handleMiscellaneous(_ token: String) throws {
        switch token {
        case "BASE": push(0) // address of base cell
        case "HEX": base = 16
        case "DECIMAL": base = 10
        case "OCTAL": base = 8
        case "BINARY": base = 2
        case "TRUE": push(-1)
        case "FALSE": push(0)
        case "DEPTH": push(dataStack.count)
        case "WITHIN":
            let hi = try pop()
            let lo = try pop()
            let n = try pop()
            push((n >= lo && n < hi) ? -1 : 0)
            
        case "AND": let b = try pop(); let a = try pop(); push(a & b)
        case "OR":  let b = try pop(); let a = try pop(); push(a | b)
        case "XOR": let b = try pop(); let a = try pop(); push(a ^ b)
        case "INVERT": push(~(try pop()))
        case "NOT": push(try pop() == 0 ? -1 : 0)
            
        case "LSHIFT": let bits = try pop(); let n = try pop(); push(n << bits)
        case "RSHIFT": let bits = try pop(); let n = try pop(); push(n >> bits)
        case "ARSHIFT": let bits = try pop(); let n = try pop(); push(n >> bits)  // signed in Swift for Int
            
        case "BL": push(32)  // space character
        case "CHAR": /* simple version */ break

        default: break
        }
    }
}
