import SwiftUI

struct ResolversTab: View {
    @EnvironmentObject var store: ProfileStore
    @State private var editing: ResolverProfile?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Resolver Sets").font(.headline)
                Spacer()
                Button {
                    editing = ResolverProfile(name: "New Resolvers", resolverText: "")
                } label: { Label("Add", systemImage: "plus") }
            }
            .padding(.bottom, 8)
            Divider()

            List {
                ForEach(store.data.resolvers) { resolver in
                    HStack {
                        Image(systemName: resolver.id == store.selectedResolver.id ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(resolver.id == store.selectedResolver.id ? Color.accentColor : .secondary)
                            .onTapGesture { store.selectResolver(resolver.id) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(resolver.name).fontWeight(.medium)
                            Text("\(resolver.entries.count) resolver(s)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            Button("Edit…") { editing = resolver }
                            Divider()
                            Button("Delete", role: .destructive) { store.deleteResolver(resolver.id) }
                                .disabled(store.data.resolvers.count <= 1)
                        } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { store.selectResolver(resolver.id) }
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(item: $editing) { resolver in
            ResolverEditor(resolver: resolver) { store.upsertResolver($0) }
        }
    }
}

private struct ResolverEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ResolverProfile
    private let onSave: (ResolverProfile) -> Void

    init(resolver: ResolverProfile, onSave: @escaping (ResolverProfile) -> Void) {
        _draft = State(initialValue: resolver)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resolvers").font(.title2.bold())
            TextField("Name", text: $draft.name)
            Text("One resolver per line. Formats: 8.8.8.8 · 1.1.1.1:5353 · 192.168.1.0/30 · [2001:4860:4860::8888]:53")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $draft.resolverText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 200)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack {
                Text("\(draft.entries.count) valid").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    if draft.name.trimmingCharacters(in: .whitespaces).isEmpty { draft.name = "Resolvers" }
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isValid)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
