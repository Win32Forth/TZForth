//
//  TZForthBigInt.swift
//  TZForth
//
//  Host multiprecision helpers for the BIG-INTEGER vocabulary.
//  Layout matches lib/big-int.fth (base 10^9 limbs). Not an ANS word set.
//

import Foundation

extension TZForth {

    /// Base 1e9 — same as `BI-BASE` in lib/big-int.fth.
    private static let biBase: Int64 = 1_000_000_000

    // MARK: - Layout accessors (ALLOCATE block: cap, len, sign, limbs…)

    private func biCap(_ bi: Int) -> Int { Int(self.readCell(bi)) }
    private func biLen(_ bi: Int) -> Int { Int(self.readCell(bi + self.CELL_SIZE)) }
    private func biSgn(_ bi: Int) -> Int {
        let s = Int(self.readCell(bi + 2 * self.CELL_SIZE))
        return s < 0 ? -1 : 1
    }
    private func biLimbAddr(_ bi: Int, _ i: Int) -> Int {
        bi + 3 * self.CELL_SIZE + i * self.CELL_SIZE
    }

    private func biSetLen(_ bi: Int, _ n: Int) {
        self.writeCell(bi + self.CELL_SIZE, Cell(max(0, n)))
    }

    private func biSetSgn(_ bi: Int, _ s: Int) {
        self.writeCell(bi + 2 * self.CELL_SIZE, Cell(s < 0 ? -1 : 1))
    }

    private func biReadLimbs(_ bi: Int) -> (sign: Int, limbs: [Int64]) {
        let n = self.biLen(bi)
        if n <= 0 { return (1, []) }
        var limbs = [Int64]()
        limbs.reserveCapacity(n)
        for i in 0..<n {
            limbs.append(Int64(self.readCell(self.biLimbAddr(bi, i))))
        }
        while limbs.last == 0 { limbs.removeLast() }
        if limbs.isEmpty { return (1, []) }
        return (self.biSgn(bi), limbs)
    }

    private func biWriteLimbs(_ bi: Int, sign: Int, limbs: [Int64]) {
        var ls = limbs
        while ls.last == 0 { ls.removeLast() }
        if ls.isEmpty {
            self.biSetLen(bi, 0)
            self.biSetSgn(bi, 1)
            return
        }
        let cap = self.biCap(bi)
        if ls.count > cap {
            self.kernelThrow(StdThrow.invalidAddress, message: "? BI capacity exceeded (need \(ls.count), cap \(cap))")
            return
        }
        for i in 0..<ls.count {
            self.writeCell(self.biLimbAddr(bi, i), Cell(ls[i]))
        }
        self.biSetLen(bi, ls.count)
        self.biSetSgn(bi, sign < 0 ? -1 : 1)
    }

    // MARK: - Limb arithmetic

    private func biMulLimbs(_ a: [Int64], _ b: [Int64]) -> [Int64] {
        if a.isEmpty || b.isEmpty { return [] }
        var c = [Int64](repeating: 0, count: a.count + b.count)
        let base = Self.biBase
        for i in 0..<a.count {
            var carry: Int64 = 0
            for j in 0..<b.count {
                let p = a[i] * b[j] + c[i + j] + carry
                c[i + j] = p % base
                carry = p / base
            }
            var k = i + b.count
            while carry != 0 {
                if k >= c.count { c.append(0) }
                let p = c[k] + carry
                c[k] = p % base
                carry = p / base
                k += 1
            }
        }
        while c.last == 0 { c.removeLast() }
        return c
    }

    private func biCmpAbs(_ a: [Int64], _ b: [Int64]) -> Int {
        if a.count != b.count { return a.count < b.count ? -1 : 1 }
        var i = a.count - 1
        while i >= 0 {
            if a[i] != b[i] { return a[i] < b[i] ? -1 : 1 }
            i -= 1
        }
        return 0
    }

    private func biAddAbs(_ a: [Int64], _ b: [Int64]) -> [Int64] {
        let base = Self.biBase
        let n = max(a.count, b.count)
        var c = [Int64](repeating: 0, count: n + 1)
        var carry: Int64 = 0
        for i in 0..<n {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            let s = av + bv + carry
            c[i] = s % base
            carry = s / base
        }
        c[n] = carry
        while c.last == 0 { c.removeLast() }
        return c
    }

