import Foundation
import OSLog

/// Common error cases surfaced by `RaceService`.
enum RaceServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed
    case invalidRequest(message: String)
    case missingRaceIdentifier
    case serverError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("error_invalid_url", comment: "Invalid URL")
        case .invalidResponse:
            return NSLocalizedString("error_invalid_response", comment: "Invalid server response")
        case .decodingFailed:
            return NSLocalizedString("error_decoding_failed", comment: "Failed to parse response")
        case let .invalidRequest(message):
            return message
        case .missingRaceIdentifier:
            return NSLocalizedString("error_missing_race_id", comment: "Missing race identifier")
        case let .serverError(statusCode, message):
            if let message, !message.isEmpty {
                return String(format: NSLocalizedString("error_server_with_message", comment: "Server error with message"), statusCode, message)
            } else {
                return String(format: NSLocalizedString("error_server_without_message", comment: "Server error without message"), statusCode)
            }
        }
    }
}

/// Fetches race series and start lists from the Naviari backend.
struct RaceService {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    private let logger = Logger(subsystem: "fi.mobiari.naviari-ios", category: "RaceService")

    init(
        baseURL: URL = RaceService.defaultBaseURL,
        apiKey: String = RaceService.defaultAPIKey,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    /// Loads every published race series plus their races.
    func fetchRaceSeries() async throws -> [RaceSeries] {
        let request = try makeRequest(
            path: "/api/race-series",
            queryItems: [URLQueryItem(name: "depth", value: "all")]
        )
        logRequest(request)
        let (data, response) = try await session.data(for: request)
        logResponse(data: data, response: response)
        try RaceService.validate(response: response, data: data)
        if let payload = try? JSONDecoder().decode(RaceSeriesEnvelope.self, from: data) {
            return payload.series
        }
        if let arrayPayload = try? JSONDecoder().decode([RaceSeries].self, from: data) {
            return arrayPayload
        }
        throw RaceServiceError.decodingFailed
    }

    /// Loads starts belonging to a specific race.
    func fetchStarts(for race: Race) async throws -> [RaceStart] {
        guard let raceId = race.rawId ?? race.slug else {
            throw RaceServiceError.missingRaceIdentifier
        }
        let request = try makeRequest(
            path: "/api/starts",
            queryItems: [URLQueryItem(name: "raceId", value: raceId)]
        )
        logRequest(request)
        let (data, response) = try await session.data(for: request)
        logResponse(data: data, response: response)
        try RaceService.validate(response: response, data: data)
        if let payload = try? JSONDecoder().decode(RaceStartEnvelope.self, from: data) {
            return payload.starts
        }
        if let arrayPayload = try? JSONDecoder().decode([RaceStart].self, from: data) {
            return arrayPayload
        }
        throw RaceServiceError.decodingFailed
    }

    /// Loads full start detail payload including optional course.
    func fetchStartDetail(startId: String) async throws -> StartDetailResponse {
        let request = try makeRequest(path: "/api/starts/id/\(startId)", queryItems: [])
        logRequest(request)
        let (data, response) = try await session.data(for: request)
        logResponse(data: data, response: response)
        try RaceService.validate(response: response, data: data)
        guard let payload = try? JSONDecoder().decode(StartDetailResponse.self, from: data) else {
            throw RaceServiceError.decodingFailed
        }
        return payload
    }

    /// Updates only the start's actual start time through the narrow backend PATCH contract.
    func updateStartActualTime(
        startId: String,
        actualUtc: String,
        updatedBy: String? = nil,
        accessToken: String? = nil
    ) async throws -> RaceStart {
        var request = try makeRequest(path: "/api/starts/\(startId)/timing", queryItems: [])
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken, !accessToken.isEmpty {
            request.setValue(accessToken, forHTTPHeaderField: "X-User-Key")
        }
        request.httpBody = try JSONEncoder().encode(
            StartTimingPatchRequest(actualUtc: actualUtc, updatedBy: updatedBy)
        )

        logRequest(request)
        let (data, response) = try await session.data(for: request)
        logResponse(data: data, response: response)
        try RaceService.validate(response: response, data: data)

        guard let payload = try? JSONDecoder().decode(StartMutationEnvelope.self, from: data) else {
            throw RaceServiceError.decodingFailed
        }

        return payload.start
    }

    /// Clears the start's actual_utc by sending null through the narrow backend PATCH contract.
    func resetStartActualTime(
        startId: String,
        accessToken: String? = nil
    ) async throws -> RaceStart {
        var request = try makeRequest(path: "/api/starts/\(startId)/timing", queryItems: [])
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken, !accessToken.isEmpty {
            request.setValue(accessToken, forHTTPHeaderField: "X-User-Key")
        }
        request.httpBody = try JSONEncoder().encode(
            StartTimingPatchRequest(actualUtc: nil, updatedBy: "start-timing-reset")
        )

        logRequest(request)
        let (data, response) = try await session.data(for: request)
        logResponse(data: data, response: response)
        try RaceService.validate(response: response, data: data)

        guard let payload = try? JSONDecoder().decode(StartMutationEnvelope.self, from: data) else {
            throw RaceServiceError.decodingFailed
        }

        return payload.start
    }

    /// Writes one course-position target using the current coordinate.
    func setCoursePosition(
        target: SetPositionTarget,
        coordinate: CoordinatePoint,
        accessToken: String,
        updatedBy: String? = "ios-set-position"
    ) async throws {
        switch target {
        case let .mark(markTarget):
            let payload = CourseMarkPositionRequest(
                id: markTarget.markId,
                name: markTarget.name,
                description: markTarget.description,
                roundingSide: markTarget.roundingSide,
                type: markTarget.type,
                status: "final",
                mark: coordinate,
                updatedBy: updatedBy
            )
            _ = try await performCourseWrite(
                path: "/api/course-marks",
                accessToken: accessToken,
                payload: payload
            )

        case let .startLine(lineTarget, side):
            let request = try linePositionRequest(
                lineTarget: lineTarget,
                selectedSide: side,
                coordinate: coordinate,
                status: target.nextLineStatus(),
                updatedBy: updatedBy
            )
            _ = try await performCourseWrite(
                path: "/api/start-lines",
                accessToken: accessToken,
                payload: request
            )

        case let .finishLine(lineTarget, side):
            let request = try linePositionRequest(
                lineTarget: lineTarget,
                selectedSide: side,
                coordinate: coordinate,
                status: target.nextLineStatus(),
                updatedBy: updatedBy
            )
            _ = try await performCourseWrite(
                path: "/api/finish-lines",
                accessToken: accessToken,
                payload: request
            )
        }
    }

    private func linePositionRequest(
        lineTarget: CourseLinePositionTarget,
        selectedSide: CourseEndpointSide,
        coordinate: CoordinatePoint,
        status: String,
        updatedBy: String?
    ) throws -> CourseLinePositionRequest {
        let left = selectedSide == .left ? coordinate : lineTarget.markLeft
        let right = selectedSide == .right ? coordinate : lineTarget.markRight

        guard let markLeft = left, let markRight = right else {
            throw RaceServiceError.invalidRequest(
                message: NSLocalizedString("set_position_error_line_endpoint_missing", comment: "Line endpoint missing")
            )
        }

        return CourseLinePositionRequest(
            id: lineTarget.lineId,
            name: lineTarget.name,
            description: lineTarget.description,
            status: status,
            markLeft: markLeft,
            markRight: markRight,
            updatedBy: updatedBy
        )
    }

    private func performCourseWrite<Payload: Encodable>(
        path: String,
        accessToken: String,
        payload: Payload
    ) async throws -> Data {
        var request = try makeRequest(path: path, queryItems: [])
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessToken, forHTTPHeaderField: "X-User-Key")
        request.httpBody = try JSONEncoder().encode(payload)

        logRequest(request)
        let (data, response) = try await session.data(for: request)
        logResponse(data: data, response: response)
        try RaceService.validate(response: response, data: data)
        return data
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw RaceServiceError.invalidURL
        }
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = normalizedPath
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw RaceServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        return request
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200 ... 299).contains(httpResponse.statusCode)
        else {
            if let httpResponse = response as? HTTPURLResponse {
                let serverMessage = RaceService.decodeErrorMessage(from: data)
                Logger(subsystem: "fi.mobiari.naviari-ios", category: "RaceService")
                    .error("Server error: status \(httpResponse.statusCode), message: \(serverMessage ?? "nil", privacy: .public)")
                throw RaceServiceError.serverError(statusCode: httpResponse.statusCode, message: serverMessage)
            }
            throw RaceServiceError.invalidResponse
        }
    }

    private static func decodeErrorMessage(from data: Data) -> String? {
        if data.isEmpty {
            return nil
        }
        if
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = (json["error"] ?? json["message"]) as? String
        {
            return message
        }
        if let text = String(data: data, encoding: .utf8) {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func logRequest(_ request: URLRequest) {
        guard let url = request.url else {
            logger.debug("RaceService: Attempted request missing URL")
            return
        }
        let maskedKey = apiKeyMasked()
        logger.log("RaceService Request -> \(url.absoluteString, privacy: .public) X-API-Key suffix \(maskedKey, privacy: .public)")
    }

    private func logResponse(data: Data, response: URLResponse) {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.debug("RaceService Response <- non-HTTP response")
            return
        }
        let snippet: String
        if let text = String(data: data, encoding: .utf8) {
            snippet = String(text.prefix(300))
        } else {
            snippet = "<binary \(data.count) bytes>"
        }
        logger.log("RaceService Response <- status \(httpResponse.statusCode) body preview: \(snippet, privacy: .public)")
    }

    private func apiKeyMasked() -> String {
        let visibleCount = min(4, apiKey.count)
        let suffix = apiKey.suffix(visibleCount)
        return "***\(suffix)"
    }
}

