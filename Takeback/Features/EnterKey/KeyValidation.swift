import Foundation

/// Internal validation primitives. Do not return decoded private material to UI state.
enum KeyValidation {
    static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    static let curveOrder: [UInt8] = [0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xfe,
        0xba,0xae,0xdc,0xe6,0xaf,0x48,0xa0,0x3b,0xbf,0xd2,0x5e,0x8c,0xd0,0x36,0x41,0x41]
    static let words: [[UInt8]] = {
        guard let url = Bundle.main.url(forResource: "english", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            preconditionFailure("Bundled BIP39 English wordlist missing")
        }
        let list = text.split(separator: "\n").map { Array($0.utf8) }
        precondition(list.count == 2048, "BIP39 wordlist must have 2048 entries")
        return list
    }()

    static func normalized(_ input: SecureBytes, lowercaseWords: Bool = false) throws -> SecureBytes {
        let output = SecureBytes(capacity: input.capacity)
        try input.withUnsafeBytes { bytes in
            // Decode whitespace without retaining a secret String or array of word substrings.
            var i = 0, pendingSpace = false
            while i < bytes.count {
                let byte = bytes[i]
                var whitespaceLength = (byte == 32 || (9...13).contains(byte)) ? 1 : 0
                if byte == 0xc2, i + 1 < bytes.count, [0x85,0xa0].contains(bytes[i+1]) { whitespaceLength = 2 }
                if byte == 0xe1, i + 2 < bytes.count, bytes[i+1] == 0x9a, bytes[i+2] == 0x80 { whitespaceLength = 3 }
                if byte == 0xe2, i + 2 < bytes.count,
                   (bytes[i+1] == 0x80 && ((0x80...0x8a).contains(bytes[i+2]) || [0xa8,0xa9,0xaf].contains(bytes[i+2]))) ||
                    (byte == 0xe2 && i + 2 < bytes.count && bytes[i+1] == 0x81 && bytes[i+2] == 0x9f) { whitespaceLength = 3 }
                if byte == 0xe3, i + 2 < bytes.count, bytes[i+1] == 0x80, bytes[i+2] == 0x80 { whitespaceLength = 3 }
                if whitespaceLength > 0 { pendingSpace = output.count > 0; i += whitespaceLength; continue }
                if pendingSpace { try output.append(32); pendingSpace = false }
                try output.append(lowercaseWords && (65...90).contains(byte) ? byte + 32 : byte)
                i += 1
            }
        }
        return output
    }