    private func biSubAbs(_ a: [Int64], _ b: [Int64]) -> [Int64] {
        // Assumes |a| >= |b|
        let base = Self.biBase
        var c = [Int64](repeating: 0, count: a.count)
        var borrow: Int64 = 0
        for i in 0..<a.count {
            let bv = i < b.count ? b[i] : 0
            var d = a[i] - bv - borrow
            if d < 0 {
                d += base
                borrow = 1
            } else {
                borrow = 0
            }
            c[i] = d
        }
        while c.last == 0 { c.removeLast() }
        return c
    }

    /// Multi-limb unsigned division: returns (quotient, remainder).
    private func biDivModLimbs(_ uIn: [Int64], _ vIn: [Int64]) -> (q: [Int64], r: [Int64]) {
        if vIn.isEmpty {
            self.kernelThrow(StdThrow.divisionByZero, message: "? BI-DIVMOD divide by zero")
            return ([], [])
        }
        var u = uIn
        var v = vIn
        while u.last == 0 { u.removeLast() }
        while v.last == 0 { v.removeLast() }
        if u.isEmpty { return ([], []) }
        if self.biCmpAbs(u, v) < 0 { return ([], u) }

        let base = Self.biBase

        // Single-limb divisor
        if v.count == 1 {
            let d = v[0]
            var rem: Int64 = 0
            var q = [Int64](repeating: 0, count: u.count)
            var i = u.count - 1
            while i >= 0 {
                let cur = rem * base + u[i]
                q[i] = cur / d
                rem = cur % d
                i -= 1
            }
            while q.last == 0 { q.removeLast() }
            let r: [Int64] = rem == 0 ? [] : [rem]
            return (q, r)
        }

        // Multi-limb: for each quotient position, binary-search qhat so v*qhat fits the window.
        let n = v.count
        let m = u.count - n
        var uu = u + [Int64(0)]
        var q = [Int64](repeating: 0, count: m + 1)

        func mulSmall(_ x: [Int64], _ k: Int64) -> [Int64] {
            if k == 0 || x.isEmpty { return [] }
            var out = [Int64](repeating: 0, count: x.count + 1)
            var carry: Int64 = 0
            for i in 0..<x.count {
                let p = x[i] * k + carry
                out[i] = p % base
                carry = p / base
            }
            out[x.count] = carry
            while out.last == 0 { out.removeLast() }
            return out
        }

        func window(_ start: Int) -> [Int64] {
            var w = Array(uu[start..<(start + n + 1)])
            while w.last == 0 { w.removeLast() }
            return w
        }

        func subFromWindow(_ prod: [Int64], start: Int) {
            var borrow: Int64 = 0
            for i in 0..<(n + 1) {
                let pv = i < prod.count ? prod[i] : 0
                var d = uu[start + i] - pv - borrow
                if d < 0 {
                    d += base
                    borrow = 1
                } else {
                    borrow = 0
                }
                uu[start + i] = d
            }
        }

        for j in stride(from: m, through: 0, by: -1) {
            var lo: Int64 = 0
            var hi: Int64 = base - 1
            let numHi = uu[j + n] * base + uu[j + n - 1]
            let lead = v[n - 1]
            if lead > 0 {
                hi = min(hi, numHi / lead)
            }
            while lo < hi {
                let mid = (lo + hi + 1) / 2
                let prod = mulSmall(v, mid)
                if self.biCmpAbs(prod, window(j)) <= 0 {
                    lo = mid
                } else {
                    hi = mid - 1
                }
            }
            if lo > 0 {
                subFromWindow(mulSmall(v, lo), start: j)
            }
            q[j] = lo
        }
        while q.last == 0 { q.removeLast() }
        var r = Array(uu.prefix(n + 1))
        while r.last == 0 { r.removeLast() }
        return (q, r)
    }

