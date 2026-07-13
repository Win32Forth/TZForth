//
//  TZForthXChar.swift
//  TZForth
//
//  ANS Forth 2012 Extended-Character word set (chapter 18) — UTF-8 codec, memory, string, parsing, I/O words.
//

import Foundation

extension TZForth {

    // MARK: - Constants

    static let maxXchar: UInt32 = 0x10_FFFF

    // MARK: - UTF-8 codec (internal)

    /// Encoded byte length for a code point (ANS XC-SIZE). Throws on invalid code points.
    func xcEncodedSize(of codePoint: UInt32) throws -> Int {
        if codePoint <= 0x7F { return 1 }
        if codePoint <= 0x7FF { return 2 }
        if codePoint >= 0xD800 && codePoint <= 0xDFFF {
            throw TZForthXCharError.malformed
        }
        if codePoint <= 0xFFFF { return 3 }
        if codePoint <= Self.maxXchar { return 4 }
        throw TZForthXCharError.malformed
    }

    /// Size of one encoded xchar from its leading byte only (ANS X-SIZE; u1 must be > 0).
    func xcLeadingByteEncodedSize(_ leading: UInt8) throws -> Int {
        if leading < 0x80 { return 1 }
        if leading < 0xC0 { throw TZForthXCharError.malformed }
        if leading < 0xE0 { return 2 }
        if leading < 0xF0 { return 3 }
        if leading < 0xF8 { return 4 }
        throw TZForthXCharError.malformed
    }

