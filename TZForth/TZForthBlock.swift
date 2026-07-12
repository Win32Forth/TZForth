//
//  TZForthBlock.swift
//  TZForth
//
//  ANS Block word set + TZForth .blk file extensions.
//

import Foundation

extension TZForth {

    // MARK: - Boot / settings

    func captureVariableDataAddr(named name: String) -> Cell {
        let hdr = self.findWord(name)
        guard hdr != 0 else { return 0 }
        let cfa = self.getCFA(hdr)
        guard self.readCell(Int(cfa)) == self.docolID,
              self.readCell(Int(cfa) + 8) == self.litID else { return 0 }
        return self.readCell(Int(cfa) + 16)
    }

    func initializeBlockVariablesFromSettings() {
        self.blockSizeVarAddr = self.captureVariableDataAddr(named: "BLOCK-SIZE")
        self.defaultBlockCountVarAddr = self.captureVariableDataAddr(named: "DEFAULT-BLOCK-COUNT")
        self.blockBufferCountVarAddr = self.captureVariableDataAddr(named: "BLOCK-BUFFER-COUNT")
        self.blkVarAddr = self.captureVariableDataAddr(named: "BLK")
        self.blockFileVarAddr = self.captureVariableDataAddr(named: "BLOCK-FILE")
        self.scrVarAddr = self.captureVariableDataAddr(named: "SCR")
        if self.blockSizeVarAddr != 0 {
            self.writeCell(self.blockSizeVarAddr, Cell(self.settings.blockSize))
        }
        if self.defaultBlockCountVarAddr != 0 {
            self.writeCell(self.defaultBlockCountVarAddr, Cell(self.settings.defaultBlockCount))
        }
        if self.blockBufferCountVarAddr != 0 {
            self.writeCell(self.blockBufferCountVarAddr, Cell(self.settings.blockBufferCount))
        }
        if self.blockFileVarAddr != 0 {
            self.writeCell(self.blockFileVarAddr, 0)
        }
        if self.blkVarAddr != 0 {
            self.writeCell(self.blkVarAddr, 0)
        }
        if self.scrVarAddr != 0 {
            self.writeCell(self.scrVarAddr, 0)
        }
    }

    func effectiveBlockSize() -> Int {
        if self.blockSizeVarAddr != 0 {
            let v = Int(self.readCell(self.blockSizeVarAddr))
            if v >= 64 { return v }
        }
        return max(64, self.settings.blockSize)
    }

    func effectiveBlockBufferCount() -> Int {
        if self.blockBufferCountVarAddr != 0 {
            let v = Int(self.readCell(self.blockBufferCountVarAddr))
            if v >= 2 { return v }
        }
        return max(2, self.settings.blockBufferCount)
    }

    func effectiveDefaultBlockCount() -> Int {
        if self.defaultBlockCountVarAddr != 0 {
            let v = Int(self.readCell(self.defaultBlockCountVarAddr))
            if v >= 1 { return v }
        }
        return max(1, self.settings.defaultBlockCount)
    }

    func charsPerBlockLine() -> Int {
        max(1, self.effectiveBlockSize() / Self.BLOCK_LINES_PER_BLOCK)
    }

    func resizeBlockBufferSlots() {
        let count = self.effectiveBlockBufferCount()
        if self.blockBufferSlots.count < count {
            let add = count - self.blockBufferSlots.count
            for _ in 0..<add {
                self.blockBufferSlots.append(BlockBufferSlot())
            }
        } else if self.blockBufferSlots.count > count {
            self.blockBufferSlots.removeLast(self.blockBufferSlots.count - count)
        }
        self.invalidateAllBlockBufferSlots()
    }

    func blockSlotAddress(_ index: Int) -> Int {
        self.blockPoolBase + index * self.effectiveBlockSize()
    }

    // MARK: - Registration

