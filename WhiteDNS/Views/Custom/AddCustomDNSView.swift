import SwiftUI

struct AddCustomDNSView: View {
    @EnvironmentObject var dns: DNSManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var primaryDNS = ""
    @State private var secondaryDNS = ""
    @State private var dohURL = ""
    @State private var selectedProtocol: DNSProtocolType = .standard
    @State private var accentColor = Color.blue
    @State private var description = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && isValidIP(primaryDNS)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        ColorPicker("", selection: $accentColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 28)

                        TextField("نام سرور (مثال: DNS من)", text: $name)
                    }

                    TextField("توضیح (اختیاری)", text: $description)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("مشخصات")
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "1.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                        TextField("DNS اصلی  •  مثال: 1.1.1.1", text: $primaryDNS)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "2.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                        TextField("DNS پشتیبان  •  اختیاری", text: $secondaryDNS)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("آدرس‌های IP")
                } footer: {
                    if !primaryDNS.isEmpty && !isValidIP(primaryDNS) {
                        Text("آدرس IP وارد شده معتبر نیست")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Picker("پروتکل اتصال", selection: $selectedProtocol) {
                        ForEach(DNSProtocolType.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedProtocol == .doh {
                        TextField("آدرس DoH  •  مثال: https://dns.example.com/dns-query",
                                  text: $dohURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else if selectedProtocol == .dot {
                        TextField("نام هاست DoT  •  مثال: dns.example.com",
                                  text: $dohURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("پروتکل")
                }
            }
            .navigationTitle("افزودن DNS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("لغو") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("ذخیره") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        var servers = [primaryDNS.trimmingCharacters(in: .whitespaces)]
        let sec = secondaryDNS.trimmingCharacters(in: .whitespaces)
        if !sec.isEmpty && isValidIP(sec) { servers.append(sec) }

        let provider = DNSProvider(
            name: name.trimmingCharacters(in: .whitespaces),
            servers: servers,
            colorHex: accentColor.toHex() ?? "3B82F6",
            description: description.isEmpty ? "DNS سفارشی" : description,
            isCustom: true,
            dohURL: selectedProtocol == .doh && !dohURL.isEmpty ? dohURL : nil,
            dotHostname: selectedProtocol == .dot && !dohURL.isEmpty ? dohURL : nil
        )
        dns.addCustomProvider(provider)
    }

    private func isValidIP(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { p in
            guard let n = Int(p) else { return false }
            return (0...255).contains(n)
        }
    }
}