    func xcDecode(at addr: Int) throws -> (codePoint: Cell, nextAddr: Int) {
        let b0 = self.readByte(addr)
        if b0 < 0x80 {
            return (Cell(b0), addr + 1)
        }
        if b0 < 0xC0 {
            throw TZForthXCharError.malformed
        }
        if b0 < 0xE0 {
            let b1 = self.readByte(addr + 1)
            if (b1 & 0xC0) != 0x80 { throw TZForthXCharError.malformed }
            let cp = UInt32(b0 & 0x1F) << 6 | UInt32(b1 & 0x3F)
            if cp < 0x80 { throw TZForthXCharError.malformed }
            return (Cell(cp), addr + 2)
        }
        if b0 < 0xF0 {
            let b1 = self.readByte(addr + 1)
            let b2 = self.readByte(addr + 2)
            if (b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 { throw TZForthXCharError.malformed }
            let cp = UInt32(b0 & 0x0F) << 12 | UInt32(b1 & 0x3F) << 6 | UInt32(b2 & 0x3F)
            if cp < 0x800 || (cp >= 0xD800 && cp <= 0xDFFF) { throw TZForthXCharError.malformed }
            return (Cell(cp), addr + 3)
        }
        if b0 < 0xF8 {
            let b1 = self.readByte(addr + 1)
            let b2 = self.readByte(addr + 2)
            let b3 = self.readByte(addr + 3)
            if (b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80 {
                throw TZForthXCharError.malformed
            }
            let cp = UInt32(b0 & 0x07) << 18 | UInt32(b1 & 0x3F) << 12 | UInt32(b2 & 0x3F) << 6 | UInt32(b3 & 0x3F)
            if cp < 0x1_0000 || cp > Self.maxXchar { throw TZForthXCharError.malformed }
            return (Cell(cp), addr + 4)
        }
        throw TZForthXCharError.malformed
    }

    func xcEncode(_ codePoint: UInt32) throws -> [UInt8] {
        let size = try self.xcEncodedSize(of: codePoint)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(size)
        switch size {
        case 1:
            bytes.append(UInt8(codePoint))
        case 2:
            bytes.append(UInt8(0xC0 | (codePoint >> 6)))
            bytes.append(UInt8(0x80 | (codePoint & 0x3F)))
        case 3:
            bytes.append(UInt8(0xE0 | (codePoint >> 12)))
            bytes.append(UInt8(0x80 | ((codePoint >> 6) & 0x3F)))
            bytes.append(UInt8(0x80 | (codePoint & 0x3F)))
        case 4:
            bytes.append(UInt8(0xF0 | (codePoint >> 18)))
            bytes.append(UInt8(0x80 | ((codePoint >> 12) & 0x3F)))
            bytes.append(UInt8(0x80 | ((codePoint >> 6) & 0x3F)))
            bytes.append(UInt8(0x80 | (codePoint & 0x3F)))
        default:
            throw TZForthXCharError.malformed
        }
        return bytes
    }

    @discardableResult
    func xcStore(codePoint: UInt32, at addr: Int) throws -> Int {
        let bytes = try self.xcEncode(codePoint)
        for (i, b) in bytes.enumerated() {
            self.writeByte(addr + i, b)
        }
        return addr + bytes.count
    }

    func xcharPlusAddr(_ xcAddr: Int) throws -> Int {
        let decoded = try self.xcDecode(at: xcAddr)
        return decoded.nextAddr
    }

    func xcharMinusAddr(_ xcAddr: Int) -> Int {
        var addr = xcAddr
        repeat {
            addr -= 1
            let b = self.readByte(addr)
            if (b & 0xC0) != 0x80 { break }
        } while addr > 0
        return addr
    }

    func xcharCodePointFromStack(_ cell: Cell) -> UInt32 {
        UInt32(truncatingIfNeeded: cell)
    }

    // MARK: - Parsing helpers (18.6.2 — shadow CHAR, [CHAR], PARSE)

    private func inputQueueHasPrefix(_ bytes: [UInt8]) -> Bool {
        if bytes.isEmpty || self.inputQueue.count < bytes.count { return false }
        for i in 0..<bytes.count where self.inputQueue[i] != bytes[i] {
            return false
        }
        return true
    }

    /// ANS XCHAR CHAR / [CHAR]: BL-delimited name → first xchar (nil when throw already raised).
    func parseNameFirstXchar() -> Cell? {
        let counted = Int(self.parseToWordBuffer(using: 32))
        let len = Int(self.readByte(counted))
        if len <= 0 {
            self.kernelThrow(StdThrow.undefinedWord, message: "? CHAR")
            return nil
        }
        if let decoded = try? self.xcDecode(at: counted + 1) {
            return decoded.codePoint
        }
        self.throwMalformedXchar()
        return nil
    }

    /// ANS XCHAR PARSE — parse SOURCE up to an xchar delimiter (byte length u).
    func parseSourceDelimitedByXchar(_ codePoint: UInt32) -> (addr: Int, len: Int)? {
        guard let delimBytes = try? self.xcEncode(codePoint) else {
            self.throwMalformedXchar()
            return nil
        }
        let startPos = Int(self.readCell(self.IN))
        var len = 0
        while !self.inputQueue.isEmpty {
            let b = self.inputQueue.first!
            if b == 10 || b == 13 { break }
            if self.inputQueueHasPrefix(delimBytes) { break }
            _ = self.consumeInput()
            len += 1
        }
        var endPos = startPos + len
        if self.inputQueueHasPrefix(delimBytes) {
            for _ in delimBytes { _ = self.consumeInput() }
            endPos += delimBytes.count
        }
        self.writeCell(self.IN, Cell(endPos))
        return (self.SOURCE_BUFFER + startPos, len)
    }

    // MARK: - Terminal I/O helpers (18.6.1)

    /// Decode a collected UTF-8 byte prefix; nil until the sequence is complete and valid.
    func decodeAssembledXKeyBytes() -> Cell? {
        if self.xkeyAssembly.isEmpty { return nil }
        guard let need = try? self.xcLeadingByteEncodedSize(self.xkeyAssembly[0]) else {
            return nil
        }
        if self.xkeyAssembly.count < need { return nil }
        let slice = Array(self.xkeyAssembly.prefix(need))
        guard let decoded = try? self.xcDecodeBytes(slice) else { return nil }
        return decoded
    }

    /// True when a complete xchar is already buffered for XKEY / XKEY?.
    func xkeyCompleteInAssembly() -> Bool {
        self.decodeAssembledXKeyBytes() != nil
    }

    private func xcDecodeBytes(_ bytes: [UInt8]) throws -> Cell {
        for (i, b) in bytes.enumerated() {
            self.writeByte(self.PAD_BUFFER + i, b)
        }
        return try self.xcDecode(at: self.PAD_BUFFER).codePoint
    }

    /// xchar from a TZForth EKEY character event (see makeCharKeyEvent).
    func xcharFromCharKeyEvent(_ x: Int) -> Cell? {
        if !self.isCharKeyEvent(x) { return nil }
        let low = x & 0xFF
        let mid = (x >> 8) & 0xFFFF
        if mid != 0 && low < 0x80 {
            return Cell(low)
        }
        return Cell(x & 0xFFFFFF)
    }

    // MARK: - String helpers (18.6.2)

    /// ANS +X/STRING — skip the first xchar in a bounded buffer.
    func plusXString(xcAddr: Int, u1: Int) throws -> (xcAddr2: Int, u2: Int) {
        if u1 <= 0 {
            return (xcAddr, 0)
        }
        let next = try self.xcharPlusAddr(xcAddr)
        let skip = next - xcAddr
        if skip > u1 {
            throw TZForthXCharError.malformed
        }
        return (next, u1 - skip)
    }

    /// ANS X\STRING- — all xchars except the last in the buffer.
    func xStringMinus(xcAddr: Int, u1: Int) -> (xcAddr: Int, u2: Int) {
        if u1 <= 0 {
            return (xcAddr, 0)
        }
        let end = xcAddr + u1
        let lastStart = self.xcharMinusAddr(end)
        return (xcAddr, lastStart - xcAddr)
    }

    /// ANS -TRAILING-GARBAGE — drop an incomplete final xchar from the counted string.
    func trailingGarbageTrim(xcAddr: Int, u1: Int) -> (xcAddr: Int, u2: Int) {
        if u1 <= 0 {
            return (xcAddr, 0)
        }
        let end = xcAddr + u1
        let lastStart = self.xcharMinusAddr(end)
        let tailLen = end - lastStart
        if tailLen > 0 {
            if let size = try? self.xcLeadingByteEncodedSize(self.readByte(lastStart)),
               size == tailLen,
               (try? self.xcDecode(at: lastStart)) != nil {
                return (xcAddr, u1)
            }
        }
        return (xcAddr, lastStart - xcAddr)
    }

    // MARK: - Registration

    func registerXCharWords() {
        _ = register("XC-SIZE") {
            let cp = self.xcharCodePointFromStack(self.pop())
            do {
                let n = try self.xcEncodedSize(of: cp)
                self.push(Cell(n))
            } catch {
                self.throwMalformedXchar()
            }
        }

        _ = register("X-SIZE") {
            let u1 = Int(self.pop())
            let xcAddr = Int(self.pop())
            if u1 <= 0 {
                self.push(0)
                return
            }
            do {
                let n = try self.xcLeadingByteEncodedSize(self.readByte(xcAddr))
                self.push(Cell(n))
            } catch {
                self.throwMalformedXchar()
            }
        }

        _ = register("XC@+") {
            let xcAddr = Int(self.pop())
            do {
                let decoded = try self.xcDecode(at: xcAddr)
                self.push(Cell(decoded.nextAddr))
                self.push(decoded.codePoint)
            } catch {
                self.throwMalformedXchar()
            }
        }

        _ = register("XC!+") {
            let xcAddr = Int(self.pop())
            let cp = self.xcharCodePointFromStack(self.pop())
            do {
                let next = try self.xcStore(codePoint: cp, at: xcAddr)
                self.push(Cell(next))
            } catch {
                self.throwMalformedXchar()
            }
        }

        _ = register("XC!+?") {
            let u1 = Int(self.pop())
            let xcAddr = Int(self.pop())
            let cp = self.xcharCodePointFromStack(self.pop())
            do {
                let need = try self.xcEncodedSize(of: cp)
                if need > u1 {
                    self.push(Cell(xcAddr))
                    self.push(Cell(u1))
                    self.push(0)
                    return
                }
                let next = try self.xcStore(codePoint: cp, at: xcAddr)
                self.push(Cell(next))
                self.push(Cell(u1 - need))
                self.push(-1)
            } catch {
                self.throwMalformedXchar()
            }
        }

        _ = register("XC,") {
            let cp = self.xcharCodePointFromStack(self.pop())
            do {
                let here = Int(self.readCell(self.DP_ADDR))
                let next = try self.xcStore(codePoint: cp, at: here)
                self.writeCell(self.DP_ADDR, Cell(next))
            } catch {
                self.throwMalformedXchar()
            }
        }

        _ = register("XCHAR+") {
            let xcAddr = Int(self.pop())
            do {
                let next = try self.xcharPlusAddr(xcAddr)
                self.push(Cell(next))
            } catch {
                self.throwMalformedXchar()
            }
        }

        _ = register("XCHAR-") {
            let xcAddr = Int(self.pop())
            self.push(Cell(self.xcharMinusAddr(xcAddr)))
        }

        _ = register("+X/STRING") {
            let u1 = Int(self.pop())
            let xcAddr = Int(self.pop())
            do {
                let result = try self.plusXString(xcAddr: xcAddr, u1: u1)
                self.push(Cell(result.xcAddr2))
                self.push(Cell(result.u2))
            } catch {
                self.throwMalformedXchar()
            }
        }

        _ = register("X\\STRING-") {
            let u1 = Int(self.pop())
            let xcAddr = Int(self.pop())
            let result = self.xStringMinus(xcAddr: xcAddr, u1: u1)
            self.push(Cell(result.xcAddr))
            self.push(Cell(result.u2))
        }

        _ = register("-TRAILING-GARBAGE") {
            let u1 = Int(self.pop())
            let xcAddr = Int(self.pop())
            let result = self.trailingGarbageTrim(xcAddr: xcAddr, u1: u1)
            self.push(Cell(result.xcAddr))
            self.push(Cell(result.u2))
        }

        // Shadow Core CHAR / [CHAR] / PARSE (ANS 18.6.2; registered after kernel primitives).
        _ = register("CHAR") {
            if let cp = self.parseNameFirstXchar(), !self.throwActive {
                self.push(cp)
            }
        }

        _ = register("[CHAR]", immediate: true) {
            if self.readCell(self.STATE) == 0 {
                self.throwCompileOnly("? [CHAR] only while compiling")
                return
            }
            guard let cp = self.parseNameFirstXchar(), !self.throwActive else { return }
            self.push(self.litID); self.comma()
            self.push(cp); self.comma()
        }

        _ = register("PARSE") {
            let cp = self.xcharCodePointFromStack(self.pop())
            if let parsed = self.parseSourceDelimitedByXchar(cp), !self.throwActive {
                self.push(Cell(parsed.addr))
                self.push(Cell(parsed.len))
            }
        }

        // Terminal I/O (18.6.1 / 18.6.2)
        _ = register("XEMIT") {
            let cp = self.xcharCodePointFromStack(self.pop())
            if let bytes = try? self.xcEncode(cp) {
                self.emitUtf8Bytes(bytes)
            } else {
                self.throwMalformedXchar()
            }
        }

        _ = register("XKEY") {
            if let cp = self.decodeAssembledXKeyBytes(),
               let need = try? self.xcLeadingByteEncodedSize(self.xkeyAssembly[0]) {
                self.xkeyAssembly.removeFirst(need)
                self.push(cp)
                return
            }
            self.waitingForXKey = true
            self.waitingForKey = true
        }

        _ = register("XKEY?") {
            self.push(self.xkeyCompleteInAssembly() ? -1 : 0)
        }

        _ = register("EKEY>XCHAR") {
            let x = Int(self.pop())
            if let cp = self.xcharFromCharKeyEvent(x) {
                self.push(cp)
                self.push(-1)
            } else {
                self.push(Cell(x))
                self.push(0)
            }
        }

        // Pictured numeric (18.6.2 — ANS reference: XC!+ then HOLDS)
        _ = register("XHOLD") {
            let cp = self.xcharCodePointFromStack(self.pop())
            if let bytes = try? self.xcEncode(cp) {
                self.picturedHoldsBytes(bytes)
            } else {
                self.throwMalformedXchar()
            }
        }
    }
}

private enum TZForthXCharError: Error {
    case malformed
}