    func registerBlockWords() {
        _ = register("BLOCK") {
            let u = Int(self.pop())
            let addr = self.blockFetch(u, updateBLK: false)
            self.push(Cell(addr))
        }

        _ = register("BUFFER") {
            let u = Int(self.pop())
            let addr = self.blockFetch(u, updateBLK: false)
            self.push(Cell(addr))
        }

        _ = register("UPDATE") {
            self.blockMarkCurrentDirty()
        }

        _ = register("FLUSH") {
            self.blockFlushCurrentVolume()
        }

        _ = register("EMPTY-BUFFERS") {
            self.blockEmptyBuffers()
        }

        _ = register("SAVE-BUFFERS") {
            self.blockSaveBuffers()
        }

        _ = register("BLK") {
            self.push(self.blkVarAddr)
        }

        _ = register("SCR") {
            self.push(self.scrVarAddr)
        }

        _ = register("LOAD") {
            let u = Int(self.pop())
            self.blockLoadSingle(u)
        }

        _ = register("LIST") {
            let u = Int(self.pop())
            self.blockList(u)
        }

        _ = register("THRU") {
            let u2 = Int(self.pop())
            let u1 = Int(self.pop())
            self.blockLoadRange(from: u1, to: u2)
        }

        _ = register("\\", immediate: true) {
            self.writeCell(self.IN, Cell(self.currentSourceLen))
            self.inputQueue.removeAll(keepingCapacity: true)
            self.inputQueue.append(10)
        }

        _ = register("CREATE-BLOCK-FILE") {
            let nBlocks = Int(self.pop())
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            let (bid, ior) = self.createBlockFileCounted(caddr: caddr, u: u, blockCount: nBlocks)
            self.push(bid)
            self.push(ior)
        }

        _ = register("OPEN-BLOCK-FILE") {
            let u = Int(self.pop())
            let caddr = Int(self.pop())
            let (bid, ior) = self.openBlockFileCounted(caddr: caddr, u: u)
            self.push(bid)
            self.push(ior)
        }

        _ = register("CLOSE-BLOCK-FILE") {
            let bid = Int(self.pop())
            self.push(self.closeBlockFile(bid))
        }

        _ = register("GROW-BLOCK-FILE") {
            let nAdd = Int(self.pop())
            let bid = Int(self.pop())
            self.push(self.growBlockFile(bid, addBlocks: nAdd))
        }

        _ = register("USE-BLOCK-FILE") {
            let bid = Int(self.pop())
            self.useBlockFile(bid)
        }

        _ = register("BLOCK-FILE") {
            self.push(self.blockFileVarAddr)
        }

        _ = register(".BLOCK-FILES") {
            self.blockListOpenFiles()
        }

        _ = register(".SETTINGS") {
            self.printSettings()
        }

        _ = register("SAVE-SETTINGS") {
            self.saveSettingsFromVariables()
        }
    }

    // MARK: - Volume management

    func normalizedBlockPath(_ spec: String) -> String {
        var path = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.lowercased().hasSuffix(".blk") {
            path += ".blk"
        }
        return path
    }

    func ensureCurrentBlockFile() {
        let current = Int(self.readCell(self.blockFileVarAddr))
        if current != 0, var entry = self.openBlockFiles[current], entry.isOpen {
            _ = entry
            return
        }
        let spec = self.settings.defaultBlocksFileName
        let url = self.resolvedURL(for: spec)
        if FileManager.default.fileExists(atPath: url.path) {
            let (bid, ior) = self.openBlockFileAtPath(url.path)
            if ior == self.FILE_IO_SUCCESS {
                self.useBlockFile(Int(bid))
            }
        } else {
            let (bid, ior) = self.createBlockFileAtPath(url.path, blockCount: self.effectiveDefaultBlockCount())
            if ior == self.FILE_IO_SUCCESS {
                self.useBlockFile(Int(bid))
            }
        }
    }

    func currentBlockFileId() -> Int {
        Int(self.readCell(self.blockFileVarAddr))
    }

    func useBlockFile(_ bid: Int) {
        guard var entry = self.openBlockFiles[bid], entry.isOpen else {
            self.throwInvalidFileId("? USE-BLOCK-FILE: invalid block file")
            return
        }
        let prev = self.currentBlockFileId()
        if prev != 0 && prev != bid {
            self.blockFlushVolume(fileId: prev, toDisk: true)
        }
        self.writeCell(self.blockFileVarAddr, Cell(bid))
        _ = entry
    }

