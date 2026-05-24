import Foundation

enum AppGroup {
    static let identifier = "group.com.AnkurKumar.Linkase"

    static func databaseURL() throws -> URL {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) {
            return container.appending(path: "Linkase.sqlite")
        }
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = support.appending(path: "Linkase", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "Linkase.sqlite")
    }
}
