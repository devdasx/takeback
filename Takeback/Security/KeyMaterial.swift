import Foundation

enum KeyMaterial {
    static func root(key: SecureBytes, passphrase phrase: SecureBytes) throws -> SecureBytes {
        let detection = detectKey(key)
        let normalized = try KeyValidation.normalized(key, lowercaseWords: detection.isPhrase)
        defer { normalized.wipe() }
        let root = SecureBytes(capacity: 64)
        try root.replace(with: repeatElement(UInt8(0), count: 64))
        if detection.isPhrase {
            let words = Self.nfkd(normalized), pass = Self.nfkd(phrase)
            defer { words.wipe(); pass.wipe() }
            let ok = words.withUnsafeBytes { w in pass.withUnsafeBytes { p in root.withUnsafeMutableBytes { r in
                takeback_search_master(w.bindMemory(to: UInt8.self).baseAddress, w.count,
                               p.bindMemory(to: UInt8.self).baseAddress, p.count,
                               r.bindMemory(to: UInt8.self).baseAddress)
            } } }
            guard ok == 1 else { throw ChainError.invalidConfiguration }
        } else {
            let decoded: SecureBytes?
            switch detection {
            case .hex: decoded = normalized.withUnsafeBytes { KeyValidation.hex($0) }
            case .mini: decoded = KeyValidation.sha256(normalized)
            default: decoded = normalized.withUnsafeBytes { KeyValidation.base58Check($0) }
            }
            guard let decoded else { throw ChainError.invalidConfiguration }
            defer { decoded.wipe() }
            decoded.withUnsafeBytes { d in root.withUnsafeMutableBytes { r in
                switch detection {
                case .extended:
                r.copyBytes(from: UnsafeRawBufferPointer(rebasing: d[46..<78]))
                for i in 0..<32 { r[32+i] = d[13+i] }
                case .wif: r.copyBytes(from: UnsafeRawBufferPointer(rebasing: d[1..<33]))
                default: r.copyBytes(from: d)
                }
            } }
        }
        return root
    }
    private static func nfkd(_ input: SecureBytes) -> SecureBytes {
        let text = input.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }.decomposedStringWithCompatibilityMapping
        let bytes = SecureBytes(capacity: max(1, text.utf8.count)); try? bytes.replace(with: text.utf8); return bytes
    }
}
