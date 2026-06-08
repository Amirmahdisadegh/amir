import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dns: DNSManager

    var body: some View {
        NavigationStack {
            List {
                // Status card
                Section {
                    statusRow
                    if let p = dns.selectedProvider {
                        LabeledContent("سرور فعال") {
                            Text(p.name).foregroundStyle(.secondary)
                        }
                        LabeledContent("آدرس") {
                            Text(p.primaryServer)
                                .font(.callout.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent("پروتکل") {
                            Text(p.protocolType.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("وضعیت اتصال")
                }

                // Actions
                Section {
                    Button(role: dns.isConnected ? .destructive : .none) {
                        Task {
                            if dns.isConnected { await dns.disconnect() }
                        }
                    } label: {
                        Label(
                            dns.isConnected ? "قطع اتصال" : "اتصال برقرار نیست",
                            systemImage: dns.isConnected ? "bolt.slash.fill" : "bolt.fill"
                        )
                    }
                    .disabled(!dns.isConnected)
                } header: {
                    Text("عملیات")
                }

                // About
                Section {
                    LabeledContent("نسخه") { Text("1.0.0").foregroundStyle(.secondary) }
                    LabeledContent("هدف") { Text("iOS 17+").foregroundStyle(.secondary) }
                    LabeledContent("توسعه‌دهنده") { Text("Amir").foregroundStyle(.secondary) }
                } header: {
                    Text("درباره White DNS")
                }

                // Note
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .padding(.top, 2)
                        Text("برای اولین استفاده، iOS یک مجوز برای تنظیمات DNS درخواست می‌کند. این مجوز برای عملکرد صحیح اپلیکیشن ضروری است.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("تنظیمات")
        }
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi")
                .foregroundStyle(dns.isConnected ? .green : .secondary)
            Text("وضعیت اتصال")
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(dns.isConnected ? Color.green : Color(.systemGray3))
                    .frame(width: 8, height: 8)
                Text(dns.isConnected ? "متصل" : "غیر فعال")
                    .font(.callout)
                    .foregroundStyle(dns.isConnected ? .green : .secondary)
            }
        }
    }
}
