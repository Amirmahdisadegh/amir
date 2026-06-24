import SwiftUI

struct SettingsTab: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var tunnel: TunnelController

    private var s: Binding<AppSettings> { $store.data.settings }

    var body: some View {
        Form {
            Section("Local listener") {
                LabeledContent("SOCKS bind address") {
                    TextField("", text: s.listenIp).frame(width: 140)
                }
                LabeledContent("SOCKS port") {
                    TextField("", value: s.listenPort, format: .number.grouping(.never)).frame(width: 80)
                }
            }

            Section("Behaviour") {
                Toggle("Manage system SOCKS proxy automatically", isOn: s.manageSystemProxy)
                Text("When on, connecting sets the system-wide SOCKS proxy (asks for your password once). When off, point apps at the address above manually.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Auto-connect when the window opens", isOn: s.autoConnectOnLaunch)
            }

            Section("Resolver selection") {
                Picker("Balancing strategy", selection: s.resolverBalancingStrategy) {
                    Text("Random").tag(1)
                    Text("Round Robin").tag(2)
                    Text("Least Loss").tag(3)
                    Text("Lowest Latency").tag(4)
                }
            }

            Section("Packet duplication (lossy links)") {
                stepper("Upload data", s.uploadDuplication, 1...8)
                stepper("Download ACK", s.downloadDuplication, 1...8)
                stepper("Upload setup", s.uploadSetupDuplication, 1...8)
                stepper("Download setup", s.downloadSetupDuplication, 1...8)
            }

            Section("Compression") {
                compressionPicker("Upload", s.uploadCompression)
                compressionPicker("Download", s.downloadCompression)
            }

            Section("MTU bounds") {
                HStack {
                    intField("Min up", s.minUploadMtu)
                    intField("Max up", s.maxUploadMtu)
                    intField("Min down", s.minDownloadMtu)
                    intField("Max down", s.maxDownloadMtu)
                }
            }

            Section("Diagnostics") {
                Picker("Log level", selection: s.logLevel) {
                    ForEach(AppSettings.logLevels, id: \.self) { Text($0).tag($0) }
                }
                LabeledContent("Stats interval (s)") {
                    TextField("", value: s.statsReportIntervalSeconds, format: .number).frame(width: 70)
                }
                LabeledContent("Ping watchdog (s)") {
                    TextField("", value: s.pingWatchdogTimeoutSeconds, format: .number).frame(width: 70)
                }
            }
        }
        .formStyle(.grouped)
        .disabled(tunnel.state.isConnected || tunnel.state.isBusy)
        .overlay(alignment: .bottom) {
            if tunnel.state.isConnected || tunnel.state.isBusy {
                Text("Disconnect to change settings.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(6)
            }
        }
    }

    private func stepper(_ title: String, _ binding: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        Stepper(value: binding, in: range) {
            LabeledContent(title) { Text("\(binding.wrappedValue)").monospacedDigit() }
        }
    }

    private func compressionPicker(_ title: String, _ binding: Binding<Int>) -> some View {
        Picker(title, selection: binding) {
            Text("Off").tag(0)
            Text("ZSTD").tag(1)
            Text("LZ4").tag(2)
            Text("ZLIB").tag(3)
        }
    }

    private func intField(_ title: String, _ binding: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("", value: binding, format: .number.grouping(.never)).frame(width: 70)
        }
    }
}
