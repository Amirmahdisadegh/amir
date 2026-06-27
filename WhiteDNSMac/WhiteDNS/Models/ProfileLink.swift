import Foundation

/// Parses and builds `stormdns://` profile links, byte-compatible with the
/// WhiteDNS Android client (WhiteDnsProfileLinks.kt).
///
/// Wire format:  `stormdns://<urlsafe-base64-no-padding(JSON)>`
///
/// JSON shape:
/// ```
/// {
///   "schema": "whitedns.profile",
///   "version": 1,
///   "profile": {
///     "name": "string",
///     "server": {
///       "domain": "string",
///       "encryption_key": "string",
///       "encryption_method": 0...5
///     }
///   }
/// }
/// ```
enum ProfileLink {

    static let scheme = "stormdns://"
    private static let schemaTag = "whitedns.profile"

    enum ParseError: LocalizedError {
        case notAStormLink
        case badBase64
        case badJSON
        case missingFields

        var errorDescription: String? {
            switch self {
            case .notAStormLink: return "This is not a stormdns:// link."
            case .badBase64: return "The link payload is not valid Base64."
            case .badJSON: return "The link does not contain a valid profile."
            case .missingFields: return "The profile is missing a domain or key."
            }
        }
    }

    // MARK: Decode

    static func parse(_ raw: String) throws -> ServerProfile {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard text.lowercased().hasPrefix(scheme) else { throw ParseError.notAStormLink }
        text = String(text.dropFirst(scheme.count))

        // Drop any fragment / query that some share sheets append.
        if let hash = text.firstIndex(of: "#") { text = String(text[..<hash]) }
        if let q = text.firstIndex(of: "?") { text = String(text[..<q]) }

        guard let data = decodeBase64URL(text) else { throw ParseError.badBase64 }

        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let profile = root["profile"] as? [String: Any],
            let server = profile["server"] as? [String: Any]
        else { throw ParseError.badJSON }

        let domain = (server["domain"] as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
            .trimmingTrailingDots()
        let key = (server["encryption_key"] as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
        let method = intValue(server["encryption_method"]) ?? EncryptionMethod.xor.rawValue
        let name = (profile["name"] as? String)?
            .trimmingCharacters(in: .whitespaces)
            .nilIfEmpty ?? (domain.nilIfEmpty ?? "WhiteDNS Profile")

        guard !domain.isEmpty, !key.isEmpty else { throw ParseError.missingFields }

        return ServerProfile(
            label: name,
            domain: domain,
            encryptionKey: key,
            encryptionMethod: max(0, min(5, method))
        )
    }

    // MARK: Encode

    static func build(from profile: ServerProfile) -> String {
        let json: [String: Any] = [
            "schema": schemaTag,
            "version": 1,
            "profile": [
                "name": profile.label,
                "server": [
                    "domain": profile.domain,
                    "encryption_key": profile.encryptionKey,
                    "encryption_method": profile.encryptionMethod,
                ],
            ],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()
        return scheme + encodeBase64URL(data)
    }

    // MARK: Base64URL helpers

    private static func decodeBase64URL(_ s: String) -> Data? {
        var b64 = s.replacingOccurrences(of: "-", with: "+")
                   .replacingOccurrences(of: "_", with: "/")
        // Restore padding.
        let rem = b64.count % 4
        if rem > 0 { b64.append(String(repeating: "=", count: 4 - rem)) }
        if let d = Data(base64Encoded: b64) { return d }
        // Fall back to plain (already-padded / standard) base64.
        return Data(base64Encoded: s)
    }

    private static func encodeBase64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String { return Int(s) }
        return nil
    }
}

private extension String {
    func trimmingTrailingDots() -> String {
        var s = self
        while s.hasSuffix(".") { s.removeLast() }
        return s
    }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
