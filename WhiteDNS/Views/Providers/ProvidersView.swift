import SwiftUI

struct ProvidersView: View {
    @EnvironmentObject var dns: DNSManager
    @State private var showAdd = false
    @State private var searchText = ""

    var filteredProviders: [DNSProvider] {
        guard !searchText.isEmpty else { return dns.allProviders }
        return dns.allProviders.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.contains(searchText) ||
            $0.servers.contains(where: { $0.hasPrefix(searchText) })
        }
    }

    var presets: [DNSProvider] { filteredProviders.filter { !$0.isCustom } }
    var custom: [DNSProvider] { filteredProviders.filter { $0.isCustom } }

    var body: some View {
        NavigationStack {
            List {
                if !presets.isEmpty {
                    Section("سرورهای پیش‌فرض") {
                        ForEach(presets) { provider in
                            ProviderRowView(provider: provider)
                                .onTapGesture {
                                    Task { await dns.connect(provider: provider) }
                                }
                        }
                    }
                }

                if !custom.isEmpty {
                    Section("سرورهای من") {
                        ForEach(custom) { provider in
                            ProviderRowView(provider: provider)
                                .onTapGesture {
                                    Task { await dns.connect(provider: provider) }
                                }
                        }
                        .onDelete { offsets in
                            // Map back to dns.customProviders indices
                            let customIDs = custom.map(\.id)
                            let toDelete = offsets.compactMap { i -> Int? in
                                let id = customIDs[i]
                                return dns.customProviders.firstIndex(where: { $0.id == id })
                            }
                            dns.deleteCustomProviders(at: IndexSet(toDelete))
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "جستجو در سرورها...")
            .navigationTitle("سرورهای DNS")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddCustomDNSView()
            }
        }
    }
}
