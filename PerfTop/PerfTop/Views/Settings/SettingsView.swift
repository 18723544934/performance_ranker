import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingClearCacheAlert = false

    var body: some View {
        NavigationView {
            Form {
                dataSection
                appearanceSection
                aboutSection
            }
            .navigationTitle("设置")
            .alert("清除缓存", isPresented: $showingClearCacheAlert) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    viewModel.clearCache()
                }
            } message: {
                Text("清除后将删除所有离线数据，下次需要重新下载。")
            }
        }
    }

    private var dataSection: some View {
        Section {
            HStack {
                Text("仅 Wi-Fi 下更新")
                Spacer()
                Toggle("", isOn: $viewModel.wifiOnlyUpdate)
            }

            HStack {
                Text("自动更新")
                Text(viewModel.autoUpdateInterval.description)
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $viewModel.autoUpdateInterval) {
                    ForEach(UpdateInterval.allCases, id: \.self) { interval in
                        Text(interval.description).tag(interval)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }

            Button {
                showingClearCacheAlert = true
            } label: {
                HStack {
                    Text("清除缓存")
                    Spacer()
                    if let cacheSize = viewModel.cacheSize {
                        Text(cacheSize)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .foregroundColor(.red)
        } header: {
            Text("数据管理")
        }
    }

    private var appearanceSection: some View {
        Section {
            HStack {
                Text("外观主题")
                Spacer()
                Text(viewModel.appearanceMode.description)
                    .foregroundColor(.secondary)
                Picker("", selection: $viewModel.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.description).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        } header: {
            Text("外观")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("数据来源")
                Spacer()
                Text("Geekbench, PassMark, 3DMark")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Link(destination: URL(string: "mailto:support@perftop.com")!) {
                HStack {
                    Text("意见反馈")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Link(destination: URL(string: "https://perftop.com/privacy")!) {
                HStack {
                    Text("隐私政策")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("关于")
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var wifiOnlyUpdate = true
    @Published var autoUpdateInterval: UpdateInterval = .daily
    @Published var appearanceMode: AppearanceMode = .system
    @Published var cacheSize: String?

    private let databaseService: DatabaseService

    init(databaseService: DatabaseService = .shared) {
        self.databaseService = databaseService
        loadSettings()
        updateCacheSize()
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        wifiOnlyUpdate = defaults.bool(forKey: "wifiOnlyUpdate")
        if let intervalRaw = defaults.object(forKey: "autoUpdateInterval") as? Int,
           let interval = UpdateInterval(rawValue: intervalRaw) {
            autoUpdateInterval = interval
        }
        if let modeRaw = defaults.object(forKey: "appearanceMode") as? Int,
           let mode = AppearanceMode(rawValue: modeRaw) {
            appearanceMode = mode
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(wifiOnlyUpdate, forKey: "wifiOnlyUpdate")
        defaults.set(autoUpdateInterval.rawValue, forKey: "autoUpdateInterval")
        defaults.set(appearanceMode.rawValue, forKey: "appearanceMode")
    }

    func clearCache() {
        do {
            try databaseService.clearCache()
            cacheSize = "0 MB"
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }

    func updateCacheSize() {
        Task {
            let size = await calculateCacheSize()
            await MainActor.run {
                self.cacheSize = formatCacheSize(size)
            }
        }
    }

    private func calculateCacheSize() async -> Int64 {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let perftopURL = appSupportURL.appendingPathComponent("PerfTop")

            if let enumerator = fileManager.enumerator(at: perftopURL, includingPropertiesForKeys: [.fileSizeKey]) {
                var totalSize: Int64 = 0
                for case let fileURL as URL in enumerator {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
                return totalSize
            }
        } catch {
            print("Failed to calculate cache size: \(error)")
        }
        return 0
    }

    private func formatCacheSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

enum UpdateInterval: Int, CaseIterable {
    case hourly = 1
    case daily = 24
    case weekly = 168

    var description: String {
        switch self {
        case .hourly: return "每小时"
        case .daily: return "每天"
        case .weekly: return "每周"
        }
    }
}

enum AppearanceMode: Int, CaseIterable {
    case light = 0
    case dark = 1
    case system = 2

    var description: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        }
    }
}

#Preview {
    SettingsView()
}
