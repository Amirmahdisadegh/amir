import Foundation
import SwiftData

/// SwiftData-backed cache so the app opens instantly offline with the last known state.
/// We store the raw inbound JSON payload plus a decoded convenience mirror.

@Model
final class CachedInbound {
    @Attribute(.unique) var inboundId: Int
    var remark: String
    var proto: String
    var port: Int
    var enable: Bool
    var up: Int64
    var down: Int64
    var total: Int64
    var expiryTime: Int64
    var clientCount: Int
    /// Full raw JSON for the inbound so we can rebuild the `Inbound` model losslessly offline.
    var rawJSON: Data
    var updatedAt: Date

    init(inboundId: Int, remark: String, proto: String, port: Int, enable: Bool,
         up: Int64, down: Int64, total: Int64, expiryTime: Int64,
         clientCount: Int, rawJSON: Data, updatedAt: Date) {
        self.inboundId = inboundId
        self.remark = remark
        self.proto = proto
        self.port = port
        self.enable = enable
        self.up = up
        self.down = down
        self.total = total
        self.expiryTime = expiryTime
        self.clientCount = clientCount
        self.rawJSON = rawJSON
        self.updatedAt = updatedAt
    }
}

@Model
final class CachedServerStatus {
    @Attribute(.unique) var key: String   // singleton row
    var rawJSON: Data
    var updatedAt: Date

    init(rawJSON: Data, updatedAt: Date) {
        self.key = "current"
        self.rawJSON = rawJSON
        self.updatedAt = updatedAt
    }
}

/// A single traffic sample used to build the dashboard chart over the session lifetime.
@Model
final class TrafficSample {
    var timestamp: Date
    var up: Int64      // bytes/sec
    var down: Int64    // bytes/sec

    init(timestamp: Date, up: Int64, down: Int64) {
        self.timestamp = timestamp
        self.up = up
        self.down = down
    }
}
