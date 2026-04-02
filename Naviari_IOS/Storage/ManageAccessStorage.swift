import Foundation

/// Scope hierarchy for manage-access token reuse.
enum ManageAccessScope: String, Codable {
    case start
    case race
    case series
}

/// Lightweight persisted token with scope metadata for manage access.
struct ManageAccessTokenRecord: Codable {
    let scope: ManageAccessScope
    let scopeId: String
    let token: String
    let savedAt: Date
}

/// UserDefaults-backed store for manage-access tokens only.
final class ManageAccessStorage {
    static let shared = ManageAccessStorage()

    private let userDefaults: UserDefaults
    private let tokenStorageKey = "manage_access_tokens"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Returns the best matching token, preferring start scope over race and series.
    func loadToken(for startId: String?, raceId: String?, seriesId: String?) -> ManageAccessTokenRecord? {
        let records = loadAllTokens()
        if let startId, let record = records[Self.makeKey(.start, id: startId)] {
            return record
        }
        if let raceId, let record = records[Self.makeKey(.race, id: raceId)] {
            return record
        }
        if let seriesId, let record = records[Self.makeKey(.series, id: seriesId)] {
            return record
        }
        return nil
    }

    /// Saves tokens for all available scopes so manage-code modal can be skipped later.
    func saveToken(token: String, startId: String?, raceId: String?, seriesId: String?) {
        var records = loadAllTokens()
        let now = Date()

        if let startId {
            records[Self.makeKey(.start, id: startId)] = ManageAccessTokenRecord(
                scope: .start,
                scopeId: startId,
                token: token,
                savedAt: now
            )
        }

        if let raceId {
            records[Self.makeKey(.race, id: raceId)] = ManageAccessTokenRecord(
                scope: .race,
                scopeId: raceId,
                token: token,
                savedAt: now
            )
        }

        if let seriesId {
            records[Self.makeKey(.series, id: seriesId)] = ManageAccessTokenRecord(
                scope: .series,
                scopeId: seriesId,
                token: token,
                savedAt: now
            )
        }

        if let data = try? JSONEncoder().encode(records) {
            userDefaults.set(data, forKey: tokenStorageKey)
        }
    }

    private func loadAllTokens() -> [String: ManageAccessTokenRecord] {
        guard let data = userDefaults.data(forKey: tokenStorageKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: ManageAccessTokenRecord].self, from: data)) ?? [:]
    }

    private static func makeKey(_ scope: ManageAccessScope, id: String) -> String {
        "\(scope.rawValue)::\(id)"
    }
}
