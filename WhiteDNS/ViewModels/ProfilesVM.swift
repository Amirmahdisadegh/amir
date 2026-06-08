import Foundation

@MainActor
class ProfilesVM: ObservableObject {
    @Published var custom: [DNSProfile] = []
    @Published var selected: DNSProfile?

    var all: [DNSProfile] { DNSProfile.builtin + custom }

    init() { load() }

    func select(_ p: DNSProfile) { selected = p; save() }

    func add(_ p: DNSProfile) { custom.append(p); save() }

    func delete(_ p: DNSProfile) {
        custom.removeAll { $0.id == p.id }
        if selected?.id == p.id { selected = nil }
        save()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(custom) { UserDefaults.standard.set(d, forKey: "wdns_custom") }
        if let p = selected, let d = try? JSONEncoder().encode(p) { UserDefaults.standard.set(d, forKey: "wdns_sel") }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: "wdns_custom"),
           let ps = try? JSONDecoder().decode([DNSProfile].self, from: d) { custom = ps }
        if let d = UserDefaults.standard.data(forKey: "wdns_sel"),
           let p = try? JSONDecoder().decode(DNSProfile.self, from: d) { selected = p }
        if selected == nil { selected = DNSProfile.builtin.first }
    }
}
