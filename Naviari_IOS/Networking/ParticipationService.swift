import Foundation
import SwiftUI

/// Request payload for creating/updating a start entry (and optional boat record).
struct ParticipationSubmission: Encodable {
    struct BoatPayload: Encodable {
        let name: String?
        let club: String?
        let rating: Double?
        let displayColor: String?
    }

    let startId: String
    let name: String?
    let sailNumber: String?
    let club: String?
    let rating: Double?
    let description: String?
    let displayColor: String?
    let dataSource: String
    let boat: BoatPayload
    let issueNewBoatSecret: Bool
    let updatedBy: String

    init(
        startId: String,
        name: String?,
        sailNumber: String?,
        club: String?,
        rating: Double?,
        description: String?,
        displayColor: String?,
        dataSource: String = "Naviari iOS",
        updatedBy: String = "ios-app"
    ) {
        self.startId = startId
        self.name = name
        self.sailNumber = sailNumber
        self.club = club
        self.rating = rating
        self.description = description
        self.displayColor = displayColor
        self.dataSource = dataSource
        self.issueNewBoatSecret = true
        self.updatedBy = updatedBy
        self.boat = BoatPayload(
            name: name,
            club: club,
            rating: rating,
            displayColor: displayColor
        )
    }
}

/// Lightweight copy of the submitted data stored on device for pre-fill.
struct ParticipationSummary: Hashable, Codable {
    let name: String?
    let sailNumber: String?
    let rating: Double?
    let club: String?
    let description: String?
    let colorHex: String?
}

/// Minimal subset returned by `/api/start-entries` that we need for persistence/broadcasts.
struct ParticipationResult {
    let startEntryId: String?
    let boatId: String?
    let boatToken: String?
    let boatCode: String?
}

/// Handles participation code login and start-entry submissions.
final class ParticipationService {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String

    init(
        session: URLSession = .shared,
        baseURL: URL = RaceService.defaultBaseURL,
        apiKey: String = RaceService.defaultAPIKey
    ) {
        self.session = session
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    /// Exchanges a participation/race code for a scoped token (required for submissions + telemetry).
    func exchangeCodeForToken(_ code: String) async throws -> String {
        var request = try makeRequest(path: "/api/access/login")
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(["code": code])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        try ParticipationService.validate(response: response, data: data)
        let payload = try JSONDecoder().decode(LoginResponse.self, from: data)
        guard let token = payload.token else {
            throw ParticipationServiceError.invalidResponse
        }
        return token
    }

    /// Creates or updates a start entry using the provided token and payload.
    func submitStartEntry(token: String, submission: ParticipationSubmission) async throws -> ParticipationResult {
        var request = try makeRequest(path: "/api/start-entries")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-User-Key")
        request.httpBody = try JSONEncoder().encode(submission)
        let (data, response) = try await session.data(for: request)
        try ParticipationService.validate(response: response, data: data)
        let payload = try JSONDecoder().decode(ParticipationAPIResponse.self, from: data)
        return ParticipationResult(
            startEntryId: payload.startEntry?.id,
            boatId: payload.boat?.id,
            boatToken: payload.boatToken,
            boatCode: payload.boatCode
        )
    }

    private func makeRequest(path: String) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ParticipationServiceError.invalidURL
        }
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = normalizedPath
        guard let url = components.url else {
            throw ParticipationServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        return request
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParticipationServiceError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = ParticipationService.decodeErrorMessage(from: data)
            throw ParticipationServiceError.serverError(status: httpResponse.statusCode, message: message)
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
}

private struct LoginResponse: Decodable {
    let token: String?
}

private struct ParticipationAPIResponse: Decodable {
    struct IdContainer: Decodable {
        let id: String?
    }

    let startEntry: IdContainer?
    let boat: IdContainer?
    let boatToken: String?
    let boatCode: String?
}

enum ParticipationServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL."
        case .invalidResponse:
            return "Invalid server response."
        case let .serverError(status, message):
            if let message, !message.isEmpty {
                return "Server error (\(status)): \(message)"
            }
            return "Server error (\(status))"
        }
    }
}
