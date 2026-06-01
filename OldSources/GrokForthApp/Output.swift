import Foundation

extension GrokForthInterpreter {
    func handleOutput(_ token: String) throws {
        switch token {
        case ".": let v = try pop(); outputBuffer += "\(v) "
        case ".\"": /* string literal already handled in tokenizer */ break
        case ".(": /* immediate string */ break
        case "EMIT": let c = try pop(); outputBuffer += String(UnicodeScalar(c) ?? "?")
        case "CR": outputBuffer += "\n"
        case "SPACE": outputBuffer += " "
        case "SPACES": let n = try pop(); outputBuffer += String(repeating: " ", count: n)
        case "\\S": outputBuffer += " "
        case "U.": let v = try pop(); outputBuffer += "\(UInt(v)) "
        case "U.R": /* right justified unsigned */ break
        default: break
        }
    }
}
