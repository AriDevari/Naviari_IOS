import Foundation

enum RaceListFilter {
    private static let isoDatePrefixLength = 10

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    static func filterCurrentAndUpcoming(
        summaries: [RaceSummary],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [RaceSummary] {
        let today = calendar.startOfDay(for: referenceDate)
        let matching = summaries.compactMap { summary -> (RaceSummary, RaceInterval)? in
            guard let interval = resolveInterval(for: summary.race, calendar: calendar) else {
                return nil
            }
            return interval.end >= today ? (summary, interval) : nil
        }

        let unresolved = summaries.filter { resolveInterval(for: $0.race, calendar: calendar) == nil }

        let sortedMatching = matching.sorted { lhs, rhs in
            if lhs.1.start != rhs.1.start {
                return lhs.1.start < rhs.1.start
            }
            if lhs.1.end != rhs.1.end {
                return lhs.1.end < rhs.1.end
            }
            return lhs.0.race.nameOrFallback.localizedCaseInsensitiveCompare(rhs.0.race.nameOrFallback) == .orderedAscending
        }.map(\.0)

        return sortedMatching + unresolved
    }

    static func hasResolvedInterval(for race: Race, calendar: Calendar = .current) -> Bool {
        resolveInterval(for: race, calendar: calendar) != nil
    }

    private static func resolveInterval(for race: Race, calendar: Calendar) -> RaceInterval? {
        guard let start = normalizedDate(from: race.startDate ?? race.date, calendar: calendar) else {
            return nil
        }
        let end = normalizedDate(from: race.endDate, calendar: calendar) ?? start
        return RaceInterval(start: start, end: max(end, start))
    }

    private static func normalizedDate(from value: String?, calendar: Calendar) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        let normalizedValue = normalizeDateOnlyValue(value)
        guard let parsed = dateOnlyFormatter.date(from: normalizedValue) else {
            return nil
        }
        return calendar.startOfDay(for: parsed)
    }

    private static func normalizeDateOnlyValue(_ value: String) -> String {
        if value.count >= isoDatePrefixLength {
            let prefix = String(value.prefix(isoDatePrefixLength))
            if dateOnlyFormatter.date(from: prefix) != nil {
                return prefix
            }
        }
        return value
    }

    private struct RaceInterval {
        let start: Date
        let end: Date
    }
}