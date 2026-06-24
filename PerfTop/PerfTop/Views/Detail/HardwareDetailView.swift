import SwiftUI

struct HardwareDetailView: View {
    let hardwareId: Int
    @StateObject private var viewModel: HardwareDetailViewModel
    @EnvironmentObject private var compareManager: CompareManager

    init(hardwareId: Int) {
        self.hardwareId = hardwareId
        _viewModel = StateObject(wrappedValue: HardwareDetailViewModel(hardwareId: hardwareId))
    }

    var body: some View {
        ScrollView {
            if let hardware = viewModel.hardware {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection(hardware: hardware)

                    Divider()

                    scoreCardsSection(hardware: hardware)

                    Divider()

                    radarChartSection

                    Divider()

                    specificationsSection(hardware: hardware)

                    Divider()

                    benchmarkDetailsSection(hardware: hardware)

                    if let price = hardware.price {
                        Divider()
                        priceSection(price: price)
                    }
                }
                .padding()
            } else if viewModel.isLoading {
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
                        viewModel.loadDetail()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.hardware?.name ?? "详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        viewModel.toggleFavorite()
                    } label: {
                        Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(viewModel.isFavorite ? .red : .primary)
                    }

                    Button {
                        compareManager.addToCompare(hardwareId: hardwareId, hardwareName: viewModel.hardware?.name ?? "")
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadDetail()
        }
    }

    private func headerSection(hardware: Hardware) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hardware.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(hardware.brand + " · " + hardware.architecture)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let launchDate = hardware.launchDate {
                    Text("发布于 \(launchDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                ScoreCard(title: "综合评分", score: hardware.overallScore, color: .blue)
            }
        }
    }

    private func scoreCardsSection(hardware: Hardware) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(hardware.benchmarks.prefix(5)) { benchmark in
                    ScoreCard(
                        title: benchmark.metricDisplayName,
                        score: benchmark.score,
                        color: scoreColor(for: benchmark.source)
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private var radarChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("性能雷达图")
                .font(.headline)

            RadarChartView(data: viewModel.radarData)
                .frame(height: 300)
        }
    }

    private func specificationsSection(hardware: Hardware) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("规格参数")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if let cores = hardware.specifications.formattedCores {
                    SpecRow(label: "核心数", value: cores)
                }
                if let threads = hardware.specifications.formattedThreads {
                    SpecRow(label: "线程数", value: threads)
                }
                if let clock = hardware.specifications.formattedClock {
                    SpecRow(label: "频率", value: clock)
                }
                if let tdp = hardware.specifications.formattedTDP {
                    SpecRow(label: "TDP", value: tdp)
                }
                if let lithography = hardware.specifications.lithography {
                    SpecRow(label: "制程", value: lithography)
                }
                if let cache = hardware.specifications.cache {
                    SpecRow(label: "缓存", value: cache)
                }
                if let vram = hardware.specifications.vramGB {
                    SpecRow(label: "显存", value: "\(vram) GB")
                }
                if let memoryType = hardware.specifications.memoryType {
                    SpecRow(label: "显存类型", value: memoryType)
                }
            }
        }
    }

    private func benchmarkDetailsSection(hardware: Hardware) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基准跑分")
                .font(.headline)

            ForEach(hardware.benchmarks) { benchmark in
                BenchmarkRow(benchmark: benchmark)
            }
        }
    }

    private func priceSection(price: PriceInfo) -> some View {
        HStack {
            Text("参考价格")
                .font(.headline)

            Spacer()

            Text(price.formattedPrice)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.green)

            Text("来源: \(price.source)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func scoreColor(for source: String) -> Color {
        switch source.lowercased() {
        case "geekbench":
            return .blue
        case "cinebench":
            return .purple
        case "3dmark":
            return .orange
        case "antutu":
            return .red
        default:
            return .green
        }
    }
}

struct ScoreCard: View {
    let title: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(String(format: "%.0f", score))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(width: 120, height: 80)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct SpecRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

struct BenchmarkRow: View {
    let benchmark: Benchmark

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(benchmark.source)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(benchmark.metricDisplayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f", benchmark.score))
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(benchmark.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

struct RadarChartView: View {
    let data: [RadarDataPoint]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 20

            ZStack {
                ForEach(0..<5) { i in
                    let levelRadius = radius * CGFloat(i + 1) / 5
                    Path { path in
                        let sides = CGFloat(data.count)
                        for j in 0..<Int(sides) {
                            let angle = 2 * .pi * CGFloat(j) / sides - .pi / 2
                            let x = center.x + levelRadius * cos(angle)
                            let y = center.y + levelRadius * sin(angle)
                            if j == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.closeSubpath()
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }

                if !data.isEmpty {
                    Path { path in
                        let sides = CGFloat(data.count)
                        let maxValue = data.map { $0.value }.max() ?? 1

                        for i in 0..<Int(sides) {
                            let angle = 2 * .pi * CGFloat(i) / sides - .pi / 2
                            let normalizedValue = data[i].value / maxValue
                            let x = center.x + radius * normalizedValue * cos(angle)
                            let y = center.y + radius * normalizedValue * sin(angle)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.closeSubpath()
                    }
                    .fill(Color.blue.opacity(0.3))
                    .stroke(Color.blue, lineWidth: 2)

                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        let angle = 2 * .pi * CGFloat(index) / CGFloat(data.count) - .pi / 2
                        let x = center.x + radius * cos(angle)
                        let y = center.y + radius * sin(angle)

                        Text(point.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .position(x: x + (x > center.x ? 20 : -20), y: y + (y > center.y ? 20 : -20))
                            .frame(width: 60, alignment: x > center.x ? .leading : .trailing)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        HardwareDetailView(hardwareId: 1)
    }
}
