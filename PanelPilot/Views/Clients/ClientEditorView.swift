import SwiftUI

/// Add or edit a client. `existing == nil` means "add".
struct ClientEditorView: View {
    let inbound: Inbound
    let existing: Client?
    @Binding var toast: ToastData?

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    private var store: DataStore { app.store }

    @State private var email: String
    @State private var uuid: String
    @State private var limitGB: Double
    @State private var expiryDays: Double
    @State private var enable: Bool
    @State private var flow: String
    @State private var ipLimit: Double
    @State private var tgId: String
    @State private var selectedInboundIds: Set<Int>
    @State private var didLoadSelection = false
    @State private var isSaving = false
    @State private var error: APIError?

    private let flowOptions = ["", "xtls-rprx-vision"]

    init(inbound: Inbound, existing: Client?, toast: Binding<ToastData?>) {
        self.inbound = inbound
        self.existing = existing
        self._toast = toast
        _email = State(initialValue: existing?.email ?? "")
        _uuid = State(initialValue: existing?.id ?? UUID().uuidString)
        _limitGB = State(initialValue: existing.map { Double($0.totalGB) / 1_073_741_824 } ?? 0)
        _enable = State(initialValue: existing?.enable ?? true)
        _flow = State(initialValue: existing?.flow ?? defaultFlow(for: inbound))
        _ipLimit = State(initialValue: Double(existing?.limitIp ?? 0))
        _tgId = State(initialValue: existing?.tgId ?? "")
        _selectedInboundIds = State(initialValue: [inbound.id])
        if let expiry = existing?.expiryTime, expiry > 0 {
            let days = (Double(expiry) / 1000 - Date().timeIntervalSince1970) / 86_400
            _expiryDays = State(initialValue: max(0, days.rounded()))
        } else {
            _expiryDays = State(initialValue: 0)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            labeledField("client.email".loc, symbol: "person") {
                                TextField("", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            Divider().overlay(Theme.cardStroke)
                            labeledField("client.uuid".loc, symbol: "number") {
                                HStack {
                                    Text(uuid)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Button {
                                        Haptics.tap(); uuid = UUID().uuidString
                                    } label: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .foregroundStyle(Theme.accentCyan)
                                    }
                                    .disabled(existing != nil)
                                    .opacity(existing != nil ? 0.4 : 1)
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            sliderField(title: "client.traffic_limit".loc,
                                        hint: "client.unlimited_hint".loc,
                                        value: $limitGB, range: 0...1000, step: 5,
                                        display: limitGB == 0 ? "common.unlimited".loc
                                                               : Fmt.digits("\(Int(limitGB)) GB"))
                            Divider().overlay(Theme.cardStroke)
                            sliderField(title: "client.expiry_days".loc,
                                        hint: "client.no_expiry_hint".loc,
                                        value: $expiryDays, range: 0...365, step: 1,
                                        display: expiryDays == 0 ? "common.never".loc
                                                                 : Fmt.digits("\(Int(expiryDays)) d"))
                            Divider().overlay(Theme.cardStroke)
                            sliderField(title: "client.ip_limit".loc,
                                        hint: "client.ip_limit_hint".loc,
                                        value: $ipLimit, range: 0...20, step: 1,
                                        display: ipLimit == 0 ? "common.unlimited".loc
                                                              : Fmt.digits("\(Int(ipLimit))"))
                        }
                    }

                    GlassCard {
                        labeledField("client.telegram_id".loc, symbol: "paperplane") {
                            TextField("", text: $tgId)
                                .keyboardType(.numbersAndPunctuation)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }

                    if store.inbounds.count > 1 {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "client.inbounds".loc, symbol: "square.stack.3d.up")
                                ForEach(store.inbounds) { inb in
                                    Button {
                                        Haptics.tap(); toggleInbound(inb.id)
                                    } label: {
                                        HStack {
                                            Image(systemName: selectedInboundIds.contains(inb.id)
                                                  ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedInboundIds.contains(inb.id)
                                                                 ? Theme.accentCyan : Theme.textTertiary)
                                            Text(inb.remark.isEmpty ? inb.tag : inb.remark)
                                                .foregroundStyle(Theme.textPrimary)
                                            Spacer()
                                            Text(inb.`protocol`.uppercased())
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(spacing: 14) {
                            if inbound.`protocol`.lowercased() == "vless" {
                                HStack {
                                    Label("client.flow".loc, systemImage: "arrow.triangle.branch")
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Picker("", selection: $flow) {
                                        Text("—").tag("")
                                        Text("vision").tag("xtls-rprx-vision")
                                    }
                                    .tint(Theme.accentCyan)
                                }
                                Divider().overlay(Theme.cardStroke)
                            }
                            Toggle(isOn: $enable) {
                                Label("client.enable".loc, systemImage: "power")
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .tint(Theme.accentCyan)
                        }
                    }

                    if let error {
                        Label(error.errorDescription ?? "", systemImage: error.symbol)
                            .font(.subheadline).foregroundStyle(Theme.expired)
                    }

                    PrimaryButton(title: "common.save".loc, systemImage: "checkmark",
                                  isLoading: isSaving,
                                  isEnabled: !email.isEmpty && !selectedInboundIds.isEmpty) { save() }
                }
                .padding()
            }
            .background(ScreenBackground())
            .scrollContentBackground(.hidden)
            .navigationTitle(existing == nil ? "client.new_title".loc : "client.edit_title".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".loc) { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .onAppear {
                // For an existing client, preselect every inbound it's attached to.
                guard !didLoadSelection else { return }
                didLoadSelection = true
                if let existing {
                    let ids = store.inboundIds(forEmail: existing.email)
                    if !ids.isEmpty { selectedInboundIds = Set(ids) }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func toggleInbound(_ id: Int) {
        if selectedInboundIds.contains(id) { selectedInboundIds.remove(id) }
        else { selectedInboundIds.insert(id) }
    }

    private func labeledField<Content: View>(_ title: String, symbol: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    private func sliderField(title: String, hint: String, value: Binding<Double>,
                             range: ClosedRange<Double>, step: Double, display: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(display).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accentCyan)
            }
            Slider(value: value, in: range, step: step).tint(Theme.accentCyan)
            Text(hint).font(.caption2).foregroundStyle(Theme.textTertiary)
        }
    }

    private func save() {
        error = nil
        isSaving = true
        let totalBytes = Int64(limitGB * 1_073_741_824)
        let expiryMs: Int64 = expiryDays == 0 ? 0
            : Int64((Date().timeIntervalSince1970 + expiryDays * 86_400) * 1000)
        let client = Client(id: uuid, email: email, flow: flow, totalGB: totalBytes,
                            expiryTime: expiryMs, enable: enable,
                            tgId: tgId.isEmpty ? nil : tgId,
                            limitIp: Int(ipLimit))
        let ids = Array(selectedInboundIds)
        Task {
            do {
                if existing == nil {
                    try await store.addClient(inboundIds: ids, client: client)
                    toast = ToastData(message: "toast.client_added".loc)
                } else {
                    try await store.updateClient(inboundIds: ids, client: client)
                    toast = ToastData(message: "toast.client_updated".loc)
                }
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

/// Default flow for a fresh client based on the inbound's security.
private func defaultFlow(for inbound: Inbound) -> String {
    inbound.stream.security.lowercased() == "reality" ? "xtls-rprx-vision" : ""
}

#Preview {
    ClientEditorView(inbound: MockData.inbounds[0], existing: nil, toast: .constant(nil))
        .environment(AppState.preview())
        .preferredColorScheme(.dark)
}