    static func sha256(_ input: SecureBytes) -> SecureBytes {
        let output = SecureBytes(capacity: 32)
        try! output.replace(with: repeatElement(UInt8(0), count: 32))
        input.withUnsafeBytes { source in
            output.withUnsafeMutableBytes { target in
                _ = CC_SHA256(source.baseAddress, CC_LONG(source.count), target.bindMemory(to: UInt8.self).baseAddress)
            }
        }
        return output
    }
    static func validScalar(_ bytes: UnsafeRawBufferPointer) -> Bool {
        guard bytes.count == 32, bytes.contains(where: { $0 != 0 }) else { return false }
        return bytes.lexicographicallyPrecedes(curveOrder)
    }
    static func uint32(_ bytes: UnsafeRawBufferPointer, at start: Int) -> UInt32 {
        (start..<start+4).reduce(UInt32(0)) { ($0 << 8) | UInt32(bytes[$1]) }
    }
    static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte { case 48...57: byte-48; case 65...70: byte-55; case 97...102: byte-87; default: nil }
    }
    static func hex(_ bytes: UnsafeRawBufferPointer) -> SecureBytes? {
        let start = bytes.count == 66 && bytes[0] == 48 && [120,88].contains(bytes[1]) ? 2 : 0
        guard bytes.count - start == 64 else { return nil }
        let output = SecureBytes(capacity: 32)
        for i in stride(from: start, to: bytes.count, by: 2) {
            guard let high = hexNibble(bytes[i]), let low = hexNibble(bytes[i+1]) else { output.wipe(); return nil }
            try! output.append(high << 4 | low)
        }
        return output
    }
    static func phrase(_ bytes: UnsafeRawBufferPointer) -> KeyDetection? {
        // Word indices are packed straight into a zeroable buffer; no secret index array.
        let packed = SecureBytes(capacity: 128)
        defer { packed.wipe() }
        try! packed.replace(with: repeatElement(UInt8(0), count: 128))
        var start = 0, count = 0, bitOffset = 0
        for end in 0...bytes.count where end == bytes.count || bytes[end] == 32 {
            let word = UnsafeRawBufferPointer(rebasing: bytes[start..<end])
            guard let index = wordIndex(word) else { return nil }
            count += 1
            if count <= 24 {
                packed.withUnsafeMutableBytes { target in
                    for bit in (0..<11).reversed() {
                        if index & (1 << bit) != 0 { target[bitOffset/8] |= 1 << (7-bitOffset%8) }
                        bitOffset += 1
                    }
                }
            }
            start = end + 1
        }
        guard KeyDetection.phraseCounts.contains(count) else { return .phrase(words: count, checksumValid: false) }
        let entropy = SecureBytes(capacity: 32)
        defer { entropy.wipe() }
        let entropyLength = count * 11 * 32 / 33 / 8
        try! packed.withUnsafeBytes { try entropy.replace(with: $0.prefix(entropyLength)) }
        let digest = sha256(entropy)
        defer { digest.wipe() }
        let checksumBits = count / 3
        let valid = packed.withUnsafeBytes { packed in
            digest.withUnsafeBytes { digest in
                packed[entropyLength] >> (8-checksumBits) == digest[0] >> (8-checksumBits)
            }
        }
        return .phrase(words: count, checksumValid: valid)
    }
    private static func wordIndex(_ word: UnsafeRawBufferPointer) -> Int? {
        var low = 0, high = words.count
        while low < high {
            let mid = (low + high) / 2, candidate = words[mid]
            var order = 0
            for i in 0..<min(word.count, candidate.count) {
                let byte = (65...90).contains(word[i]) ? word[i] + 32 : word[i]
                if byte != candidate[i] { order = byte < candidate[i] ? -1 : 1; break }
            }
            if order == 0 { order = word.count == candidate.count ? 0 : word.count < candidate.count ? -1 : 1 }
            if order == 0 { return mid }
            if order < 0 { high = mid } else { low = mid + 1 }
        }
        return nil
    }
    static func base58Check(_ bytes: UnsafeRawBufferPointer) -> SecureBytes? {
        guard (26...112).contains(bytes.count) else { return nil }
        let scratch = SecureBytes(capacity: bytes.count)
        defer { scratch.wipe() }
        try! scratch.replace(with: repeatElement(UInt8(0), count: bytes.count))
        var length = 0
        for byte in bytes {
            guard let digit = base58Alphabet.firstIndex(of: byte) else { return nil }
            var carry = digit
            scratch.withUnsafeMutableBytes { number in
                for index in 0..<length { carry += Int(number[index]) * 58; number[index] = UInt8(carry & 255); carry >>= 8 }
                while carry > 0 { number[length] = UInt8(carry & 255); length += 1; carry >>= 8 }
            }
        }
        let decoded = SecureBytes(capacity: bytes.count)
        defer { decoded.wipe() }
        for _ in bytes.prefix(while: { $0 == 49 }) { try! decoded.append(0) }
        scratch.withUnsafeBytes { number in
            for index in (0..<length).reversed() { try! decoded.append(number[index]) }
        }
        guard decoded.count > 4 else { return nil }
        let payload = SecureBytes(capacity: decoded.count)
        try! decoded.withUnsafeBytes { try payload.replace(with: $0.dropLast(4)) }
        let first = sha256(payload), second = sha256(first)
        defer { first.wipe(); second.wipe() }
        let valid = decoded.withUnsafeBytes { raw in second.withUnsafeBytes { raw.suffix(4).elementsEqual($0.prefix(4)) } }
        guard valid else { payload.wipe(); return nil }
        return payload
    }
    static func publicDescriptor(_ bytes: UnsafeRawBufferPointer) -> Bool {
        let functions = ["pk(","pkh(","wpkh(","sh(","wsh(","tr(","addr(","raw(","combo(","multi(","sortedmulti("]
        guard functions.contains(where: { bytes.starts(with: $0.utf8) }), bytes.contains(41) else { return false }
        // Private descriptors are not imported by this screen; do not label them public.
        for prefix in ["xprv","yprv","zprv","tprv","uprv","vprv"] {
            let pattern = Array(prefix.utf8)
            if bytes.count >= pattern.count, (0...bytes.count-pattern.count).contains(where: { bytes[$0..<$0+pattern.count].elementsEqual(pattern) }) { return false }
        }
        // Look at Base58 tokens to catch embedded WIFs as well.
        var start: Int?
        for i in 0...bytes.count {
            if i < bytes.count && base58Alphabet.contains(bytes[i]) { if start == nil { start = i } }
            else if let begin = start {
                if let payload = base58Check(UnsafeRawBufferPointer(rebasing: bytes[begin..<i])) {
                    defer { payload.wipe() }
                    if payload.withUnsafeBytes({ [33,34].contains($0.count) && [0x80,0xef].contains($0[0]) }) { return false }
                }
                start = nil
            }
        }
        return true
    }
    static func isWitnessAddress(_ bytes: UnsafeRawBufferPointer) -> Bool {
        guard (14...90).contains(bytes.count) else { return false }
        // Reject private formats before allocating public-address decoding arrays.
        let hrps = ["bc1", "tb1", "bcrt1"]
        guard hrps.contains(where: { prefix in
            let publicBytes = Array(prefix.utf8)
            return bytes.count >= publicBytes.count && publicBytes.indices.allSatisfy {
                let byte = bytes[$0]
                return ((65...90).contains(byte) ? byte + 32 : byte) == publicBytes[$0]
            }
        }) else { return false }
        var lower = bytes.map { (65...90).contains($0) ? $0 + 32 : $0 }
        defer { lower.withUnsafeMutableBytes { takeback_secure_zero($0.baseAddress, $0.count) } }
        guard lower.starts(with: Array("bc1".utf8)) || lower.starts(with: Array("tb1".utf8)) || lower.starts(with: Array("bcrt1".utf8)) else { return false }
        if bytes.contains(where: { (65...90).contains($0) }) && bytes.contains(where: { (97...122).contains($0) }) { return false }
        guard let separator = lower.lastIndex(of: 49) else { return false }
        let alphabet = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l".utf8)
        let values = lower[(separator+1)...].compactMap { alphabet.firstIndex(of: $0).map(UInt32.init) }
        guard values.count == lower.count-separator-1, values.count >= 7, values[0] <= 16 else { return false }
        var checksum: UInt32 = 1
        let generators: [UInt32] = [0x3b6a57b2,0x26508e6d,0x1ea119fa,0x3d4233dd,0x2a1462b3]
        func add(_ value: UInt32) {
            let top = checksum >> 25
            checksum = ((checksum & 0x1ffffff) << 5) ^ value
            for i in 0..<5 where ((top >> i) & 1) != 0 { checksum ^= generators[i] }
        }
        for byte in lower[..<separator] { add(UInt32(byte >> 5)) }; add(0)
        for byte in lower[..<separator] { add(UInt32(byte & 31)) }
        for value in values { add(value) }
        guard checksum == (values[0] == 0 ? 1 : 0x2bc830a3) else { return false }
        let payloadBits = (values.count-7)*5, programLength = payloadBits/8
        let padding = payloadBits%8
        guard padding < 5, (2...40).contains(programLength), values[0] != 0 || [20,32].contains(programLength) else { return false }
        return padding == 0 || values[values.count-7] & ((1 << padding)-1) == 0
    }
}
