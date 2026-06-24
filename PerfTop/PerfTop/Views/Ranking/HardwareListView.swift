import SwiftUI

struct HardwareListView: View {
    @StateObject private var viewModel = HardwareListViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                categorySelector

                sortButtons

                List {
                    ForEach(viewModel.items) { item in
                        NavigationLink(destination: HardwareDetailView(hardwareId: item.id)) {
                            HardwareListItemView(item: item)
                        }
                        .onAppear {
                            if item.id == viewModel.items.last?.id {
                                viewModel.loadItems()
                            }
                        }
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowSeparator(.hidden)
                    }
                }
                .refreshable {
                    viewModel.loadItems(refresh: true)
                }
                .searchable(text: $searchText, prompt: "搜索型号...")
                .onChange(of: searchText) { newValue in
                    viewModel.search(query: newValue)
                }
            }
            .navigationTitle("排行榜")
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
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
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var sortButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SortButton(title: "综合", isSelected: viewModel.currentSortBy == "overall_score") {
                    viewModel.changeSortBy("overall_score")
                }
                SortButton(title: "单核", isSelected: viewModel.currentSortBy == "single_core") {
                    viewModel.changeSortBy("single_core")
                }
                SortButton(title: "多核", isSelected: viewModel.currentSortBy == "multi_core") {
                    viewModel.changeSortBy("multi_core")
                }
                SortButton(title: "游戏", isSelected: viewModel.currentSortBy == "gaming") {
                    viewModel.changeSortBy("gaming")
                }
                SortButton(title: "能效", isSelected: viewModel.currentSortBy == "efficiency") {
                    viewModel.changeSortBy("efficiency")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct CategoryButton: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(category.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(UIColor.secondarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct SortButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(12)
        }
    }
}

struct HardwareListItemView: View {
    let item: HardwareListItem

    var body: some View {
        HStack(spacing: 12) {
            rankLabel

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(item.brand)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.formattedScore)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                scoreBar
            }
            .frame(width: 80)
        }
        .padding(.vertical, 4)
    }

    private var rankLabel: some View {
        Text("\(item.rank ?? 0)")
            .font(.title3)
            .fontWeight(.bold)
            .frame(width: 30)
            .foregroundColor(rankColor)
    }

    private var rankColor: Color {
        guard let rank = item.rank else { return .secondary }
        if rank <= 3 {
            return .orange
        } else if rank <= 10 {
            return .blue
        } else {
            return .secondary
        }
    }

    private var scoreBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(height: 4)

                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * item.scoreRatio, height: 4)
            }
        }
        .frame(height: 4)
    }
}

#Preview {
    HardwareListView()
}
