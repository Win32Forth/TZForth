import Foundation

enum ForthError: Error {
    case stackUnderflow
    case unknownWord(String)
    
    var errorDescription: String {
        switch self {
        case .stackUnderflow:
            return "Stack underflow"
        case .unknownWord(let word):
            return "\(word) ?"
        }
    }
}
