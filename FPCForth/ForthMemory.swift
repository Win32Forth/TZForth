// ForthMemory.swift
//
// Single flat addressable memory buffer for the FPCForth dictionary.
// This buffer holds both headers and code/parameter fields in one
// address space so that addresses formed inside user definitions
// can refer to headers (and vice versa) — classic Forth behavior.
//
// Per current direction:
// - JIT / native code generation is considered a far-future concern.
// - For now we only need a normal data buffer (no executable permissions required).
// - We allocate logical regions inside this buffer for the kernel and user dictionary.

import Foundation

/// A memory address within the ForthMemory buffer.
public typealias Address = Int

/// Represents the single flat data memory for the entire dictionary.
/// Headers and code/parameter fields live together in this buffer.
public final class ForthMemory {

    // MARK: - Storage

    private var storage: [UInt8] = []

    // MARK: - Regions

    /// Describes a contiguous region within the buffer.
    public struct Region {
        public let start: Address
        public private(set) var end: Address   // exclusive

        public var size: Int { end - start }

        fileprivate init(start: Address, end: Address) {
            self.start = start
            self.end = end
        }

        fileprivate mutating func grow(by bytes: Int) {
            end += bytes
        }
    }

    /// Kernel region (core F-PC definitions we are porting).
    /// This includes both headers and their code/parameter fields.
    public private(set) var kernel: Region

    /// User dictionary region (definitions created at runtime).
    /// This also includes both headers and their code/parameter fields.
    public private(set) var user: Region

    // MARK: - Initialization

    public init(initialKernelSize: Int = 64 * 1024,
                initialUserSize: Int   = 256 * 1024) {

        // Reserve space for kernel region first
        let kernelStart = 0
        storage.append(contentsOf: repeatElement(0, count: initialKernelSize))

        let userStart = storage.count
        storage.append(contentsOf: repeatElement(0, count: initialUserSize))

        self.kernel = Region(start: kernelStart, end: storage.count - initialUserSize)
        self.user   = Region(start: userStart,   end: storage.count)
    }

    // MARK: - Basic Access

    public var size: Int {
        storage.count
    }

    public subscript(_ address: Address) -> UInt8 {
        get {
            precondition(address >= 0 && address < storage.count, "Address out of range")
            return storage[address]
        }
        set {
            precondition(address >= 0 && address < storage.count, "Address out of range")
            storage[address] = newValue
        }
    }

    // NOTE: rawBuffer was removed.
    //
    // Exposing the internal [UInt8] storage via UnsafeMutableRawBufferPointer
    // creates a dangling pointer hazard (the compiler correctly warns about this).
    //
    // This class (ForthMemory) is legacy / not the active engine.
    // The current implementation (LBForth) manages its own flat buffer directly.
    //
    // If raw pointer access is ever needed in the future, the storage model
    // should be changed (e.g. to ManagedBuffer or a stable allocation) rather
    // than trying to vend a pointer to a Swift Array.
    //
    // public var rawBuffer: UnsafeMutableRawBufferPointer { ... }


    // MARK: - Allocation within Regions

    /// Allocate space inside the kernel region.
    /// Returns the starting address of the allocated block.
    @discardableResult
    public func allocateInKernel(_ bytes: Int, alignment: Int = 1) -> Address {
        let alignedStart = align(kernel.end, to: alignment)
        let newEnd = alignedStart + bytes

        if newEnd > kernel.start + (user.start - kernel.start) {
            // In a real implementation we would grow the buffer and adjust user region
            fatalError("Kernel region exhausted (simple implementation)")
        }

        // Zero the newly allocated area
        for addr in alignedStart..<newEnd {
            storage[addr] = 0
        }

        kernel.grow(by: newEnd - kernel.end)
        return alignedStart
    }

    /// Allocate space inside the user dictionary region.
    /// Returns the starting address of the allocated block.
    @discardableResult
    public func allocateInUser(_ bytes: Int, alignment: Int = 1) -> Address {
        let alignedStart = align(user.end, to: alignment)
        let newEnd = alignedStart + bytes

        if newEnd > storage.count {
            // Grow the buffer to accommodate user dictionary growth
            let additional = newEnd - storage.count
            storage.append(contentsOf: repeatElement(0, count: additional))
            user.grow(by: additional)
        }

        // Zero the newly allocated area
        for addr in alignedStart..<newEnd {
            storage[addr] = 0
        }

        user.grow(by: newEnd - user.end)
        return alignedStart
    }

    // MARK: - Utilities

    private func align(_ address: Address, to alignment: Int) -> Address {
        guard alignment > 1 else { return address }
        let remainder = address % alignment
        return remainder == 0 ? address : address + (alignment - remainder)
    }

    /// Debug / introspection helper
    public func dumpRegions() {
        print("ForthMemory regions:")
        print("  Kernel: 0x\(String(format: "%04X", kernel.start)) – 0x\(String(format: "%04X", kernel.end)) (size: \(kernel.size))")
        print("  User:   0x\(String(format: "%04X", user.start)) – 0x\(String(format: "%04X", user.end)) (size: \(user.size))")
        print("  Total buffer size: \(size) bytes")
    }
}

// MARK: - Example Usage

/*
let mem = ForthMemory(initialKernelSize: 4096, initialUserSize: 8192)

// Allocate some space for a kernel header + its code field
let kernelHeaderAddr = mem.allocateInKernel(32, alignment: 4)
let kernelCodeAddr   = mem.allocateInKernel(64, alignment: 4)

// Later, when a user defines a word:
let userHeaderAddr = mem.allocateInUser(24, alignment: 4)
let userBodyAddr   = mem.allocateInUser(128, alignment: 4)

mem.dumpRegions()
*/