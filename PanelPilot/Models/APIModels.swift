import Foundation

// MARK: - Generic envelope

/// The 3x-ui panel wraps every API response in `{ success, msg, obj }`.
struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let msg: String?
    let obj: T?
}

/// Envelope where `obj` is ignored / can be any shape.
struct APIStatusEnvelope: Decodable {
    let success: Bool
    let msg: String?
}

// MARK: - Inbound

/// A single inbound as returned by `/panel/api/inbounds/list`.
/// `settings` and `streamSettings` arrive as JSON *strings* that require secondary decoding.
struct Inbound: Decodable, Identifiable, Hashable {
    let id: Int
    let up: Int64
    let down: Int64
    let total: Int64
    let remark: String
    let enable: Bool
    let expiryTime: Int64
    let listen: String
    let port: Int
    let `protocol`: String
    let settingsRaw: String
    let streamSettingsRaw: String
    let tag: String
    let clientStats: [ClientStat]

    enum CodingKeys: String, CodingKey {
        case id, up, down, total, remark, enable, expiryTime, listen, port
        case `protocol`
        case settings, streamSettings, tag, clientStats
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        up = (try? c.decode(Int64.self, forKey: .up)) ?? 0
        down = (try? c.decode(Int64.self, forKey: .down)) ?? 0
        total = (try? c.decode(Int64.self, forKey: .total)) ?? 0
        remark = (try? c.decode(String.self, forKey: .remark)) ?? ""
        enable = (try? c.decode(Bool.self, forKey: .enable)) ?? true
        expiryTime = (try? c.decode(Int64.self, forKey: .expiryTime)) ?? 0
        listen = (try? c.decode(String.self, forKey: .listen)) ?? ""
        port = (try? c.decode(Int.self, forKey: .port)) ?? 0
        `protocol` = (try? c.decode(String.self, forKey: .protocol)) ?? ""
        // Modern panels return settings/streamSettings as inline JSON objects;
        // classic panels return them as JSON strings. Normalize both to a string.
        settingsRaw = c.decodeJSONStringOrObject(.settings)
        streamSettingsRaw = c.decodeJSONStringOrObject(.streamSettings)
        tag = (try? c.decode(String.self, forKey: .tag)) ?? ""
        clientStats = (try? c.decode([ClientStat].self, forKey: .clientStats)) ?? []
    }

    /// Memberwise init for mock data and cache hydration.
    init(id: Int, up: Int64, down: Int64, total: Int64, remark: String, enable: Bool,
         expiryTime: Int64, listen: String, port: Int, protocol proto: String,
         settingsRaw: String, streamSettingsRaw: String, tag: String, clientStats: [ClientStat]) {
        self.id = id; self.up = up; self.down = down; self.total = total
        self.remark = remark; self.enable = enable; self.expiryTime = expiryTime
        self.listen = listen; self.port = port; self.`protocol` = proto
        self.settingsRaw = settingsRaw; self.streamSettingsRaw = streamSettingsRaw
        self.tag = tag; self.clientStats = clientStats
    }

    // Lazily decoded nested structures
    var settings: InboundSettings { InboundSettings.decode(from: settingsRaw) }
    var stream: StreamSettings { StreamSettings.decode(from: streamSettingsRaw) }

    var clients: [Client] {
        let fromSettings = settings.clients
        if !fromSettings.isEmpty { return fromSettings }
        // Fallback: some panels keep client config outside `settings`; synthesize
        // a display list from the per-client traffic stats (email keyed).
        return clientStats
            .filter { !$0.email.isEmpty }
            .map { stat in
                Client(id: stat.email, email: stat.email, flow: "",
                       totalGB: stat.total, expiryTime: stat.expiryTime, enable: stat.enable)
            }
    }

    var totalTraffic: Int64 { up + down }
}

// MARK: - Inbound settings (nested JSON string)

struct InboundSettings: Decodable {
    var clients: [Client]

    enum CodingKeys: String, CodingKey { case clients }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clients = (try? c.decode([Client].self, forKey: .clients)) ?? []
    }

    init(clients: [Client]) { self.clients = clients }

    static func decode(from raw: String) -> InboundSettings {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(InboundSettings.self, from: data)
        else { return InboundSettings(clients: []) }
        return decoded
    }
}

