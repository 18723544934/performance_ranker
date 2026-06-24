import Foundation
import Combine

@MainActor
class HardwareDetailViewModel: ObservableObject {
    @Published var hardware: Hardware?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFavorite = false

    private let hardwareId: Int
    private let apiClient: APIClient
    private let databaseService: DatabaseService
    private var cancellables = Set<AnyCancellable>()

    init(hardwareId: Int, apiClient: APIClient = .shared, databaseService: DatabaseService = .shared) {
        self.hardwareId = hardwareId
        self.apiClient = apiClient
        self.databaseService = databaseService
    }

    func loadDetail() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await fetchAndSaveDetail()
                try checkFavoriteStatus()
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    try? self.loadFromCache()
                }
            }
        }
    }

    private func fetchAndSaveDetail() async throws {
        let hardware = try await fetchHardwareDetail()
        try databaseService.saveHardware(hardware)
        try databaseService.addToHistory(History(hardwareId: hardwareId, hardwareName: hardware.name))
        await MainActor.run {
            self.hardware = hardware
        }
    }

    private func fetchHardwareDetail() async throws -> Hardware {
        try await withCheckedThrowingContinuation { continuation in
            apiClient.getHardwareDetail(id: hardwareId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                },
                receiveValue: { hardware in
                    continuation.resume(returning: hardware)
                }
            )
            .store(in: &cancellables)
        }
    }

    private func loadFromCache() throws {
        if let cachedHardware = try databaseService.getHardware(id: hardwareId) {
            self.hardware = cachedHardware
            try checkFavoriteStatus()
        }
    }

    private func checkFavoriteStatus() throws {
        isFavorite = try databaseService.isFavorite(hardwareId: hardwareId)
    }

    func toggleFavorite() {
        guard let hardware = hardware else { return }

        do {
            if isFavorite {
                try databaseService.removeFavorite(hardwareId: hardwareId)
            } else {
                try databaseService.addFavorite(Favorite(
                    hardwareId: hardwareId,
                    hardwareName: hardware.name
                ))
            }
            isFavorite.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var radarData: [RadarDataPoint] {
        guard let hardware = hardware else { return [] }

        var points: [RadarDataPoint] = []

        let singleCore = hardware.benchmarks.first { $0.metric == "single_core" }
        let multiCore = hardware.benchmarks.first { $0.metric == "multi_core" }
        let gpu3D = hardware.benchmarks.first { $0.metric == "gpu_3d" }
        let gpuCompute = hardware.benchmarks.first { $0.metric == "gpu_compute" }
        let ai = hardware.benchmarks.first { $0.metric == "ai" }
        let memory = hardware.benchmarks.first { $0.metric == "memory" }

        if let score = singleCore?.score {
            points.append(RadarDataPoint(label: "单核", value: score))
        }
        if let score = multiCore?.score {
            points.append(RadarDataPoint(label: "多核", value: score))
        }
        if let score = gpu3D?.score {
            points.append(RadarDataPoint(label: "3D 性能", value: score))
        }
        if let score = gpuCompute?.score {
            points.append(RadarDataPoint(label: "计算性能", value: score))
        }
        if let score = ai?.score {
            points.append(RadarDataPoint(label: "AI 推理", value: score))
        }
        if let score = memory?.score {
            points.append(RadarDataPoint(label: "内存", value: score))
        }

        return points
    }
}

struct RadarDataPoint {
    let label: String
    let value: Double
}
