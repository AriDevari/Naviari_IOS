import Foundation

/// Centralizes the various date/relative-time formatting helpers used throughout the app.
enum DateFormattingHelper {
    private static let twoDaysInSeconds: TimeInterval = 2 * 24 * 60 * 60

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

    private static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
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

    /// Formats a date using the user’s locale with time only.
    static func localizedTime(from date: Date) -> String {
        timeOnlyFormatter.locale = Locale.current
        return timeOnlyFormatter.string(from: date)
    }

    /// Formats a date as a 24-hour local time string using `HH:mm`.
    static func localizedHourMinute(
        from date: Date,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// Parses a backend date string and formats it as a 24-hour local time string using `HH:mm`.
    static func localizedHourMinute(
        from value: String?,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String? {
        guard let value, let date = parseDate(from: value) else {
            return nil
        }
        return localizedHourMinute(from: date, locale: locale, timeZone: timeZone)
    }

    /// Formats a date as a localized "Today, d MMMM yyyy" string for date context display.
    static func localizedTodayDate(
        from date: Date,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Formats a countdown for `actual_utc` display.
    /// - More than 2 full days: day-based relative text, e.g. `in 4 days`
    /// - 2 days or less: positional `HH:MM:SS`
    /// - Past/zero: `00:00:00`
    static func actualStartCountdownString(
        to target: Date,
        now: Date = Date(),
        locale: Locale = .current
    ) -> String {
        let remainingSeconds = max(0, Int(target.timeIntervalSince(now).rounded(.down)))

        if TimeInterval(remainingSeconds) > twoDaysInSeconds {
            let fullDaysRemaining = max(1, remainingSeconds / 86_400)
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            formatter.locale = locale
            let relativeTarget = now.addingTimeInterval(TimeInterval(fullDaysRemaining * 86_400))
            return formatter.localizedString(for: relativeTarget, relativeTo: now)
        }

        let hours = remainingSeconds / 3_600
        let minutes = (remainingSeconds % 3_600) / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Parses a backend date string and formats it using the actual-start countdown rules.
    static func actualStartCountdownString(
        from value: String?,
        now: Date = Date(),
        locale: Locale = .current
    ) -> String? {
        guard let value, let date = parseDate(from: value) else {
            return nil
        }
        return actualStartCountdownString(to: date, now: now, locale: locale)
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
