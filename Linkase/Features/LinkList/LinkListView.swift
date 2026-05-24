import SwiftUI

struct LinkListView: View {
    @Environment(\.container) private var container
    @Binding var selection: SidebarSelection?
    @Binding var detail: LinkWithTags?

    @State private var viewModel: LinkListViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                let vm = LinkListViewModel(repository: container.repository)
                vm.selection = selection
                viewModel = vm
                vm.startObserving()
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: LinkListViewModel) -> some View {
        VStack(spacing: 0) {
            AddLinkView()
                .padding()
            Divider()
            List(selection: $detail) {
                if vm.links.isEmpty {
                    ContentUnavailableView(
                        "No links yet",
                        systemImage: "link",
                        description: Text("Paste a URL above to save it.")
                    )
                } else {
                    ForEach(vm.links) { item in
                        LinkRow(item: item)
                            .tag(item)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.delete(item) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .listStyle(.inset)
        }
        .searchable(text: Binding(get: { vm.search }, set: { vm.search = $0 }), prompt: "Search")
        .onChange(of: vm.search) { _, _ in vm.startObserving() }
        .onChange(of: selection) { _, newValue in
            vm.selection = newValue
            vm.startObserving()
        }
        .navigationTitle(title(for: selection))
    }

    private func title(for selection: SidebarSelection?) -> String {
        switch selection {
        case .tag(let t): return "#\(t.name)"
        default: return "All Links"
        }
    }
}

private struct LinkRow: View {
    let item: LinkWithTags

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.link.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                if item.link.aiGenerated {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                        .imageScale(.small)
                }
            }
            if !item.link.description.isEmpty {
                Text(item.link.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 6) {
                Text(item.link.host)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                ForEach(item.tags) { tag in
                    Text(tag.name)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
