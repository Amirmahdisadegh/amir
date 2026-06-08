import SwiftUI

struct ScanView: View {
    @StateObject private var vm = ScanVM()

    var body: some View {
        ZStack {
            Color.wdBg.ignoresSafeArea()
            VStack(spacing: 0) {

                // Header
                HStack {
                    Text("اسکن DNS")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.wdInk)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Servers input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("لیست سرورها")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.wdMuted)
                            TextEditor(text: $vm.servers)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.wdInk)
                                .scrollContentBackground(.hidden)
                                .frame(height: 120)
                                .padding(12)
                                .background(Color.wdSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.wdBorder, lineWidth: 1))
                                .disabled(vm.isScanning)
                        }

                        // Workers slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("تعداد کارگرها")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.wdMuted)
                                Spacer()
                                Text("\(Int(vm.workers))")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.wdAccent)
                            }
                            Slider(value: $vm.workers, in: 1...16, step: 1)
                                .tint(.wdAccent)
                                .disabled(vm.isScanning)
                        }

                        // Progress bar
                        if vm.isScanning {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("در حال اسکن…")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.wdMuted)
                                    Spacer()
                                    Text("\(Int(vm.progress * 100))%")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.wdAccent)
                                }
                                ProgressView(value: vm.progress)
                                    .tint(.wdAccent)
                            }
                            .transition(.opacity)
                        }

                        // Start / Stop button
                        Button {
                            if vm.isScanning { vm.stopScan() } else { vm.startScan() }
                        } label: {
                            HStack(spacing: 8) {
                                if vm.isScanning {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                }
                                Text(vm.isScanning ? "توقف" : "شروع اسکن")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(vm.isScanning ? Color.wdError : Color.wdAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                        }

                        // Results
                        if !vm.results.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("نتایج")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.wdMuted)

                                ForEach(vm.results) { r in
                                    scanResultRow(r)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.isScanning)
    }

    private func scanResultRow(_ r: ScanResult) -> some View {
        HStack(spacing: 12) {
            // Status dot
            ZStack {
                Circle().fill(dotColor(r).opacity(0.15)).frame(width: 28, height: 28)
                dotIcon(r)
            }

            Text(r.server)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.wdInk)

            Spacer()

            if let ms = r.latency {
                Text(String(format: "%.0f ms", ms))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(latencyColor(ms))
            } else if r.status == .timeout {
                Text("timeout")
                    .font(.system(size: 12))
                    .foregroundStyle(.wdError)
            } else if r.status == .testing {
                ProgressView().scaleEffect(0.7).tint(.wdMuted)
            }
        }
        .padding(12)
        .background(Color.wdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.wdBorder, lineWidth: 1))
    }

    private func dotColor(_ r: ScanResult) -> Color {
        switch r.status {
        case .ok:       return .wdSuccess
        case .timeout, .error: return .wdError
        case .testing:  return .wdWarning
        default:        return .wdMuted
        }
    }

    private func dotIcon(_ r: ScanResult) -> some View {
        Group {
            switch r.status {
            case .ok:
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.wdSuccess)
            case .timeout, .error:
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.wdError)
            case .testing:
                ProgressView().scaleEffect(0.5).tint(.wdWarning)
            default:
                Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(.wdMuted)
            }
        }
    }

    private func latencyColor(_ ms: Double) -> Color {
        if ms < 80 { return .wdSuccess }
        if ms < 200 { return .wdWarning }
        return .wdError
    }
}