    private func biIsqrtLimbs(_ a: [Int64]) -> [Int64] {
        if a.isEmpty { return [] }
        if a.count == 1 {
            let r = Int64(Double(a[0]).squareRoot())
            // refine
            var x = r
            while (x + 1) * (x + 1) <= a[0] { x += 1 }
            while x * x > a[0] { x -= 1 }
            return x == 0 ? [] : [x]
        }
        // Newton: x_{n+1} = (x + a/x) / 2
        var x: [Int64]
        // initial: 1 limb shorter than a, top bits from leading
        let initLen = (a.count + 1) / 2
        x = [Int64](repeating: 0, count: initLen)
        x[initLen - 1] = max(1, Int64(Double(a[a.count - 1]).squareRoot()) + 1)
        if x[initLen - 1] >= Self.biBase {
            x[initLen - 1] = Self.biBase - 1
        }

        var prev: [Int64] = []
        var guardCount = 0
        while x != prev && guardCount < 10_000 {
            guardCount += 1
            prev = x
            let (q, _) = self.biDivModLimbs(a, x)
            if self.throwActive { return [] }
            let s = self.biAddAbs(x, q)
            // s / 2
            var carry: Int64 = 0
            var half = [Int64](repeating: 0, count: s.count)
            var i = s.count - 1
            while i >= 0 {
                let cur = carry * Self.biBase + s[i]
                half[i] = cur / 2
                carry = cur % 2
                i -= 1
            }
            while half.last == 0 { half.removeLast() }
            x = half.isEmpty ? [1] : half
            // ensure x^2 does not overshoot forever: if x*x > a, x -= 1 once at end
        }
        // Final adjust
        while true {
            let sq = self.biMulLimbs(x, x)
            if self.biCmpAbs(sq, a) <= 0 {
                let xp = self.biAddAbs(x, [1])
                let sq2 = self.biMulLimbs(xp, xp)
                if self.biCmpAbs(sq2, a) <= 0 {
                    x = xp
                    continue
                }
                break
            } else {
                x = self.biSubAbs(x, [1])
            }
        }
        return x
    }

    // MARK: - Primitives

    private func biPrimMul(a: Int, b: Int, r: Int) {
        let (sa, la) = self.biReadLimbs(a)
        let (sb, lb) = self.biReadLimbs(b)
        let prod = self.biMulLimbs(la, lb)
        self.biWriteLimbs(r, sign: sa * sb, limbs: prod)
    }

    private func biPrimDivMod(num: Int, den: Int, quot: Int, rem: Int) {
        let (sn, ln) = self.biReadLimbs(num)
        let (sd, ld) = self.biReadLimbs(den)
        if ld.isEmpty {
            self.kernelThrow(StdThrow.divisionByZero, message: "? BI-DIVMOD divide by zero")
            return
        }
        if ln.isEmpty {
            self.biWriteLimbs(quot, sign: 1, limbs: [])
            self.biWriteLimbs(rem, sign: 1, limbs: [])
            return
        }
        let (q, r) = self.biDivModLimbs(ln, ld)
        if self.throwActive { return }
        let qs = (q.isEmpty) ? 1 : sn * sd
        let rs = (r.isEmpty) ? 1 : sn
        self.biWriteLimbs(quot, sign: qs, limbs: q)
        self.biWriteLimbs(rem, sign: rs, limbs: r)
    }

    private func biPrimIsqrt(a: Int, r: Int) {
        let (_, la) = self.biReadLimbs(a)
        let root = self.biIsqrtLimbs(la)
        if self.throwActive { return }
        self.biWriteLimbs(r, sign: 1, limbs: root)
    }

    // MARK: - Registration

    /// Install BIG-INTEGER vocabulary host words (layout matches lib/big-int.fth).
    func registerBigIntWords() {
        guard let wid = self.wordlistHead(named: "BIG-INTEGER") else {
            print("WARNING: BIG-INTEGER vocabulary missing; host BI words not installed")
            return
        }

        _ = self.installVocabPrimitive("BI-MUL", wordlist: wid) {
            let r = Int(self.pop())
            let b = Int(self.pop())
            let a = Int(self.pop())
            self.biPrimMul(a: a, b: b, r: r)
        }

        // Stack matches pure-Forth BI-DIVMOD: work is accepted and ignored (host uses its own temps).
        _ = self.installVocabPrimitive("BI-DIVMOD", wordlist: wid) {
            _ = self.pop() // work
            let rem = Int(self.pop())
            let quot = Int(self.pop())
            let den = Int(self.pop())
            let num = Int(self.pop())
            self.biPrimDivMod(num: num, den: den, quot: quot, rem: rem)
        }

        // Stack matches pure-Forth BI-ISQRT: scratch buffers are popped and ignored.
        _ = self.installVocabPrimitive("BI-ISQRT", wordlist: wid) {
            _ = self.pop() // t2
            _ = self.pop() // t1
            _ = self.pop() // work
            _ = self.pop() // rem
            _ = self.pop() // quot
            let r = Int(self.pop())
            let a = Int(self.pop())
            self.biPrimIsqrt(a: a, r: r)
        }
    }
}
