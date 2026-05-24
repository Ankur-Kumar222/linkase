import SwiftUI

struct ManualPrefill: Equatable, Sendable {
    var url: URL
    var host: String
    var title: String
    var description: String
}

struct ManualEntryForm: View {
    let prefill: ManualPrefill
    var onCancel: () -> Void
    var onSave: (_ title: String, _ description: String, _ tagsCSV: String) async -> Void

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var tags: String = ""
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Apple Intelligence is unavailable — fill in details to save.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(prefill.url.absoluteString)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            TextField("Tags (comma separated)", text: $tags)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                Spacer()
                Button("Save") {
                    saving = true
                    Task {
                        await onSave(title, description, tags)
                        saving = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || saving)
            }
        }
        .padding(10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .onAppear {
            title = prefill.title
            description = prefill.description
        }
    }
}
