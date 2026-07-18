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

    /// ANS 12.3.7: float literal syntax; BASE is ignored when parsing (see ttester.fs note).
    internal func parseTextFloat(_ name: String) -> Double? {
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

    /// ANS 12.6.1.0558 >FLOAT: broader syntax; blanks-only string is zero.
    internal func parseGreaterFloatString(_ text: String) -> Double? {
        guard !text.isEmpty else { return 0 }
        if text.allSatisfy({ $0.isWhitespace }) { return 0 }
        if text.contains(where: { $0.isWhitespace }) { return nil }

        let chars = Array(text)
        var i = 0

        var sign: Double = 1
        if i < chars.count, chars[i] == "+" || chars[i] == "-" {
            if chars[i] == "-" { sign = -1 }
            i += 1
        }
        guard i < chars.count else { return nil }

        var intPart: Double = 0
        var fracPart: Double = 0
        var fracDivisor: Double = 1
        var hasInt = false
        var hasFrac = false

        if chars[i].isNumber {
            hasInt = true
            while i < chars.count, chars[i].isNumber {
                intPart = intPart * 10 + Double(chars[i].wholeNumberValue ?? 0)
                i += 1
            }
        }

        if i < chars.count, chars[i] == "." {
            i += 1
            while i < chars.count, chars[i].isNumber {
                hasFrac = true
                fracPart = fracPart * 10 + Double(chars[i].wholeNumberValue ?? 0)
                fracDivisor *= 10
                i += 1
            }
        }

        guard hasInt || hasFrac else { return nil }

        var value = sign * (intPart + fracPart / fracDivisor)

        if i < chars.count {
            let marker = chars[i]
            if marker == "e" || marker == "E" || marker == "d" || marker == "D" {
                i += 1
                var expSign = 1
                if i < chars.count, chars[i] == "+" || chars[i] == "-" {
                    if chars[i] == "-" { expSign = -1 }
                    i += 1
                }
                var expValue = 0
                while i < chars.count, chars[i].isNumber {
                    expValue = expValue * 10 + (chars[i].wholeNumberValue ?? 0)
                    i += 1
                }
                value *= pow(10.0, Double(expSign * expValue))
            } else if marker == "+" || marker == "-" {
                let expSign = marker == "-" ? -1 : 1
                i += 1
                guard i < chars.count, chars[i].isNumber else { return nil }
                var expValue = 0
                while i < chars.count, chars[i].isNumber {
                    expValue = expValue * 10 + (chars[i].wholeNumberValue ?? 0)
                    i += 1
                }
                value *= pow(10.0, Double(expSign * expValue))
            } else {
                return nil
            }
        }

        guard i == chars.count else { return nil }
        return value
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

    private func roundLeadingDigits(_ digits: String, keep: Int) -> String {
        guard keep > 0 else { return "" }
        let chars = Array(digits)
        guard !chars.isEmpty else { return "" }
        var lead = Array(chars.prefix(keep))
        if chars.count > keep, chars[keep] >= Character("5") {
            for i in (0..<lead.count).reversed() {
                if lead[i] == Character("9") {
                    lead[i] = Character("0")
                } else if let v = lead[i].asciiValue {
                    lead[i] = Character(UnicodeScalar(v + 1))
                    return String(lead)
                }
            }
            return "1" + String(repeating: "0", count: keep)
        }
        return String(lead)
    }

    private func forthFmMod(_ d: Int, _ divisor: Int) -> (remainder: Int, quotient: Int) {
        guard divisor != 0 else { return (0, 0) }
        var quotient = d / divisor
        var remainder = d % divisor
        if (d ^ divisor) < 0 && remainder != 0 {
            quotient -= 1
            remainder += divisor
        }
        return (remainder, quotient)
    }

    /// ANS REPRESENT significand: u digits, implied decimal left of first digit; returns k (decimal exponent).
    private func floatRepresentSignificand(
        _ value: Double,
        u: Int,
        writeTo buffer: Int?,
        scratch: inout [UInt8]
    ) -> (k: Int, charFlag: Int, exact: Bool) {
        let width = max(1, u)
        scratch = Array(repeating: UInt8(ascii: "0"), count: width)
        if let buffer {
            for i in 0..<width where buffer + i < self.memory.count {
                self.memory[buffer + i] = UInt8(ascii: "0")
            }
        }

        if value.isNaN || value.isInfinite {
            return (0, 0, false)
        }
        if value == 0 {
            scratch[0] = UInt8(ascii: "0")
            if let buffer, buffer < self.memory.count {
                self.memory[buffer] = UInt8(ascii: "0")
            }
            return (0, 0, true)
        }

        let absValue = abs(value)
        var k = Int(floor(log10(absValue))) + 1
        let scale = pow(10.0, Double(width - k))
        var significand = (absValue * scale).rounded(.toNearestOrAwayFromZero)
        let upper = pow(10.0, Double(width))
        if significand >= upper {
            significand /= 10
            k += 1
        }

        let digits = String(format: "%0\(width).0f", significand)
        let chars = Array(digits.utf8.prefix(width))
        for (i, b) in chars.enumerated() {
            scratch[i] = b
            if let buffer, buffer + i < self.memory.count {
                self.memory[buffer + i] = b
            }
        }

        let charFlag = value < 0 ? -1 : 0
        return (k, charFlag, true)
    }

    private func floatRepresentScratch(_ value: Double) -> (k: Int, charFlag: Int, exact: Bool, digits: [UInt8]) {
        let prec = max(1, self.floatSetPrecision)
        var scratch = [UInt8]()
        let result = self.floatRepresentSignificand(value, u: prec, writeTo: nil, scratch: &scratch)
        return (result.k, result.charFlag, result.exact, scratch)
    }

    private func formatFloatOutput(_ value: Double) -> String {
        if value.isNaN { return "NaN " }
        if value.isInfinite {
            return value.sign == .minus ? "-Infinity " : "Infinity "
        }
        let rep = self.floatRepresentScratch(value)
        if !rep.exact {
            let text = String(bytes: rep.digits, encoding: .ascii) ?? ""
            let trimmed = text.replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            return (rep.charFlag != 0 ? "-" : "") + trimmed + " "
        }

        let prec = max(1, self.floatSetPrecision)
        let k = rep.k
        let digits = String(bytes: rep.digits, encoding: .ascii) ?? ""
        var out = rep.charFlag != 0 ? "-" : ""
        if k <= 0 {
            out += "0."
            if k < 0 {
                out += String(repeating: "0", count: -k)
            }
            let sigShow = max(0, prec + k)
            if sigShow > 0 {
                out += self.roundLeadingDigits(digits, keep: sigShow)
            }
        } else {
            let lead = min(k, prec)
            out += String(digits.prefix(lead))
            out += "."
            let fracStart = k
            if fracStart < prec {
                var frac = String(digits.dropFirst(fracStart))
                while frac.last == "0" { frac.removeLast() }
                out += frac
            }
        }
        return out + " "
    }

    private func pushFloatCompareFlag(_ flag: Bool) {
        self.push(flag ? -1 : 0)
    }

    private func floatIsNegativeZero(_ value: Double) -> Bool {
        value.bitPattern == 0x8000_0000_0000_0000
    }

    private func floatIsPositiveZero(_ value: Double) -> Bool {
        value == 0 && !self.floatIsNegativeZero(value)
    }

    /// Single UNIX / POSIX `atan2(y, x)` edge cases (fatan2-test.fs).
    private func floatAtan2(y: Double, x: Double) -> Double {
        if y.isNaN || x.isNaN { return .nan }

        let pi = Double.pi
        let halfPi = pi / 2
        let threeQuarterPi = 3 * pi / 4
        let quarterPi = pi / 4

        let xNegInf = x.isInfinite && x.sign == .minus
        let xPosInf = x.isInfinite && x.sign == .plus
        let yPosInf = y.isInfinite && y.sign == .plus
        let yNegInf = y.isInfinite && y.sign == .minus

        if self.floatIsPositiveZero(y) {
            if self.floatIsNegativeZero(x) || x < 0 { return pi }
            if x > 0 || self.floatIsPositiveZero(x) { return 0 }
        }
        if self.floatIsNegativeZero(y) {
            if self.floatIsNegativeZero(x) || x < 0 { return -pi }
            if x > 0 || self.floatIsPositiveZero(x) { return -0.0 }
        }

        if y > 0 && (self.floatIsPositiveZero(x) || self.floatIsNegativeZero(x)) {
            return halfPi
        }
        if y < 0 && (self.floatIsPositiveZero(x) || self.floatIsNegativeZero(x)) {
            return -halfPi
        }

        if yPosInf {
            if xNegInf { return threeQuarterPi }
            if xPosInf { return quarterPi }
            return halfPi
        }
        if yNegInf {
            if xNegInf { return -threeQuarterPi }
            if xPosInf { return -quarterPi }
            return -halfPi
        }

        if xNegInf {
            if y > 0 { return pi }
            if y < 0 { return -pi }
        }
        if xPosInf {
            if y > 0 { return 0 }
            if y < 0 { return -0.0 }
        }

        return atan2(y, x)
    }

    private func floatTilde(_ r1: Double, _ r2: Double, _ u: Double) -> Bool {
        if u == 0 {
            return r1.bitPattern == r2.bitPattern
        }
        let diff = abs(r1 - r2)
        if diff.isNaN { return false }
        if u > 0 {
            return diff < u
        }
        let limit = abs(u) * (abs(r1) + abs(r2))
        if limit.isNaN { return false }
        return diff < limit
    }

    private func alignAddress(_ addr: Int, boundary: Int) -> Int {
        (addr + boundary - 1) & ~(boundary - 1)
    }

    private func formatFloatEngineering(_ value: Double) -> String {
        if value.isNaN { return "NaN " }
        if value.isInfinite {
            return (value.sign == .minus ? "-Infinity " : "Infinity ")
        }
        let rep = self.floatRepresentScratch(value)
        if !rep.exact {
            let text = String(bytes: rep.digits, encoding: .ascii) ?? ""
            let trimmed = text.replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            return (rep.charFlag != 0 ? "-" : "") + trimmed + " "
        }

        // Digit count already respects SET-PRECISION via floatRepresentScratch.
        let digits = String(bytes: rep.digits, encoding: .ascii) ?? ""
        let exp = rep.k - 1
        var out = rep.charFlag != 0 ? "-" : ""
        if !digits.isEmpty {
            out += String(digits.prefix(1))
            out += "."
            if digits.count > 1 {
                out += String(digits.dropFirst())
            }
        }
        out += "E\(exp)"
        return out + " "
    }

    private func formatFloatFixed(_ value: Double) -> String {
        if value.isNaN { return "NaN " }
        if value.isInfinite {
            return (value.sign == .minus ? "-Infinity " : "Infinity ")
        }
        let rep = self.floatRepresentScratch(value)
        if !rep.exact {
            let text = String(bytes: rep.digits, encoding: .ascii) ?? ""
            let trimmed = text.replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            return (rep.charFlag != 0 ? "-" : "") + trimmed + " "
        }

        let prec = max(1, self.floatSetPrecision)
        let k = rep.k
        let n = k - 1
        let (rem, quot) = self.forthFmMod(n, 3)
        let engExp = quot * 3
        let leadDigits = rem + 1
        let digits = String(bytes: rep.digits, encoding: .ascii) ?? ""
        var out = rep.charFlag != 0 ? "-" : ""
        let typeCount = min(leadDigits, prec)
        if leadDigits > 0 {
            out += String(digits.prefix(typeCount))
        } else {
            out += "0"
        }
        if leadDigits > typeCount {
            out += String(repeating: "0", count: leadDigits - typeCount)
        }
        out += "."
        let fracStart = max(0, leadDigits)
        if fracStart < prec {
            out += String(digits.dropFirst(fracStart))
        }
        out += "E\(engExp)"
        return out + " "
    }

    private func representFloat(_ value: Double, buffer: Int, u: Int) -> (k: Int, charFlag: Int, exact: Bool) {
        var scratch = [UInt8]()
        return self.floatRepresentSignificand(value, u: u, writeTo: buffer, scratch: &scratch)
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
            let n = Int(self.pop())
            self.push(Cell(n * 8))
        }

        _ = self.register("SFLOATS") {
            let n = Int(self.pop())
            self.push(Cell(n * 4))
        }

        _ = self.register("DFLOATS") {
            let n = Int(self.pop())
            self.push(Cell(n * 8))
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
            self.fpush(self.floatAtan2(y: y, x: x))
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

        _ = self.register("F>") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.pushFloatCompareFlag(r1 > r2)
        }

        _ = self.register("F=") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.pushFloatCompareFlag(r1 == r2)
        }

        _ = self.register("F<>") {
            let r2 = self.fpop()
            let r1 = self.fpop()
            self.pushFloatCompareFlag(r1 != r2)
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
                  let value = self.parseGreaterFloatString(text) else {
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