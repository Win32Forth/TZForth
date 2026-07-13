//
//  TZForthFloat.swift
//  TZForth
//
//  Float Tier A — minimal ANS floating-point (IEEE 64-bit, separate 16-deep F stack).
//

import Foundation

extension TZForth {

    // MARK: - Float stack (separate from data/return stacks)

    internal func fspGet() -> Cell { floatingStackPointer }  // TZForth.swift (resetRuntimeState)
    internal func fspSet(_ v: Cell) { floatingStackPointer = v }  // TZForth.swift (resetRuntimeState)

    internal func fpop() -> Double {
        var s = self.fspGet()
        if s < 1 || s > Cell(self.FSTACK_SIZE) {
            self.tell("? Corrupted floating-point stack pointer (FSP=\(s)), auto-recovering\n")
            s = 1
            self.fspSet(1)
        }
        if s <= 1 {
            self.fspSet(1)
            let msg = self.readCell(self.STATE) != 0
                ? "? Floating-point stack underflow while compiling"
                : "? Floating-point stack underflow"
            self.kernelThrow(StdThrow.stackUnderflow, message: msg)
            return 0
        }
        self.fspSet(s - 1)
        return self.readFloat(self.fstackBase + (Int(s) - 2) * 8)
    }

    internal func fpush(_ v: Double) {
        var s = self.fspGet()
        if s < 1 || s > Cell(self.FSTACK_SIZE) {
            self.tell("? Corrupted floating-point stack pointer (FSP=\(s)), auto-recovering\n")
            s = 1
            self.fspSet(1)
        }
        if s >= Cell(self.FSTACK_SIZE) {
            self.kernelThrow(StdThrow.stackOverflow, message: "? Floating-point stack overflow")
            return
        }
        self.writeFloat(self.fstackBase + (Int(s) - 1) * 8, v)
        self.fspSet(s + 1)
    }

    private func fpeek(_ u: Int) -> Double {
        let s = self.fspGet()
        let depth = Int(s) - 1
        guard u >= 0, u < depth else {
            self.kernelThrow(StdThrow.stackUnderflow, message: "? Floating-point stack underflow")
            return 0
        }
        return self.readFloat(self.fstackBase + (depth - 1 - u) * 8)
    }

    // MARK: - IEEE 64-bit memory codec

    internal func readFloat(_ addr: Int) -> Double {
        if addr < 0 || addr + 8 > self.memory.count {
            self.throwInvalidAddress("? Memory read out of range (addr=\(addr))")
            return 0
        }
        var bits: UInt64 = 0
        for i in 0..<8 {
            bits |= UInt64(self.memory[addr + i]) << (i * 8)
        }
        return Double(bitPattern: bits)
    }

    internal func writeFloat(_ addr: Int, _ value: Double) {
        if addr < 0 || addr + 8 > self.memory.count {
            self.throwInvalidAddress("? Memory write out of range (addr=\(addr))")
            return
        }
        let bits = value.bitPattern
        for i in 0..<8 {
            self.memory[addr + i] = UInt8((bits >> (i * 8)) & 0xFF)
        }
    }

    internal func floatToCell(_ value: Double) -> Cell {
        Cell(bitPattern: UInt(truncatingIfNeeded: value.bitPattern))
    }

    internal func cellToFloat(_ bits: Cell) -> Double {
        Double(bitPattern: UInt64(UInt(bitPattern: bits)))
    }

    // MARK: - Text parsing / compilation

    /// ANS 12.3.7: decimal float literal when BASE is 10 and token contains '.' or 'E'.
    internal func parseTextFloat(_ name: String) -> Double? {
        guard self.readCell(self.BASE) == 10 else { return nil }
        let upper = name.uppercased()
        guard upper.contains(".") || upper.contains("E") else { return nil }
        return self.parseFloatString(name)
    }

    internal func parseFloatString(_ text: String) -> Double? {
        var s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        if s.hasPrefix("+") { s = String(s.dropFirst()) }
        guard !s.isEmpty else { return nil }
        return Double(s)
    }

    internal func compileFloatLiteral(_ value: Double) {
        self.push(self.flitID); self.comma()
        self.push(self.floatToCell(value)); self.comma()
    }

    internal func formatFloatForDecompile(_ bits: Cell) -> String {
        let value = self.cellToFloat(bits)
        if value.isNaN { return "NaN" }
        if value.isInfinite {
            return value.sign == .minus ? "-Infinity" : "Infinity"
        }
        return String(value)
    }

