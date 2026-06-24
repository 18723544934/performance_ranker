import Foundation

struct Favorite: Codable, Identifiable {
    let id: UUID
    let hardwareId: Int
    let hardwareName: String
    let groupName: String
    let createdAt: Date

    init(hardwareId: Int, hardwareName: String, groupName: String = "默认") {
        self.id = UUID()
        self.hardwareId = hardwareId
        self.hardwareName = hardwareName
        self.groupName = groupName
        self.createdAt = Date()
    }
}

struct History: Codable, Identifiable {
    let id: UUID
    let hardwareId: Int
    let hardwareName: String
    let visitedAt: Date

    init(hardwareId: Int, hardwareName: String) {
        self.id = UUID()
        self.hardwareId = hardwareId
        self.hardwareName = hardwareName
        self.visitedAt = Date()
    }
}
