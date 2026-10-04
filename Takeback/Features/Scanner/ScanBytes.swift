import Foundation

enum ScanDecodeError: Error { case invalid, unsupported, publicKey, testnet }

enum ScanBytes {
    static let limit = 65_536
    static func copy<C: Collection>(_ bytes: C) throws -> SecureBytes where C.Element == UInt8 {
        guard bytes.count <= limit else { throw ScanDecodeError.invalid }
        let value = SecureBytes(capacity: max(1, bytes.count))
        try value.replace(with: bytes)
        return value
    }
    static func xor(_ destination: SecureBytes, _ source: SecureBytes) {
        precondition(destination.count == source.count)
        source.withUnsafeBytes { source in destination.withUnsafeMutableBytes { target in
            for i in target.indices { target[i] ^= source[i] }
        } }
    }
    static func equal(_ lhs: SecureBytes, _ rhs: SecureBytes) -> Bool {
        lhs.withUnsafeBytes { a in rhs.withUnsafeBytes { a.elementsEqual($0) } }
    }
}
enum ScanCRC32 {
    static func checksum(_ bytes: UnsafeRawBufferPointer) -> UInt32 {
        var value = UInt32.max
        for byte in bytes {
            value ^= UInt32(byte)
            for _ in 0..<8 { value = (value >> 1) ^ (value & 1 == 1 ? 0xedb88320 : 0) }
        }
        return ~value
    }
}

/// CBOR nodes contain ranges into one owned buffer, never copied secret byte arrays/Strings.
struct ScanCBOR {
    indirect enum Node {
        case unsigned(UInt64), bytes(Range<Int>), text(Range<Int>), array([Node]), map([UInt64: Node]), bool(Bool), tag(UInt64, Node), null
        var uint: UInt64? { if case .unsigned(let value) = self { value } else { nil } }
        var boolean: Bool? { if case .bool(let value) = self { value } else { nil } }
        var byteRange: Range<Int>? { if case .bytes(let value) = self { value } else { nil } }
        var array: [Node]? { if case .array(let value) = self { value } else { nil } }
        var map: [UInt64: Node]? { if case .map(let value) = self { value } else { nil } }
        func untagged(_ allowed: Set<UInt64>) throws -> Node {
            if case .tag(let tag, let value) = self {
                guard allowed.contains(tag) else { throw ScanDecodeError.invalid }; return value
            }
            return self
        }
    }
    let bytes: UnsafeRawBufferPointer
    var offset = 0
    var nodes = 0
    static func decode(_ source: SecureBytes) throws -> Node {
        try source.withUnsafeBytes { bytes in
            var reader = ScanCBOR(bytes: bytes)
            let value = try reader.read()
            guard reader.offset == bytes.count else { throw ScanDecodeError.invalid }
            return value
        }
    }
    mutating func read(depth: Int = 0) throws -> Node {
        guard offset < bytes.count, depth < 16, nodes < 4096 else { throw ScanDecodeError.invalid }
        nodes += 1
        let head = bytes[offset]; offset += 1
        let major = head >> 5, additional = head & 31
        if major == 7 {
            switch additional { case 20: return .bool(false); case 21: return .bool(true); case 22: return .null; default: throw ScanDecodeError.invalid }
        }
        let length: UInt64
        if additional < 24 { length = UInt64(additional) }
        else {
            guard (24...27).contains(additional) else { throw ScanDecodeError.invalid }
            let count = 1 << Int(additional - 24)
            guard count <= bytes.count - offset else { throw ScanDecodeError.invalid }
            length = bytes[offset..<offset+count].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }; offset += count
        }
        switch major {
        case 0: return .unsigned(length)
        case 2, 3:
            guard length <= bytes.count - offset else { throw ScanDecodeError.invalid }
            let range = offset..<offset+Int(length); offset = range.upperBound
            return major == 2 ? .bytes(range) : .text(range)
        case 4:
            guard length <= 1024 else { throw ScanDecodeError.invalid }
            return .array(try (0..<Int(length)).map { _ in try read(depth: depth + 1) })
        case 5:
            guard length <= 64 else { throw ScanDecodeError.invalid }
            var values: [UInt64: Node] = [:]
            for _ in 0..<length {
                guard let key = try read(depth: depth + 1).uint, values[key] == nil else { throw ScanDecodeError.invalid }
                values[key] = try read(depth: depth + 1)
            }
            return .map(values)
        case 6: return .tag(length, try read(depth: depth + 1))
        default: throw ScanDecodeError.invalid
        }
    }
}
