import SwiftUI

struct LadderView: View {
    @StateObject private var viewModel = LadderViewModel()
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    categorySelector

                    if viewModel.isLoading {
                        ProgressView("加载中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)

                            Text(errorMessage)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)

                            Button("重试") {
                                viewModel.loadLadderData()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else {
                        ladderChart
                    }
                }
            }
            .navigationTitle("天梯图")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.loadLadderData()
        }
    }

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Category.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: viewModel.currentCategory == category
                    ) {
                        viewModel.changeCategory(category)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.systemBackground))
    }

    private var ladderChart: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.ladderItems.enumerated()), id: \.element.id) { index, item in
                        LadderBarItem(
                            item: item,
                            rank: index + 1,
                            maxWidth: geometry.size.width * 3,
                            scale: scale
                        )
                    }
                }
                .padding()
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = value
                    }
            )
        }
    }
}

struct LadderBarItem: View {
    let item: LadderItem
    let rank: Int
    let maxWidth: CGFloat
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            rankLabel

            NavigationLink(destination: HardwareDetailView(hardwareId: item.id)) {
                barContent
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 6)
    }

    private var rankLabel: some View {
        Text("\(rank)")
            .font(.subheadline)
            .fontWeight(.bold)
            .frame(width: 30)
            .foregroundColor(rankColor)
    }

    private var rankColor: Color {
        if rank == 1 {
            return .yellow
        } else if rank == 2 {
            return .orange
        } else if rank == 3 {
            return .red
        } else {
            return .secondary
        }
    }

    private var barContent: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(height: 24)

                Rectangle()
                    .fill(barGradient)
                    .frame(
                        width: barWidth,
                        height: 24
                    )

                Text(item.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .cornerRadius(4)

            Text(String(format: "%.1f", item.score))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private var barWidth: CGFloat {
        maxWidth * scale * (item.score / viewModelMaxScore)
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: brandColors),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var brandColors: [Color] {
        switch item.brand.lowercased() {
        case "intel":
            return [.blue, .purple]
        case "amd":
            return [.red, .orange]
        case "nvidia":
            return [.green, .teal]
        case "apple":
            return [.gray, .black]
        case "qualcomm":
            return [.blue, .cyan]
        case "mediatek":
            return [.orange, .yellow]
        default:
            return [.blue, .purple]
        }
    }

    private var viewModelMaxScore: Double {
        1000.0
    }
}

@MainActor
class LadderViewModel: ObservableObject {
    @Published var ladderItems: [LadderItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentCategory: Category = .pcCPU

    private let apiClient: APIClient
    private let databaseService: DatabaseService
    private var cancellables = Set<AnyCancellable>()

    init(apiClient: APIClient = .shared, databaseService: DatabaseService = .shared) {
        self.apiClient = apiClient
        self.databaseService = databaseService
    }

    func loadLadderData() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let items = try await fetchLadderData()
                await MainActor.run {
                    self.ladderItems = items
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

    private func fetchLadderData() async throws -> [LadderItem] {
        try await withCheckedThrowingContinuation { continuation in
            apiClient.getHardwareList(
                category: currentCategory,
                sortBy: "overall_score",
                order: "desc",
                page: 1,
                perPage: 100
            )
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                },
                receiveValue: { response in
                    let items = response.data.map { item in
                        LadderItem(
                            id: item.id,
                            name: item.name,
                            brand: item.brand,
                            score: item.overallScore
                        )
                    }
                    continuation.resume(returning: items)
                }
            )
            .store(in: &cancellables)
        }
    }

    private func loadFromCache() throws {
        let cachedItems = try databaseService.getHardwareList(
            category: currentCategory,
            limit: 100,
            offset: 0
        )
        ladderItems = cachedItems.map { item in
            LadderItem(
                id: item.id,
                name: item.name,
                brand: item.brand,
                score: item.overallScore
            )
        }
    }

    func changeCategory(_ category: Category) {
        guard currentCategory != category else { return }
        currentCategory = category
        loadLadderData()
    }
}

struct LadderItem: Identifiable {
    let id: Int
    let name: String
    let brand: String
    let score: Double
}

#Preview {
    LadderView()
}
