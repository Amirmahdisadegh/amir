import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject var profilesVM: ProfilesVM
    @EnvironmentObject var connectVM: ConnectVM
    @State private var showAdd = false
    @State private var editTarget: DNSProfile?

    var body: some View {
        ZStack {
            Color.wdBg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("پروفایل‌ها")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.wdInk)
                    Spacer()
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.wdAccent)
                            .frame(width: 36, height: 36)
                            .background(Color.wdSurface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.wdBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // List
                List {
                    if !DNSProfile.builtin.isEmpty {
                        Section {
                            ForEach(DNSProfile.builtin) { p in
                                profileRow(p)
                                    .listRowBackground(Color.wdSurface)
                                    .listRowSeparatorTint(Color.wdBorder)
                            }
                        } header: {
                            Text("پیش‌فرض")
                                .foregroundStyle(.wdMuted)
                                .font(.system(size: 12, weight: .medium))
                        }
                    }

                    if !profilesVM.custom.isEmpty {
                        Section {
                            ForEach(profilesVM.custom) { p in
                                profileRow(p)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            profilesVM.delete(p)
                                        } label: {
                                            Label("حذف", systemImage: "trash")
                                        }
                                        Button {
                                            editTarget = p
                                        } label: {
                                            Label("ویرایش", systemImage: "pencil")
                                        }
                                        .tint(.wdAccent)
                                    }
                                    .listRowBackground(Color.wdSurface)
                                    .listRowSeparatorTint(Color.wdBorder)
                            }
                        } header: {
                            Text("سفارشی")
                                .foregroundStyle(.wdMuted)
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showAdd) { EditProfileView() }
        .sheet(item: $editTarget) { p in EditProfileView(editing: p) }
    }

    private func profileRow(_ p: DNSProfile) -> some View {
        HStack(spacing: 14) {
            // Color indicator
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: p.colorHex) ?? .wdAccent)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: iconFor(p))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(p.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.wdInk)
                    Text(p.proto.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.wdBorder)
                        .foregroundStyle(.wdMuted)
                        .clipShape(Capsule())
                }
                Text(p.servers.joined(separator: "  ·  "))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.wdMuted)
            }

            Spacer()

            if profilesVM.selected?.id == p.id {
                Image(systemName: connectVM.status.isConnected ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundStyle(connectVM.status.isConnected ? .wdSuccess : .wdAccent)
                    .font(.system(size: 18))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { profilesVM.select(p) }
    }

    private func iconFor(_ p: DNSProfile) -> String {
        switch p.name {
        case "Cloudflare":  return "bolt.fill"
        case "Google":      return "magnifyingglass"
        case "Quad9":       return "shield.fill"
        case "AdGuard":     return "hand.raised.fill"
        case "Shecan":      return "flag.fill"
        case "403.online":  return "lock.open.fill"
        case "Electro":     return "bolt.circle.fill"
        case "NextDNS":     return "arrow.triangle.2.circlepath"
        default:            return "server.rack"
        }
    }
}
