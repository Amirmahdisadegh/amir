import Foundation

/// A minimal, lossless JSON value used to re-serialize fields that a panel may
/// return either as a JSON *string* (classic 3x-ui) or a nested JSON *object*
/// (modern 3x-ui / OAS). Lets us normalize both into a raw JSON string.
enum JSONValue: Codable {
    case string(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int64.self) {
            self = .int(i)
        } else if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .bool(let b): try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a): try c.encode(a)
        case .null: try c.encodeNil()
        }
    }

    private func toFoundation() -> Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return NSNumber(value: i)
        case .double(let d): return NSNumber(value: d)
        case .bool(let b): return NSNumber(value: b)
        case .null: return NSNull()
        case .array(let a): return a.map { $0.toFoundation() }
        case .object(let o): return o.mapValues { $0.toFoundation() }
        }
    }

    /// Serialize this value back into a compact JSON string.
    var rawJSONString: String {
        let foundation = toFoundation()
        guard JSONSerialization.isValidJSONObject(foundation),
              let data = try? JSONSerialization.data(withJSONObject: foundation),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }
}

extension KeyedDecodingContainer {
    /// Decode a field that may be a JSON *string* or an inline JSON *object/array*,
    /// returning it as a raw JSON string either way.
    func decodeJSONStringOrObject(_ key: Key, default def: String = "{}") -> String {
        if let s = try? decode(String.self, forKey: key) { return s }
        if let v = try? decode(JSONValue.self, forKey: key) {
            switch v {
            case .object, .array: return v.rawJSONString
            case .string(let s): return s
            default: break
            }
        }
        return def
    }
}
