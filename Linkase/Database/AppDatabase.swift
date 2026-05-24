import Foundation
import GRDB

final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        Migrations.register(in: &migrator)
        try migrator.migrate(writer)
    }

    static func shared() throws -> AppDatabase {
        let url = try AppGroup.databaseURL()
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let pool = try DatabasePool(path: url.path, configuration: config)
        return try AppDatabase(pool)
    }
}
