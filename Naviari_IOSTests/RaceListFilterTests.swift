import XCTest
@testable import Naviari_IOS

final class RaceListFilterTests: XCTestCase {
    func testCurrentAndUpcomingIncludesSingleDayTodayRace() {
        let filtered = RaceListFilter.filterCurrentAndUpcoming(
            summaries: [summary(id: "today", startDate: "2026-04-18")],
            referenceDate: utcDate("2026-04-18T12:00:00Z")
        )

        XCTAssertEqual(filtered.map(\.race.rawId), ["today"])
    }

    func testCurrentAndUpcomingIncludesMultiDayOngoingRace() {
        let filtered = RaceListFilter.filterCurrentAndUpcoming(
            summaries: [summary(id: "ongoing", startDate: "2026-04-17", endDate: "2026-04-19")],
            referenceDate: utcDate("2026-04-18T12:00:00Z")
        )

        XCTAssertEqual(filtered.map(\.race.rawId), ["ongoing"])
    }

    func testCurrentAndUpcomingExcludesHistoricalRace() {
        let filtered = RaceListFilter.filterCurrentAndUpcoming(
            summaries: [summary(id: "past", startDate: "2026-04-16", endDate: "2026-04-17")],
            referenceDate: utcDate("2026-04-18T12:00:00Z")
        )

        XCTAssertTrue(filtered.isEmpty)
    }

    func testCurrentAndUpcomingExcludesHistoricalRaceWhenBackendSendsIsoTimestampDates() {
        let filtered = RaceListFilter.filterCurrentAndUpcoming(
            summaries: [
                summary(
                    id: "past-iso",
                    startDate: "2025-06-03T00:00:00.000Z",
                    endDate: "2025-06-03T00:00:00.000Z"
                )
            ],
            referenceDate: utcDate("2026-04-18T12:00:00Z")
        )

        XCTAssertTrue(filtered.isEmpty)
    }

    func testCurrentAndUpcomingIncludesFutureRaceWhenEndDateMissing() {
        let filtered = RaceListFilter.filterCurrentAndUpcoming(
            summaries: [summary(id: "future", startDate: "2026-04-20", endDate: nil)],
            referenceDate: utcDate("2026-04-18T12:00:00Z")
        )

        XCTAssertEqual(filtered.map(\.race.rawId), ["future"])
    }

    func testCurrentAndUpcomingIncludesFutureRaceWhenBackendSendsIsoTimestampDates() {
        let filtered = RaceListFilter.filterCurrentAndUpcoming(
            summaries: [summary(id: "future-iso", startDate: "2026-05-19T00:00:00.000Z", endDate: nil)],
            referenceDate: utcDate("2026-04-18T12:00:00Z")
        )

        XCTAssertEqual(filtered.map(\.race.rawId), ["future-iso"])
    }

    func testUnresolvedRaceStaysVisibleAtEndOfList() {
        let filtered = RaceListFilter.filterCurrentAndUpcoming(
            summaries: [
                summary(id: "future", startDate: "2026-04-20"),
                summary(id: "unknown", startDate: nil),
                summary(id: "today", startDate: "2026-04-18")
            ],
            referenceDate: utcDate("2026-04-18T12:00:00Z")
        )

        XCTAssertEqual(filtered.map(\.race.rawId), ["today", "future", "unknown"])
    }

    func testCurrentAndUpcomingSortsEarliestFirst() {
        let filtered = RaceListFilter.filterCurrentAndUpcoming(
            summaries: [
                summary(id: "later", startDate: "2026-04-21"),
                summary(id: "future", startDate: "2026-04-20"),
                summary(id: "today", startDate: "2026-04-18")
            ],
            referenceDate: utcDate("2026-04-18T12:00:00Z")
        )

        XCTAssertEqual(filtered.map(\.race.rawId), ["today", "future", "later"])
    }

    private func summary(id: String, startDate: String?, endDate: String? = nil) -> RaceSummary {
        let race = Race(
            rawId: id,
            name: id,
            description: nil,
            status: nil,
            scheduledUTC: nil,
            actualUTC: nil,
            date: nil,
            startDate: startDate,
            endDate: endDate,
            slug: nil,
            parentSeriesId: nil,
            starts: nil,
            imageId: nil
        )
        return RaceSummary(
            race: race,
            seriesName: "Series",
            seriesId: "series-1",
            seriesImageId: nil,
            raceImageId: nil
        )
    }

    private func utcDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }
}