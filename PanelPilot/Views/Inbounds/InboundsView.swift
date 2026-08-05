import SwiftUI
import CryptoKit

struct InboundsView: View {
    @Environment(AppState.self) private var app
    private var store: DataStore { app.store }

    @State private var showAddInbound = false
    @State private var toast: ToastData?
    @State private var inboundToDelete: Inbound?

    var body: some View {
        NavigationStack {
            Group {
                if store.inbounds.isEmpty {
                    if store.isLoading {
                        ScrollView { SkeletonList(count: 4).padding(.top, 8) }
                    } else if let error = store.error {
                        ScrollView {
                            ErrorStateView(error: error) { Task { await store.refreshAll() } }
                                .padding(.top, 60)
                        }
                    } else {
                        EmptyStateView(systemImage: "tray",
                                       title: "inbounds.empty".loc,
                                       message: "inbounds.empty_hint".loc)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.inbounds) { inbound in
                                NavigationLink(value: inbound.id) {
                                    InboundCard(inbound: inbound,
                                                onlineCount: onlineCount(for: inbound))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        Haptics.tap(); toggleInbound(inbound)
                                    } label: {
                                        Label(inbound.enable ? "common.disabled".loc : "common.enabled".loc,
                                              systemImage: inbound.enable ? "pause.circle" : "play.circle")
                                    }
                                    Button(role: .destructive) {
                                        Haptics.warning(); inboundToDelete = inbound
                                    } label: {
                                        Label("common.delete".loc, systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(ScreenBackground())
            .scrollContentBackground(.hidden)
            .navigationTitle("inbounds.title".loc)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        Button {
                            Haptics.tap(); showAddInbound = true
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accentGradient)
                        }
                        RefreshButton(isLoading: store.isLoading) {
                            Task { await store.refreshAll() }
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddInbound) {
                InboundEditorView(toast: $toast)
            }
            .confirmationDialog("inbound.delete_confirm".loc,
                                isPresented: Binding(get: { inboundToDelete != nil },
                                                     set: { if !$0 { inboundToDelete = nil } }),
                                titleVisibility: .visible) {
                Button("common.delete".loc, role: .destructive) {
                    if let inbound = inboundToDelete { deleteInbound(inbound) }
                }
                Button("common.cancel".loc, role: .cancel) { inboundToDelete = nil }
            } message: {
                Text(inboundToDelete.map { $0.remark.isEmpty ? $0.tag : $0.remark } ?? "")
            }
            .toast($toast)
            .navigationDestination(for: Int.self) { id in
                if let inbound = store.inbound(withId: id) {
                    InboundDetailView(inboundId: inbound.id)
                }
            }
            .refreshable { await store.refreshAll() }
        }
    }

    private func onlineCount(for inbound: Inbound) -> Int {
        inbound.clients.filter { store.onlineEmails.contains($0.email) }.count
    }

    private func toggleInbound(_ inbound: Inbound) {
        Task {
            do {
                try await store.setInboundEnable(id: inbound.id, enable: !inbound.enable)
                toast = ToastData(message: "toast.saved".loc)
            } catch {
                toast = ToastData(message: (error as? APIError)?.errorDescription ?? "",
                                  symbol: "exclamationmark.triangle")
            }
        }
    }

    private func deleteInbound(_ inbound: Inbound) {
        Task {
            do {
                try await store.deleteInbound(id: inbound.id)
                Haptics.success()
                toast = ToastData(message: "toast.client_deleted".loc, symbol: "trash")
            } catch {
                toast = ToastData(message: (error as? APIError)?.errorDescription ?? "",
                                  symbol: "exclamationmark.triangle")
            }
            inboundToDelete = nil
        }
    }
}

struct InboundCard: View {
    let inbound: Inbound
    let onlineCount: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            StatusDot(color: inbound.enable ? Theme.online : Theme.offline)
                            Text(inbound.remark.isEmpty ? inbound.tag : inbound.remark)
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Text("inbounds.port".loc(Fmt.digits(String(inbound.port))))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    protocolBadge
                }

                HStack(spacing: 10) {
                    pill(systemImage: "person.2.fill",
                         text: Fmt.digits("inbounds.clients_count".loc(inbound.clients.count)))
                    pill(systemImage: "dot.radiowaves.left.and.right",
                         text: Fmt.count(onlineCount), tint: Theme.online)
                }

                HStack(spacing: 16) {
                    trafficLabel("arrow.up", Fmt.bytes(inbound.up), Theme.accentIndigo)
                    trafficLabel("arrow.down", Fmt.bytes(inbound.down), Theme.accentCyan)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private var protocolBadge: some View {
        Text(inbound.`protocol`.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundStyle(.white)
            .background(Theme.accentGradient, in: Capsule())
    }

    private func pill(systemImage: String, text: String, tint: Color = Theme.textSecondary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage).font(.caption2)
            Text(text).font(.caption.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.white.opacity(0.05), in: Capsule())
    }

    private func trafficLabel(_ symbol: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption2).foregroundStyle(tint)
            Text(value).font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
        }
    }
}

#Preview {
    InboundsView()
        .environment(AppState.preview())
        .preferredColorScheme(.dark)
}

// MARK: - Add inbound

/// Minimal inbound creator for the two most common setups: VLESS+Reality
/// (keys generated on-device) and VMess over WebSocket. Sends the inbound as
/// a nested-JSON payload to POST /panel/api/inbounds/add.
struct InboundEditorView: View {
    @Binding var toast: ToastData?
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    private var store: DataStore { app.store }

