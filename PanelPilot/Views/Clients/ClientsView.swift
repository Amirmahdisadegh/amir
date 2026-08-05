import SwiftUI

enum ClientFilter: String, CaseIterable, Identifiable {
    case online, expiring, over80, disabled
    var id: String { rawValue }

    var title: String {
        switch self {
        case .online:   return "clients.filter.online".loc
        case .expiring: return "clients.filter.expiring".loc
        case .over80:   return "clients.filter.over80".loc
        case .disabled: return "clients.filter.disabled".loc
        }
    }
    var symbol: String {
        switch self {
        case .online:   return "dot.radiowaves.left.and.right"
        case .expiring: return "hourglass"
        case .over80:   return "gauge.high"
        case .disabled: return "pause.circle"
        }
    }
}

enum ClientSort: String, CaseIterable, Identifiable {
    case name, usage, expiry
    var id: String { rawValue }
    var title: String {
        switch self {
        case .name:   return "clients.sort.name".loc
        case .usage:  return "clients.sort.usage".loc
        case .expiry: return "clients.sort.expiry".loc
        }
    }
}

struct ClientsView: View {
    @Environment(AppState.self) private var app
    private var store: DataStore { app.store }

    @State private var search = ""
    @State private var sort: ClientSort = .name
    @State private var activeFilters: Set<ClientFilter> = []
    @State private var selectedInbound: Int? = nil   // nil == all
    @State private var toast: ToastData?
    @State private var addToInbound: Inbound?
    @State private var showInboundPicker = false

    private var filteredRows: [ClientRow] {
        var rows = store.allClientRows
        if let selectedInbound { rows = rows.filter { $0.inbound.id == selectedInbound } }
        if !search.isEmpty {
            rows = rows.filter { $0.client.email.localizedCaseInsensitiveContains(search) }
        }
        for filter in activeFilters {
            switch filter {
            case .online:   rows = rows.filter { $0.isOnline && $0.client.enable }
            case .expiring: rows = rows.filter { $0.isExpiringSoon }
            case .over80:   rows = rows.filter { $0.isOverEighty }
            case .disabled: rows = rows.filter { !$0.client.enable }
            }
        }
        switch sort {
        case .name:
            return rows.sorted { $0.client.email.localizedCaseInsensitiveCompare($1.client.email) == .orderedAscending }
        case .usage:
            return rows.sorted { $0.used > $1.used }
        case .expiry:
            // Soonest real expiry first; "never" (0) sinks to the bottom.
            return rows.sorted {
                let a = $0.client.expiryTime <= 0 ? Int64.max : $0.client.expiryTime
                let b = $1.client.expiryTime <= 0 ? Int64.max : $1.client.expiryTime
                return a < b
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                content
            }
            .background(ScreenBackground())
            .navigationTitle("clients.title".loc)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        Menu {
                            Picker("clients.sort".loc, selection: $sort) {
                                ForEach(ClientSort.allCases) { Text($0.title).tag($0) }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .foregroundStyle(Theme.accentGradient)
                        }
                        Button {
                            Haptics.tap(); startAddClient()
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accentGradient)
                        }
                        .disabled(store.inbounds.isEmpty)
                        RefreshButton(isLoading: store.isLoading) {
                            Task { await store.refreshAll() }
                        }
                    }
                }
            }
            .navigationDestination(for: ClientRow.self) { row in
                ClientDetailView(inboundId: row.inbound.id, clientId: row.client.id)
            }
            .searchable(text: $search, prompt: "clients.search".loc)
            .refreshable { await store.refreshAll() }
            .sheet(item: $addToInbound) { inbound in
                ClientEditorView(inbound: inbound, existing: nil, toast: $toast)
            }
            .confirmationDialog("clients.pick_inbound".loc, isPresented: $showInboundPicker,
                                titleVisibility: .visible) {
                ForEach(store.inbounds) { inbound in
                    Button(inbound.remark.isEmpty ? inbound.tag : inbound.remark) {
                        addToInbound = inbound
                    }
                }
                Button("common.cancel".loc, role: .cancel) {}
            }
            .toast($toast)
        }
    }

    private func startAddClient() {
        if let id = selectedInbound, let inbound = store.inbound(withId: id) {
            addToInbound = inbound
        } else if store.inbounds.count == 1 {
            addToInbound = store.inbounds.first
        } else {
            showInboundPicker = true
        }
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "clients.all_inbounds".loc, systemImage: "square.stack.3d.up",
                               isSelected: selectedInbound == nil) {
                        withAnimation(Theme.spring) { selectedInbound = nil }
                    }
                    ForEach(store.inbounds) { inbound in
                        FilterChip(title: inbound.remark.isEmpty ? inbound.tag : inbound.remark,
                                   isSelected: selectedInbound == inbound.id) {
                            withAnimation(Theme.spring) { selectedInbound = inbound.id }
                        }
                    }
                }
                .padding(.horizontal)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ClientFilter.allCases) { filter in
                        FilterChip(title: filter.title, systemImage: filter.symbol,
                                   isSelected: activeFilters.contains(filter)) {
                            withAnimation(Theme.spring) {
                                if activeFilters.contains(filter) { activeFilters.remove(filter) }
                                else { activeFilters.insert(filter) }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if store.allClientRows.isEmpty {
            if store.isLoading {
                ScrollView { SkeletonList(count: 6).padding(.top, 8) }
            } else if let error = store.error {
                ScrollView {
                    ErrorStateView(error: error) { Task { await store.refreshAll() } }
                        .padding(.top, 40)
                }
            } else {
                EmptyStateView(systemImage: "person.2.slash",
                               title: "clients.empty".loc,
                               message: "clients.empty_hint".loc)
                Spacer()
            }
        } else if filteredRows.isEmpty {
            EmptyStateView(systemImage: "magnifyingglass", title: "clients.empty".loc)
            Spacer()
        } else {
            List {
                Section {
                    ForEach(filteredRows) { row in
                        ClientListItem(row: row, showInbound: selectedInbound == nil, toast: $toast)
                    }
                } header: {
                    Text(Fmt.digits("clients.count".loc(filteredRows.count)))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

#Preview {
    ClientsView()
        .environment(AppState.preview())
        .preferredColorScheme(.dark)
}
