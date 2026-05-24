import Foundation
import GRDB

struct LinkWithTags: Identifiable, Hashable {
    var link: Link
    var tags: [Tag]
    var id: Int64 { link.id ?? 0 }
}

struct LinkRepository: Sendable {
    let database: AppDatabase

    // MARK: - Writes

    @discardableResult
    func upsert(link incoming: Link, tagNames: [String]) async throws -> Link {
        try await database.writer.write { db in
            var stored: Link
            if let existing = try Link.filter(Link.Columns.url == incoming.url).fetchOne(db) {
                stored = existing
                stored.title = incoming.title
                stored.description = incoming.description
                stored.host = incoming.host
                stored.aiGenerated = incoming.aiGenerated
                try stored.update(db)
            } else {
                stored = incoming
                try stored.insert(db)
            }

            guard let linkId = stored.id else { return stored }

            try LinkTag
                .filter(Column("link_id") == linkId)
                .deleteAll(db)

            for raw in tagNames {
                let name = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !name.isEmpty else { continue }
                let tag: Tag
                if let existing = try Tag.filter(Tag.Columns.name == name).fetchOne(db) {
                    tag = existing
                } else {
                    var newTag = Tag(id: nil, name: name)
                    try newTag.insert(db)
                    tag = newTag
                }
                if let tagId = tag.id {
                    try LinkTag(linkId: linkId, tagId: tagId).insert(db, onConflict: .ignore)
                }
            }

            return stored
        }
    }

    func delete(linkId: Int64) async throws {
        _ = try await database.writer.write { db in
            try Link.deleteOne(db, key: linkId)
        }
    }

    func update(link: Link) async throws {
        try await database.writer.write { db in
            try link.update(db)
        }
    }

    // MARK: - Observations

    func linksObservation(search: String?, tagId: Int64?) -> ValueObservation<ValueReducers.Fetch<[LinkWithTags]>> {
        ValueObservation.tracking { db in
            try Self.fetch(db, search: search, tagId: tagId)
        }
    }

    func tagsObservation() -> ValueObservation<ValueReducers.Fetch<[TagWithCount]>> {
        ValueObservation.tracking { db in
            try TagWithCount.fetchAll(db, sql: """
                SELECT t.id AS "tag.id", t.name AS "tag.name", COUNT(lt.link_id) AS count
                FROM tag t
                LEFT JOIN link_tag lt ON lt.tag_id = t.id
                GROUP BY t.id
                ORDER BY count DESC, t.name ASC
            """)
        }
    }

    private static func fetch(_ db: Database, search: String?, tagId: Int64?) throws -> [LinkWithTags] {
        var linkRows: [Link]

        if let q = search?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty,
           let pattern = FTS5Pattern(matchingAllPrefixesIn: q) {
            let sql: String
            let arguments: StatementArguments
            if let tagId {
                sql = """
                SELECT link.* FROM link
                JOIN link_fts ON link_fts.rowid = link.id
                JOIN link_tag ON link_tag.link_id = link.id
                WHERE link_fts MATCH ? AND link_tag.tag_id = ?
                ORDER BY link.createdAt DESC
                """
                arguments = [pattern, tagId]
            } else {
                sql = """
                SELECT link.* FROM link
                JOIN link_fts ON link_fts.rowid = link.id
                WHERE link_fts MATCH ?
                ORDER BY link.createdAt DESC
                """
                arguments = [pattern]
            }
            linkRows = try Link.fetchAll(db, sql: sql, arguments: arguments)
        } else if let tagId {
            linkRows = try Link.fetchAll(db, sql: """
                SELECT link.* FROM link
                JOIN link_tag ON link_tag.link_id = link.id
                WHERE link_tag.tag_id = ?
                ORDER BY link.createdAt DESC
            """, arguments: [tagId])
        } else {
            linkRows = try Link.order(Link.Columns.createdAt.desc).fetchAll(db)
        }

        guard !linkRows.isEmpty else { return [] }

        let ids = linkRows.compactMap(\.id)
        let idList = ids.map { String($0) }.joined(separator: ",")
        let rows = try Row.fetchAll(db, sql: """
            SELECT lt.link_id AS linkId, t.id AS id, t.name AS name
            FROM link_tag lt JOIN tag t ON t.id = lt.tag_id
            WHERE lt.link_id IN (\(idList))
        """)
        var tagsByLink: [Int64: [Tag]] = [:]
        for row in rows {
            let linkId: Int64 = row["linkId"]
            let tag = Tag(id: row["id"], name: row["name"])
            tagsByLink[linkId, default: []].append(tag)
        }

        return linkRows.map { LinkWithTags(link: $0, tags: tagsByLink[$0.id ?? 0] ?? []) }
    }
}
