import Foundation

/// Centralizes the various date/relative-time formatting helpers used throughout the app.
enum DateFormattingHelper {
    private static let isoDateTimeWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let isoDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale.current
        return formatter
    }()

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    /// Parses an ISO8601 string and returns a localized date (optionally with time) for display in lists.
    static func localizedDateString(from value: String?, includeTime: Bool) -> String? {
        guard let value else { return nil }
        guard let date = parseDate(from: value) else { return nil }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = includeTime ? .short : .none
        return dateFormatter.string(from: date)
    }

    /// Formats a date using natural-language relative phrasing (e.g., “5 minutes ago”).
    static func relativeTimeString(from date: Date) -> String {
        relativeFormatter.locale = Locale.current
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Formats a date using the user’s locale short date + medium time styles.
    static func localizedShortDateTime(from date: Date) -> String {
        shortDateTimeFormatter.locale = Locale.current
        return shortDateTimeFormatter.string(from: date)
    }

    /// Attempts to parse backend date strings (with or without fractional seconds) plus legacy date-only values.
    private static func parseDate(from value: String) -> Date? {
        if let date = isoDateTimeWithFractional.date(from: value) {
            return date
        }
        if let date = isoDateTime.date(from: value) {
            return date
        }
        return dateOnlyFormatter.date(from: value)
    }
}