    func createBlockFileCounted(caddr: Int, u: Int, blockCount: Int) -> (Cell, Cell) {
        let spec = self.stringFromAddr(caddr, u)
        let path = self.normalizedBlockPath(spec)
        let url = self.pathURLFromCounted(caddr, u)
        let resolved = self.resolvedURL(for: path)
        return self.createBlockFileAtPath(resolved.path, blockCount: max(1, blockCount))
    }

    func createBlockFileAtPath(_ path: String, blockCount: Int) -> (Cell, Cell) {
        let bs = self.effectiveBlockSize()
        let total = bs * max(1, blockCount)
        let data = Data(repeating: 0, count: total)
        do {
            let url = URL(fileURLWithPath: path)
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            return (0, self.FILE_IO_ERROR)
        }
        let bid = self.nextBlockFileId
        self.nextBlockFileId += 1
        self.openBlockFiles[bid] = BlockFileEntry(
            path: path,
            blockSize: bs,
            blockCount: max(1, blockCount),
            data: data,
            isOpen: true,
            writeDirty: false
        )
        return (Cell(bid), self.FILE_IO_SUCCESS)
    }

    func openBlockFileCounted(caddr: Int, u: Int) -> (Cell, Cell) {
        let spec = self.stringFromAddr(caddr, u)
        let path = self.normalizedBlockPath(spec)
        let url = self.resolvedURL(for: path)
        return self.openBlockFileAtPath(url.path)
    }

    func openBlockFileAtPath(_ path: String) -> (Cell, Cell) {
        let bs = self.effectiveBlockSize()
        guard FileManager.default.fileExists(atPath: path) else {
            return (0, self.FILE_IO_ERROR)
        }
        do {
            var data = try Data(contentsOf: URL(fileURLWithPath: path))
            if data.count % bs != 0 {
                return (0, self.FILE_IO_ERROR)
            }
            let count = data.count / bs
            if count == 0 {
                return (0, self.FILE_IO_ERROR)
            }
            if let existing = self.openBlockFiles.first(where: { $0.value.path == path && $0.value.isOpen }) {
                return (Cell(existing.key), self.FILE_IO_SUCCESS)
            }
            let bid = self.nextBlockFileId
            self.nextBlockFileId += 1
            self.openBlockFiles[bid] = BlockFileEntry(
                path: path,
                blockSize: bs,
                blockCount: count,
                data: data,
                isOpen: true,
                writeDirty: false
            )
            return (Cell(bid), self.FILE_IO_SUCCESS)
        } catch {
            return (0, self.FILE_IO_ERROR)
        }
    }

    func closeBlockFile(_ bid: Int) -> Cell {
        guard var entry = self.openBlockFiles[bid] else {
            return self.FILE_IO_ERROR
        }
        if entry.isOpen {
            self.blockFlushVolume(fileId: bid, toDisk: true)
            entry.isOpen = false
            self.openBlockFiles[bid] = entry
        }
        self.invalidateBlockBufferSlots(for: bid)
        if self.currentBlockFileId() == bid {
            self.writeCell(self.blockFileVarAddr, 0)
        }
        return self.FILE_IO_SUCCESS
    }

    func growBlockFile(_ bid: Int, addBlocks: Int) -> Cell {
        guard addBlocks >= 0, var entry = self.openBlockFiles[bid], entry.isOpen else {
            return self.FILE_IO_ERROR
        }
        let bs = entry.blockSize
        let addBytes = bs * addBlocks
        if addBytes > 0 {
            entry.data.append(contentsOf: repeatElement(UInt8(0), count: addBytes))
            entry.blockCount += addBlocks
            entry.writeDirty = true
            self.openBlockFiles[bid] = entry
            self.blockFlushVolume(fileId: bid, toDisk: true)
        }
        return self.FILE_IO_SUCCESS
    }

    // MARK: - Buffer cache

    func invalidateAllBlockBufferSlots() {
        for i in 0..<self.blockBufferSlots.count {
            self.blockBufferSlots[i].blockNum = -1
            self.blockBufferSlots[i].blockFileId = -1
            self.blockBufferSlots[i].dirty = false
        }
    }

