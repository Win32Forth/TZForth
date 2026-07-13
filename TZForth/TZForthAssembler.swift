//
//  TZForthAssembler.swift
//  TZForth
//
//  Minimal ANS Programming-Tools CODE / ;CODE with threaded RET (noop-capable).
//

import Foundation

extension TZForth {

    // MARK: - ASSEMBLER vocab helpers

    /// Word-list head cell for a VOCABULARY/CREATE word (e.g. ASSEMBLER).
    private func wordlistHead(named vocabName: String) -> Cell? {
        let hdr = self.findWord(vocabName)
        if hdr == 0 { return nil }
        let cfa = self.getCFA(hdr)
        let first = self.readCell(Int(cfa))
        if first == self.createRuntimeID {
            return self.readCell(Int(cfa) + 8)
        }
        if first == self.dodoesID {
            // VOCABULARY … DOES> — word-list head cell is the CREATE data field (cfa+16).
            return Cell(Int(cfa) + 16)
        }
        return nil
    }

    private func pushAssemblerSearchOrder() {
        guard let wid = self.wordlistHead(named: "ASSEMBLER") else {
            self.kernelThrow(StdThrow.illegalArgument, message: "? ASSEMBLER vocabulary missing")
            return
        }
        if self.searchOrder.count >= self.MAX_VOCABS {
            self.kernelThrow(StdThrow.illegalArgument, message: "? Search order full")
            return
        }
        self.searchOrder.insert(wid, at: 0)
        self.assemblerSearchPushed = true
    }

    private func popAssemblerSearchOrder() {
        if self.assemblerSearchPushed, !self.searchOrder.isEmpty {
            self.searchOrder.removeFirst()
        }
        self.assemblerSearchPushed = false
    }

    // MARK: - Registration

    func registerAssemblerWords() {
        _ = self.register("CODE") {
            if self.assemblerCompileActive {
                self.kernelThrow(StdThrow.illegalArgument, message: "? CODE already open")
                return
            }
            if self.readCell(self.STATE) != 0 {
                self.kernelThrow(StdThrow.compileOnly, message: "? CODE not allowed while compiling a colon definition")
                return
            }
            let name = self.parseWord()
            if name.isEmpty {
                self.throwZeroLengthName("? CODE needs a name")
                return
            }
            self.createWord(name: name, immediate: false)
            self.writeCellHere(self.codeEntryID)
            let defsHeadCell = self.readCell(self.CURRENT)
            let latest = self.readCell(defsHeadCell)
            self.codeDefinitionHeader = latest
            let fl = self.readByte(Int(latest) + 8)
            self.writeByte(Int(latest) + 8, fl | self.FLAG_HIDDEN)
            self.pushAssemblerSearchOrder()
            self.assemblerCompileActive = true
        }

        _ = self.register(";CODE") {
            if !self.assemblerCompileActive {
                self.kernelThrow(StdThrow.illegalArgument, message: "? ;CODE without CODE")
                return
            }
            let cfa = self.getCFA(self.codeDefinitionHeader)
            let bodyStart = Int(cfa) + 8
            let here = Int(self.readCell(self.DP_ADDR))
            if here == bodyStart {
                self.writeCellHere(self.exitID)
            }
            self.alignHere()
            let fl = self.readByte(Int(self.codeDefinitionHeader) + 8)
            self.writeByte(Int(self.codeDefinitionHeader) + 8, fl & ~self.FLAG_HIDDEN)
            self.popAssemblerSearchOrder()
            self.assemblerCompileActive = false
            self.codeDefinitionHeader = 0
        }

        if let asmWid = self.wordlistHead(named: "ASSEMBLER") {
            _ = self.installVocabPrimitive("RET", wordlist: asmWid) {
                if !self.assemblerCompileActive {
                    self.kernelThrow(StdThrow.illegalArgument, message: "? RET only during CODE")
                    return
                }
                self.writeCellHere(self.exitID)
            }
        }
    }
}