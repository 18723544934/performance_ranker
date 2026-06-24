import Foundation

enum Category: String, Codable, CaseIterable {
    case pcCPU = "pc_cpu"
    case pcGPU = "pc_gpu"
    case mobileCPU = "mobile_cpu"
    case mobileGPU = "mobile_gpu"

    var displayName: String {
        switch self {
        case .pcCPU: return "电脑 CPU"
        case .pcGPU: return "电脑 GPU"
        case .mobileCPU: return "手机 CPU"
        case .mobileGPU: return "手机 GPU"
        }
    }
}

struct Hardware: Codable, Identifiable {
    let id: Int
    let name: String
    let brand: String
    let category: Category
    let architecture: String
    let launchDate: Date?
    let specifications: Specs
    let benchmarks: [Benchmark]
    let overallScore: Double
    let price: PriceInfo?
    let imageUrls: [String]?

    var displayName: String {
        name
    }

    var formattedScore: String {
        String(format: "%.1f", overallScore)
    }
}

struct Specs: Codable {
    // CPU
    let cores: Int?
    let threads: Int?
    let baseClockGHz: Double?
    let boostClockGHz: Double?
    let tdpWatts: Int?
    let lithography: String?
    // GPU
    let vramGB: Int?
    let memoryType: String?
    let bandwidthGBs: Double?
    // 通用
    let cache: String?

    var formattedCores: String? {
        cores.map { "\($0) 核" }
    }

    var formattedThreads: String? {
        threads.map { "\($0) 线程" }
    }

    var formattedClock: String? {
        if let base = baseClockGHz, let boost = boostClockGHz {
            return String(format: "%.1f - %.1f GHz", base, boost)
        } else if let base = baseClockGHz {
            return String(format: "%.1f GHz", base)
        }
        return nil
    }

    var formattedTDP: String? {
        tdpWatts.map { "\($0)W" }
    }
}

struct Benchmark: Codable, Identifiable {
    let id: String?
    let source: String
    let metric: String
    let score: Double
    let unit: String

    var metricDisplayName: String {
        switch metric {
        case "single_core": return "单核"
        case "multi_core": return "多核"
        case "gpu_3d": return "3D 性能"
        case "gpu_compute": return "计算性能"
        case "memory": return "内存"
        case "ai": return "AI 推理"
        default: return metric
        }
    }
}

struct PriceInfo: Codable {
    let currency: String
    let amount: Double
    let source: String
    let updated: Date?

    var formattedPrice: String {
        String(format: "¥%.0f", amount)
    }
}

struct HardwareListItem: Codable, Identifiable {
    let id: Int
    let name: String
    let brand: String
    let category: Category
    let overallScore: Double
    let topBenchmarks: [Benchmark]
    let rank: Int?

    var displayName: String {
        name
    }

    var formattedScore: String {
        String(format: "%.1f", overallScore)
    }

    var scoreRatio: Double {
        overallScore / 1000.0
    }
}

struct HardwareListResponse: Codable {
    let data: [HardwareListItem]
    let meta: Meta
}

struct Meta: Codable {
    let total: Int
    let page: Int
    let perPage: Int
}

struct CompareData: Codable {
    let hardwares: [Hardware]
    let comparison: ComparisonResult
}

struct ComparisonResult: Codable {
    let best: [String: Int]
    let worst: [String: Int]
}

struct FilterOptions: Codable {
    let brands: [String]
    let architectures: [String]
    let coreRange: (min: Int, max: Int)?
    let frequencyRange: (min: Double, max: Double)?
    let years: [Int]
    let tdpRange: (min: Int, max: Int)?
}