    func invalidateBlockBufferSlots(for bid: Int) {
        for i in 0..<self.blockBufferSlots.count {
            if self.blockBufferSlots[i].blockFileId == bid {
                self.blockBufferSlots[i].blockNum = -1
                self.blockBufferSlots[i].blockFileId = -1
                self.blockBufferSlots[i].dirty = false
            }
        }
    }

    func blockFetch(_ blockNum: Int, updateBLK: Bool = false) -> Int {
        self.ensureCurrentBlockFile()
        let bid = self.currentBlockFileId()
        guard let entry = self.openBlockFiles[bid], entry.isOpen else {
            self.throwInvalidFileId("? BLOCK: no current block file")
            return self.blockPoolBase
        }
        if blockNum < 0 || blockNum >= entry.blockCount {
            self.throwInvalidFileId("? BLOCK: block out of range")
            return self.blockPoolBase
        }
        self.lastBlockAccessNum = blockNum
        self.lastBlockAccessFileId = bid
        if updateBLK, self.blkVarAddr != 0 {
            self.writeCell(self.blkVarAddr, Cell(blockNum))
        }
        let bs = entry.blockSize
        if let idx = self.blockBufferSlots.firstIndex(where: { $0.blockFileId == bid && $0.blockNum == blockNum }) {
            self.blockCacheSequence += 1
            self.blockBufferSlots[idx].lastUsed = self.blockCacheSequence
            self.lastBlockAccessSlotIndex = idx
            return self.blockSlotAddress(idx)
        }
        let slot = self.allocateBlockBufferSlot(bid: bid, blockNum: blockNum)
        let addr = self.blockSlotAddress(slot)
        let src = blockNum * bs
        for i in 0..<bs {
            self.writeByte(addr + i, entry.data[src + i])
        }
        self.blockBufferSlots[slot].blockFileId = bid
        self.blockBufferSlots[slot].blockNum = blockNum
        self.blockBufferSlots[slot].dirty = false
        self.blockCacheSequence += 1
        self.blockBufferSlots[slot].lastUsed = self.blockCacheSequence
        self.lastBlockAccessSlotIndex = slot
        return addr
    }

    func allocateBlockBufferSlot(bid: Int, blockNum: Int) -> Int {
        if let free = self.blockBufferSlots.firstIndex(where: { $0.blockFileId < 0 }) {
            return free
        }
        var lru = 0
        var minUsed = UInt64.max
        for i in 0..<self.blockBufferSlots.count {
            if self.blockBufferSlots[i].lastUsed < minUsed {
                minUsed = self.blockBufferSlots[i].lastUsed
                lru = i
            }
        }
        self.evictBlockSlot(lru)
        return lru
    }

    func evictBlockSlot(_ index: Int) {
        let slot = self.blockBufferSlots[index]
        if slot.dirty, slot.blockFileId >= 0, slot.blockNum >= 0 {
            self.mergeDirtySlotToMemory(slotIndex: index)
        }
        self.blockBufferSlots[index].blockNum = -1
        self.blockBufferSlots[index].blockFileId = -1
        self.blockBufferSlots[index].dirty = false
    }

    func blockMarkCurrentDirty() {
        var idx = self.lastBlockAccessSlotIndex
        if idx < 0 || idx >= self.blockBufferSlots.count {
            let bid = self.lastBlockAccessFileId
            let blk = self.lastBlockAccessNum
            guard bid >= 0, blk >= 0,
                  let found = self.blockBufferSlots.firstIndex(where: { $0.blockFileId == bid && $0.blockNum == blk }) else {
                return
            }
            idx = found
        }
        self.blockBufferSlots[idx].dirty = true
    }

    func mergeDirtySlotToMemory(slotIndex: Int) {
        let slot = self.blockBufferSlots[slotIndex]
        guard slot.blockFileId >= 0, slot.blockNum >= 0,
              var entry = self.openBlockFiles[slot.blockFileId], entry.isOpen else { return }
        let bs = entry.blockSize
        let dst = slot.blockNum * bs
        let addr = self.blockSlotAddress(slotIndex)
        if dst + bs <= entry.data.count {
            for i in 0..<bs {
                entry.data[dst + i] = self.readByte(addr + i)
            }
            entry.writeDirty = true
            self.openBlockFiles[slot.blockFileId] = entry
        }
        self.blockBufferSlots[slotIndex].dirty = false
    }

