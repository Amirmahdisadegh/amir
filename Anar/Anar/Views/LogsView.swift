import SwiftUI
import AppKit

struct LogsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var log: LogStore
    @State private var autoScroll = true

    private let tf: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Logs").font(.title2.bold())
                Spacer()
                Toggle("Auto-scroll", isOn: $autoScroll).toggleStyle(.switch).controlSize(.small)
                Button { copy() } label: { Label("Copy", systemImage: "doc.on.doc") }
                Button { log.clear() } label: { Label("Clear", systemImage: "trash") }
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(log.lines) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Text(tf.string(from: line.date)).foregroundStyle(.secondary)
                                Text(line.text).foregroundStyle(line.color).textSelection(.enabled)
                                Spacer(minLength: 0)
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .background(.black.opacity(0.04))
                .onChange(of: log.lines.count) { _, _ in
                    if autoScroll, let last = log.lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .frame(width: 640, height: 460)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(log.plainText, forType: .string)
    }
}
