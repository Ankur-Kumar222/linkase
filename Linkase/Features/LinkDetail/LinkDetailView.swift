import SwiftUI

struct LinkDetailView: View {
    @Environment(\.container) private var container
    @Environment(\.openURL) private var openURL

    let item: LinkWithTags

    @State private var title: String
    @State private var description: String
    @State private var tagsCSV: String
    @State private var isEditing = false
    @State private var deleted = false

    init(item: LinkWithTags) {
        self.item = item
        _title = State(initialValue: item.link.title)
        _description = State(initialValue: item.link.description)
        _tagsCSV = State(initialValue: item.tags.map(\.name).joined(separator: ", "))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(item.link.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if item.link.aiGenerated {
                        Label("AI", systemImage: "sparkles")
                            .font(.caption)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                    Text(item.link.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isEditing {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                        .textFieldStyle(.roundedBorder)
                    TextField("Tags (comma separated)", text: $tagsCSV)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(item.link.title)
                        .font(.title2.bold())
                    if !item.link.description.isEmpty {
                        Text(item.link.description)
                            .foregroundStyle(.secondary)
                    }
                    if !item.tags.isEmpty {
                        HStack {
                            ForEach(item.tags) { tag in
                                Text(tag.name)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                    }
                }

                if let url = URL(string: item.link.url) {
                    Button {
                        openURL(url)
                    } label: {
                        Label(item.link.url, systemImage: "safari")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Save") {
                        Task { await save() }
                    }
                } else {
                    Button("Edit") { isEditing = true }
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    Task { await delete() }
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private func save() async {
        guard let id = item.link.id else { return }
        var updated = item.link
        updated.title = title
        updated.description = description
        let tagNames = tagsCSV
            .split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        _ = try? await container.repository.upsert(link: updated, tagNames: tagNames)
        _ = id
        isEditing = false
    }

    private func delete() async {
        guard let id = item.link.id else { return }
        try? await container.repository.delete(linkId: id)
        deleted = true
    }
}
