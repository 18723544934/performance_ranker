import Foundation
import GRDB

class DatabaseService {
    static let shared = DatabaseService()

    private let dbQueue: DatabaseQueue
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let fileURL = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("PerfTop")
            .appendingPathComponent("database.sqlite")

        try! FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)

        dbQueue = try! DatabaseQueue(path: fileURL.path)
        try! setupDatabase()
    }

    private func setupDatabase() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "hardware") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("brand", .text).notNull()
                t.column("category", .text).notNull()
                t.column("architecture", .text).notNull()
                t.column("launch_date", .date)
                t.column("specifications", .blob).notNull()
                t.column("benchmarks", .blob).notNull()
                t.column("overall_score", .double).notNull()
                t.column("price", .blob)
                t.column("image_urls", .blob)
                t.column("cached_at", .datetime).notNull()
            }

            try db.create(table: "favorite") { t in
                t.column("id", .text).primaryKey()
                t.column("hardware_id", .integer).notNull()
                t.column("hardware_name", .text).notNull()
                t.column("group_name", .text).notNull()
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: "history") { t in
                t.column("id", .text).primaryKey()
                t.column("hardware_id", .integer).notNull()
                t.column("hardware_name", .text).notNull()
                t.column("visited_at", .datetime).notNull()
            }

            try db.create(index: "favorite_hardware_id", on: "favorite", columns: ["hardware_id"])
            try db.create(index: "history_hardware_id", on: "history", columns: ["hardware_id"])
            try db.create(index: "history_visited_at", on: "history", columns: ["visited_at"])
        }

        try migrator.migrate(dbQueue)
    }

    func saveHardware(_ hardware: Hardware) throws {
        try dbQueue.write { db in
            let specsData = try encoder.encode(hardware.specifications)
            let benchmarksData = try encoder.encode(hardware.benchmarks)
            let priceData = try hardware.price.map { try encoder.encode($0) }
            let imageUrlsData = try hardware.imageUrls.map { try encoder.encode($0) }

            try db.execute(
                sql: "INSERT OR REPLACE INTO hardware (id, name, brand, category, architecture, launch_date, specifications, benchmarks, overall_score, price, image_urls, cached_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                arguments: [
                    hardware.id,
                    hardware.name,
                    hardware.brand,
                    hardware.category.rawValue,
                    hardware.architecture,
                    hardware.launchDate,
                    specsData,
                    benchmarksData,
                    hardware.overallScore,
                    priceData,
                    imageUrlsData,
                    Date()
                ]
            )
        }
    }

    func getHardware(id: Int) throws -> Hardware? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM hardware WHERE id = ?",
                arguments: [id]
            ) else {
                return nil
            }

            return try decodeHardware(from: row)
        }
    }

    func getHardwareList(
        category: Category,
        limit: Int = 20,
        offset: Int = 0
    ) throws -> [HardwareListItem] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name, brand, category, overall_score,
                       json_extract(benchmarks, '$[0]') as top_benchmark
                FROM hardware
                WHERE category = ?
                ORDER BY overall_score DESC
                LIMIT ? OFFSET ?
                """,
                arguments: [category.rawValue, limit, offset]
            )

            return try rows.enumerated().map { index, row in
                let topBenchmarks: [Benchmark] = if let data = row.data(at: "top_benchmark") {
                    [try decoder.decode(Benchmark.self, from: data)]
                } else {
                    []
                }

                return HardwareListItem(
                    id: row["id"],
                    name: row["name"],
                    brand: row["brand"],
                    category: Category(rawValue: row["category"]) ?? .pcCPU,
                    overallScore: row["overall_score"],
                    topBenchmarks: topBenchmarks,
                    rank: offset + index + 1
                )
            }
        }
    }

    func searchHardware(query: String, category: Category? = nil) throws -> [HardwareListItem] {
        try dbQueue.read { db in
            var sql = """
            SELECT id, name, brand, category, overall_score
            FROM hardware
            WHERE name LIKE ?
            """
            var arguments: [DatabaseValue] = ["%\(query)%"]

            if let category = category {
                sql += " AND category = ?"
                arguments.append(category.rawValue)
            }

            sql += " ORDER BY overall_score DESC LIMIT 50"

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))

            return try rows.enumerated().map { index, row in
                HardwareListItem(
                    id: row["id"],
                    name: row["name"],
                    brand: row["brand"],
                    category: Category(rawValue: row["category"]) ?? .pcCPU,
                    overallScore: row["overall_score"],
                    topBenchmarks: [],
                    rank: index + 1
                )
            }
        }
    }

    private func decodeHardware(from row: Row) throws -> Hardware {
        let specsData: Data = row["specifications"]
        let benchmarksData: Data = row["benchmarks"]
        let specifications = try decoder.decode(Specs.self, from: specsData)
        let benchmarks = try decoder.decode([Benchmark].self, from: benchmarksData)
        let price: PriceInfo? = if let data: Data? = row["price"], let data = data {
            try decoder.decode(PriceInfo.self, from: data)
        } else {
            nil
        }
        let imageUrls: [String]? = if let data: Data? = row["image_urls"], let data = data {
            try decoder.decode([String].self, from: data)
        } else {
            nil
        }

        return Hardware(
            id: row["id"],
            name: row["name"],
            brand: row["brand"],
            category: Category(rawValue: row["category"]) ?? .pcCPU,
            architecture: row["architecture"],
            launchDate: row["launch_date"],
            specifications: specifications,
            benchmarks: benchmarks,
            overallScore: row["overall_score"],
            price: price,
            imageUrls: imageUrls
        )
    }

    func addFavorite(_ favorite: Favorite) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO favorite (id, hardware_id, hardware_name, group_name, created_at) VALUES (?, ?, ?, ?, ?)",
                arguments: [
                    favorite.id.uuidString,
                    favorite.hardwareId,
                    favorite.hardwareName,
                    favorite.groupName,
                    favorite.createdAt
                ]
            )
        }
    }

    func removeFavorite(hardwareId: Int) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM favorite WHERE hardware_id = ?",
                arguments: [hardwareId]
            )
        }
    }

    func getFavorites() throws -> [Favorite] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM favorite ORDER BY created_at DESC"
            )
            return rows.map { row in
                Favorite(
                    id: UUID(uuidString: row["id"]) ?? UUID(),
                    hardwareId: row["hardware_id"],
                    hardwareName: row["hardware_name"],
                    groupName: row["group_name"],
                    createdAt: row["created_at"]
                )
            }
        }
    }

    func isFavorite(hardwareId: Int) throws -> Bool {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM favorite WHERE hardware_id = ?",
                arguments: [hardwareId]
            ) ?? 0 > 0
        }
    }

    func addToHistory(_ history: History) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO history (id, hardware_id, hardware_name, visited_at) VALUES (?, ?, ?, ?)",
                arguments: [
                    history.id.uuidString,
                    history.hardwareId,
                    history.hardwareName,
                    history.visitedAt
                ]
            )

            try db.execute(
                sql: "DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY visited_at DESC LIMIT 100)"
            )
        }
    }

    func getHistory(limit: Int = 50) throws -> [History] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM history ORDER BY visited_at DESC LIMIT ?",
                arguments: [limit]
            )
            return rows.map { row in
                History(
                    id: UUID(uuidString: row["id"]) ?? UUID(),
                    hardwareId: row["hardware_id"],
                    hardwareName: row["hardware_name"],
                    visitedAt: row["visited_at"]
                )
            }
        }
    }

    func clearCache() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM hardware")
        }
    }

    func getLastUpdateTime() throws -> Date? {
        try dbQueue.read { db in
            try Date.fetchOne(
                db,
                sql: "SELECT MAX(cached_at) FROM hardware"
            )
        }
    }
}
