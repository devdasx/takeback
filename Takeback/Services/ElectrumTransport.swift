import Foundation
import Network

enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Decimal), bool(Bool), array([JSONValue]), object([String: JSONValue]), null
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? value.decode(Decimal.self) { self = .number(number) }
        else if let string = try? value.decode(String.self) { self = .string(string) }
        else if let array = try? value.decode([JSONValue].self) { self = .array(array) }
        else { self = .object(try value.decode([String: JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let v): try value.encode(v)
        case .number(let v): try value.encode(v)
        case .bool(let v): try value.encode(v)
        case .array(let v): try value.encode(v)
        case .object(let v): try value.encode(v)
        case .null: try value.encodeNil()
        }
    }
    var decimal: Decimal? { if case .number(let v) = self { v } else { nil } }
    var string: String? { if case .string(let v) = self { v } else { nil } }
    var integer: Int? {
        guard let decimal, !decimal.isNaN,
              decimal >= Decimal(Int.min), decimal <= Decimal(Int.max) else { return nil }
        let integer = NSDecimalNumber(decimal: decimal).intValue
        return Decimal(integer) == decimal ? integer : nil
    }
}

struct RPCCall: Sendable { let method: String; var params: [JSONValue] = [] }
struct RPCFailure: Error, Equatable, Sendable { let code: Int; let message: String }
protocol ElectrumTransport: Sendable {
    func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue
    func batch(server: ElectrumServer, calls: [RPCCall], timeout: TimeInterval) async throws -> [Result<JSONValue, RPCFailure>]
}
extension ElectrumTransport {
    func batch(server: ElectrumServer, calls: [RPCCall], timeout: TimeInterval) async throws -> [Result<JSONValue, RPCFailure>] { throw ChainError.noBatch }
}
