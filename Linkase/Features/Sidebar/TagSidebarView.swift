import SwiftUI
import GRDB

struct TagSidebarView: View {
    @Environment(\.container) private var container
    @Binding var selection: SidebarSelection?
    @State private var tags: [TagWithCount] = []

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("All Links", systemImage: "tray.full")
                    .tag(SidebarSelection.all)
            }
            if !tags.isEmpty {
                Section("Tags") {
                    ForEach(tags) { tagged in
                        HStack {
                            Label(tagged.tag.name, systemImage: "tag")
                            Spacer()
                            Text("\(tagged.count)")
                                .foregroundStyle(.secondary)
                                .font(.caption.monospacedDigit())
                        }
                        .tag(SidebarSelection.tag(tagged.tag))
                    }
                }
            }
        }
        .navigationTitle("Linkase")
        .task {
            do {
                for try await rows in container.repository.tagsObservation()
                    .values(in: container.database.writer) {
                    self.tags = rows
                }
            } catch {
                self.tags = []
            }
        }
    }
}
