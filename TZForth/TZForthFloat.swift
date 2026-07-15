//
//  TZForthFloat.swift
//  TZForth
//
//  Float Tier A + B — ANS floating-point (IEEE 64-bit, separate 16-deep F stack).
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

    private func readSingleFloat(_ addr: Int) -> Double {
        if addr < 0 || addr + 4 > self.memory.count {
            self.throwInvalidAddress("? Memory read out of range (addr=\(addr))")
            return 0
        }
        var bits: UInt32 = 0
        for i in 0..<4 {
            bits |= UInt32(self.memory[addr + i]) << (i * 8)
        }
        return Double(Float(bitPattern: bits))
    }

    private func writeSingleFloat(_ addr: Int, _ value: Double) {
        if addr < 0 || addr + 4 > self.memory.count {
            self.throwInvalidAddress("? Memory write out of range (addr=\(addr))")
            return
        }
        let bits = Float(value).bitPattern
        for i in 0..<4 {
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

    private func looksLikeFloatToken(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let upper = name.uppercased()
        if upper.contains(".") || upper.contains("E") { return true }
        if upper.hasSuffix("D") {
            let stem = String(upper.dropLast())
            return !stem.isEmpty && stem.allSatisfy { $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }
        }
        return false
    }

    /// ANS 12.3.7: decimal float literal when BASE is 10.
    internal func parseTextFloat(_ name: String) -> Double? {
        guard self.readCell(self.BASE) == 10 else { return nil }
        guard self.looksLikeFloatToken(name) else { return nil }
        return self.parseFloatString(name)
    }

    internal func parseFloatString(_ text: String) -> Double? {
        var s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        if s.hasPrefix("+") { s = String(s.dropFirst()) }
        guard !s.isEmpty else { return nil }
        var upper = s.uppercased()
        if upper.hasSuffix("D") {
            upper = String(upper.dropLast()) + "E0"
            s = String(s.dropLast()) + "e0"
        }
        if upper.hasSuffix("E") {
            s += "0"
            upper += "0"
        }
        if let v = Double(s) { return v }
        if let v = Double(upper) { return v }
        return nil
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

    private func floatTilde(_ r1: Double, _ r2: Double, _ u: Double) -> Bool {
        if u == 0 {
            return r1 == r2
        }
        let diff = abs(r1 - r2)
        if u < 0 {
            return diff <= abs(u)
        }
        if r1 == 0 && r2 == 0 {
            return true
        }
        return diff <= abs(r1) * u
    }

    private func alignAddress(_ addr: Int, boundary: Int) -> Int {
        (addr + boundary - 1) & ~(boundary - 1)
    }

    private func formatFloatEngineering(_ value: Double) -> String {
        let prec = max(1, self.floatSetPrecision)
        if value.isNaN { return "NaN " }
        if value.isInfinite {
            return (value.sign == .minus ? "-Infinity " : "Infinity ")
        }
        if value == 0 {
            let zeros = String(repeating: "0", count: max(0, prec - 1))
            return "0.\(zeros)E0 "
        }
        let exp = Int(floor(log10(abs(value))))
        let mantissa = value / pow(10.0, Double(exp))
        let fracDigits = max(0, prec - 1)
        let fmt = String(format: "%%.%dE", fracDigits)
        var s = String(format: fmt, mantissa).uppercased()
        if !s.contains(".") {
            if let eRange = s.range(of: "E") {
                s.insert(contentsOf: ".", at: eRange.lowerBound)
            }
        }
        if let eRange = s.range(of: "E") {
            let tail = s[eRange.upperBound...]
            if let n = Int(tail) {
                s = String(s[..<eRange.upperBound]) + String(n)
            }
        }
        return s + " "
    }

    private func formatFloatFixed(_ value: Double) -> String {
        let prec = max(1, self.floatSetPrecision)
        if value.isNaN { return "NaN " }
        if value.isInfinite {
            return (value.sign == .minus ? "-Infinity " : "Infinity ")
        }
        let fmt = String(format: "%%.%dE", max(0, prec - 1))
        var s = String(format: fmt, value).uppercased()
        if let eRange = s.range(of: "E") {
            s = String(s[..<eRange.lowerBound])
        }
        if !s.contains(".") { s += "." }
        return s + " "
    }

    private func representFloat(_ value: Double, buffer: Int, u: Int) -> (k: Int, charFlag: Int, exact: Bool) {
        let width = max(1, u)
        for i in 0..<width {
            if buffer + i < self.memory.count {
                self.memory[buffer + i] = UInt8(ascii: "0")
            }
        }
        if value.isNaN || value.isInfinite {
            return (0, 0, false)
        }
        if value == 0 {
            if width > 0, buffer < self.memory.count {
                self.memory[buffer] = UInt8(ascii: "0")
            }
            return (0, 0, true)
        }
        var exp = Int(floor(log10(abs(value))))
        var mantissa = value / pow(10.0, Double(exp - (width - 1)))
        mantissa = (mantissa.rounded(.toNearestOrAwayFromZero))
        if abs(mantissa) >= pow(10.0, Double(width)) {
            mantissa /= 10
            exp += 1
        }
        let digits = String(format: "%0\(width).0f", abs(mantissa))
        let chars = Array(digits.utf8.prefix(width))
        for (i, b) in chars.enumerated() where buffer + i < self.memory.count {
            self.memory[buffer + i] = b
        }
        let charFlag = value < 0 ? 45 : 0
        let reconstructed = (value < 0 ? -1.0 : 1.0) * mantissa * pow(10.0, Double(exp - (width - 1)))
        let exact = reconstructed == value
        return (exp, charFlag, exact)
    }

    // MARK: - Registration

    func registerFloatWords() {
        self.flitID = self.register("FLIT") {
            let bits = self.readCell(self.ip)
            self.ip += 8
            self.fpush(self.cellToFloat(bits))
        }

        self.fvalueFetchID = self.register("(FVALUE@)") {
            let addr = Int(self.pop())
            self.fpush(self.readFloat(addr))
        }
        self.fvalueStoreID = self.register("(FVALUE!)") {
            let addr = Int(self.pop())
            self.writeFloat(addr, self.fpop())
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

        _ = self.register("FROT") {
            let r3 = self.fpop()
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.fpush(r2)
            self.fpush(r3)
            self.fpush(r1)
        }

        _ = self.register("F-ROT") {
            let r1 = self.fpop()
            let r2 = self.fpop()
            let r3 = self.fpop()
            self.fpush(r1)
            self.fpush(r3)
            self.fpush(r2)
        }

        _ = self.register("FLOATS") {
            self.push(8)
        }

        _ = self.register("SFLOATS") {
            self.push(4)
        }

        _ = self.register("DFLOATS") {
            self.push(8)
        }

        _ = self.register("FLOAT+") {
            let addr = Int(self.pop())
            self.push(Cell(addr + 8))
        }

        _ = self.register("SFLOAT+") {
            let addr = Int(self.pop())
            self.push(Cell(addr + 4))
        }

        _ = self.register("DFLOAT+") {
            let addr = Int(self.pop())
            self.push(Cell(addr + 8))
        }

        _ = self.register("FALIGN") {
            let addr = Int(self.pop())
            self.push(Cell(self.alignAddress(addr, boundary: 8)))
        }

        _ = self.register("SFALIGN") {
            let addr = Int(self.pop())
            self.push(Cell(self.alignAddress(addr, boundary: 4)))
        }

        _ = self.register("DFALIGN") {
            let addr = Int(self.pop())
            self.push(Cell(self.alignAddress(addr, boundary: 8)))
        }

        _ = self.register("FALIGNED") {
            let addr = Int(self.pop())
            self.push((addr & 7) == 0 ? -1 : 0)
        }

        _ = self.register("SFALIGNED") {
            let addr = Int(self.pop())
            self.push((addr & 3) == 0 ? -1 : 0)
        }

        _ = self.register("DFALIGNED") {
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

        _ = self.register("SF@") {
            let addr = Int(self.pop())
            self.fpush(self.readSingleFloat(addr))
        }

        _ = self.register("SF!") {
            let addr = Int(self.pop())
            self.writeSingleFloat(addr, self.fpop())
        }

        _ = self.register("DF@") {
            let addr = Int(self.pop())
            self.fpush(self.readFloat(addr))
        }

        _ = self.register("DF!") {
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

        _ = self.register("FABS") {
            self.fpush(abs(self.fpop()))
        }

        _ = self.register("FMAX") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.fpush(max(r1, r2))
        }

        _ = self.register("FMIN") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.fpush(min(r1, r2))
        }

        _ = self.register("FMOD") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.fpush(r1.truncatingRemainder(dividingBy: r2))
        }

        _ = self.register("FLOOR") {
            self.fpush(floor(self.fpop()))
        }

        _ = self.register("FROUND") {
            self.fpush((self.fpop()).rounded())
        }

        _ = self.register("FSQRT") {
            self.fpush(sqrt(self.fpop()))
        }

        _ = self.register("F**") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.fpush(pow(r1, r2))
        }

        _ = self.register("FEXP") {
            self.fpush(exp(self.fpop()))
        }

        _ = self.register("FEXPM1") {
            self.fpush(expm1(self.fpop()))
        }

        _ = self.register("FLN") {
            self.fpush(log(self.fpop()))
        }

        _ = self.register("FLNP1") {
            self.fpush(log1p(self.fpop()))
        }

        _ = self.register("FLOG") {
            self.fpush(log10(self.fpop()))
        }

        _ = self.register("FALOG") {
            self.fpush(pow(10.0, self.fpop()))
        }

        _ = self.register("FSIN") {
            self.fpush(sin(self.fpop()))
        }

        _ = self.register("FCOS") {
            self.fpush(cos(self.fpop()))
        }

        _ = self.register("FTAN") {
            self.fpush(tan(self.fpop()))
        }

        _ = self.register("FASIN") {
            self.fpush(asin(self.fpop()))
        }

        _ = self.register("FACOS") {
            self.fpush(acos(self.fpop()))
        }

        _ = self.register("FATAN") {
            self.fpush(atan(self.fpop()))
        }

        _ = self.register("FATAN2") {
            let x = self.fpop()
            let y = self.fpop()
            self.fpush(atan2(y, x))
        }

        _ = self.register("FSINCOS") {
            let r = self.fpop()
            self.fpush(sin(r))
            self.fpush(cos(r))
        }

        _ = self.register("FSINH") {
            self.fpush(sinh(self.fpop()))
        }

        _ = self.register("FCOSH") {
            self.fpush(cosh(self.fpop()))
        }

        _ = self.register("FTANH") {
            self.fpush(tanh(self.fpop()))
        }

        _ = self.register("FASINH") {
            self.fpush(asinh(self.fpop()))
        }

        _ = self.register("FACOSH") {
            self.fpush(acosh(self.fpop()))
        }

        _ = self.register("FATANH") {
            self.fpush(atanh(self.fpop()))
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

        _ = self.register("F~") {
            let u = self.fpop()
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.pushFloatCompareFlag(self.floatTilde(r1, r2, u))
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

        _ = self.register("F>D") {
            let r = self.fpop()
            let truncated = Int128(r.rounded(.towardZero))
            let pair = self.disassembleSignedDouble(truncated)
            self.push(pair.lo)
            self.push(pair.hi)
        }

        _ = self.register("F>S") {
            let r = self.fpop()
            self.push(Cell(Int64(r.rounded(.towardZero))))
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

        _ = self.register("FS.") {
            self.tell(self.formatFloatEngineering(self.fpop()))
        }

        _ = self.register("FE.") {
            self.tell(self.formatFloatFixed(self.fpop()))
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

        _ = self.register("PRECISION") {
            self.push(Cell(self.floatSetPrecision))
        }

        _ = self.register("SET-PRECISION") {
            let u = Int(self.pop())
            self.floatSetPrecision = max(1, u)
        }

        _ = self.register("REPRESENT") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            let r = self.fpop()
            let result = self.representFloat(r, buffer: caddr, u: u)
            self.push(Cell(result.k))
            self.push(Cell(result.charFlag))
            self.push(result.exact ? -1 : 0)
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

        _ = self.register("FVARIABLE") {
            let name = self.parseWord()
            if name.isEmpty {
                self.throwZeroLengthName("? FVARIABLE needs a name")
                return
            }
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            let dataAddr = self.readCell(self.DP_ADDR) + 16
            self.push(dataAddr); self.comma()
            self.push(self.exitID); self.comma()
            self.writeCell(self.DP_ADDR, self.readCell(self.DP_ADDR) + 8)
        }

        _ = self.register("FVALUE") {
            let name = self.parseWord()
            if name.isEmpty {
                self.throwZeroLengthName("? FVALUE needs a name")
                return
            }
            let bits = self.floatToCell(self.fpop())
            self.createWord(name: name, immediate: false)
            self.push(self.docolID); self.comma()
            self.push(self.litID); self.comma()
            let valCellAddr = self.readCell(self.DP_ADDR) + 24
            self.push(valCellAddr); self.comma()
            self.push(self.fvalueFetchID); self.comma()
            self.push(self.exitID); self.comma()
            self.writeCell(self.DP_ADDR, self.readCell(self.DP_ADDR) + 8)
            self.writeFloat(Int(valCellAddr), self.cellToFloat(bits))
        }
    }
}