    func blockSaveBuffers() {
        let bid = self.currentBlockFileId()
        if bid == 0 { return }
        for i in 0..<self.blockBufferSlots.count {
            if self.blockBufferSlots[i].dirty && self.blockBufferSlots[i].blockFileId == bid {
                self.mergeDirtySlotToMemory(slotIndex: i)
            }
        }
    }

    func blockFlushVolume(fileId bid: Int, toDisk: Bool) {
        guard self.openBlockFiles[bid]?.isOpen == true else { return }
        for i in 0..<self.blockBufferSlots.count {
            if self.blockBufferSlots[i].dirty && self.blockBufferSlots[i].blockFileId == bid {
                self.mergeDirtySlotToMemory(slotIndex: i)
            }
        }
        guard var entry = self.openBlockFiles[bid], entry.isOpen else { return }
        if toDisk {
            if entry.writeDirty {
                do {
                    try entry.data.write(to: URL(fileURLWithPath: entry.path), options: .atomic)
                    entry.writeDirty = false
                    self.openBlockFiles[bid] = entry
                } catch {
                    self.tell("? block flush failed: \(entry.path)\n")
                }
            }
            self.invalidateBlockBufferSlots(for: bid)
        }
    }

    func blockFlushCurrentVolume() {
        let bid = self.currentBlockFileId()
        if bid == 0 {
            self.ensureCurrentBlockFile()
        }
        let current = self.currentBlockFileId()
        if current != 0 {
            self.blockFlushVolume(fileId: current, toDisk: true)
        }
    }

    func blockEmptyBuffers() {
        self.invalidateAllBlockBufferSlots()
    }

    func shutdownBlockSubsystem() {
        for (bid, entry) in self.openBlockFiles where entry.isOpen {
            self.blockFlushVolume(fileId: bid, toDisk: true)
            var e = entry
            e.isOpen = false
            self.openBlockFiles[bid] = e
        }
        self.invalidateAllBlockBufferSlots()
        if self.blockFileVarAddr != 0 {
            self.writeCell(self.blockFileVarAddr, 0)
        }
    }

    // MARK: - LIST / LOAD

    func blockList(_ u: Int) {
        let addr = self.blockFetch(u, updateBLK: false)
        let cpl = self.charsPerBlockLine()
        var out = ""
        for line in 0..<Self.BLOCK_LINES_PER_BLOCK {
            var lineText = ""
            for col in 0..<cpl {
                let ch = self.readByte(addr + line * cpl + col)
                if ch >= 32 && ch < 127 {
                    lineText.append(Character(UnicodeScalar(ch)))
                } else if ch == 0 {
                    lineText.append(" ")
                } else {
                    lineText.append(Character(UnicodeScalar(ch)))
                }
            }
            out += lineText + "\n"
        }
        self.tell(out)
        if self.scrVarAddr != 0 {
            self.writeCell(self.scrVarAddr, Cell(u))
        }
    }

    func blockLoadSingle(_ u: Int) {
        self.blockLoadRange(from: u, to: u)
    }

