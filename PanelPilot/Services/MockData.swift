import Foundation

/// Fake data for SwiftUI previews and the built-in mock mode.
enum MockData {
    static let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
    static let gb: Int64 = 1024 * 1024 * 1024

    static var realityStream: String {
        """
        {"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"yahoo.com:443","serverNames":["yahoo.com","www.yahoo.com"],"privateKey":"xxx","shortIds":["0453b3b8"],"settings":{"publicKey":"o4B1234PublicKeyExampleABCDEF_gHiJkLmNoPqRsTuVwXyZ012","fingerprint":"chrome","spiderX":"/"}}}
        """
    }

    static var clientsSettings: String {
        """
        {"clients":[
        {"id":"9f8b1c2d-3e4f-5a6b-7c8d-9e0f1a2b3c4d","email":"amir-vip","flow":"xtls-rprx-vision","totalGB":\(107374182400),"expiryTime":\(nowMs + 20*86_400_000),"enable":true},
        {"id":"1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d","email":"sara","flow":"xtls-rprx-vision","totalGB":\(53687091200),"expiryTime":\(nowMs + 2*86_400_000),"enable":true},
        {"id":"2b3c4d5e-6f7a-8b9c-0d1e-2f3a4b5c6d7e","email":"reza-expired","flow":"","totalGB":\(10737418240),"expiryTime":\(nowMs - 5*86_400_000),"enable":true},
        {"id":"3c4d5e6f-7a8b-9c0d-1e2f-3a4b5c6d7e8f","email":"guest","flow":"","totalGB":0,"expiryTime":0,"enable":false}
        ],"decryption":"none","fallbacks":[]}
        """
    }

    static var inbounds: [Inbound] {
        let stats = [
            ClientStat(id: 1, inboundId: 1, enable: true, email: "amir-vip",
                       up: 12 * gb, down: 78 * gb, expiryTime: nowMs + 20*86_400_000,
                       total: 100 * gb),
            ClientStat(id: 2, inboundId: 1, enable: true, email: "sara",
                       up: 3 * gb, down: 42 * gb, expiryTime: nowMs + 2*86_400_000,
                       total: 50 * gb),
            ClientStat(id: 3, inboundId: 1, enable: true, email: "reza-expired",
                       up: 1 * gb, down: 2 * gb, expiryTime: nowMs - 5*86_400_000,
                       total: 10 * gb),
            ClientStat(id: 4, inboundId: 1, enable: false, email: "guest",
                       up: 0, down: 0, expiryTime: 0, total: 0)
        ]
        let reality = Inbound(
            id: 1, up: 16 * gb, down: 124 * gb, total: 0,
            remark: "Reality-Germany", enable: true, expiryTime: 0,
            listen: "", port: 443, protocol: "vless",
            settingsRaw: clientsSettings, streamSettingsRaw: realityStream,
            tag: "inbound-443", clientStats: stats
        )
        let ws = Inbound(
            id: 2, up: 4 * gb, down: 31 * gb, total: 0,
            remark: "WS-CDN", enable: true, expiryTime: 0,
            listen: "", port: 8443, protocol: "vmess",
            settingsRaw: "{\"clients\":[{\"id\":\"aaaa-bbbb\",\"email\":\"cdn-user\",\"totalGB\":0,\"expiryTime\":0,\"enable\":true}]}",
            streamSettingsRaw: "{\"network\":\"ws\",\"security\":\"none\",\"wsSettings\":{\"path\":\"/vpn\",\"headers\":{\"host\":\"cdn.example.com\"}}}",
            tag: "inbound-8443",
            clientStats: [ClientStat(id: 5, inboundId: 2, enable: true, email: "cdn-user",
                                     up: 1 * gb, down: 30 * gb, expiryTime: 0, total: 0)]
        )
        return [reality, ws]
    }

    static let onlineEmails = ["amir-vip", "cdn-user"]

    static var serverStatus: ServerStatus {
        ServerStatus(
            cpu: 23.4, cpuCores: 4,
            memCurrent: Int64(1.9 * Double(gb)), memTotal: 4 * gb,
            swapCurrent: 0, swapTotal: gb,
            diskCurrent: 18 * gb, diskTotal: 40 * gb,
            xrayState: "running", xrayVersion: "1.8.24",
            uptime: 842_133,
            netUp: 2_400_000, netDown: 8_600_000,
            netSent: 512 * gb, netRecv: 1024 * gb,
            tcpCount: 128, udpCount: 22
        )
    }
}
