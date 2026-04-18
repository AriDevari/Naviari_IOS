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
    let startDate: String?
    let endDate: String?
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
        case startDate = "start_date"
        case endDate = "end_date"
        case slug
        case parentSeriesId
        case starts
        case imageId = "image_id"
    }

    init(
        rawId: String?,
        name: String?,
        description: String?,
        status: String?,
        scheduledUTC: String?,
        actualUTC: String?,
        date: String?,
        startDate: String? = nil,
        endDate: String? = nil,
        slug: String?,
        parentSeriesId: String?,
        starts: [RaceStart]?,
        imageId: String?
    ) {
        self.rawId = rawId
        self.name = name
        self.description = description
        self.status = status
        self.scheduledUTC = scheduledUTC
        self.actualUTC = actualUTC
        self.date = date
        self.startDate = startDate
        self.endDate = endDate
        self.slug = slug
        self.parentSeriesId = parentSeriesId
        self.starts = starts
        self.imageId = imageId
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
    let iconKey: String?
    let iconColor: String?

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
        case iconKey = "icon_key"
        case iconColor = "icon_color"
    }
}

extension RaceStart {
    private static let startDateParsers: [ISO8601DateFormatter] = {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractionalSeconds = ISO8601DateFormatter()
        withoutFractionalSeconds.formatOptions = [.withInternetDateTime]

        return [withFractionalSeconds, withoutFractionalSeconds]
    }()

    var normalizedStatus: String? {
        status?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var estimatedStartDate: Date? {
        Self.parseDateString(scheduledUTC)
    }

    var actualStartDate: Date? {
        Self.parseDateString(actualUTC)
    }

    var hasEstimatedStartDate: Bool {
        estimatedStartDate != nil
    }

    func actualStartEditorInitialDate(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        if let actualStartDate {
            return actualStartDate
        }
        if let estimatedStartDate {
            return estimatedStartDate
        }
        return Self.roundDownToMinute(referenceDate, calendar: calendar)
    }

    static func actualStartDateFromTimer(
        minutes: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let clampedMinutes = max(0, minutes)
        let roundedReferenceDate = roundDownToMinute(referenceDate, calendar: calendar)
        return calendar.date(byAdding: .minute, value: clampedMinutes, to: roundedReferenceDate)
            ?? roundedReferenceDate.addingTimeInterval(TimeInterval(clampedMinutes * 60))
    }

    var isCompletedStatus: Bool {
        switch normalizedStatus {
        case "completed", "finished":
            return true
        default:
            return false
        }
    }

    var isScheduledStatus: Bool {
        switch normalizedStatus {
        case "scheduled", "planned":
            return true
        default:
            return false
        }
    }

    var localizedStatusKey: String {
        localizedStatusKeyForDate()
    }

    func localizedStatusKeyForDate(referenceDate: Date = Date()) -> String {
        switch normalizedStatus {
        case "completed", "finished":
            return "start_status_completed"
        case "scheduled", "planned":
            guard let actual = actualStartDate else {
                return "start_status_scheduled"
            }
            let timeUntilStart = actual.timeIntervalSince(referenceDate)
            if timeUntilStart > 2 * 3600 {
                // More than 2 hours before actual start
                return "start_status_scheduled"
            } else if timeUntilStart > 0 {
                // Within 2 hours before actual start
                return "start_status_ready_participating"
            } else {
                // Actual start time has passed
                return "start_status_live"
            }
        default:
            return "start_status_unknown"
        }
    }

    func isRehearsalWindow(referenceDate: Date = Date()) -> Bool {
        guard !isCompletedStatus, estimatedStartDate != nil else {
            return false
        }
        return !isRealBroadcastWindowOpen(referenceDate: referenceDate)
    }

    func isRealBroadcastWindowOpen(referenceDate: Date = Date()) -> Bool {
        guard !isCompletedStatus, let estimatedStartDate else {
            return false
        }
        return referenceDate >= estimatedStartDate.addingTimeInterval(-2 * 60 * 60)
    }

    private static func parseDateString(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        for formatter in startDateParsers {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static func roundDownToMinute(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
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
