import SwiftUI
import AppKit

struct LogsTab: View {
    @EnvironmentObject var log: LogStore
    @State private var autoScroll = true

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Logs").font(.headline)
                Spacer()
                Toggle("Auto-scroll", isOn: $autoScroll).toggleStyle(.switch).controlSize(.small)
                Button { copyAll() } label: { Label("Copy", systemImage: "doc.on.doc") }
                Button { log.clear() } label: { Label("Clear", systemImage: "trash") }
            }
            .padding(.bottom, 8)
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(log.lines) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Text(timeFormatter.string(from: line.date))
                                    .foregroundStyle(.secondary)
                                Text(line.text).foregroundStyle(line.color)
                                    .textSelection(.enabled)
                                Spacer(minLength: 0)
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: log.lines.count) { _, _ in
                    if autoScroll, let last = log.lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(log.plainText, forType: .string)
    }
}
