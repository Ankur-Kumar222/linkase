import Foundation
import GRDB

struct Tag: Identifiable, Codable, Hashable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var name: String

    static let databaseTableName = "tag"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct LinkTag: Codable, FetchableRecord, PersistableRecord {
    var linkId: Int64
    var tagId: Int64

    static let databaseTableName = "link_tag"

    enum CodingKeys: String, CodingKey {
        case linkId = "link_id"
        case tagId = "tag_id"
    }
}

struct TagWithCount: Identifiable, Hashable, FetchableRecord, Decodable {
    var id: Int64 { tag.id ?? 0 }
    var tag: Tag
    var count: Int
}
