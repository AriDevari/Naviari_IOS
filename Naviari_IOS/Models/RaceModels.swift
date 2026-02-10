import Foundation

struct RaceSeries: Decodable, Identifiable {
    let rawId: String?
    let name: String?
    let description: String?
    let status: String?
    let slug: String?
    let races: [Race]

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
    }

    init(
        rawId: String?,
        name: String?,
        description: String?,
        status: String?,
        slug: String?,
        races: [Race]
    ) {
        self.rawId = rawId
        self.name = name
        self.description = description
        self.status = status
        self.slug = slug
        self.races = races
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawId = try container.decodeIfPresent(String.self, forKey: .rawId)
        let name = try container.decodeIfPresent(String.self, forKey: .name)
        let description = try container.decodeIfPresent(String.self, forKey: .description)
        let status = try container.decodeIfPresent(String.self, forKey: .status)
        let slug = try container.decodeIfPresent(String.self, forKey: .slug)
        let races = try container.decodeIfPresent([Race].self, forKey: .races) ?? []
        self.init(rawId: rawId, name: name, description: description, status: status, slug: slug, races: races)
    }
}

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
    }
}

struct RaceStart: Decodable, Identifiable, Equatable, Hashable {
    let rawId: String?
    let name: String?
    let status: String?
    let scheduledUTC: String?
    let actualUTC: String?
    let description: String?
    let className: String?
    let slug: String?

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
    }
}

struct RaceSummary: Identifiable, Equatable, Hashable {
    let race: Race
    let seriesName: String?
    let seriesId: String?

    var id: String {
        race.id
    }
}

extension Race {
    var nameOrFallback: String {
        if let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        return slug ?? NSLocalizedString("race_unnamed_placeholder", comment: "Unnamed race")
    }
}
