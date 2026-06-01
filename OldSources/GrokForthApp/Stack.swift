import Foundation

extension GrokForthInterpreter {
    
    func handleStack(_ token: String) throws {
        switch token {
        // Basic stack
        case "DUP":   let v = try pop(); push(v); push(v)
        case "DROP":  _ = try pop()
        case "SWAP":  let b = try pop(); let a = try pop(); push(b); push(a)
        case "OVER":  let b = try pop(); let a = try pop(); push(a); push(b); push(a)
        case "ROT":   let c = try pop(); let b = try pop(); let a = try pop(); push(b); push(c); push(a)
        case "-ROT":  let c = try pop(); let b = try pop(); let a = try pop(); push(c); push(a); push(b)
        case "NIP":   let b = try pop(); _ = try pop(); push(b)
        case "TUCK":  let b = try pop(); let a = try pop(); push(b); push(a); push(b)
            
        // Double stack
        case "2DUP":  let b = try pop(); let a = try pop(); push(a); push(b); push(a); push(b)
        case "2DROP": _ = try pop(); _ = try pop()
        case "2SWAP": let d = try pop(); let c = try pop(); let b = try pop(); let a = try pop(); push(c); push(d); push(a); push(b)
        case "2OVER": let d = try pop(); let c = try pop(); let b = try pop(); let a = try pop(); push(a); push(b); push(c); push(d); push(a); push(b)
            
        // Return stack
        case ">R":    let v = try pop(); returnStack.append(v)
        case "R>":    let v = returnStack.removeLast(); push(v)
        case "R@":    push(returnStack.last ?? 0)
        case "2>R":   let b = try pop(); let a = try pop(); returnStack.append(a); returnStack.append(b)
        case "2R>":   let b = returnStack.removeLast(); let a = returnStack.removeLast(); push(a); push(b)
        case "2R@":   let b = returnStack[returnStack.count-1]; let a = returnStack[returnStack.count-2]; push(a); push(b)
            
        // Others
        case "PICK":
            let n = try pop()
            guard n >= 0 && n < dataStack.count else { throw ForthError.stackUnderflow }
            push(dataStack[dataStack.count - 1 - n])
            
        case "ROLL":
            let n = try pop()
            guard n > 0 && n < dataStack.count else { throw ForthError.stackUnderflow }
            let v = dataStack.remove(at: dataStack.count - 1 - n)
            dataStack.append(v)
            
        case "DEPTH":
            push(dataStack.count)
            
        default:
            break
        }
    }
}
