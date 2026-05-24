import SwiftUI

@main
struct LinkaseApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.container, container)
                .environment(container)
        }
    }
}