    enum Kind: String, CaseIterable, Identifiable {
        case vlessReality, vmessWS
        var id: String { rawValue }
        var title: String {
            switch self {
            case .vlessReality: return "VLESS + Reality"
            case .vmessWS: return "VMess + WS"
            }
        }
    }

    @State private var kind: Kind = .vlessReality
    @State private var remark = ""
    @State private var port = "443"
    @State private var sni = "yahoo.com"
    @State private var wsPath = "/"
    @State private var isSaving = false
    @State private var error: APIError?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("inbound.type".loc)
                                .font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
                            Picker("", selection: $kind) {
                                ForEach(Kind.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            field("inbound.remark".loc, text: $remark, symbol: "tag", keyboard: .default)
                            Divider().overlay(Theme.cardStroke)
                            field("inbound.port_label".loc, text: $port, symbol: "number", keyboard: .numberPad)
                            if kind == .vlessReality {
                                Divider().overlay(Theme.cardStroke)
                                field("inbound.sni".loc, text: $sni, symbol: "globe", keyboard: .URL)
                                Text("inbound.reality_hint".loc)
                                    .font(.caption2).foregroundStyle(Theme.textTertiary)
                            } else {
                                Divider().overlay(Theme.cardStroke)
                                field("inbound.ws_path".loc, text: $wsPath, symbol: "point.topleft.down.curvedto.point.bottomright.up", keyboard: .URL)
                            }
                        }
                    }

                    if let error {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: error.symbol)
                            Text(error.errorDescription ?? "")
                                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        }
                        .font(.footnote).foregroundStyle(Theme.expired)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(title: "inbound.create".loc, systemImage: "plus",
                                  isLoading: isSaving,
                                  isEnabled: !remark.isEmpty && Int(port) != nil) { save() }
                }
                .padding()
            }
            .background(ScreenBackground())
            .scrollContentBackground(.hidden)
            .navigationTitle("inbound.new".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".loc) { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func field(_ title: String, text: Binding<String>, symbol: String,
                       keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
            TextField("", text: text)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(keyboard).foregroundStyle(Theme.textPrimary)
        }
    }

    private func save() {
        guard let portNum = Int(port) else { return }
        error = nil
        isSaving = true
        let payload: [String: Any] = kind == .vlessReality
            ? RealityKeygen.vlessRealityInbound(remark: remark, port: portNum, sni: sni)
            : RealityKeygen.vmessWSInbound(remark: remark, port: portNum, path: wsPath)
        Task {
            do {
                let data = try JSONSerialization.data(withJSONObject: payload)
                try await store.addInbound(jsonBody: data)
                toast = ToastData(message: "toast.saved".loc)
                Haptics.success()
                dismiss()
            } catch {
                self.error = APIError.from(error)
                Haptics.error()
            }
            isSaving = false
        }
    }
}

/// Builds inbound payloads and generates Reality X25519 keys on-device.
enum RealityKeygen {
    static func keyPair() -> (privateKey: String, publicKey: String) {
        let priv = Curve25519.KeyAgreement.PrivateKey()
        return (priv.rawRepresentation.base64URLNoPad,
                priv.publicKey.rawRepresentation.base64URLNoPad)
    }

    static func shortId(_ bytes: Int = 4) -> String {
        (0..<(bytes * 2)).map { _ in "0123456789abcdef".randomElement()! }
            .reduce(into: "") { $0.append($1) }
    }

    static func vlessRealityInbound(remark: String, port: Int, sni: String) -> [String: Any] {
        let keys = keyPair()
        let serverName = sni.trimmingCharacters(in: .whitespaces).isEmpty ? "yahoo.com" : sni

        let realitySettings: [String: Any] = [
            "show": false,
            "dest": "\(serverName):443",
            "xver": 0,
            "serverNames": [serverName],
            "privateKey": keys.privateKey,
            "shortIds": [shortId()],
            "settings": ["publicKey": keys.publicKey, "fingerprint": "chrome", "spiderX": "/"]
        ]
        let streamSettings: [String: Any] = [
            "network": "tcp",
            "security": "reality",
            "realitySettings": realitySettings,
            "tcpSettings": ["header": ["type": "none"]]
        ]
        let settings: [String: Any] = [
            "clients": [Any](), "decryption": "none", "fallbacks": [Any]()
        ]
        let sniffing: [String: Any] = ["enabled": true, "destOverride": ["http", "tls", "quic"]]

        return [
            "remark": remark, "enable": true, "listen": "", "port": port,
            "protocol": "vless", "expiryTime": 0, "total": 0,
            "settings": settings, "streamSettings": streamSettings, "sniffing": sniffing
        ]
    }

    static func vmessWSInbound(remark: String, port: Int, path: String) -> [String: Any] {
        let wsPath = path.isEmpty ? "/" : path
        let streamSettings: [String: Any] = [
            "network": "ws",
            "security": "none",
            "wsSettings": ["path": wsPath, "headers": [String: String]()]
        ]
        let settings: [String: Any] = ["clients": [Any]()]
        let sniffing: [String: Any] = ["enabled": true, "destOverride": ["http", "tls", "quic"]]

        return [
            "remark": remark, "enable": true, "listen": "", "port": port,
            "protocol": "vmess", "expiryTime": 0, "total": 0,
            "settings": settings, "streamSettings": streamSettings, "sniffing": sniffing
        ]
    }
}

extension Data {
    /// base64url without padding — the encoding Xray uses for Reality keys.
    var base64URLNoPad: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
