import Foundation
import Combine

@MainActor
class CompareViewModel: ObservableObject {
    @Published var selectedIds: [Int] = []
    @Published var selectedHardwares: [Hardware] = []
    @Published var comparisonResult: ComparisonResult?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient
    private let databaseService: DatabaseService
    private var cancellables = Set<AnyCancellable>()

    private static let maxSelection = 5

    init(apiClient: APIClient = .shared, databaseService: DatabaseService = .shared) {
        self.apiClient = apiClient
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
            } else {
                await fetchHardwareDetail(id: hardwareId)
            }
        }
    }

    private func fetchHardwareDetail(id: Int) async {
        do {
            let hardware = try await withCheckedThrowingContinuation { continuation in
                apiClient.getHardwareDetail(id: id)
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

            await MainActor.run {
                if let index = self.selectedIds.firstIndex(of: id) {
                    self.selectedHardwares.insert(hardware, at: index)
                }
            }
        } catch {
            print("Failed to fetch hardware detail: \(error)")
        }
    }

    func removeFromCompare(hardwareId: Int) {
        selectedIds.removeAll { $0 == hardwareId }
        selectedHardwares.removeAll { $0.id == hardwareId }
    }

    func clearSelection() {
        selectedIds.removeAll()
        selectedHardwares.removeAll()
        comparisonResult = nil
    }

    func performComparison() {
        guard isReadyToCompare else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let compareData = try await fetchCompareData()
                await MainActor.run {
                    self.comparisonResult = compareData.comparison
                    self.selectedHardwares = compareData.hardwares
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func fetchCompareData() async throws -> CompareData {
        try await withCheckedThrowingContinuation { continuation in
            apiClient.getCompareData(ids: selectedIds)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                },
                receiveValue: { data in
                    continuation.resume(returning: data)
                }
            )
            .store(in: &cancellables)
        }
    }

    var comparisonItems: [ComparisonItem] {
        guard !selectedHardwares.isEmpty else { return [] }

        var items: [ComparisonItem] = []

        let specs = selectedHardwares.map { $0.specifications }

        items.append(ComparisonItem(
            label: "品牌",
            values: selectedHardwares.map { $0.brand },
            bestIndex: nil
        ))

        items.append(ComparisonItem(
            label: "架构",
            values: selectedHardwares.map { $0.architecture },
            bestIndex: nil
        ))

        if let cores = specs.first?.cores {
            items.append(ComparisonItem(
                label: "核心数",
                values: specs.compactMap { $0.cores.map(String.init) },
                bestIndex: specs.compactMap { $0.cores }.indices(of: specs.compactMap { $0.cores }.max() ?? 0).first
            ))
        }

        if let threads = specs.first?.threads {
            items.append(ComparisonItem(
                label: "线程数",
                values: specs.compactMap { $0.threads.map(String.init) },
                bestIndex: specs.compactMap { $0.threads }.indices(of: specs.compactMap { $0.threads }.max() ?? 0).first
            ))
        }

        if let baseClock = specs.first?.baseClockGHz {
            items.append(ComparisonItem(
                label: "基础频率",
                values: specs.compactMap { $0.baseClockGHz.map { String(format: "%.1f GHz", $0) } },
                bestIndex: specs.compactMap { $0.baseClockGHz }.indices(of: specs.compactMap { $0.baseClockGHz }.max() ?? 0).first
            ))
        }

        if let boostClock = specs.first?.boostClockGHz {
            items.append(ComparisonItem(
                label: "加速频率",
                values: specs.compactMap { $0.boostClockGHz.map { String(format: "%.1f GHz", $0) } },
                bestIndex: specs.compactMap { $0.boostClockGHz }.indices(of: specs.compactMap { $0.boostClockGHz }.max() ?? 0).first
            ))
        }

        if let tdp = specs.first?.tdpWatts {
            items.append(ComparisonItem(
                label: "TDP",
                values: specs.compactMap { $0.tdpWatts.map { "\($0)W" } },
                bestIndex: specs.compactMap { $0.tdpWatts }.indices(of: specs.compactMap { $0.tdpWatts }.min() ?? 0).first
            ))
        }

        return items
    }

    var benchmarkComparison: [BenchmarkComparison] {
        guard !selectedHardwares.isEmpty else { return [] }

        var allMetrics: Set<String> = []
        selectedHardwares.forEach { hardware in
            hardware.benchmarks.forEach { benchmark in
                allMetrics.insert(benchmark.metric)
            }
        }

        return allMetrics.map { metric in
            let values = selectedHardwares.map { hardware in
                hardware.benchmarks.first { $0.metric == metric }?.score ?? 0
            }
            let maxValue = values.max() ?? 0

            return BenchmarkComparison(
                metric: metric,
                metricName: selectedHardwares.first?.benchmarks.first { $0.metric == metric }?.metricDisplayName ?? metric,
                values: values,
                maxValue: maxValue
            )
        }
    }
}

struct ComparisonItem {
    let label: String
    let values: [String]
    let bestIndex: Int?
}

struct BenchmarkComparison {
    let metric: String
    let metricName: String
    let values: [Double]
    let maxValue: Double
}
