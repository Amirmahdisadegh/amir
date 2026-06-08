import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var connectVM: ConnectVM
    @EnvironmentObject var profilesVM: ProfilesVM
    @EnvironmentObject var logsVM: LogsVM
    @State private var showProfilePicker = false

    var body: some View {
        ZStack {
            Color.wdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Mode selector
                        modeSelector
                            .padding(.top, 8)

                        // Status ring
                        StatusRingView(status: connectVM.status)
                            .padding(.vertical, 8)

                        // Stats (only when connected)
                        if connectVM.status.isConnected {
                            statsRow
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        // Resolver card
                        resolverCard

                        // Connect button
                        connectButton
                            .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showProfilePicker) {
            ProfilePickerSheet()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: connectVM.status.isConnected)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Text("White DNS")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.wdInk)
            Spacer()
            Button {
                Task { await connectVM.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.wdMuted)
                    .frame(width: 36, height: 36)
                    .background(Color.wdSurface)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: Mode selector

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ConnectionMode.allCases) { m in
                Button {
                    withAnimation(.spring(response: 0.25)) { connectVM.mode = m }
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 14, weight: connectVM.mode == m ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            connectVM.mode == m
                                ? Color.wdAccent
                                : Color.clear
                        )
                        .foregroundStyle(connectVM.mode == m ? .white : .wdMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(connectVM.status.isConnected)
            }
        }
        .padding(4)
        .background(Color.wdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.wdBorder, lineWidth: 1)
        )
    }

    // MARK: Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statChip(
                icon: "arrow.down.circle.fill",
                color: .wdSuccess,
                label: "دریافت",
                value: connectVM.stats.rxFormatted
            )
            statChip(
                icon: "arrow.up.circle.fill",
                color: .wdAccent,
                label: "ارسال",
                value: connectVM.stats.txFormatted
            )
            statChip(
                icon: "clock.fill",
                color: .wdWarning,
                label: "مدت",
                value: connectVM.stats.duration
            )
        }
    }

    private func statChip(icon: String, color: Color, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.wdInk)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.wdMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.wdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wdBorder, lineWidth: 1))
    }

    // MARK: Resolver card

    private var resolverCard: some View {
        Button {
            if !connectVM.status.isConnected { showProfilePicker = true }
        } label: {
            HStack(spacing: 14) {
                // Color dot
                Circle()
                    .fill(Color(hex: profilesVM.selected?.colorHex ?? "7C6FEA") ?? .wdAccent)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text("رزولور")
                        .font(.system(size: 11))
                        .foregroundStyle(.wdMuted)
                    Text(profilesVM.selected?.name ?? "انتخاب نشده")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.wdInk)
                    if let p = profilesVM.selected {
                        Text(p.servers.joined(separator: "  ·  "))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.wdMuted)
                    }
                }

                Spacer()

                if !connectVM.status.isConnected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.wdMuted)
                }
            }
            .padding(16)
            .background(Color.wdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wdBorder, lineWidth: 1))
        }
        .disabled(connectVM.status.isConnected)
    }

    // MARK: Connect button

    private var connectButton: some View {
        Button {
            Task {
                let p = profilesVM.selected
                await connectVM.toggle(profile: p)
                if connectVM.status.isConnected {
                    logsVM.append("اتصال برقرار شد: \(p?.name ?? "")", level: .info)
                } else if connectVM.status.isIdle {
                    logsVM.append("اتصال قطع شد", level: .info)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if case .connecting = connectVM.status {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                }
                Text(buttonLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(buttonColor)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: buttonColor.opacity(0.4), radius: 14, y: 6)
        }
        .disabled(isButtonDisabled)
        .animation(.easeInOut(duration: 0.2), value: connectVM.status.isConnected)
    }

    private var buttonLabel: String {
        switch connectVM.status {
        case .connected:       return "قطع اتصال"
        case .connecting:      return "در حال اتصال…"
        case .disconnecting:   return "در حال قطع…"
        case .disconnected:    return "اتصال"
        }
    }

    private var buttonColor: Color {
        switch connectVM.status {
        case .connected:       return .wdError
        case .connecting:      return .wdAccent.opacity(0.7)
        case .disconnecting:   return .wdWarning
        case .disconnected:    return .wdAccent
        }
    }

    private var isButtonDisabled: Bool {
        if case .connecting   = connectVM.status { return true }
        if case .disconnecting = connectVM.status { return true }
        if connectVM.status.isIdle && profilesVM.selected == nil { return true }
        return false
    }
}

// MARK: - Profile Picker Sheet

struct ProfilePickerSheet: View {
    @EnvironmentObject var profilesVM: ProfilesVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.wdBg.ignoresSafeArea()
                List {
                    ForEach(profilesVM.all) { p in
                        Button {
                            profilesVM.select(p)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(Color(hex: p.colorHex) ?? .wdAccent)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(p.name)
                                        .foregroundStyle(.wdInk)
                                        .font(.system(size: 15, weight: .medium))
                                    Text(p.servers.joined(separator: "  ·  "))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.wdMuted)
                                }
                                Spacer()
                                if profilesVM.selected?.id == p.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.wdAccent)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.wdSurface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("انتخاب رزولور")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("بستن") { dismiss() }
                        .foregroundStyle(.wdAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
