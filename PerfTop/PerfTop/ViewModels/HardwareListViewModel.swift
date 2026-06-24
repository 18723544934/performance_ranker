import Foundation
import Combine

@MainActor
class HardwareListViewModel: ObservableObject {
    @Published var items: [HardwareListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMoreData = true
    @Published var currentCategory: Category = .pcCPU
    @Published var currentSortBy: String = "overall_score"

    private var currentPage = 1
    private let perPage = 20
    private var cancellables = Set<AnyCancellable>()

    private let apiClient: APIClient
    private let databaseService: DatabaseService

    init(apiClient: APIClient = .shared, databaseService: DatabaseService = .shared) {
        self.apiClient = apiClient
        self.databaseService = databaseService
    }

    func loadItems(refresh: Bool = false) {
        if refresh {
            currentPage = 1
            hasMoreData = true
            items.removeAll()
        }

        guard !isLoading && hasMoreData else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await fetchHardwareList()
                await MainActor.run {
                    if refresh {
                        self.items = response.data
                    } else {
                        self.items.append(contentsOf: response.data)
                    }
                    self.currentPage += 1
                    self.hasMoreData = response.data.count == self.perPage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false

                    if refresh {
                        try? self.loadFromCache()
                    }
                }
            }
        }
    }

    private func fetchHardwareList() async throws -> HardwareListResponse {
        try await withCheckedThrowingContinuation { continuation in
            apiClient.getHardwareList(
                category: currentCategory,
                sortBy: currentSortBy,
                order: "desc",
                page: currentPage,
                perPage: perPage
            )
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                },
                receiveValue: { response in
                    continuation.resume(returning: response)
                }
            )
            .store(in: &cancellables)
        }
    }

    private func loadFromCache() throws {
        let cachedItems = try databaseService.getHardwareList(
            category: currentCategory,
            limit: perPage,
            offset: (currentPage - 1) * perPage
        )
        items = cachedItems
        hasMoreData = cachedItems.count == perPage
    }

    func changeCategory(_ category: Category) {
        guard currentCategory != category else { return }
        currentCategory = category
        loadItems(refresh: true)
    }

    func changeSortBy(_ sortBy: String) {
        guard currentSortBy != sortBy else { return }
        currentSortBy = sortBy
        loadItems(refresh: true)
    }

    func search(query: String) {
        guard !query.isEmpty else {
            loadItems(refresh: true)
            return
        }

        isLoading = true
        Task {
            do {
                let response = try await searchHardware(query: query)
                await MainActor.run {
                    self.items = response.data
                    self.hasMoreMoreData = false
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    if let cachedItems = try? self.databaseService.searchHardware(
                        query: query,
                        category: self.currentCategory
                    ) {
                        self.items = cachedItems
                    } else {
                        self.items = []
                        self.errorMessage = error.localizedDescription
                    }
                    self.hasMoreMoreData = false
                    self.isLoading = false
                }
            }
        }
    }

    private func searchHardware(query: String) async throws -> HardwareListResponse {
        try await withCheckedThrowingContinuation { continuation in
            apiClient.searchHardware(query: query, category: currentCategory)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                },
                receiveValue: { response in
                    continuation.resume(returning: response)
                }
            )
            .store(in: &cancellables)
        }
    }
}
