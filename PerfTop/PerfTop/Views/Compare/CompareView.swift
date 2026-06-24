import SwiftUI

struct CompareView: View {
    @StateObject private var viewModel = CompareViewModel()
    @StateObject private var compareManager = CompareManager()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if compareManager.isReadyToCompare {
                    comparisonContent
                } else {
                    emptyState
                }
            }
            .navigationTitle("对比")
            .navigationBarTitleDisplayMode(.inline)
            .environmentObject(compareManager)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("选择至少 2 款硬件进行对比")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Text("最多可选择 5 款硬件")
                .font(.subheadline)
                .foregroundColor(.secondary)

            NavigationLink(destination: HardwareListView()) {
                Text("去选择硬件")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var comparisonContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                selectedHardwareCards

                Divider()

                specificationsComparison

                Divider()

                benchmarkComparison
            }
            .padding()
        }
        .refreshable {
            viewModel.performComparison()
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            viewModel.selectedIds = compareManager.selectedIds
            viewModel.selectedHardwares = compareManager.selectedHardwares
            viewModel.performComparison()
        }
    }

    private var selectedHardwareCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("已选择的硬件")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(compareManager.selectedHardwares) { hardware in
                        SelectedHardwareCard(
                            hardware: hardware,
                            onRemove: {
                                compareManager.removeFromCompare(hardwareId: hardware.id)
                                viewModel.removeFromCompare(hardwareId: hardware.id)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var specificationsComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("规格对比")
                .font(.headline)

            ForEach(viewModel.comparisonItems, id: \.label) { item in
                ComparisonRow(label: item.label, values: item.values, bestIndex: item.bestIndex)
            }
        }
    }

    private var benchmarkComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("跑分对比")
                .font(.headline)

            ForEach(viewModel.benchmarkComparison, id: \.metric) { benchmark in
                BenchmarkChartRow(
                    metric: benchmark.metricName,
                    values: benchmark.values,
                    maxValue: benchmark maxValue
                )
            }
        }
    }
}

struct SelectedHardwareCard: View {
    let hardware: Hardware
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hardware.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    Text(hardware.brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding()

            Text(String(format: "%.1f", hardware.overallScore))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
        }
        .frame(width: 200)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ComparisonRow: View {
    let label: String
    let values: [String]
    let bestIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Text(value)
                        .font(.caption)
                        .fontWeight(index == bestIndex ? .semibold : .regular)
                        .foregroundColor(index == bestIndex ? .green : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            index == bestIndex ?
                            Color.green.opacity(0.1) :
                            Color(UIColor.tertiarySystemGroupedBackground)
                        )
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

struct BenchmarkChartRow: View {
    let metric: String
    let values: [Double]
    let maxValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(metric)
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 4) {
                        GeometryReader { geometry in
                            let barHeight = geometry.size.height * (value / maxValue)

                            Rectangle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .frame(height: barHeight)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(4)
                                .position(x: geometry.size.width / 2, y: geometry.size.height - barHeight / 2)
                        }
                        .frame(height: 120)

                        Text(String(format: "%.0f", value))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

#Preview {
    CompareView()
}
