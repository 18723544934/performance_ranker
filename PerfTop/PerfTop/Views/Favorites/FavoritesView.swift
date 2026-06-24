import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker(selection: $selectedTab) {
                    Text("我的收藏").tag(0)
                    Text("最近浏览").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if selectedTab == 0 {
                    favoritesContent
                } else {
                    historyContent
                }
            }
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var favoritesContent: some View {
        Group {
            if viewModel.favorites.isEmpty {
                emptyState(
                    icon: "heart",
                    title: "还没有收藏任何硬件",
                    subtitle: "点击详情页的心形按钮添加收藏"
                )
            } else {
                List {
                    ForEach(viewModel.favorites) { favorite in
                        NavigationLink(destination: HardwareDetailView(hardwareId: favorite.hardwareId)) {
                            FavoriteItemView(favorite: favorite)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.removeFavorite(hardwareId: favorite.hardwareId)
                            } label: {
                                Label("取消收藏", systemImage: "trash")
                            }
                        }
                    }
                }
                .refreshable {
                    viewModel.loadFavorites()
                }
            }
        }
    }

    private var historyContent: some View {
        Group {
            if viewModel.history.isEmpty {
                emptyState(
                    icon: "clock",
                    title: "还没有浏览记录",
                    subtitle: "浏览过的硬件会自动出现在这里"
                )
            } else {
                List {
                    ForEach(viewModel.history) { history in
                        NavigationLink(destination: HardwareDetailView(hardwareId: history.hardwareId)) {
                            HistoryItemView(history: history)
                        }
                    }
                }
                .refreshable {
                    viewModel.loadHistory()
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Text(subtitle)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct FavoriteItemView: View {
    let favorite: Favorite

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.hardwareName)
                    .font(.headline)
                    .lineLimit(1)

                Text(favorite.groupName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)

                Text(favorite.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HistoryItemView: View {
    let history: History

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(history.hardwareName)
                    .font(.headline)
                    .lineLimit(1)

                Text("浏览于 \(history.visitedAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class FavoritesViewModel: ObservableObject {
    @Published var favorites: [Favorite] = []
    @Published var history: [History] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let databaseService: DatabaseService

    init(databaseService: DatabaseService = .shared) {
        self.databaseService = databaseService
    }

    func loadFavorites() {
        isLoading = true
        errorMessage = nil

        do {
            favorites = try databaseService.getFavorites()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func loadHistory() {
        isLoading = true
        errorMessage = nil

        do {
            history = try databaseService.getHistory()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func removeFavorite(hardwareId: Int) {
        do {
            try databaseService.removeFavorite(hardwareId: hardwareId)
            favorites.removeAll { $0.hardwareId == hardwareId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearHistory() {
        do {
            try databaseService.clearHistory()
            history.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension DatabaseService {
    func clearHistory() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM history")
        }
    }
}

#Preview {
    FavoritesView()
}
