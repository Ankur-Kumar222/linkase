import Foundation
import GRDB

struct Link: Identifiable, Codable, Hashable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var url: String
    var title: String
    var description: String
    var host: String
    var createdAt: Date
    var aiGenerated: Bool

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let url = Column(CodingKeys.url)
        static let title = Column(CodingKeys.title)
        static let description = Column(CodingKeys.description)
        static let host = Column(CodingKeys.host)
        static let createdAt = Column(CodingKeys.createdAt)
        static let aiGenerated = Column(CodingKeys.aiGenerated)
    }

    static let databaseTableName = "link"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
