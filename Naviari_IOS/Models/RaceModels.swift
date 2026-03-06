import Foundation

/// API payload describing a race series plus its nested race objects.
struct RaceSeries: Decodable, Identifiable {
    let rawId: String?
    let name: String?
    let description: String?
    let status: String?
    let slug: String?
    let races: [Race]
    let imageId: String?

    var id: String {
        rawId ?? slug ?? UUID().uuidString
    }

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case name
        case description
        case status
        case slug
        case races
        case imageId = "image_id"
    }

    init(
        rawId: String?,
        name: String?,
        description: String?,
        status: String?,
        slug: String?,
        races: [Race],
        imageId: String?
    ) {
        self.rawId = rawId
        self.name = name
        self.description = description
        self.status = status
        self.slug = slug
        self.races = races
        self.imageId = imageId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawId = try container.decodeIfPresent(String.self, forKey: .rawId)
        let name = try container.decodeIfPresent(String.self, forKey: .name)
        let description = try container.decodeIfPresent(String.self, forKey: .description)
        let status = try container.decodeIfPresent(String.self, forKey: .status)
        let slug = try container.decodeIfPresent(String.self, forKey: .slug)
        let races = try container.decodeIfPresent([Race].self, forKey: .races) ?? []
        let imageId = try container.decodeIfPresent(String.self, forKey: .imageId)
        self.init(rawId: rawId, name: name, description: description, status: status, slug: slug, races: races, imageId: imageId)
    }
}

/// Backend race object (contains metadata and optional embedded starts).
struct Race: Decodable, Identifiable, Equatable, Hashable {
    let rawId: String?
    let name: String?
    let description: String?
    let status: String?
    let scheduledUTC: String?
    let actualUTC: String?
    let date: String?
    let slug: String?
    let parentSeriesId: String?
    let starts: [RaceStart]?
    let imageId: String?

    var id: String {
        rawId ?? slug ?? UUID().uuidString
    }

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case name
        case description
        case status
        case scheduledUTC = "scheduled_utc"
        case actualUTC = "actual_utc"
        case date
        case slug
        case parentSeriesId
        case starts
        case imageId = "image_id"
    }
}

/// Individual start within a race (class information, schedule, status).
struct RaceStart: Decodable, Identifiable, Equatable, Hashable {
    let rawId: String?
    let name: String?
    let status: String?
    let scheduledUTC: String?
    let actualUTC: String?
    let description: String?
    let className: String?
    let slug: String?
    let imageId: String?

    var id: String {
        rawId ?? slug ?? UUID().uuidString
    }

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case name
        case status
        case scheduledUTC = "scheduled_utc"
        case actualUTC = "actual_utc"
        case description
        case className = "class_name"
        case slug
        case imageId = "image_id"
    }
}

/// Convenience wrapper used by the UI to tag a race with its parent series info.
struct RaceSummary: Identifiable, Equatable, Hashable {
    let race: Race
    let seriesName: String?
    let seriesId: String?
    let seriesImageId: String?
    let raceImageId: String?

    var id: String {
        race.id
    }

    var preferredImageId: String? {
        if let trimmed = normalizedIdentifier(seriesImageId) {
            return trimmed
        }
        return normalizedIdentifier(raceImageId)
    }
}

extension Race {
    /// Returns the provided race name or a localization-backed placeholder when missing.
    var nameOrFallback: String {
        if let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        return slug ?? NSLocalizedString("race_unnamed_placeholder", comment: "Unnamed race")
    }
}

private func normalizedIdentifier(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
