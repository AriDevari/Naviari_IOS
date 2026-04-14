import Foundation

/// Scopes that determine how broadly a participation token can be reused.
enum ParticipationScope: String, Codable {
    case start
    case race
    case series
}

/// Stored snapshot of the participation flow (token, identifiers, summary fields).
struct ParticipationRecord: Codable {
    let scope: ParticipationScope
    let scopeId: String
    let token: String
    let startEntryId: String?
    let boatId: String?
    let boatToken: String?
    let boatCode: String?
    let summary: ParticipationSummary
    let savedAt: Date
}

extension ParticipationSummary {
    var compactBoatName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false)
            ? trimmed!
            : NSLocalizedString("broadcast_drawer_value_missing", comment: "")
    }

    var compactSailNumber: String {
        let trimmed = sailNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false)
            ? trimmed!
            : NSLocalizedString("broadcast_drawer_value_missing", comment: "")
    }

    func compactRatingText(locale: Locale = .current) -> String {
        guard let rating else {
            return NSLocalizedString("broadcast_drawer_value_missing", comment: "")
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: rating)) ?? "\(rating)"
    }
}

/// Lightweight token record persisted even before a start entry exists.
struct ParticipationTokenRecord: Codable {
    let scope: ParticipationScope
    let scopeId: String
    let token: String
    let savedAt: Date
}

/// Simple UserDefaults-backed cache for participation tokens/metadata.
final class ParticipationStorage {
    static let shared = ParticipationStorage()

    private let userDefaults: UserDefaults
    private let storageKey = "participation_records"
    private let tokenStorageKey = "participation_tokens"

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Returns the best-matching record given optional start/race/series identifiers (prefers the most specific scope).
    func loadRecord(for startId: String?, raceId: String?, seriesId: String?) -> ParticipationRecord? {
        let records = loadAllRecords()
        if let startId, let record = records[ParticipationStorage.makeKey(.start, id: startId)] {
            return record
        }
        if let raceId, let record = records[ParticipationStorage.makeKey(.race, id: raceId)] {
            return record
        }
        if let seriesId, let record = records[ParticipationStorage.makeKey(.series, id: seriesId)] {
            return record
        }
        return nil
    }

    /// Saves/overwrites a single record for its scope.
    func save(record: ParticipationRecord) {
        var records = loadAllRecords()
        records[ParticipationStorage.makeKey(record.scope, id: record.scopeId)] = record
        if let data = try? JSONEncoder().encode(records) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    /// Bulk-saves records (used when we want to persist start/race/series scopes together).
    func saveRecords(_ records: [ParticipationRecord]) {
        guard !records.isEmpty else { return }
        var stored = loadAllRecords()
        for record in records {
            stored[ParticipationStorage.makeKey(record.scope, id: record.scopeId)] = record
        }
        if let data = try? JSONEncoder().encode(stored) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    /// Loads and decodes all stored records from disk.
    private func loadAllRecords() -> [String: ParticipationRecord] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: ParticipationRecord].self, from: data)) ?? [:]
    }

    /// Returns the best matching token record, preferring start scope over race and series.
    func loadToken(for startId: String?, raceId: String?, seriesId: String?) -> ParticipationTokenRecord? {
        let records = loadAllTokens()
        if let startId, let record = records[ParticipationStorage.makeKey(.start, id: startId)] {
            return record
        }
        if let raceId, let record = records[ParticipationStorage.makeKey(.race, id: raceId)] {
            return record
        }
        if let seriesId, let record = records[ParticipationStorage.makeKey(.series, id: seriesId)] {
            return record
        }
        return nil
    }

    /// Saves token records for all available scopes so code modal can be skipped on future opens.
    func saveToken(token: String, startId: String?, raceId: String?, seriesId: String?) {
        var records = loadAllTokens()
        let now = Date()
        if let startId {
            records[ParticipationStorage.makeKey(.start, id: startId)] = ParticipationTokenRecord(
                scope: .start,
                scopeId: startId,
                token: token,
                savedAt: now
            )
        }
        if let raceId {
            records[ParticipationStorage.makeKey(.race, id: raceId)] = ParticipationTokenRecord(
                scope: .race,
                scopeId: raceId,
                token: token,
                savedAt: now
            )
        }
        if let seriesId {
            records[ParticipationStorage.makeKey(.series, id: seriesId)] = ParticipationTokenRecord(
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

    /// Loads and decodes all standalone token records from disk.
    private func loadAllTokens() -> [String: ParticipationTokenRecord] {
        guard let data = userDefaults.data(forKey: tokenStorageKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: ParticipationTokenRecord].self, from: data)) ?? [:]
    }

    /// Generates the dictionary key for a scope/id pair.
    private static func makeKey(_ scope: ParticipationScope, id: String) -> String {
        "\(scope.rawValue)::\(id)"
    }
}