// MARK: - Client (lives inside settings.clients)

struct Client: Codable, Identifiable, Hashable {
    var id: String            // UUID
    var email: String
    var flow: String
    var totalGB: Int64        // bytes; 0 == unlimited
    var expiryTime: Int64     // ms epoch; 0 == never
    var enable: Bool
    var tgId: String?
    var subId: String?
    var limitIp: Int?

    enum CodingKeys: String, CodingKey {
        case id, email, flow, totalGB, expiryTime, enable, tgId, subId, limitIp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        flow = (try? c.decode(String.self, forKey: .flow)) ?? ""
        totalGB = (try? c.decode(Int64.self, forKey: .totalGB)) ?? 0
        expiryTime = (try? c.decode(Int64.self, forKey: .expiryTime)) ?? 0
        enable = (try? c.decode(Bool.self, forKey: .enable)) ?? true
        // tgId can be sent as number or string by different panel versions
        if let s = try? c.decode(String.self, forKey: .tgId) { tgId = s }
        else if let n = try? c.decode(Int64.self, forKey: .tgId) { tgId = String(n) }
        else { tgId = nil }
        subId = try? c.decode(String.self, forKey: .subId)
        limitIp = try? c.decode(Int.self, forKey: .limitIp)
    }

    init(id: String, email: String, flow: String = "", totalGB: Int64 = 0,
         expiryTime: Int64 = 0, enable: Bool = true, tgId: String? = nil,
         subId: String? = nil, limitIp: Int? = nil) {
        self.id = id; self.email = email; self.flow = flow; self.totalGB = totalGB
        self.expiryTime = expiryTime; self.enable = enable; self.tgId = tgId
        self.subId = subId; self.limitIp = limitIp
    }
}

// MARK: - Client traffic statistics (inbound.clientStats[])

struct ClientStat: Codable, Identifiable, Hashable {
    var id: Int
    var inboundId: Int
    var enable: Bool
    var email: String
    var up: Int64
    var down: Int64
    var expiryTime: Int64
    var total: Int64        // limit in bytes; 0 == unlimited
    var reset: Int?

    enum CodingKeys: String, CodingKey {
        case id, inboundId, enable, email, up, down, expiryTime, total, reset
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        inboundId = (try? c.decode(Int.self, forKey: .inboundId)) ?? 0
        enable = (try? c.decode(Bool.self, forKey: .enable)) ?? true
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        up = (try? c.decode(Int64.self, forKey: .up)) ?? 0
        down = (try? c.decode(Int64.self, forKey: .down)) ?? 0
        expiryTime = (try? c.decode(Int64.self, forKey: .expiryTime)) ?? 0
        total = (try? c.decode(Int64.self, forKey: .total)) ?? 0
        reset = try? c.decode(Int.self, forKey: .reset)
    }

    init(id: Int, inboundId: Int, enable: Bool, email: String, up: Int64,
         down: Int64, expiryTime: Int64, total: Int64, reset: Int? = nil) {
        self.id = id; self.inboundId = inboundId; self.enable = enable
        self.email = email; self.up = up; self.down = down
        self.expiryTime = expiryTime; self.total = total; self.reset = reset
    }

    var used: Int64 { up + down }
}

// MARK: - Stream settings (nested JSON string)

struct StreamSettings: Decodable {
    var network: String
    var security: String
    var reality: RealitySettings?
    var tlsServerName: String?
    var tcpHeaderType: String?
    var wsPath: String?
    var wsHost: String?

    enum CodingKeys: String, CodingKey {
        case network, security, realitySettings, tlsSettings, tcpSettings, wsSettings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        network = (try? c.decode(String.self, forKey: .network)) ?? "tcp"
        security = (try? c.decode(String.self, forKey: .security)) ?? "none"
        reality = try? c.decode(RealitySettings.self, forKey: .realitySettings)