extension RaceService {
    /// Resolves the base URL from environment, Info.plist, or production fallback.
    static var defaultBaseURL: URL {
        if
            let value = ProcessInfo.processInfo.environment["NAVIARI_API_BASE"],
            let envURL = URL(string: value)
        {
            return envURL
        }
        if
            let plistValue = Bundle.main.object(forInfoDictionaryKey: "NaviariAPIBaseURL") as? String,
            let plistURL = URL(string: plistValue)
        {
            return plistURL
        }
        return URL(string: "https://naviaribackend-production.up.railway.app")!
    }

    /// Resolves the API key from environment, Info.plist, or production fallback.
    static var defaultAPIKey: String {
        if let value = ProcessInfo.processInfo.environment["NAVIARI_API_KEY"] {
            return value
        }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "NaviariAPIKey") as? String {
            return plistValue
        }
        return "2d7fa1686e751498c3397fd7f4a19ff578f5b73698cd6e857c39a190e283ffe8"
    }
}

private struct RaceSeriesEnvelope: Decodable {
    let series: [RaceSeries]
}

private struct RaceStartEnvelope: Decodable {
    let starts: [RaceStart]
}

struct StartDetailResponse: Decodable {
    let ok: Bool
    let start: RaceStart
    let course: RaceCourse?
}

private struct StartMutationEnvelope: Decodable {
    let start: RaceStart
}

private struct StartTimingPatchRequest: Encodable {
    let actualUtc: String?
    let updatedBy: String?
    /// When true, explicitly encodes actualUtc even when nil (as JSON null).
    let includeActualUtc: Bool

    init(actualUtc: String?, updatedBy: String? = nil, includeActualUtc: Bool = true) {
        self.actualUtc = actualUtc
        self.updatedBy = updatedBy
        self.includeActualUtc = includeActualUtc
    }

    enum CodingKeys: String, CodingKey {
        case actualUtc, updatedBy
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if includeActualUtc {
            try container.encode(actualUtc, forKey: .actualUtc)
        }
        try container.encodeIfPresent(updatedBy, forKey: .updatedBy)
    }
}

private struct CourseMarkPositionRequest: Encodable {
    let id: String
    let name: String
    let description: String?
    let roundingSide: String?
    let type: String?
    let status: String
    let mark: CoordinatePoint
    let updatedBy: String?
}

private struct CourseLinePositionRequest: Encodable {
    let id: String
    let name: String
    let description: String?
    let status: String
    let markLeft: CoordinatePoint
    let markRight: CoordinatePoint
    let updatedBy: String?
}
