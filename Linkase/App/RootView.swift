import SwiftUI

struct RootView: View {
    @State private var sidebarSelection: SidebarSelection? = .all
    @State private var detailSelection: LinkWithTags?

    var body: some View {
        NavigationSplitView {
            TagSidebarView(selection: $sidebarSelection)
        } content: {
            LinkListView(selection: $sidebarSelection, detail: $detailSelection)
        } detail: {
            if let item = detailSelection {
                LinkDetailView(item: item)
            } else {
                ContentUnavailableView(
                    "Select a link",
                    systemImage: "link",
                    description: Text("Pick a saved link to see its details.")
                )
            }
        }
    }
}
