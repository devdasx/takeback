import Foundation
import Darwin

/// Owns a single, fixed allocation. Deliberately not Codable, Sendable or printable as bytes.
/// Borrow bytes only for synchronous cryptographic work; never retain the borrowed pointer.
final class SecureBytes: CustomStringConvertible, CustomDebugStringConvertible {
    private let storage: UnsafeMutableRawPointer
    let capacity: Int
    private(set) var count = 0
    var description: String { "<SecureBytes: redacted>" }
    var debugDescription: String { description }

    init(capacity: Int = 4096) {
        precondition(capacity > 0)
        self.capacity = capacity
        storage = .allocate(byteCount: capacity, alignment: 16)
        storage.initializeMemory(as: UInt8.self, repeating: 0, count: capacity)
        // Best effort: iOS may deny mlock. No disk-backed allocation is used.
        _ = mlock(storage, capacity)
    }

    func replace<C: Collection>(with bytes: C) throws where C.Element == UInt8 {
        guard bytes.count <= capacity else { throw StorageError.tooLarge }
        wipe()
        for (offset, byte) in bytes.enumerated() { storage.storeBytes(of: byte, toByteOffset: offset, as: UInt8.self) }
        count = bytes.count
    }

    func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        try body(UnsafeRawBufferPointer(start: storage, count: count))
    }

    /// Synchronous scratch work only; the pointer must never escape this closure.
    func withUnsafeMutableBytes<T>(_ body: (UnsafeMutableRawBufferPointer) throws -> T) rethrows -> T {
        try body(UnsafeMutableRawBufferPointer(start: storage, count: count))
    }

    func append(_ byte: UInt8) throws {
        guard count < capacity else { throw StorageError.tooLarge }
        storage.storeBytes(of: byte, toByteOffset: count, as: UInt8.self)
        count += 1
    }

    func wipe() {
        // takeback_secure_zero is not optimized away, unlike ordinary zero assignments.
        takeback_secure_zero(storage, capacity)
        count = 0
    }

    deinit {
        takeback_secure_zero(storage, capacity)
        _ = munlock(storage, capacity)
        storage.deallocate()
    }

    enum StorageError: Error { case tooLarge }
}
