import Foundation
import GRDB
import SwiftUI

@MainActor
@Observable
final class AppContainer {
    let database: AppDatabase
    let repository: LinkRepository
    let scraper: PageScraper
    let extractor: MetadataExtractor
    let ingestor: LinkIngestor

    var initError: String?

    init() {
        let db: AppDatabase
        var errorMessage: String?
        do {
            db = try AppDatabase.shared()
        } catch let dbError {
            errorMessage = "Failed to open database: \(dbError.localizedDescription)"
            db = try! AppDatabase(DatabaseQueue())
        }
        self.database = db
        self.initError = errorMessage

        let repo = LinkRepository(database: db)
        self.repository = repo
        self.scraper = PageScraper()
        self.extractor = MetadataExtractor()
        self.ingestor = LinkIngestor(repository: repo, scraper: self.scraper, extractor: self.extractor)
    }
}

extension EnvironmentValues {
    @Entry var container: AppContainer = AppContainer()
}
