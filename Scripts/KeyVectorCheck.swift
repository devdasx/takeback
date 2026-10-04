import Foundation

struct Vector: Decodable { let id: String; let input: String; let kind: String; let valid: Bool }
@main enum KeyVectorCheck {
    static func main() throws {
        let vectors = try JSONDecoder().decode([Vector].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        var failures = 0
        for vector in vectors {
            let input = SecureBytes()
            try input.replace(with: vector.input.utf8)
            let detected = detectKey(input)
            let matches = detected.isValid == vector.valid && kind(detected) == vector.kind
                && input.withUnsafeBytes { $0.elementsEqual(vector.input.utf8) }
            if !matches { failures += 1; print("FAIL: \(vector.id), classification=\(kind(detected)), valid=\(detected.isValid)") }
            input.withUnsafeBytes { pointer in
                input.wipe()
                if !pointer.allSatisfy({ $0 == 0 }) { failures += 1; print("FAIL: owned memory zeroing") }
            }
        }
        print("\(vectors.count) detection vectors, \(failures) failures. Owned input preservation and zeroing checked.")
        if failures > 0 { exit(1) }
    }
    static func kind(_ value: KeyDetection) -> String {
        switch value {
        case .empty: "empty"
        case .phrase(_, true): "phrase"
        case .phrase(let count, false): KeyDetection.phraseCounts.contains(count) ? "invalid" : "incomplete"
        case .wif(let compressed): compressed ? "compressed" : "uncompressed"
        case .mini: "mini"
        case .hex: "hex"
        case .extended(let prefix, _, _): prefix.rawValue
        case .publicOnly: "public"
        case .testnet: "testnet"
        case .unrecognized: "invalid"
        }
    }
}
