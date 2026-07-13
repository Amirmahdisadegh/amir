import Foundation

/// User-facing networking errors with localized descriptions and SF Symbol hints.
enum APIError: LocalizedError, Equatable {
    case notConfigured
    case invalidURL
    case invalidCredentials
    case sessionExpired
    case panelUnreachable
    case timeout
    case tlsError
    case decoding(String)
    case server(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:      return "error.not_configured".loc
        case .invalidURL:         return "error.invalid_url".loc
        case .invalidCredentials: return "error.invalid_credentials".loc
        case .sessionExpired:     return "error.session_expired".loc
        case .panelUnreachable:   return "error.unreachable".loc
        case .timeout:            return "error.timeout".loc
        case .tlsError:           return "error.tls".loc
        case .decoding(let m):    return "error.decoding".loc + " \(m)"
        case .server(let m):      return m
        case .unknown(let m):     return m
        }
    }

    var symbol: String {
        switch self {
        case .invalidCredentials, .sessionExpired: return "lock.trianglebadge.exclamationmark"
        case .panelUnreachable, .timeout:          return "wifi.exclamationmark"
        case .tlsError:                            return "exclamationmark.shield"
        case .notConfigured:                       return "gearshape"
        default:                                   return "exclamationmark.triangle"
        }
    }

    /// Map a URLError into a friendly APIError.
    static func from(_ error: Error) -> APIError {
        if let api = error as? APIError { return api }
        let urlError = error as? URLError
        switch urlError?.code {
        case .some(.timedOut):
            return .timeout
        case .some(.cannotFindHost), .some(.cannotConnectToHost),
             .some(.networkConnectionLost), .some(.notConnectedToInternet),
             .some(.dnsLookupFailed):
            return .panelUnreachable
        case .some(.secureConnectionFailed), .some(.serverCertificateUntrusted),
             .some(.serverCertificateHasBadDate), .some(.serverCertificateHasUnknownRoot),
             .some(.serverCertificateNotYetValid), .some(.clientCertificateRejected):
            return .tlsError
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
