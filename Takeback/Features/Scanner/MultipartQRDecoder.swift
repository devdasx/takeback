import Foundation

struct ScanPayload {
    enum Format: Equatable { case text, ur(String), bbqr(Character) }
    let format: Format
    let bytes: SecureBytes
}
enum ScanAssembly {
    case progress(received: Int, total: Int)
    case payload(ScanPayload)
}

/// Owned by one serial scanner worker. No secrets are persisted or printed.
final class MultipartQRDecoder {
    private struct Equation { var indexes: Set<Int>; let bytes: SecureBytes }
    private var basis: [Int: Equation] = [:]
    private var fragments: [Int: SecureBytes] = [:]
    private var identity: String?
    private var messageLength = 0
    private var checksum: UInt32 = 0
    private var fragmentLength = 0
    private var total = 0
    private(set) var storedByteCount = 0
    func reset() {
        basis.values.forEach { $0.bytes.wipe() }; fragments.values.forEach { $0.wipe() }
        basis.removeAll(); fragments.removeAll(); identity = nil
        messageLength = 0; fragmentLength = 0; checksum = 0; total = 0; storedByteCount = 0
    }
    deinit { reset() }
    func receive(_ input: SecureBytes) throws -> ScanAssembly {
        // The system QR APIs supply String. This short-lived parsing String is never retained.
        guard input.count > 0, input.count <= 16_384 else { throw ScanDecodeError.invalid }
        let text = input.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }
        do {
            if text.lowercased().hasPrefix("ur:") { return try receiveUR(text) }
            if text.hasPrefix("B$") { return try receiveBBQr(text) }
            return .payload(.init(format: .text, bytes: try input.withUnsafeBytes(ScanBytes.copy)))
        } catch { reset(); throw error }
    }
    private func receiveUR(_ text: String) throws -> ScanAssembly {
        let parts = text.dropFirst(3).split(separator: "/", omittingEmptySubsequences: false)
        guard [2,3].contains(parts.count), !parts[0].isEmpty,
              parts[0].utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }) else { throw ScanDecodeError.invalid }
        let type = parts[0].lowercased()
        let data = try ScannerBytewords.decode(parts.last!)
        if parts.count == 2 { reset(); return .payload(.init(format: .ur(type), bytes: data)) }
        defer { data.wipe() }
        let sequence = parts[1].split(separator: "-")
        guard sequence.count == 2, let seq = UInt32(sequence[0]), seq > 0,
              let count = Int(sequence[1]), (1...512).contains(count),
              let array = try ScanCBOR.decode(data).array, array.count == 5,
              array[0].uint == UInt64(seq), array[1].uint == UInt64(count),
              let length = array[2].uint, length > 0, length <= ScanBytes.limit,
              let crc = array[3].uint, crc <= UInt32.max, let range = array[4].byteRange,
              range.count > 0, count * range.count <= ScanBytes.limit + 4096,
              (count - 1) * range.count < Int(length), Int(length) <= count * range.count else { throw ScanDecodeError.invalid }
        let id = "ur:\(type):\(count):\(length):\(crc):\(range.count)"
        if identity != id {
            reset(); identity = id; total = count; messageLength = Int(length); checksum = UInt32(crc); fragmentLength = range.count
        }
        let bytes = try data.withUnsafeBytes { try ScanBytes.copy($0[range]) }
        var indexes = Self.chooseFragments(seq: seq, count: count, checksum: UInt32(crc))
        while let pivot = indexes.min(), let existing = basis[pivot] {
            indexes.formSymmetricDifference(existing.indexes); ScanBytes.xor(bytes, existing.bytes)
        }
        if let pivot = indexes.min() {
            basis[pivot] = Equation(indexes: indexes, bytes: bytes); storedByteCount += bytes.count
        } else {
            defer { bytes.wipe() }
            guard bytes.withUnsafeBytes({ $0.allSatisfy { $0 == 0 } }) else { throw ScanDecodeError.invalid }
        }
        guard basis.count == total else { return .progress(received: basis.count, total: total) }
        // Back substitution handles mixed fountain parts even when simple parts never arrive.
        for index in (0..<total).reversed() {
            guard let row = basis[index] else { throw ScanDecodeError.invalid }
            for other in row.indexes where other != index {
                guard let solved = basis[other] else { throw ScanDecodeError.invalid }
                ScanBytes.xor(row.bytes, solved.bytes)
            }
        }
        let result = SecureBytes(capacity: messageLength)
        for index in 0..<total {
            try basis[index]!.bytes.withUnsafeBytes { block in
                for byte in block.prefix(messageLength - result.count) { try result.append(byte) }
            }
        }
        guard result.withUnsafeBytes({ ScanCRC32.checksum($0) }) == checksum else { result.wipe(); throw ScanDecodeError.invalid }
        reset(); return .payload(.init(format: .ur(type), bytes: result))
    }
    /// Fragment selection follows URKit's reference order exactly; inputs are public metadata.
    static func chooseFragments(seq: UInt32, count: Int, checksum: UInt32) -> Set<Int> {
        if seq <= count { return [Int(seq) - 1] }
        let seed = [seq, checksum].flatMap { value in (0..<4).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) } }
        let rng = ScannerXoshiro256(seed: Data(seed))
        let sampler = ScannerRandomSampler((1...count).map { 1 / Double($0) })
        let degree = sampler.next(rng.nextDouble) + 1
        var remaining = Array(0..<count), result = Set<Int>()
        for _ in 0..<degree { result.insert(remaining.remove(at: rng.nextInt(in: 0..<remaining.count))) }
        return result
    }
    private func receiveBBQr(_ text: String) throws -> ScanAssembly {
        let header = Array(text.utf8.prefix(8)) // Public protocol header only.
        guard header.count == 8, [72,50,90].contains(header[2]), "PTJCUBX".utf8.contains(header[3]) else { throw ScanDecodeError.invalid }
        func base36(_ a: UInt8, _ b: UInt8) throws -> Int {
            func digit(_ c: UInt8) throws -> Int {
                if (48...57).contains(c) { return Int(c-48) }
                if (65...90).contains(c) { return Int(c-55) }
                throw ScanDecodeError.invalid
            }
            return try digit(a) * 36 + digit(b)
        }
        let count = try base36(header[4],header[5]), index = try base36(header[6],header[7])
        guard (1...1295).contains(count), index < count else { throw ScanDecodeError.invalid }
        let id = String(decoding: header.prefix(6), as: UTF8.self)
        let decoded = try decodeBlock(text.dropFirst(8), hex: header[2] == 72)
        guard decoded.count > 0 else { decoded.wipe(); throw ScanDecodeError.invalid }
        if identity != id { reset(); identity = id; total = count }
        if let existing = fragments[index] {
            defer { decoded.wipe() }
            guard ScanBytes.equal(existing, decoded) else { throw ScanDecodeError.invalid }
        } else {
            guard storedByteCount + decoded.count <= ScanBytes.limit else { decoded.wipe(); throw ScanDecodeError.invalid }
            fragments[index] = decoded; storedByteCount += decoded.count
        }
        let regular = fragments.filter { $0.key != count-1 }.values
        if let length = regular.first?.count {
            guard regular.allSatisfy({ $0.count == length }), fragments[count-1].map({ $0.count <= length }) ?? true else { throw ScanDecodeError.invalid }
        }
        guard fragments.count == total else { return .progress(received: fragments.count, total: total) }
        let joined = SecureBytes(capacity: storedByteCount)
        for i in 0..<count { try fragments[i]!.withUnsafeBytes { for b in $0 { try joined.append(b) } } }
        reset()
        if header[2] == 90 {
            defer { joined.wipe() }
            return .payload(.init(format: .bbqr(Character(UnicodeScalar(header[3]))), bytes: try inflate(joined)))
        }
        return .payload(.init(format: .bbqr(Character(UnicodeScalar(header[3]))), bytes: joined))
    }
    private func decodeBlock(_ text: Substring, hex: Bool) throws -> SecureBytes {
        let result = SecureBytes(capacity: max(1,text.utf8.count))
        do {
            var accumulator: UInt32 = 0, bits = 0
            let width = hex ? 4 : 5
            for c in text.utf8 {
                let value: UInt32
                if hex, let nibble = KeyValidation.hexNibble(c), !(97...102).contains(c) { value = UInt32(nibble) }
                else if !hex, (65...90).contains(c) { value = UInt32(c-65) }
                else if !hex, (50...55).contains(c) { value = UInt32(c-24) }
                else { throw ScanDecodeError.invalid }
                accumulator = (accumulator << width) | value; bits += width
                if bits >= 8 { bits -= 8; try result.append(UInt8(truncatingIfNeeded: accumulator >> bits)) }
                accumulator &= (1 << bits) - 1
            }
            guard (hex ? bits == 0 : bits < 5), accumulator == 0 else { throw ScanDecodeError.invalid }
            return result
        } catch { result.wipe(); throw error }
    }
    private func inflate(_ input: SecureBytes) throws -> SecureBytes {
        let result = SecureBytes(capacity: ScanBytes.limit)
        try result.replace(with: repeatElement(UInt8(0), count: result.capacity))
        var count = 0
        let ok = input.withUnsafeBytes { source in result.withUnsafeMutableBytes { target in
            takeback_qr_inflate(source.bindMemory(to: UInt8.self).baseAddress, source.count,
                                target.bindMemory(to: UInt8.self).baseAddress, target.count, &count)
        } }
        guard ok == 1 else { result.wipe(); throw ScanDecodeError.invalid }
        defer { result.wipe() }
        return try result.withUnsafeBytes { try ScanBytes.copy($0.prefix(count)) }
    }
}
