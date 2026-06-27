import SwiftUI

/// Full V2BOX-style server editor: every field, adaptive to the protocol.
struct ServerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProxyProfile
    let isNew: Bool
    let onSave: (ProxyProfile) -> Void
    let onDelete: (() -> Void)?

    init(profile: ProxyProfile, isNew: Bool,
         onSave: @escaping (ProxyProfile) -> Void, onDelete: (() -> Void)? = nil) {
        _draft = State(initialValue: profile)
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "New Server" : "Edit Server").font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
            }
            .padding(20)
            Divider()

            Form {
                Section("General") {
                    Picker("Protocol", selection: $draft.type) {
                        ForEach(ProxyType.allCases, id: \.self) { Text($0.display).tag($0) }
                    }
                    TextField("Remarks", text: $draft.name, prompt: Text("My server"))
                    TextField("Address", text: $draft.server, prompt: Text("example.com"))
                    TextField("Port", value: $draft.port, format: .number.grouping(.never))
                    credentialFields
                }

                if usesTransport { transportSection }
                if usesTLS { tlsSection }
                protocolExtras

                if let onDelete {
                    Section {
                        Button("Delete", role: .destructive) { onDelete(); dismiss() }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 520, height: 660)
    }

    // MARK: - Sections

    @ViewBuilder private var credentialFields: some View {
        switch draft.type {
        case .vmess:
            TextField("ID (UUID)", text: $draft.uuid)
            Picker("Encryption", selection: $draft.encryption) {
                ForEach(["auto", "none", "aes-128-gcm", "chacha20-poly1305", "zero"], id: \.self) { Text($0).tag($0) }
            }
            TextField("AlterId", value: $draft.alterId, format: .number.grouping(.never))
        case .vless:
            TextField("ID (UUID)", text: $draft.uuid)
            Picker("Flow", selection: $draft.flow) {
                Text("none").tag("")
                Text("xtls-rprx-vision").tag("xtls-rprx-vision")
            }
        case .trojan, .hysteria2:
            TextField("Password", text: $draft.password)
        case .tuic:
            TextField("UUID", text: $draft.uuid)
            TextField("Password", text: $draft.password)
        case .shadowsocks:
            Picker("Method", selection: $draft.method) {
                ForEach(["aes-128-gcm", "aes-256-gcm", "chacha20-ietf-poly1305", "2022-blake3-aes-128-gcm", "2022-blake3-aes-256-gcm", "none"], id: \.self) { Text($0).tag($0) }
            }
            TextField("Password", text: $draft.password)
        case .wireguard, .socks, .http:
            EmptyView()
        }
    }

    private var transportSection: some View {
        Section("Transport") {
            Picker("Network", selection: $draft.network) {
                ForEach(["tcp", "ws", "grpc", "http"], id: \.self) { Text($0).tag($0) }
            }
            if draft.network == "grpc" {
                TextField("gRPC service name", text: $draft.path)
            } else if draft.network != "tcp" {
                TextField("Path", text: $draft.path, prompt: Text("/"))
                TextField("Host", text: $draft.hostHeader)
            }
        }
    }

    private var tlsSection: some View {
        Section("TLS / Reality") {
            Picker("Security", selection: securityBinding) {
                Text("none").tag("none")
                Text("tls").tag("tls")
                Text("reality").tag("reality")
            }
            if draft.tls || draft.reality {
                TextField("SNI (server name)", text: $draft.sni)
                TextField("ALPN (comma separated)", text: alpnText)
                Picker("uTLS fingerprint", selection: $draft.fingerprint) {
                    Text("none").tag("")
                    ForEach(["chrome", "firefox", "safari", "ios", "edge", "random"], id: \.self) { Text($0).tag($0) }
                }
                if draft.reality {
                    TextField("Public key (pbk)", text: $draft.publicKey)
                    TextField("Short ID (sid)", text: $draft.shortId)
                } else {
                    Toggle("Allow insecure", isOn: $draft.insecure)
                }
            }
        }
    }

    @ViewBuilder private var protocolExtras: some View {
        switch draft.type {
        case .hysteria2:
            Section("Hysteria2") {
                TextField("Obfs type (salamander)", text: $draft.obfs)
                TextField("Obfs password", text: $draft.obfsPassword)
                tlsExtraForQUIC
            }
        case .tuic:
            Section("TUIC") {
                Picker("Congestion control", selection: $draft.congestionControl) {
                    ForEach(["bbr", "cubic", "new_reno"], id: \.self) { Text($0).tag($0) }
                }
                Picker("UDP relay mode", selection: $draft.udpRelayMode) {
                    ForEach(["native", "quic"], id: \.self) { Text($0).tag($0) }
                }
                tlsExtraForQUIC
            }
        case .wireguard:
            Section("WireGuard") {
                TextField("Private key", text: $draft.privateKey)
                TextField("Peer public key", text: $draft.peerPublicKey)
                TextField("Pre-shared key (optional)", text: $draft.preSharedKey)
                TextField("Local address(es)", text: localAddrText, prompt: Text("172.16.0.2/32"))
                TextField("Reserved (comma)", text: reservedText)
            }
        default:
            EmptyView()
        }
    }

    /// Hysteria2/TUIC always use TLS; expose SNI/insecure/ALPN here.
    private var tlsExtraForQUIC: some View {
        Group {
            TextField("SNI (server name)", text: $draft.sni)
            TextField("ALPN (comma separated)", text: alpnText)
            Toggle("Allow insecure", isOn: $draft.insecure)
        }
    }

    // MARK: - Bindings & helpers

    private var usesTransport: Bool { [.vmess, .vless, .trojan].contains(draft.type) }
    private var usesTLS: Bool { [.vmess, .vless, .trojan].contains(draft.type) }

    private var securityBinding: Binding<String> {
        Binding(
            get: { draft.reality ? "reality" : (draft.tls ? "tls" : "none") },
            set: { v in
                draft.reality = (v == "reality")
                draft.tls = (v == "tls" || v == "reality")
            }
        )
    }
    private var alpnText: Binding<String> {
        Binding(get: { draft.alpn.joined(separator: ",") },
                set: { draft.alpn = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } })
    }
    private var localAddrText: Binding<String> {
        Binding(get: { draft.localAddresses.joined(separator: ",") },
                set: { draft.localAddresses = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } })
    }
    private var reservedText: Binding<String> {
        Binding(get: { draft.reserved.map(String.init).joined(separator: ",") },
                set: { draft.reserved = $0.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } })
    }

    private func save() {
        var d = draft
        d.server = d.server.trimmingCharacters(in: .whitespaces)
        d.name = d.name.trimmingCharacters(in: .whitespaces)
        if d.name.isEmpty { d.name = d.server }
        onSave(d)
        dismiss()
    }
}
