import Foundation
import Combine

class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://api.perftop.example.com/v1"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    private func buildURL(endpoint: String, parameters: [String: String] = [:]) -> URL? {
        guard var components = URLComponents(string: baseURL + endpoint) else {
            return nil
        }

        if !parameters.isEmpty {
            components.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: value)
            }
        }

        return components.url
    }

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        parameters: [String: String] = [:],
        body: Data? = nil
    ) -> AnyPublisher<T, Error> {
        guard let url = buildURL(endpoint: endpoint, parameters: parameters) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    func getHardwareList(
        category: Category,
        sortBy: String = "overall_score",
        order: String = "desc",
        page: Int = 1,
        perPage: Int = 20,
        filters: [String: String] = [:]
    ) -> AnyPublisher<HardwareListResponse, Error> {
        var params: [String: String] = [
            "category": category.rawValue,
            "sort_by": sortBy,
            "order": order,
            "page": String(page),
            "per_page": String(perPage)
        ]
        params.merge(filters) { _, new in new }

        return request(endpoint: "/hardwares", parameters: params)
    }

    func getHardwareDetail(id: Int) -> AnyPublisher<Hardware, Error> {
        return request(endpoint: "/hardwares/\(id)")
    }

    func getCompareData(ids: [Int]) -> AnyPublisher<CompareData, Error> {
        let idsString = ids.map(String.init).joined(separator: ",")
        return request(endpoint: "/hardwares/compare", parameters: ["ids": idsString])
    }

    func searchHardware(query: String, category: Category? = nil) -> AnyPublisher<HardwareListResponse, Error> {
        var params = ["q": query]
        if let category = category {
            params["category"] = category.rawValue
        }
        return request(endpoint: "/hardwares/search", parameters: params)
    }

    func getFilterOptions(category: Category) -> AnyPublisher<FilterOptions, Error> {
        return request(endpoint: "/meta/filters", parameters: ["category": category.rawValue])
    }

    func exportAllData() -> AnyPublisher<[Hardware], Error> {
        return request(endpoint: "/hardwares/export/all")
    }

    func getBenchmarkSources() -> AnyPublisher<[String: [String]], Error> {
        return request(endpoint: "/benchmarks/sources")
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    case serverError(statusCode: Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .networkError:
            return "网络连接错误"
        case .decodingError:
            return "数据解析错误"
        case .serverError(let statusCode):
            return "服务器错误: \(statusCode)"
        case .noData:
            return "没有数据"
        }
    }
}
