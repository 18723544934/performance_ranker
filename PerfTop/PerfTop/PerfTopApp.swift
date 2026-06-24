import SwiftUI

@main
struct PerfTopApp: App {
    @StateObject private var compareManager = CompareManager()

    init() {
        setupAppearance()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(compareManager)
        }
    }

    private func setupAppearance() {
        let defaults = UserDefaults.standard
        if let modeRaw = defaults.object(forKey: "appearanceMode") as? Int,
           let mode = AppearanceMode(rawValue: modeRaw) {
            switch mode {
            case .light:
                overrideUserInterfaceStyle = .light
            case .dark:
                overrideUserInterfaceStyle = .dark
            case .system:
                overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HardwareListView()
                .tabItem {
                    Label("排行榜", systemImage: "list.number")
                }
                .tag(0)

            LadderView()
                .tabItem {
                    Label("天梯图", systemImage: "chart.bar.fill")
                }
                .tag(1)

            CompareView()
                .tabItem {
                    Label("对比", systemImage: "square.and.arrow.up")
                }
                .tag(2)

            FavoritesView()
                .tabItem {
                    Label("收藏", systemImage: "heart")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}
