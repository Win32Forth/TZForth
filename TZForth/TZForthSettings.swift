//
//  TZForthSettings.swift
//  TZForth
//
//  Persisted host preferences (block subsystem, memory size, STEP-LIMIT). Loaded before engine init.
//

import Foundation

public struct TZForthSettings: Codable, Equatable {
    public var blockSize: Int = 1024
    public var blockBufferCount: Int = 4
    public var defaultBlockCount: Int = 32
    public var defaultMemoryMB: Int = 1
    public var defaultBlocksFileName: String = "blocks.blk"
    /// Max inner-interpreter steps per run; 0 = unlimited (no runaway guard).
    public var stepLimit: Int = 2_000_000

    public init() {}

    public init(
        blockSize: Int = 1024,
        blockBufferCount: Int = 4,
        defaultBlockCount: Int = 32,
        defaultMemoryMB: Int = 1,
        defaultBlocksFileName: String = "blocks.blk",
        stepLimit: Int = 2_000_000
    ) {
        self.blockSize = blockSize
        self.blockBufferCount = blockBufferCount
        self.defaultBlockCount = defaultBlockCount
        self.defaultMemoryMB = defaultMemoryMB
        self.defaultBlocksFileName = defaultBlocksFileName
        self.stepLimit = stepLimit
    }

    /// Decode with defaults for keys missing from older settings.json files.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        blockSize = try c.decodeIfPresent(Int.self, forKey: .blockSize) ?? 1024
        blockBufferCount = try c.decodeIfPresent(Int.self, forKey: .blockBufferCount) ?? 4
        defaultBlockCount = try c.decodeIfPresent(Int.self, forKey: .defaultBlockCount) ?? 32
        defaultMemoryMB = try c.decodeIfPresent(Int.self, forKey: .defaultMemoryMB) ?? 1
        defaultBlocksFileName = try c.decodeIfPresent(String.self, forKey: .defaultBlocksFileName) ?? "blocks.blk"
        stepLimit = try c.decodeIfPresent(Int.self, forKey: .stepLimit) ?? 2_000_000
    }

    /// Application Support settings file (macOS app); CLI uses the same path when writable.
    public static func storageURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("TZForth", isDirectory: true)
        return dir.appendingPathComponent("settings.json")
    }

    public static func load() -> TZForthSettings {
        let url = storageURL()
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(TZForthSettings.self, from: data)
                return decoded.sanitized()
            } catch {
                // Fall through to defaults
            }
        }
        return TZForthSettings().sanitized()
    }

    public func save() throws {
        let url = Self.storageURL()
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(sanitized())
        try data.write(to: url, options: .atomic)
    }

    func sanitizedForBoot() -> TZForthSettings {
        sanitized()
    }

    private func sanitized() -> TZForthSettings {
        var s = self
        if s.blockSize < 64 { s.blockSize = 64 }
        if s.blockBufferCount < 2 { s.blockBufferCount = 2 }
        if s.defaultBlockCount < 1 { s.defaultBlockCount = 1 }
        if s.defaultMemoryMB < 1 { s.defaultMemoryMB = 1 }
        if s.defaultBlocksFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.defaultBlocksFileName = "blocks.blk"
        }
        // 0 = disabled (unlimited). Negative values are treated as unlimited.
        if s.stepLimit < 0 { s.stepLimit = 0 }
        return s
    }
}