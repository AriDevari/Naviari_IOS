import Foundation
import OSLog

enum BoatMetricsServiceError: LocalizedError {
    case invalidURL
    case missingStartEntryId
    case encodingFailed
    case serverError(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL."
        case .missingStartEntryId:
            return "Missing start entry identifier."
        case .encodingFailed:
            return "Failed to encode boat metrics payload."
        case let .serverError(status, message):
            if let message, !message.isEmpty {
                return "Server error (\(status)): \(message)"
            }
            return "Server error (\(status))."
        }
    }
}

struct BoatMetricsPayload: Encodable {
    struct Sample: Encodable {
        let timestamp: String
        let lat: Double
        let lon: Double
        let SOG_mps: Double
        let SOG_5_sec_avg_mps: Double?
        let COG_rad: Double
        let COG_rad_5_sec_avg: Double?
        let GPS_accuracy_m: Double
    }

    let startEntryId: String
    let startId: String?
    let boatId: String?
    let samples: [Sample]
}

final class BoatMetricsService {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String
    private let logger = Logger(subsystem: "fi.mobiari.naviari-ios", category: "BoatMetricsService")

    init(
        session: URLSession = .shared,
        baseURL: URL = RaceService.defaultBaseURL,
        apiKey: String = RaceService.defaultAPIKey
    ) {
        self.session = session
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func submit(
        token: String,
        boatToken: String? = nil,
        startEntryId: String,
        startId: String?,
        boatId: String?,
        samples: [BoatMetricRow]
    ) async throws {
        guard !samples.isEmpty else { return }
        guard !startEntryId.isEmpty else {
            throw BoatMetricsServiceError.missingStartEntryId
        }
        let payloadSamples = samples.map { sample in
            BoatMetricsPayload.Sample(
                timestamp: isoTimestamp(fromMilliseconds: sample.timestampMs),
                lat: sample.latitude,
                lon: sample.longitude,
                SOG_mps: knotsToMetersPerSecond(sample.sog),
                SOG_5_sec_avg_mps: sample.sogAvg.map(knotsToMetersPerSecond),
                COG_rad: degreesToRadians(sample.cog),
                COG_rad_5_sec_avg: sample.cogAvg.map(degreesToRadians),
                GPS_accuracy_m: sample.accuracy
            )
        }
        let payload = BoatMetricsPayload(
            startEntryId: startEntryId,
            startId: startId,
            boatId: boatId,
            samples: payloadSamples
        )
        var request = try makeRequest(path: "/api/boat-metrics")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-User-Key")
        if let boatToken, !boatToken.isEmpty {
            request.setValue(boatToken, forHTTPHeaderField: "X-Boat-Token")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(payload) else {
            throw BoatMetricsServiceError.encodingFailed
        }
        request.httpBody = body
        logRequest(request, sampleCount: samples.count)
        let (data, response) = try await session.data(for: request)
        logResponse(data: data, response: response)
        try Self.validate(response: response, data: data)
    }

    private func makeRequest(path: String) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw BoatMetricsServiceError.invalidURL
        }
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = normalizedPath
        guard let url = components.url else {
            throw BoatMetricsServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        return request
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BoatMetricsServiceError.serverError(status: -1, message: "Invalid response.")
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = decodeErrorMessage(from: data)
            throw BoatMetricsServiceError.serverError(status: httpResponse.statusCode, message: message)
        }
    }

    private static func decodeErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = (json["error"] ?? json["message"]) as? String
        {
            return message
        }
        return String(data: data, encoding: .utf8)
    }

    private func knotsToMetersPerSecond(_ value: Double) -> Double {
        value / 1.943844
    }

    private func degreesToRadians(_ value: Double) -> Double {
        value * .pi / 180
    }

private func isoTimestamp(fromMilliseconds value: Int64) -> String {
    let seconds = TimeInterval(value) / 1000
    return Date(timeIntervalSince1970: seconds).iso8601String()
}

    private func logRequest(_ request: URLRequest, sampleCount: Int) {
        guard let url = request.url else {
            logger.debug("BoatMetricsService: missing URL")
            return
        }
        let maskedKey = apiKeyMasked()
        logger.log("BoatMetricsService Request -> \(url.absoluteString, privacy: .public) count \(sampleCount) X-API-Key suffix \(maskedKey, privacy: .public)")
    }

    private func logResponse(data: Data, response: URLResponse) {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.debug("BoatMetricsService Response <- non-HTTP response")
            return
        }
        let snippet: String
        if let text = String(data: data, encoding: .utf8) {
            snippet = String(text.prefix(200))
        } else {
            snippet = "<binary \(data.count) bytes>"
        }
        logger.log("BoatMetricsService Response <- status \(httpResponse.statusCode) body preview: \(snippet, privacy: .public)")
    }

    private func apiKeyMasked() -> String {
        let visibleCount = min(4, apiKey.count)
        let suffix = apiKey.suffix(visibleCount)
        return "***\(suffix)"
    }
}

private extension Date {
    func iso8601String() -> String {
        Date.iso8601Formatter.string(from: self)
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