    func blockLoadRange(from u1: Int, to u2: Int) {
        self.ensureCurrentBlockFile()
        let bid = self.currentBlockFileId()
        guard self.openBlockFiles[bid]?.isOpen == true else { return }
        let start = min(u1, u2)
        let end = max(u1, u2)
        let savedBlk: Cell = self.blkVarAddr != 0 ? self.readCell(self.blkVarAddr) : 0
        self.pushInputSourceFrame()
        self.blockInterpretActive = true
        self.blockInterpretFileId = bid
        self.blockInterpretBlockNum = start
        self.blockInterpretEndBlock = end
        self.blockInterpretStopBlock = end
        let spillAllowed = start == end && self.blockLoadDepth == 0
        self.blockRefillMaxBlock = spillAllowed ? end + 1 : end
        self.blockInterpretLine = 0
        self.currentSourceId = Self.BLOCK_SOURCE_ID
        self.loadNesting += 1
        self.blockLoadDepth += 1
        self.sourceLoadStop = false
        defer {
            self.blockInterpretActive = false
            self.blockRestoreResumeTail = []
            self.blockRestoreResumeBlock = -1
            self.blockRestoreResumeLine = -1
            if self.blockLoadDepth > 0 { self.blockLoadDepth -= 1 }
            if self.loadNesting > 0 { self.loadNesting -= 1 }
            self.popInputSourceFrame()
            self.sourceLoadStop = false
            if self.blkVarAddr != 0 {
                self.writeCell(self.blkVarAddr, savedBlk)
            }
        }
        while self.refillFromBlockSource() {
            self.validateAndRepairSystemState()
            self.runInterpreter()
            if self.errorFlag || self.throwActive || self.sourceLoadStop { break }
        }
    }

    func blockLineBytes(blockNum: Int, line: Int) -> [UInt8] {
        let addr = self.blockFetch(blockNum, updateBLK: false)
        let cpl = self.charsPerBlockLine()
        let offset = line * cpl
        var bytes: [UInt8] = []
        for i in 0..<cpl {
            bytes.append(self.readByte(addr + offset + i))
        }
        return bytes
    }

    func blockLineTailAfterToken(blockNum: Int, line: Int, token: String) -> [UInt8] {
        let lineBytes = self.blockLineBytes(blockNum: blockNum, line: line)
        guard let tokenBytes = token.data(using: .ascii), !tokenBytes.isEmpty else { return [] }
        let t = Array(tokenBytes)
        let limit = lineBytes.count - t.count
        if limit < 0 { return [] }
        var start = -1
        for i in 0...limit {
            var matched = true
            for j in 0..<t.count where matched {
                if lineBytes[i + j] != t[j] { matched = false }
            }
            if matched { start = i + t.count }
        }
        guard start >= 0, start < lineBytes.count else { return [] }
        var tail: [UInt8] = []
        for i in start..<lineBytes.count {
            let ch = lineBytes[i]
            if ch == 0 { break }
            tail.append(ch)
        }
        return tail
    }

    /// Advance past SAVE-INPUT when the save point is on that token (Hayes block restore must not re-run it).
    func skipSaveInputTokenIfPresent(in bytes: [UInt8], from pos: Int) -> Int {
        let clamped = max(0, min(pos, bytes.count))
        var p = clamped
        while p < bytes.count && bytes[p] <= 32 { p += 1 }
        let needle = Array("SAVE-INPUT".utf8)
        var matched = !needle.isEmpty
        for k in 0..<needle.count where matched {
            if p + k >= bytes.count || bytes[p + k] != needle[k] { matched = false }
        }
        if matched {
            return p + needle.count
        }
        return clamped
    }

    /// Prefix through the MARK immediate before `' RESTORE-INPUT` on a block line (e.g. ` MARK C`).
    func blockLineMarkBeforeQuotedRestore(blockNum: Int, line: Int) -> [UInt8] {
        let lineBytes = self.blockLineBytes(blockNum: blockNum, line: line)
        let needle = Array("RESTORE-INPUT".utf8)
        var restoreStart = -1
        for i in 0..<lineBytes.count where restoreStart < 0 {
            if lineBytes[i] == 39 { // '
                var j = i + 1
                while j < lineBytes.count && lineBytes[j] <= 32 { j += 1 }
                var matched = true
                for k in 0..<needle.count where matched {
                    if j + k >= lineBytes.count || lineBytes[j + k] != needle[k] { matched = false }
                }
                if matched { restoreStart = i }
            }
        }
        guard restoreStart > 0 else { return [] }
        let markNeedle = Array("MARK".utf8)
        var markStart = -1
        for i in stride(from: restoreStart - 1, through: 0, by: -1) where markStart < 0 {
            if i + markNeedle.count <= restoreStart {
                var matched = true
                for k in 0..<markNeedle.count where matched {
                    if lineBytes[i + k] != markNeedle[k] { matched = false }
                }
                if matched {
                    var start = i
                    while start > 0 && lineBytes[start - 1] > 32 { start -= 1 }
                    if start > 0 && lineBytes[start - 1] <= 32 { start -= 1 }
                    markStart = start
                }
            }
        }
        guard markStart >= 0 else { return [] }
        var end = markStart
        while end < restoreStart && lineBytes[end] <= 32 { end += 1 }
        while end < restoreStart && lineBytes[end] > 32 { end += 1 }
        while end < restoreStart && lineBytes[end] <= 32 { end += 1 }
        if end < restoreStart && lineBytes[end] > 32 { end += 1 }
        return Array(lineBytes[markStart..<end])
    }

