import Foundation

/// The API models decode a panel-specific JSON shape (nested strings, nested objects).
/// To cache them losslessly we re-encode into the *same* shape so `Inbound`/`ServerStatus`
/// can decode them straight back on the next launch.

struct EncodableInbound: Encodable {
    private let inbound: Inbound
    init(_ inbound: Inbound) { self.inbound = inbound }

    enum CodingKeys: String, CodingKey {
        case id, up, down, total, remark, enable, expiryTime, listen, port
        case `protocol`, settings, streamSettings, tag, clientStats
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(inbound.id, forKey: .id)
        try c.encode(inbound.up, forKey: .up)
        try c.encode(inbound.down, forKey: .down)
        try c.encode(inbound.total, forKey: .total)
        try c.encode(inbound.remark, forKey: .remark)
        try c.encode(inbound.enable, forKey: .enable)
        try c.encode(inbound.expiryTime, forKey: .expiryTime)
        try c.encode(inbound.listen, forKey: .listen)
        try c.encode(inbound.port, forKey: .port)
        try c.encode(inbound.`protocol`, forKey: .protocol)
        try c.encode(inbound.settingsRaw, forKey: .settings)
        try c.encode(inbound.streamSettingsRaw, forKey: .streamSettings)
        try c.encode(inbound.tag, forKey: .tag)
        try c.encode(inbound.clientStats, forKey: .clientStats)
    }
}

struct EncodableStatus: Encodable {
    private let s: ServerStatus
    init(_ status: ServerStatus) { self.s = status }

    enum CodingKeys: String, CodingKey {
        case cpu, cpuCores, mem, swap, disk, xray, uptime, netIO, netTraffic, tcpCount, udpCount
    }
    enum ResKeys: String, CodingKey { case current, total }
    enum XrayKeys: String, CodingKey { case state, version }
    enum NetKeys: String, CodingKey { case up, down, sent, recv }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(s.cpu, forKey: .cpu)
        try c.encode(s.cpuCores, forKey: .cpuCores)
        try c.encode(s.uptime, forKey: .uptime)
        try c.encode(s.tcpCount, forKey: .tcpCount)
        try c.encode(s.udpCount, forKey: .udpCount)

        var mem = c.nestedContainer(keyedBy: ResKeys.self, forKey: .mem)
        try mem.encode(s.memCurrent, forKey: .current)
        try mem.encode(s.memTotal, forKey: .total)

        var swap = c.nestedContainer(keyedBy: ResKeys.self, forKey: .swap)
        try swap.encode(s.swapCurrent, forKey: .current)
        try swap.encode(s.swapTotal, forKey: .total)

        var disk = c.nestedContainer(keyedBy: ResKeys.self, forKey: .disk)
        try disk.encode(s.diskCurrent, forKey: .current)
        try disk.encode(s.diskTotal, forKey: .total)

        var xray = c.nestedContainer(keyedBy: XrayKeys.self, forKey: .xray)
        try xray.encode(s.xrayState, forKey: .state)
        try xray.encode(s.xrayVersion, forKey: .version)

        var netIO = c.nestedContainer(keyedBy: NetKeys.self, forKey: .netIO)
        try netIO.encode(s.netUp, forKey: .up)
        try netIO.encode(s.netDown, forKey: .down)

        var netTraffic = c.nestedContainer(keyedBy: NetKeys.self, forKey: .netTraffic)
        try netTraffic.encode(s.netSent, forKey: .sent)
        try netTraffic.encode(s.netRecv, forKey: .recv)
    }
}
