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
    private let schemaVersionKey = "manage_access_tokens_schema_version"
    private let schemaVersion = 2
    private let tokenStorageKey = "manage_access_tokens_v2"
    private let legacyTokenStorageKey = "manage_access_tokens"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Returns the best matching token, preferring start scope over race and series.
    func loadToken(for startId: String?, raceId: String?, seriesId: String?) -> ManageAccessTokenRecord? {
        ensureSchemaVersion2()
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

    /// Persists one server-declared management credential at its declared scope only.
    func save(loginResult: ManageAccessLoginResult) {
        ensureSchemaVersion2()
        var records = loadAllTokens()
        records[Self.makeKey(loginResult.scope, id: loginResult.scopeId)] = ManageAccessTokenRecord(
            scope: loginResult.scope,
            scopeId: loginResult.scopeId,
            token: loginResult.token,
            savedAt: Date()
        )

        if let data = try? JSONEncoder().encode(records) {
            userDefaults.set(data, forKey: tokenStorageKey)
        }
    }

    /// Compatibility shim for pre-typed callers. Without a server-declared scope it must not persist.
    func saveToken(token: String, startId: String?, raceId: String?, seriesId: String?) {
        ensureSchemaVersion2()
    }

    private func loadAllTokens() -> [String: ManageAccessTokenRecord] {
        guard let data = userDefaults.data(forKey: tokenStorageKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: ManageAccessTokenRecord].self, from: data)) ?? [:]
    }

    private func ensureSchemaVersion2() {
        guard userDefaults.integer(forKey: schemaVersionKey) != schemaVersion else {
            return
        }

        userDefaults.removeObject(forKey: legacyTokenStorageKey)
        userDefaults.removeObject(forKey: tokenStorageKey)
        userDefaults.set(schemaVersion, forKey: schemaVersionKey)
    }

    private static func makeKey(_ scope: ManageAccessScope, id: String) -> String {
        "\(scope.rawValue)::\(id)"
    }
}