    /// Hayes TCSIRIR2/4: replay pictured MARK before RESTORE plus tail after ?EXECUTE.
    func blockRestoreContinuationTail(blockNum: Int, line: Int) -> [UInt8] {
        var tail = self.blockLineMarkBeforeQuotedRestore(blockNum: blockNum, line: line)
        let afterExecute = self.blockLineTailAfterToken(blockNum: blockNum, line: line, token: "?EXECUTE")
        if !afterExecute.isEmpty {
            if !tail.isEmpty { tail.append(32) }
            tail.append(contentsOf: afterExecute)
        }
        return tail
    }

    /// Non-blank block lines after `afterLine` on the same block (Hayes TCSIRIR4 cross-block restore).
    func blockIntermediateLinesAfter(blockNum: Int, afterLine: Int) -> [UInt8] {
        var combined: [UInt8] = []
        for line in (afterLine + 1)..<Self.BLOCK_LINES_PER_BLOCK {
            if self.blockLineIsBlank(blockNum: blockNum, line: line) { continue }
            let bytes = self.blockLineBytes(blockNum: blockNum, line: line)
            var len = bytes.count
            while len > 0 && bytes[len - 1] <= 32 { len -= 1 }
            var start = 0
            while start < len && bytes[start] <= 32 { start += 1 }
            guard start < len else { continue }
            if !combined.isEmpty { combined.append(32) }
            combined.append(contentsOf: bytes[start..<len])
        }
        return combined
    }

    func blockLineIsBlank(blockNum: Int, line: Int) -> Bool {
        let addr = self.blockFetch(blockNum, updateBLK: false)
        let cpl = self.charsPerBlockLine()
        let offset = line * cpl
        for i in 0..<cpl {
            let ch = self.readByte(addr + offset + i)
            if ch > 32 { return false }
        }
        return true
    }

    func refillFromBlockSource() -> Bool {
        guard self.blockInterpretActive else { return false }
        let cpl = self.charsPerBlockLine()
        // Single-block LOAD may REFILL-spill into end+1; only extend range after spill advanced there.
        let maxBlock: Int
        if self.blockRefillInProgress {
            maxBlock = self.blockRefillMaxBlock
        } else if self.blockInterpretBlockNum > self.blockInterpretStopBlock {
            maxBlock = self.blockRefillMaxBlock
        } else {
            maxBlock = self.blockInterpretStopBlock
        }
        while self.blockInterpretBlockNum <= maxBlock {
            if self.blockInterpretLine < Self.BLOCK_LINES_PER_BLOCK {
                if self.blockRefillInProgress {
                    while self.blockInterpretLine < Self.BLOCK_LINES_PER_BLOCK,
                          self.blockLineIsBlank(blockNum: self.blockInterpretBlockNum, line: self.blockInterpretLine) {
                        self.blockInterpretLine += 1
                    }
                    if self.blockInterpretLine >= Self.BLOCK_LINES_PER_BLOCK {
                        self.blockInterpretBlockNum += 1
                        self.blockInterpretLine = 0
                        if self.blockInterpretBlockNum > maxBlock { return false }
                        continue
                    }
                }
                if !self.blockRestoreResumeTail.isEmpty,
                   self.blockInterpretBlockNum == self.blockRestoreResumeBlock,
                   self.blockInterpretLine == self.blockRestoreResumeLine {
                    var tail = self.blockRestoreResumeTail
                    self.blockRestoreResumeTail = []
                    self.blockRestoreResumeBlock = -1
                    self.blockRestoreResumeLine = -1
                    var len = tail.count
                    while len > 0 && tail[len - 1] <= 32 { len -= 1 }
                    var trimStart = 0
                    while trimStart < len && tail[trimStart] <= 32 { trimStart += 1 }
                    len -= trimStart
                    self.currentSourceLen = len
                    for i in 0..<len {
                        self.writeByte(self.SOURCE_BUFFER + i, tail[trimStart + i])
                    }
                    self.writeCell(self.IN, 0)
                    self.realignBlockInputQueueFromSource()
                    self.blockInterpretLine += 1
                    return true
                }
                let addr = self.blockFetch(self.blockInterpretBlockNum, updateBLK: true)
                let offset = self.blockInterpretLine * cpl
                self.currentSourceLen = min(cpl, self.effectiveBlockSize() - offset)
                for i in 0..<self.currentSourceLen {
                    self.writeByte(self.SOURCE_BUFFER + i, self.readByte(addr + offset + i))
                }
                self.writeCell(self.IN, 0)
                self.realignBlockInputQueueFromSource()
                self.blockInterpretLine += 1
                return true
            }
            self.blockInterpretBlockNum += 1
            self.blockInterpretLine = 0
        }
        return false
    }

