import SwiftUI
import SwiftData
import Observation

/// Shared, local-first data layer. Fetches from the panel, mirrors into SwiftData,
/// and exposes the last known state instantly on launch.
@MainActor
@Observable
final class DataStore {
    var inbounds: [Inbound] = []
    var onlineEmails: Set<String> = []
    var serverStatus: ServerStatus?
    var trafficSamples: [(date: Date, up: Int64, down: Int64)] = []

    var lastUpdated: Date?
    var isLoading = false
    var error: APIError?

    /// Injected after the SwiftData container is created.
    var context: ModelContext?

    private let maxSamples = 60

    // MARK: - Cache hydration

    func loadFromCache() {
        guard let context else { return }
        // Inbounds
        if let cached = try? context.fetch(FetchDescriptor<CachedInbound>(
            sortBy: [SortDescriptor(\.port)])) {
            let decoded = cached.compactMap { row -> Inbound? in
                try? JSONDecoder().decode(Inbound.self, from: row.rawJSON)
            }
            if !decoded.isEmpty {
                inbounds = decoded
                lastUpdated = cached.map(\.updatedAt).max()
            }
        }
        // Server status
        if let row = try? context.fetch(FetchDescriptor<CachedServerStatus>()).first,
           let status = try? JSONDecoder().decode(ServerStatus.self, from: row.rawJSON) {
            serverStatus = status
        }
        // Traffic samples
        if let samples = try? context.fetch(FetchDescriptor<TrafficSample>(
            sortBy: [SortDescriptor(\.timestamp)])) {
            trafficSamples = samples.map { (date: $0.timestamp, up: $0.up, down: $0.down) }
        }
        rebuildClientRows()
    }

    // MARK: - Refresh

    func refreshAll() async {
        isLoading = true
        error = nil
        do {
            async let inboundsTask = APIClient.shared.fetchInbounds()
            async let onlinesTask = APIClient.shared.fetchOnlineClients()
            async let statusTask = APIClient.shared.fetchServerStatus()

            let fetchedInbounds = try await inboundsTask
            let fetchedOnlines = (try? await onlinesTask) ?? []
            let fetchedStatus = try? await statusTask

            inbounds = fetchedInbounds
            onlineEmails = Set(fetchedOnlines)
            rebuildClientRows()
            if let fetchedStatus {
                serverStatus = fetchedStatus
                appendSample(up: fetchedStatus.netUp, down: fetchedStatus.netDown)
            }
            lastUpdated = Date()
            persist(inbounds: fetchedInbounds, status: fetchedStatus)
        } catch {
            self.error = APIError.from(error)
        }
        isLoading = false
    }

    func refreshOnlines() async {
        if let onlines = try? await APIClient.shared.fetchOnlineClients() {
            onlineEmails = Set(onlines)
            rebuildClientRows()
        }
    }

    // MARK: - Client mutations (optimistic refresh)

    func addInbound(jsonBody: Data) async throws {
        try await APIClient.shared.addInbound(jsonBody: jsonBody)
        await refreshAll()
    }

    func deleteInbound(id: Int) async throws {
        try await APIClient.shared.deleteInbound(id: id)
        await refreshAll()
    }

    func setInboundEnable(id: Int, enable: Bool) async throws {
        try await APIClient.shared.setInboundEnable(id: id, enable: enable)
        await refreshAll()
    }

    func addClient(inboundId: Int, client: Client) async throws {
        try await addClient(inboundIds: [inboundId], client: client)
    }

    func addClient(inboundIds: [Int], client: Client) async throws {
        try await APIClient.shared.addClient(inboundIds: inboundIds, client: client)
        await refreshAll()
    }

    func updateClient(inboundId: Int, client: Client) async throws {
        try await updateClient(inboundIds: [inboundId], client: client)
    }

    func updateClient(inboundIds: [Int], client: Client) async throws {
        try await APIClient.shared.updateClient(inboundIds: inboundIds, client: client)
        await refreshAll()
    }

    func deleteClient(inboundId: Int, client: Client) async throws {
        try await APIClient.shared.deleteClient(inboundId: inboundId, client: client)
        await refreshAll()
    }

    func resetTraffic(inboundId: Int, email: String) async throws {
        try await APIClient.shared.resetClientTraffic(inboundId: inboundId, email: email)
        await refreshAll()
    }

    /// Toggle enable flag, preserving the client's full set of attached inbounds.
    func toggleClient(inboundId: Int, client: Client) async throws {
        var updated = client
        updated.enable.toggle()
        let ids = inboundIds(forEmail: client.email)
        try await updateClient(inboundIds: ids.isEmpty ? [inboundId] : ids, client: updated)
    }

    // MARK: - Derived data (cached for performance)

    /// Rebuilt once whenever inbounds/onlines change, so views (search, filters)
    /// don't re-parse every inbound's settings JSON on each keystroke.
    var allClientRows: [ClientRow] = []

