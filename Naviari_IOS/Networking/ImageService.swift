import Foundation
import OSLog
import UIKit

enum ImageServiceError: Error {
    case invalidURL
    case invalidResponse
    case decodingFailed
}

struct ImageService {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    private let logger = Logger(subsystem: "fi.mobiari.naviari-ios", category: "ImageService")

    init(
        baseURL: URL = RaceService.defaultBaseURL,
        apiKey: String = RaceService.defaultAPIKey,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    func fetchImage(withId id: String) async throws -> UIImage {
        let request = try makeRequest(for: id)
        logger.log("ImageService Request -> \(request.url?.absoluteString ?? "<nil>", privacy: .public)")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        guard let image = UIImage(data: data) else {
            throw ImageServiceError.decodingFailed
        }
        return image
    }

    private func makeRequest(for id: String) throws -> URLRequest {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("images")
            .appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                let snippet = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
                logger.error("ImageService Response <- status \(httpResponse.statusCode) body \(snippet, privacy: .public)")
            }
            throw ImageServiceError.invalidResponse
        }
    }
}

actor ImageRepository {
    static let shared = ImageRepository()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlightTasks: [String: Task<UIImage, Error>] = [:]
    private let service = ImageService()

    func image(for id: String) async -> UIImage? {
        if let cached = cache.object(forKey: id as NSString) {
            return cached
        }
        if let task = inFlightTasks[id] {
            return try? await task.value
        }
        let task = Task {
            try await service.fetchImage(withId: id)
        }
        inFlightTasks[id] = task
        defer { inFlightTasks[id] = nil }
        if let image = try? await task.value {
            cache.setObject(image, forKey: id as NSString)
            return image
        }
        return nil
    }
}
