import SwiftUI

struct SubscriptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: ProfileStore

    @State private var name = ""
    @State private var url = ""
    @State private var refreshing: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Subscriptions").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }

            if store.data.subscriptions.isEmpty {
                Text("No subscriptions yet. Add a subscription URL below to auto-import many servers.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(store.data.subscriptions) { sub in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name.isEmpty ? sub.url : sub.name).fontWeight(.medium)
                                Text(countText(sub)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if refreshing.contains(sub.id) {
                                ProgressView().controlSize(.small)
                            } else {
                                Button { refresh(sub.id) } label: { Image(systemName: "arrow.clockwise") }
                                    .buttonStyle(.borderless)
                            }
                            Button { store.deleteSubscription(sub.id) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).foregroundStyle(.red)
                        }
                        .padding(.vertical, 3)
                    }
                }
                .frame(height: 160)
                Button("Refresh all") { store.data.subscriptions.forEach { refresh($0.id) } }
            }

            Divider()
            Text("Add subscription").font(.headline)
            TextField("Name (optional)", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                TextField("https://…", text: $url).textFieldStyle(.roundedBorder)
                Button("Add") { add() }.disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func countText(_ sub: Subscription) -> String {
        let n = store.data.profiles.filter { $0.subscriptionId == sub.id }.count
        if let d = sub.lastUpdated {
            let f = RelativeDateTimeFormatter()
            return "\(n) servers · updated \(f.localizedString(for: d, relativeTo: Date()))"
        }
        return "\(n) servers"
    }

    private func add() {
        let sub = Subscription(name: name.trimmingCharacters(in: .whitespaces),
                               url: url.trimmingCharacters(in: .whitespaces))
        store.addSubscription(sub)
        name = ""; url = ""
        refresh(sub.id)
    }

    private func refresh(_ id: String) {
        refreshing.insert(id)
        Task {
            await store.refreshSubscription(id)
            refreshing.remove(id)
        }
    }
}
