import SwiftUI
import AppKit

struct AddProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onImport: (String) -> Void

    @State private var text = ""
    @State private var subURL = ""
    @State private var fetching = false
    @State private var fetchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Servers").font(.title2.bold())

            Text("Paste one or more share links (vmess://, vless://, trojan://, ss://, hysteria2://, tuic://), or a base64 subscription body.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $text)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 130)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            HStack {
                Button("Paste from clipboard") {
                    if let s = NSPasteboard.general.string(forType: .string) { text = s }
                }
                Spacer()
                Button("Import") { onImport(text); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()

            Text("Or fetch a subscription URL").font(.headline)
            HStack {
                TextField("https://…", text: $subURL)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await fetchSubscription() }
                } label: {
                    if fetching { ProgressView().controlSize(.small) } else { Text("Fetch") }
                }
                .disabled(subURL.isEmpty || fetching)
            }
            if let fetchError {
                Text(fetchError).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    @MainActor
    private func fetchSubscription() async {
        guard let url = URL(string: subURL.trimmingCharacters(in: .whitespaces)) else {
            fetchError = "Invalid URL"; return
        }
        fetching = true; fetchError = nil
        defer { fetching = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.isEmpty { fetchError = "Empty response"; return }
            onImport(body)
            dismiss()
        } catch {
            fetchError = error.localizedDescription
        }
    }
}
