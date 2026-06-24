import Foundation
import Combine

@MainActor
class CompareManager: ObservableObject {
    @Published var selectedIds: [Int] = []
    @Published var selectedHardwares: [Hardware] = []

    private static let maxSelection = 5
    private let databaseService: DatabaseService

    init(databaseService: DatabaseService = .shared) {
        self.databaseService = databaseService
    }

    var canAddMore: Bool {
        selectedIds.count < Self.maxSelection
    }

    var isReadyToCompare: Bool {
        selectedIds.count >= 2
    }

    func addToCompare(hardwareId: Int, hardwareName: String) {
        guard canAddMore, !selectedIds.contains(hardwareId) else { return }

        selectedIds.append(hardwareId)

        Task {
            if let hardware = try? databaseService.getHardware(id: hardwareId) {
                await MainActor.run {
                    self.selectedHardwares.append(hardware)
                }
            }
        }
    }

    func removeFromCompare(hardwareId: Int) {
        selectedIds.removeAll { $0 == hardwareId }
        selectedHardwares.removeAll { $0.id == hardwareId }
    }

    func clearSelection() {
        selectedIds.removeAll()
        selectedHardwares.removeAll()
    }

    var selectionCount: Int {
        selectedIds.count
    }
}
