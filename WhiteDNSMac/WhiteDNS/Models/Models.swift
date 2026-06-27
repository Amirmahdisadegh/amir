import Foundation

// MARK: - Encryption methods (must match StormDNS core DATA_ENCRYPTION_METHOD)

enum EncryptionMethod: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case xor = 1
    case chacha20 = 2
    case aes128gcm = 3
    case aes192gcm = 4
    case aes256gcm = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .xor: return "XOR"
        case .chacha20: return "ChaCha20"
        case .aes128gcm: return "AES-128-GCM"
        case .aes192gcm: return "AES-192-GCM"
        case .aes256gcm: return "AES-256-GCM"
        }
    }
}

// MARK: - Server profile
// Mirrors WhiteDnsServerProfile from the Android client.

struct ServerProfile: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var label: String
    var domain: String
    var encryptionKey: String
    var encryptionMethod: Int = EncryptionMethod.xor.rawValue

    var method: EncryptionMethod {
        EncryptionMethod(rawValue: encryptionMethod) ?? .xor
    }

    /// A profile is usable only when it carries a tunnel domain and a key.
    var isValid: Bool {
        !domain.trimmingCharacters(in: .whitespaces).isEmpty &&
        !encryptionKey.isEmpty
    }
}

// MARK: - Resolver profile
// A named bundle of DNS resolvers, one per line (mirrors ResolverProfile).

struct ResolverProfile: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var resolverText: String

    /// Non-empty, non-comment lines.
    var entries: [String] {
        resolverText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    var isValid: Bool { !entries.isEmpty }

    static let defaultResolvers = ResolverProfile(
        name: "Public resolvers",
        resolverText: """
        8.8.8.8
        8.8.4.4
        1.1.1.1
        1.0.0.1
        9.9.9.9
        208.67.222.222
        """
    )
}

// MARK: - Tuning settings
// Subset of WhiteDnsSettings that maps directly onto the StormDNS client TOML.
// Every other key falls back to the core's built-in defaults.

struct AppSettings: Codable, Equatable {
    // Local SOCKS5 listener
    var listenIp: String = "127.0.0.1"
    var listenPort: Int = 18000

    // Resolver selection: 1=Random 2=RoundRobin 3=LeastLoss 4=LowestLatency
    var resolverBalancingStrategy: Int = 3

    // Packet duplication (lossy-link reliability), clamped [1,8] by the core
    var uploadDuplication: Int = 2
    var downloadDuplication: Int = 6
    var uploadSetupDuplication: Int = 4
    var downloadSetupDuplication: Int = 8

    // Compression: 0=OFF 1=ZSTD 2=LZ4 3=ZLIB
    var uploadCompression: Int = 2
    var downloadCompression: Int = 2

    // MTU discovery bounds
    var minUploadMtu: Int = 100
    var maxUploadMtu: Int = 200
    var minDownloadMtu: Int = 1000
    var maxDownloadMtu: Int = 4000

    // Watchdog / stats / logging
    var pingWatchdogTimeoutSeconds: Double = 300
    var statsReportIntervalSeconds: Double = 2.0
    var logLevel: String = "INFO"

    // App behaviour
    var autoConnectOnLaunch: Bool = false
    var manageSystemProxy: Bool = true

    static let logLevels = ["DEBUG", "INFO", "WARN", "ERROR"]
}

// MARK: - Persisted app state

struct AppData: Codable {
    var servers: [ServerProfile] = []
    var resolvers: [ResolverProfile] = [ResolverProfile.defaultResolvers]
    var selectedServerId: String? = nil
    var selectedResolverId: String? = nil
    var settings: AppSettings = AppSettings()
}