        if let tls = try? c.decode(TLSSettings.self, forKey: .tlsSettings) {
            tlsServerName = tls.serverName
        }
        if let tcp = try? c.decode(TCPSettings.self, forKey: .tcpSettings) {
            tcpHeaderType = tcp.header?.type
        }
        if let ws = try? c.decode(WSSettings.self, forKey: .wsSettings) {
            wsPath = ws.path
            wsHost = ws.headers?.host
        }
    }

    init(network: String, security: String, reality: RealitySettings? = nil,
         tlsServerName: String? = nil, tcpHeaderType: String? = nil,
         wsPath: String? = nil, wsHost: String? = nil) {
        self.network = network; self.security = security; self.reality = reality
        self.tlsServerName = tlsServerName; self.tcpHeaderType = tcpHeaderType
        self.wsPath = wsPath; self.wsHost = wsHost
    }

    static func decode(from raw: String) -> StreamSettings {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(StreamSettings.self, from: data)
        else { return StreamSettings(network: "tcp", security: "none") }
        return decoded
    }
}

struct RealitySettings: Decodable {
    var serverNames: [String]
    var shortIds: [String]
    var publicKey: String
    var fingerprint: String
    var spiderX: String

    enum CodingKeys: String, CodingKey {
        case serverNames, shortIds, settings, dest
    }
    enum SettingsKeys: String, CodingKey {
        case publicKey, fingerprint, spiderX
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverNames = (try? c.decode([String].self, forKey: .serverNames)) ?? []
        shortIds = (try? c.decode([String].self, forKey: .shortIds)) ?? []
        if let s = try? c.nestedContainer(keyedBy: SettingsKeys.self, forKey: .settings) {
            publicKey = (try? s.decode(String.self, forKey: .publicKey)) ?? ""
            fingerprint = (try? s.decode(String.self, forKey: .fingerprint)) ?? "chrome"
            spiderX = (try? s.decode(String.self, forKey: .spiderX)) ?? "/"
        } else {
            publicKey = ""; fingerprint = "chrome"; spiderX = "/"
        }
    }

    init(serverNames: [String], shortIds: [String], publicKey: String,
         fingerprint: String = "chrome", spiderX: String = "/") {
        self.serverNames = serverNames; self.shortIds = shortIds
        self.publicKey = publicKey; self.fingerprint = fingerprint; self.spiderX = spiderX
    }

    var primaryServerName: String { serverNames.first ?? "" }
    var primaryShortId: String { shortIds.first ?? "" }
}

private struct TLSSettings: Decodable { let serverName: String? }
private struct TCPSettings: Decodable {
    struct Header: Decodable { let type: String? }
    let header: Header?
}
private struct WSSettings: Decodable {
    struct Headers: Decodable { let host: String? }
    let path: String?
    let headers: Headers?
}

// MARK: - Server status (/server/status)

struct ServerStatus: Decodable {
    var cpu: Double
    var cpuCores: Int
    var memCurrent: Int64
    var memTotal: Int64
    var swapCurrent: Int64
    var swapTotal: Int64
    var diskCurrent: Int64
    var diskTotal: Int64
    var xrayState: String
    var xrayVersion: String
    var uptime: Int64
    var netUp: Int64        // bytes/sec
    var netDown: Int64      // bytes/sec
    var netSent: Int64      // total bytes
    var netRecv: Int64      // total bytes
    var tcpCount: Int
    var udpCount: Int

    enum CodingKeys: String, CodingKey {
        case cpu, cpuCores, mem, swap, disk, xray, uptime, netIO, netTraffic, tcpCount, udpCount
    }
    enum ResKeys: String, CodingKey { case current, total }
    enum XrayKeys: String, CodingKey { case state, version }
    enum NetKeys: String, CodingKey { case up, down, sent, recv }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cpu = (try? c.decode(Double.self, forKey: .cpu)) ?? 0
        cpuCores = (try? c.decode(Int.self, forKey: .cpuCores)) ?? 0
        uptime = (try? c.decode(Int64.self, forKey: .uptime)) ?? 0
        tcpCount = (try? c.decode(Int.self, forKey: .tcpCount)) ?? 0
        udpCount = (try? c.decode(Int.self, forKey: .udpCount)) ?? 0

