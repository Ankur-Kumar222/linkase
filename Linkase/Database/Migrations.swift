import Foundation
import GRDB

enum Migrations {
    static func register(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1") { db in
            try db.create(table: "link") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("url", .text).notNull().unique()
                t.column("title", .text).notNull()
                t.column("description", .text).notNull().defaults(to: "")
                t.column("host", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("aiGenerated", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "tag") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().unique().collate(.nocase)
            }

            try db.create(table: "link_tag") { t in
                t.column("link_id", .integer)
                    .notNull()
                    .references("link", onDelete: .cascade)
                t.column("tag_id", .integer)
                    .notNull()
                    .references("tag", onDelete: .cascade)
                t.primaryKey(["link_id", "tag_id"])
            }

            try db.create(virtualTable: "link_fts", using: FTS5()) { t in
                t.synchronize(withTable: "link")
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("title")
                t.column("description")
                t.column("url")
            }
        }
    }
}