    func rebuildClientRows() {
        allClientRows = inbounds.flatMap { inbound in
            let stats = inbound.clientStats
            return inbound.clients.map { client in
                ClientRow(
                    client: client,
                    inbound: inbound,
                    stat: stats.first { $0.email == client.email },
                    isOnline: onlineEmails.contains(client.email)
                )
            }
        }
    }

    func inbound(withId id: Int) -> Inbound? { inbounds.first { $0.id == id } }

    func clientRows(forInbound id: Int) -> [ClientRow] {
        allClientRows.filter { $0.inbound.id == id }
    }

    /// Inbound IDs a client (by email) is currently attached to.
    func inboundIds(forEmail email: String) -> [Int] {
        inbounds.filter { inb in inb.clients.contains { $0.email == email } }.map { $0.id }
    }

    /// One representative row per unique client (by email).
    var uniqueClientRows: [ClientRow] {
        var seen = Set<String>()
        var result: [ClientRow] = []
        for row in allClientRows {
            let key = row.client.email.isEmpty ? row.id : row.client.email
            if seen.insert(key).inserted { result.append(row) }
        }
        return result
    }

    /// Distinct clients (by email), so a client on multiple inbounds counts once.
    var totalClients: Int { uniqueClientRows.count }
    var onlineCount: Int { onlineEmails.count }
    var expiringSoonCount: Int { uniqueClientRows.filter { $0.isExpiringSoon }.count }
    var overLimitCount: Int { uniqueClientRows.filter { $0.isOverEighty }.count }
    var disabledCount: Int { uniqueClientRows.filter { !$0.client.enable }.count }
    var expiredCount: Int { uniqueClientRows.filter { $0.isExpired }.count }
    var totalTraffic: Int64 { inbounds.reduce(0) { $0 + $1.totalTraffic } }

    // MARK: - Persistence

    private func appendSample(up: Int64, down: Int64) {
        trafficSamples.append((date: Date(), up: up, down: down))
        if trafficSamples.count > maxSamples {
            trafficSamples.removeFirst(trafficSamples.count - maxSamples)
        }
        guard let context else { return }
        context.insert(TrafficSample(timestamp: Date(), up: up, down: down))
        // Trim old samples
        if let all = try? context.fetch(FetchDescriptor<TrafficSample>(
            sortBy: [SortDescriptor(\.timestamp)])), all.count > maxSamples {
            for row in all.prefix(all.count - maxSamples) { context.delete(row) }
        }
        try? context.save()
    }

    private func persist(inbounds: [Inbound], status: ServerStatus?) {
        guard let context else { return }
        // Replace inbound cache
        if let existing = try? context.fetch(FetchDescriptor<CachedInbound>()) {
            for row in existing { context.delete(row) }
        }
        for inbound in inbounds {
            guard let data = try? JSONEncoder().encode(EncodableInbound(inbound)) else { continue }
            context.insert(CachedInbound(
                inboundId: inbound.id, remark: inbound.remark, proto: inbound.`protocol`,
                port: inbound.port, enable: inbound.enable, up: inbound.up, down: inbound.down,
                total: inbound.total, expiryTime: inbound.expiryTime,
                clientCount: inbound.clients.count, rawJSON: data, updatedAt: Date()))
        }
        // Server status singleton
        if let status, let data = try? JSONEncoder().encode(EncodableStatus(status)) {
            if let existing = try? context.fetch(FetchDescriptor<CachedServerStatus>()) {
                for row in existing { context.delete(row) }
            }
            context.insert(CachedServerStatus(rawJSON: data, updatedAt: Date()))
        }
        try? context.save()
    }

    func clear() {
        inbounds = []
        onlineEmails = []
        allClientRows = []
        serverStatus = nil
        trafficSamples = []
        lastUpdated = nil
        guard let context else { return }
        try? context.delete(model: CachedInbound.self)
        try? context.delete(model: CachedServerStatus.self)
        try? context.delete(model: TrafficSample.self)
        try? context.save()
    }
}

/// A client paired with everything a row needs to render.
struct ClientRow: Identifiable, Hashable {
    let client: Client
    let inbound: Inbound
    let stat: ClientStat?
    let isOnline: Bool

    var id: String { "\(inbound.id)-\(client.id)" }

    var used: Int64 { stat?.used ?? 0 }
    var limit: Int64 { client.totalGB }
    var trafficFraction: Double { Fmt.trafficFraction(used: used, limit: limit) }

    var isExpired: Bool {
        guard let days = Fmt.daysRemaining(expiryMs: client.expiryTime) else { return false }
        return days < 0
    }
    var isExpiringSoon: Bool {
        guard let days = Fmt.daysRemaining(expiryMs: client.expiryTime) else { return false }
        return days >= 0 && days < 3
    }
    var isOverEighty: Bool { trafficFraction >= 0.8 }

    /// Status dot color priority: expired > offline/online.
    var statusColor: Color {
        if !client.enable { return Theme.offline }
        if isExpired { return Theme.expired }
        return isOnline ? Theme.online : Theme.offline
    }
}