        if let m = try? c.nestedContainer(keyedBy: ResKeys.self, forKey: .mem) {
            memCurrent = (try? m.decode(Int64.self, forKey: .current)) ?? 0
            memTotal = (try? m.decode(Int64.self, forKey: .total)) ?? 0
        } else { memCurrent = 0; memTotal = 0 }

        if let s = try? c.nestedContainer(keyedBy: ResKeys.self, forKey: .swap) {
            swapCurrent = (try? s.decode(Int64.self, forKey: .current)) ?? 0
            swapTotal = (try? s.decode(Int64.self, forKey: .total)) ?? 0
        } else { swapCurrent = 0; swapTotal = 0 }

        if let d = try? c.nestedContainer(keyedBy: ResKeys.self, forKey: .disk) {
            diskCurrent = (try? d.decode(Int64.self, forKey: .current)) ?? 0
            diskTotal = (try? d.decode(Int64.self, forKey: .total)) ?? 0
        } else { diskCurrent = 0; diskTotal = 0 }

        if let x = try? c.nestedContainer(keyedBy: XrayKeys.self, forKey: .xray) {
            xrayState = (try? x.decode(String.self, forKey: .state)) ?? "unknown"
            xrayVersion = (try? x.decode(String.self, forKey: .version)) ?? ""
        } else { xrayState = "unknown"; xrayVersion = "" }

        if let n = try? c.nestedContainer(keyedBy: NetKeys.self, forKey: .netIO) {
            netUp = (try? n.decode(Int64.self, forKey: .up)) ?? 0
            netDown = (try? n.decode(Int64.self, forKey: .down)) ?? 0
        } else { netUp = 0; netDown = 0 }

        if let n = try? c.nestedContainer(keyedBy: NetKeys.self, forKey: .netTraffic) {
            netSent = (try? n.decode(Int64.self, forKey: .sent)) ?? 0
            netRecv = (try? n.decode(Int64.self, forKey: .recv)) ?? 0
        } else { netSent = 0; netRecv = 0 }
    }

    init(cpu: Double, cpuCores: Int, memCurrent: Int64, memTotal: Int64,
         swapCurrent: Int64, swapTotal: Int64, diskCurrent: Int64, diskTotal: Int64,
         xrayState: String, xrayVersion: String, uptime: Int64,
         netUp: Int64, netDown: Int64, netSent: Int64, netRecv: Int64,
         tcpCount: Int, udpCount: Int) {
        self.cpu = cpu; self.cpuCores = cpuCores
        self.memCurrent = memCurrent; self.memTotal = memTotal
        self.swapCurrent = swapCurrent; self.swapTotal = swapTotal
        self.diskCurrent = diskCurrent; self.diskTotal = diskTotal
        self.xrayState = xrayState; self.xrayVersion = xrayVersion; self.uptime = uptime
        self.netUp = netUp; self.netDown = netDown; self.netSent = netSent; self.netRecv = netRecv
        self.tcpCount = tcpCount; self.udpCount = udpCount
    }

    var memFraction: Double { memTotal > 0 ? Double(memCurrent) / Double(memTotal) : 0 }
    var diskFraction: Double { diskTotal > 0 ? Double(diskCurrent) / Double(diskTotal) : 0 }
    var xrayRunning: Bool { xrayState.lowercased() == "running" }
}

// MARK: - Online client entry

/// An entry from `/panel/api/inbounds/onlines` when the panel returns objects
/// instead of plain email strings. Reads the email from any common key.
struct OnlineEntry: Decodable {
    let email: String?
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicKey.self)
        for key in ["email", "clientEmail", "name", "user"] {
            if let k = DynamicKey(stringValue: key),
               let v = try? c.decode(String.self, forKey: k), !v.isEmpty {
                email = v
                return
            }
        }
        email = nil
    }
    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}

// MARK: - JSON value helper

/// A minimal, lossless JSON value used to re-serialize fields a panel may return
/// either as a JSON *string* (classic 3x-ui) or a nested JSON *object* (modern
/// 3x-ui / OAS). Lets us normalize both into a raw JSON string.
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