    private func formatFloatOutput(_ value: Double) -> String {
        if value.isNaN { return "NaN " }
        if value.isInfinite {
            return value.sign == .minus ? "-Infinity " : "Infinity "
        }
        var s = String(value)
        if !s.contains(".") && !s.uppercased().contains("E") {
            s += "."
        }
        return s + " "
    }

    private func pushFloatCompareFlag(_ flag: Bool) {
        self.push(flag ? -1 : 0)
    }

    // MARK: - Registration

    func registerFloatWords() {
        self.flitID = self.register("FLIT") {
            let bits = self.readCell(self.ip)
            self.ip += 8
            self.fpush(self.cellToFloat(bits))
        }

        _ = self.register("FDEPTH") {
            self.push(self.fspGet() - 1)
        }

        _ = self.register("FDROP") {
            _ = self.fpop()
        }

        _ = self.register("FDUP") {
            self.fpush(self.fpeek(0))
        }

        _ = self.register("FSWAP") {
            let r1 = self.fpop()
            let r2 = self.fpop()
            self.fpush(r1)
            self.fpush(r2)
        }

        _ = self.register("FOVER") {
            self.fpush(self.fpeek(1))
        }

        _ = self.register("FLOATS") {
            self.push(8)
        }

        _ = self.register("FLOAT+") {
            let addr = Int(self.pop())
            self.push(Cell(addr + 8))
        }

        _ = self.register("FALIGN") {
            let addr = Int(self.pop())
            self.push(Cell((addr + 7) & ~7))
        }

        _ = self.register("FALIGNED") {
            let addr = Int(self.pop())
            self.push((addr & 7) == 0 ? -1 : 0)
        }

        _ = self.register("F@") {
            let addr = Int(self.pop())
            self.fpush(self.readFloat(addr))
        }

        _ = self.register("F!") {
            let addr = Int(self.pop())
            self.writeFloat(addr, self.fpop())
        }

        _ = self.register("F+") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.fpush(r1 + r2)
        }

        _ = self.register("F-") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.fpush(r1 - r2)
        }

        _ = self.register("F*") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.fpush(r1 * r2)
        }

        _ = self.register("F/") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.fpush(r1 / r2)
        }

        _ = self.register("FNEGATE") {
            self.fpush(-self.fpop())
        }

        _ = self.register("F0=") {
            self.pushFloatCompareFlag(self.fpop() == 0)
        }

        _ = self.register("F0<") {
            self.pushFloatCompareFlag(self.fpop() < 0)
        }

        _ = self.register("F<") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.pushFloatCompareFlag(r1 < r2)
        }

        _ = self.register("S>F") {
            self.fpush(Double(self.pop()))
        }

        _ = self.register("D>F") {
            let hi = self.pop()
            let lo = self.pop()
            let d = self.assembleSignedDouble(lo: lo, hi: hi)
            self.fpush(Double(d))
        }

        _ = self.register(">FLOAT") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            var bytes = [UInt8]()
            bytes.reserveCapacity(u)
            for i in 0..<u {
                bytes.append(self.readByte(caddr + i))
            }
            guard let text = String(bytes: bytes, encoding: .utf8),
                  let value = self.parseFloatString(text) else {
                self.push(0)
                return
            }
            self.fpush(value)
            self.push(-1)
        }

        _ = self.register("F.") {
            self.tell(self.formatFloatOutput(self.fpop()))
        }

        _ = self.register(".FS") {
            let depth = Int(self.fspGet() - 1)
            self.tell("<\(depth)> ")
            for i in 0..<depth {
                let val = self.readFloat(self.fstackBase + i * 8)
                self.tell(self.formatFloatOutput(val))
            }
            self.putkey(10)
        }

        _ = self.register("FLITERAL", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.throwCompileOnly("? FLITERAL only while compiling")
                return
            }
            self.compileFloatLiteral(self.fpop())
        }

        _ = self.register("FCONSTANT") {
            let name = self.parseWord()
            if name.isEmpty {
                self.throwZeroLengthName("? FCONSTANT needs a name")
                return
            }
            let bits = self.floatToCell(self.fpop())
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.flitID); self.comma()
            self.push(bits); self.comma()
            self.push(self.exitID); self.comma()
        }
    }
}