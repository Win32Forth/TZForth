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

    /// ANS XC-WIDTH lookup ranges (width, first, last) from reference wc-table.
    private static let xcWidthRanges: [(width: Int, first: UInt32, last: UInt32)] = [
        (0, 0x0300, 0x0357), (0, 0x035D, 0x036F), (0, 0x0483, 0x0486), (0, 0x0488, 0x0489),
        (0, 0x0591, 0x05A1), (0, 0x05A3, 0x05B9), (0, 0x05BB, 0x05BD), (0, 0x05BF, 0x05BF),
        (0, 0x05C1, 0x05C2), (0, 0x05C4, 0x05C4), (0, 0x0600, 0x0603), (0, 0x0610, 0x0615),
        (0, 0x064B, 0x0658), (0, 0x0670, 0x0670), (0, 0x06D6, 0x06E4), (0, 0x06E7, 0x06E8),
        (0, 0x06EA, 0x06ED), (0, 0x070F, 0x070F), (0, 0x0711, 0x0711), (0, 0x0730, 0x074A),
        (0, 0x07A6, 0x07B0), (0, 0x0901, 0x0902), (0, 0x093C, 0x093C), (0, 0x0941, 0x0948),
        (0, 0x094D, 0x094D), (0, 0x0951, 0x0954), (0, 0x0962, 0x0963), (0, 0x0981, 0x0981),
        (0, 0x09BC, 0x09BC), (0, 0x09C1, 0x09C4), (0, 0x09CD, 0x09CD), (0, 0x09E2, 0x09E3),
        (0, 0x0A01, 0x0A02), (0, 0x0A3C, 0x0A3C), (0, 0x0A41, 0x0A42), (0, 0x0A47, 0x0A48),
        (0, 0x0A4B, 0x0A4D), (0, 0x0A70, 0x0A71), (0, 0x0A81, 0x0A82), (0, 0x0ABC, 0x0ABC),
        (0, 0x0AC1, 0x0AC5), (0, 0x0AC7, 0x0AC8), (0, 0x0ACD, 0x0ACD), (0, 0x0AE2, 0x0AE3),
        (0, 0x0B01, 0x0B01), (0, 0x0B3C, 0x0B3C), (0, 0x0B3F, 0x0B3F), (0, 0x0B41, 0x0B43),
        (0, 0x0B4D, 0x0B4D), (0, 0x0B56, 0x0B56), (0, 0x0B82, 0x0B82), (0, 0x0BC0, 0x0BC0),
        (0, 0x0BCD, 0x0BCD), (0, 0x0C3E, 0x0C40), (0, 0x0C46, 0x0C48), (0, 0x0C4A, 0x0C4D),
        (0, 0x0C55, 0x0C56), (0, 0x0CBC, 0x0CBC), (0, 0x0CBF, 0x0CBF), (0, 0x0CC6, 0x0CC6),
        (0, 0x0CCC, 0x0CCD), (0, 0x0D41, 0x0D43), (0, 0x0D4D, 0x0D4D), (0, 0x0DCA, 0x0DCA),
        (0, 0x0DD2, 0x0DD4), (0, 0x0DD6, 0x0DD6), (0, 0x0E31, 0x0E31), (0, 0x0E34, 0x0E3A),
        (0, 0x0E47, 0x0E4E), (0, 0x0EB1, 0x0EB1), (0, 0x0EB4, 0x0EB9), (0, 0x0EBB, 0x0EBC),
        (0, 0x0EC8, 0x0ECD), (0, 0x0F18, 0x0F19), (0, 0x0F35, 0x0F35), (0, 0x0F37, 0x0F37),
        (0, 0x0F39, 0x0F39), (0, 0x0F71, 0x0F7E), (0, 0x0F80, 0x0F84), (0, 0x0F86, 0x0F87),
        (0, 0x0F90, 0x0F97), (0, 0x0F99, 0x0FBC), (0, 0x0FC6, 0x0FC6), (0, 0x102D, 0x1030),
        (0, 0x1032, 0x1032), (0, 0x1036, 0x1037), (0, 0x1039, 0x1039), (0, 0x1058, 0x1059),
        (1, 0x0000, 0x1100), (2, 0x1100, 0x115F), (0, 0x1160, 0x11FF), (0, 0x1712, 0x1714),
        (0, 0x1732, 0x1734), (0, 0x1752, 0x1753), (0, 0x1772, 0x1773), (0, 0x17B4, 0x17B5),
        (0, 0x17B7, 0x17BD), (0, 0x17C6, 0x17C6), (0, 0x17C9, 0x17D3), (0, 0x17DD, 0x17DD),
        (0, 0x180B, 0x180D), (0, 0x18A9, 0x18A9), (0, 0x1920, 0x1922), (0, 0x1927, 0x1928),
        (0, 0x1932, 0x1932), (0, 0x1939, 0x193B), (0, 0x200B, 0x200F), (0, 0x202A, 0x202E),
        (0, 0x2060, 0x2063), (0, 0x206A, 0x206F), (0, 0x20D0, 0x20EA), (2, 0x2329, 0x232A),
        (0, 0x302A, 0x302F), (2, 0x2E80, 0x303E), (0, 0x3099, 0x309A), (2, 0x3040, 0xA4CF),
        (2, 0xAC00, 0xD7A3), (2, 0xF900, 0xFAFF), (0, 0xFB1E, 0xFB1E), (0, 0xFE00, 0xFE0F),
        (0, 0xFE20, 0xFE23), (2, 0xFE30, 0xFE6F), (0, 0xFEFF, 0xFEFF), (2, 0xFF00, 0xFF60),
        (2, 0xFFE0, 0xFFE6), (0, 0xFFF9, 0xFFFB), (0, 0x1D167, 0x1D169), (0, 0x1D173, 0x1D182),
        (0, 0x1D185, 0x1D18B), (0, 0x1D1AA, 0x1D1AD), (2, 0x20000, 0x2FFFD), (2, 0x30000, 0x3FFFD),
        (0, 0xE0001, 0xE0001), (0, 0xE0020, 0xE007F), (0, 0xE0100, 0xE01EF),
    ]

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

    // MARK: - Display width (18.6.2)

    /// ANS XC-WIDTH — monospace display columns for one xchar (default 1).
    func xcDisplayWidth(of codePoint: UInt32) -> Int {
        for range in Self.xcWidthRanges where codePoint >= range.first && codePoint <= range.last {
            return range.width
        }
        return 1
    }

    /// ANS X-WIDTH — sum of XC-WIDTH over a bounded UTF-8 xchar string.
    func xWidth(xcAddr: Int, u1: Int) throws -> Int {
        if u1 <= 0 { return 0 }
        var total = 0
        var addr = xcAddr
        let end = xcAddr + u1
        while addr < end {
            let decoded = try self.xcDecode(at: addr)
            if decoded.nextAddr > end {
                throw TZForthXCharError.malformed
            }
            total += self.xcDisplayWidth(of: UInt32(truncatingIfNeeded: decoded.codePoint))
            addr = decoded.nextAddr
        }
        return total
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

        _ = register("XC-WIDTH") {
            let cp = self.xcharCodePointFromStack(self.pop())
            do {
                _ = try self.xcEncodedSize(of: cp)
                self.push(Cell(self.xcDisplayWidth(of: cp)))
            } catch {
                self.throwMalformedXchar()
            }
        }

        _ = register("X-WIDTH") {
            let u1 = Int(self.pop())
            let xcAddr = Int(self.pop())
            do {
                self.push(Cell(try self.xWidth(xcAddr: xcAddr, u1: u1)))
            } catch {
                self.throwMalformedXchar()
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