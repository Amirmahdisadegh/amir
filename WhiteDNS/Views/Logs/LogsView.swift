import SwiftUI

struct LogsView: View {
    @EnvironmentObject var logsVM: LogsVM

    var body: some View {
        ZStack {
            Color.wdBg.ignoresSafeArea()
            VStack(spacing: 0) {

                // Header
                HStack {
                    Text("لاگ")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.wdInk)
                    Spacer()
                    Button {
                        logsVM.clear()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.wdMuted)
                            .frame(width: 36, height: 36)
                            .background(Color.wdSurface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.wdBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if logsVM.entries.isEmpty {
                    emptyState
                } else {
                    logList
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.wdBorder)
            Text("لاگی وجود ندارد")
                .font(.system(size: 15))
                .foregroundStyle(.wdMuted)
            Spacer()
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(logsVM.entries) { entry in
                        logRow(entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .onChange(of: logsVM.entries.count) { _, _ in
                if let last = logsVM.entries.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Level tag
            Text(entry.levelTag)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(levelColor(entry.level))
                .frame(width: 36)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.wdInk)
                    .textSelection(.enabled)

                Text(timeString(entry.date))
                    .font(.system(size: 10))
                    .foregroundStyle(.wdMuted)
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Divider().background(Color.wdBorder).opacity(0.5)
        }
    }

    private func levelColor(_ l: LogEntry.Level) -> Color {
        switch l {
        case .info:  return .wdSuccess
        case .warn:  return .wdWarning
        case .error: return .wdError
        case .debug: return .wdMuted
        }
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: d)
    }
}
