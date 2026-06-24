import SwiftUI
import AppKit

/// Add/edit sheet for a server profile.
struct ServerEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ServerProfile
    private let onSave: (ServerProfile) -> Void

    init(server: ServerProfile, onSave: @escaping (ServerProfile) -> Void) {
        _draft = State(initialValue: server)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(draft.label.isEmpty ? "New Server" : "Edit Server")
                .font(.title2.bold())
                .padding(.bottom, 12)

            Form {
                TextField("Name", text: $draft.label)
                TextField("Tunnel domain", text: $draft.domain, prompt: Text("v.example.com"))
                TextField("Encryption key", text: $draft.encryptionKey)
                Picker("Encryption", selection: $draft.encryptionMethod) {
                    ForEach(EncryptionMethod.allCases) { m in
                        Text(m.label).tag(m.rawValue)
                    }
                }
            }
            .formStyle(.grouped)

            Text("These must match the StormDNS server you are connecting to.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.top, 4)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    var d = draft
                    d.domain = d.domain.trimmingCharacters(in: .whitespaces)
                    d.encryptionKey = d.encryptionKey.trimmingCharacters(in: .whitespaces)
                    if d.label.trimmingCharacters(in: .whitespaces).isEmpty {
                        d.label = d.domain.isEmpty ? "WhiteDNS Profile" : d.domain
                    }
                    onSave(d)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isValid)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .frame(width: 420)
    }
}

/// Paste-a-link import sheet.
struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onImport: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import profile").font(.title2.bold())
            Text("Paste a stormdns:// link.")
                .font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack {
                Button("Paste from clipboard") {
                    if let s = NSPasteboard.general.string(forType: .string) { text = s }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Import") { onImport(text) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
