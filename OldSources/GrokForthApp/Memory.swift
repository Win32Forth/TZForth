import Foundation

extension GrokForthInterpreter {
    func handleMemory(_ token: String) throws {
        switch token {
        case "@":  let addr = try pop(); push(memory[addr] ?? 0)
        case "!":  let addr = try pop(); let val = try pop(); memory[addr] = val
        case "+!": let n = try pop(); let addr = try pop(); memory[addr] = (memory[addr] ?? 0) + n
        case "-!": let n = try pop(); let addr = try pop(); memory[addr] = (memory[addr] ?? 0) - n
        case "C@": let addr = try pop(); push((memory[addr] ?? 0) & 0xFF)
        case "C!": let val = try pop(); let addr = try pop(); memory[addr] = val & 0xFF
        case ",":  let n = try pop(); memory[nextAddress] = n; nextAddress += 1
        case "C,": let n = try pop(); memory[nextAddress] = n & 0xFF; nextAddress += 1
        case "ALLOT": let n = try pop(); nextAddress += n
        case "HERE": push(nextAddress)
        case "CELL+": let addr = try pop(); push(addr + 1)
        case "CELLS": let n = try pop(); push(n)   // cell size = 1 in this implementation
        case "CHAR+": let addr = try pop(); push(addr + 1)
        case "CHARS": let n = try pop(); push(n)
        case "2@": let addr = try pop(); push(memory[addr] ?? 0); push(memory[addr+1] ?? 0)
        case "2!": let hi = try pop(); let lo = try pop(); let addr = try pop(); memory[addr] = lo; memory[addr+1] = hi
        default: break
        }
    }
}
