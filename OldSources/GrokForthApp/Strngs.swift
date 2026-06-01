import Foundation

extension GrokForthInterpreter {

    func handleStrings(_ token: String) throws {
        if token.hasPrefix("\u{01}S\"") {
            // Remove the prefix and any leading space
            var content = String(token.dropFirst(3))
            if content.hasPrefix(" ") {
                content.removeFirst()
            }
            
            let addr = nextAddress
            for char in content.utf8 {
                memory[nextAddress] = Int(char)
                nextAddress += 1
            }
            memory[nextAddress] = 0
            nextAddress += 1
            
            push(addr)
            push(content.count)
            
        } else if token.hasPrefix("\u{01}.\"") {
            var content = String(token.dropFirst(3))
            if content.hasPrefix(" ") {
                content.removeFirst()
            }
            outputBuffer += content
            
        } else if token.hasPrefix("\u{01}.(") {
            // .( text )  — print immediately (used for messages while loading files)
            var content = String(token.dropFirst(3))
            if content.hasPrefix(" ") {
                content.removeFirst()
            }
            outputBuffer += content
        }
    }
}