    func realignBlockInputQueueFromSource() {
        let pos = Int(self.clampInOffset(self.readCell(self.IN)))
        self.inputQueue.removeAll(keepingCapacity: true)
        guard pos < self.currentSourceLen else { return }
        for i in pos..<self.currentSourceLen {
            self.inputQueue.append(self.readByte(self.SOURCE_BUFFER + i))
        }
    }

    // MARK: - Settings words

    func printSettings() {
        let bs = self.effectiveBlockSize()
        let bufCount = self.effectiveBlockBufferCount()
        let defBlocks = self.effectiveDefaultBlockCount()
        let memMB = self.memory.count / (1024 * 1024)
        self.tell("TZForth settings (session / persisted):\n")
        self.tell("  BLOCK-SIZE @           = \(bs) (restart to resize pool)\n")
        self.tell("  BLOCK-BUFFER-COUNT @   = \(bufCount) (restart to resize pool)\n")
        self.tell("  DEFAULT-BLOCK-COUNT @  = \(defBlocks)\n")
        self.tell("  memory bytes           = \(self.memory.count) (\(memMB) MB)\n")
        self.tell("  default blocks file    = \(self.settings.defaultBlocksFileName)\n")
        self.tell("  block pool base        = \(self.blockPoolBase)\n")
        self.tell("  current BLOCK-FILE @   = \(self.currentBlockFileId())\n")
    }

    func saveSettingsFromVariables() {
        var s = self.settings
        if self.blockSizeVarAddr != 0 {
            s.blockSize = max(64, Int(self.readCell(self.blockSizeVarAddr)))
        }
        if self.blockBufferCountVarAddr != 0 {
            s.blockBufferCount = max(2, Int(self.readCell(self.blockBufferCountVarAddr)))
        }
        if self.defaultBlockCountVarAddr != 0 {
            s.defaultBlockCount = max(1, Int(self.readCell(self.defaultBlockCountVarAddr)))
        }
        s.defaultMemoryMB = max(1, self.memory.count / (1024 * 1024))
        do {
            try s.save()
            self.settings = s
            self.tell("Settings saved. Restart TZForth for BLOCK-SIZE / BLOCK-BUFFER-COUNT / memory changes.\n")
        } catch {
            self.tell("? SAVE-SETTINGS failed: \(error.localizedDescription)\n")
        }
    }

    func blockListOpenFiles() {
        if self.openBlockFiles.isEmpty {
            self.tell("(no open block files)\n")
            return
        }
        for (bid, entry) in self.openBlockFiles.sorted(by: { $0.key < $1.key }) {
            let state = entry.isOpen ? "open" : "closed"
            self.tell("  \(bid): \(entry.path)  \(entry.blockCount) blocks  \(state)\n")
        }
    }
}