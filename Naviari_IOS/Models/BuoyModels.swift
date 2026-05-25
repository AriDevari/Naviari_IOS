import Foundation

struct BuoyRecord: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let raceId: String
    let name: String
    let description: String?
    let coordinate: CoordinatePoint?
    let lastUpdated: Date

    init(
        id: String,
        raceId: String,
        name: String,
        description: String?,
        coordinate: CoordinatePoint?,
        lastUpdated: Date
    ) {
        self.id = id
        self.raceId = raceId
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = BuoyRecord.normalizedOptionalText(description)
        self.coordinate = coordinate
        self.lastUpdated = lastUpdated
    }

    func coordinateSummary(missingText: String) -> String {
        guard let coordinate else { return missingText }
        return String(
            format: "%.5f, %.5f",
            locale: Locale(identifier: "en_US_POSIX"),
            coordinate.lat,
            coordinate.lon
        )
    }

    private static func normalizedOptionalText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
