import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var profilesVM: ProfilesVM
    @Environment(\.dismiss) private var dismiss

    var editing: DNSProfile?

    @State private var name = ""
    @State private var primary = ""
    @State private var secondary = ""
    @State private var proto: DNSProtocol = .udp
    @State private var dohURL = ""
    @State private var color = Color.wdAccent

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && isIP(primary)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.wdBg.ignoresSafeArea()
                Form {
                    Section {
                        HStack {
                            ColorPicker("", selection: $color, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 28)
                            TextField("نام پروفایل", text: $name)
                                .foregroundStyle(.wdInk)
                        }
                    } header: { Text("مشخصات").foregroundStyle(.wdMuted) }
                    .listRowBackground(Color.wdSurface)

                    Section {
                        ipRow(label: "DNS اصلی", placeholder: "1.1.1.1", text: $primary)
                        ipRow(label: "DNS پشتیبان", placeholder: "اختیاری", text: $secondary)
                    } header: { Text("آدرس‌های IP").foregroundStyle(.wdMuted) }
                    .listRowBackground(Color.wdSurface)

                    Section {
                        Picker("پروتکل", selection: $proto) {
                            ForEach(DNSProtocol.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .foregroundStyle(.wdInk)
                        .tint(.wdAccent)

                        if proto == .doh {
                            TextField("https://dns.example.com/dns-query", text: $dohURL)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(.wdInk)
                        }
                        if proto == .dot {
                            TextField("dns.example.com", text: $dohURL)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(.wdInk)
                        }
                    } header: { Text("پروتکل").foregroundStyle(.wdMuted) }
                    .listRowBackground(Color.wdSurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(editing == nil ? "پروفایل جدید" : "ویرایش پروفایل")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("لغو") { dismiss() }.foregroundStyle(.wdMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("ذخیره") { save(); dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.wdAccent)
                        .disabled(!isValid)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { populate() }
    }

    private func ipRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.wdMuted)
                .frame(width: 90, alignment: .leading)
            TextField(placeholder, text: text)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .foregroundStyle(.wdInk)
        }
    }

    private func populate() {
        guard let e = editing else { return }
        name = e.name; primary = e.primary; secondary = e.secondary
        proto = e.proto; dohURL = e.proto == .doh ? e.dohURL : e.dotHost
        color = Color(hex: e.colorHex) ?? .wdAccent
    }

    private func save() {
        let p = DNSProfile(
            id: editing?.id ?? .init(),
            name: name.trimmingCharacters(in: .whitespaces),
            primary: primary.trimmingCharacters(in: .whitespaces),
            secondary: secondary.trimmingCharacters(in: .whitespaces),
            proto: proto,
            dohURL: proto == .doh ? dohURL : "",
            dotHost: proto == .dot ? dohURL : "",
            colorHex: color.toHex() ?? "7C6FEA"
        )
        if editing != nil {
            profilesVM.delete(editing!)
        }
        profilesVM.add(p)
    }

    private func isIP(_ s: String) -> Bool {
        let parts = s.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { p in (0...255).contains(Int(p) ?? -1) }
    }
}
