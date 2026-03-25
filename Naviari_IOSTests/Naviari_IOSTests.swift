import XCTest
@testable import Naviari_IOS

final class Naviari_IOSTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchRaceSeriesDecodesResponse() async throws {
        let expectation = expectation(description: "request handled")
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            expectation.fulfill()
            let payload = """
            {"series":[{"id":"series-1","name":"Spring Series","races":[{"id":"race-1","name":"Opener","status":"scheduled"}]}]}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let service = makeService()
        let series = try await service.fetchRaceSeries()
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series.first?.races.first?.name, "Opener")
    }

    func testFetchStartsIncludesRaceIdQuery() async throws {
        let inspectedURL = expectation(description: "raceId parameter present")
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("raceId=race-123") ?? false)
            inspectedURL.fulfill()
            let payload = """
            {"starts":[{"id":"start-1","name":"Morning Fleet","status":"scheduled"}]}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let service = makeService()
        let race = Race(
            rawId: "race-123",
            name: "Sample",
            description: nil,
            status: nil,
            scheduledUTC: nil,
            actualUTC: nil,
            date: nil,
            slug: nil,
            parentSeriesId: nil,
            starts: nil,
            imageId: nil
        )
        let starts = try await service.fetchStarts(for: race)
        wait(for: [inspectedURL], timeout: 1.0)
        XCTAssertEqual(starts.first?.name, "Morning Fleet")
    }

    func testFetchStartsDecodesVisualIdentityFields() async throws {
        MockURLProtocol.requestHandler = { request in
            let payload = """
            {"starts":[{"id":"start-1","name":"Morning Fleet","status":"scheduled","icon_key":"laser","icon_color":"#D84315","image_id":"image-1"}]}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let service = makeService()
        let race = Race(
            rawId: "race-123",
            name: "Sample",
            description: nil,
            status: nil,
            scheduledUTC: nil,
            actualUTC: nil,
            date: nil,
            slug: nil,
            parentSeriesId: nil,
            starts: nil,
            imageId: nil
        )
        let starts = try await service.fetchStarts(for: race)
        XCTAssertEqual(starts.first?.iconKey, "laser")
        XCTAssertEqual(starts.first?.iconColor, "#D84315")
        XCTAssertEqual(starts.first?.imageId, "image-1")
    }

    func testFetchStartsDecodesCharacterNamespacedIconKey() async throws {
        MockURLProtocol.requestHandler = { request in
            let payload = """
            {"starts":[{"id":"start-1","name":"Morning Fleet","status":"scheduled","icon_key":"character:a","icon_color":"#D84315","image_id":null}]}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let service = makeService()
        let race = Race(
            rawId: "race-123",
            name: "Sample",
            description: nil,
            status: nil,
            scheduledUTC: nil,
            actualUTC: nil,
            date: nil,
            slug: nil,
            parentSeriesId: nil,
            starts: nil,
            imageId: nil
        )
        let starts = try await service.fetchStarts(for: race)
        XCTAssertEqual(starts.first?.iconKey, "character:a")
        XCTAssertEqual(starts.first?.iconColor, "#D84315")
        XCTAssertNil(starts.first?.imageId)
    }

    func testStartIconAssetNamesMatchApprovedKeys() {
        XCTAssertEqual(debugStartIconAssetName(nil), "system:sailboat.fill")
        XCTAssertEqual(debugStartIconAssetName("default"), "system:sailboat.fill")
        XCTAssertEqual(debugStartIconAssetName("laser"), "StartIconLaser")
        XCTAssertEqual(debugStartIconAssetName("kite"), "StartIconKite")
        XCTAssertEqual(debugStartIconAssetName("sailboat-2"), "StartIconSailboat2")
        XCTAssertEqual(debugStartIconAssetName("sport-boat"), "StartIconSportBoat")
        XCTAssertEqual(debugStartIconAssetName("submarine"), "StartIconSubmarine")
        XCTAssertEqual(debugStartIconAssetName("sub"), "StartIconSUB")
        XCTAssertEqual(debugStartIconAssetName("foil"), "StartIconFoil")
        XCTAssertEqual(debugStartIconAssetName("windsurfing"), "StartIconWindsurfing")
        XCTAssertEqual(debugStartIconAssetName("character:A"), "character:A")
        XCTAssertEqual(debugStartIconAssetName("ChArAcTeR:z"), "character:z")
        XCTAssertEqual(debugStartIconAssetName("character:🚀"), "system:sailboat.fill")
        XCTAssertEqual(debugStartIconAssetName("character:ab"), "system:sailboat.fill")
    }

    func testRaceStartRealBroadcastWindowOpensTwoHoursBeforeEstimatedStart() {
        let start = RaceStart(
            rawId: "start-1",
            name: "Morning Fleet",
            status: "scheduled",
            scheduledUTC: "2026-03-25T12:00:00Z",
            actualUTC: nil,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )

        XCTAssertFalse(start.isRealBroadcastWindowOpen(referenceDate: Date(timeIntervalSince1970: 1_743_191_999)))
        XCTAssertTrue(start.isRealBroadcastWindowOpen(referenceDate: Date(timeIntervalSince1970: 1_743_192_000)))
    }

    func testRaceStartUsesRehearsalWindowBeforeTwoHourThreshold() {
        let start = RaceStart(
            rawId: "start-1",
            name: "Morning Fleet",
            status: "scheduled",
            scheduledUTC: "2026-03-25T12:00:00Z",
            actualUTC: nil,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )

        XCTAssertTrue(start.isRehearsalWindow(referenceDate: Date(timeIntervalSince1970: 1_743_191_999)))
        XCTAssertFalse(start.isRehearsalWindow(referenceDate: Date(timeIntervalSince1970: 1_743_192_000)))
    }

    func testRaceStartCompletedStatusClosesRealBroadcastWindow() {
        let start = RaceStart(
            rawId: "start-1",
            name: "Morning Fleet",
            status: "completed",
            scheduledUTC: "2026-03-25T12:00:00Z",
            actualUTC: "2026-03-25T12:05:00Z",
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )

        XCTAssertTrue(start.isCompletedStatus)
        XCTAssertFalse(start.isRealBroadcastWindowOpen(referenceDate: Date(timeIntervalSince1970: 1_743_192_000)))
    }

    func testRaceStartWithoutEstimatedTimeCannotOpenBroadcastWindow() {
        let start = RaceStart(
            rawId: "start-1",
            name: "Morning Fleet",
            status: "scheduled",
            scheduledUTC: nil,
            actualUTC: "2026-03-25T12:05:00Z",
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )

        XCTAssertFalse(start.hasEstimatedStartDate)
        XCTAssertFalse(start.isRealBroadcastWindowOpen(referenceDate: Date(timeIntervalSince1970: 1_743_192_000)))
        XCTAssertFalse(start.isRehearsalWindow(referenceDate: Date(timeIntervalSince1970: 1_743_191_000)))
    }

    func testRaceStartUsesLocalizedStatusKeysForApprovedStatuses() {
        let scheduled = RaceStart(
            rawId: "start-1",
            name: nil,
            status: "scheduled",
            scheduledUTC: "2026-03-25T12:00:00Z",
            actualUTC: nil,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )
        let completed = RaceStart(
            rawId: "start-2",
            name: nil,
            status: "completed",
            scheduledUTC: "2026-03-25T12:00:00Z",
            actualUTC: nil,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )

        XCTAssertEqual(scheduled.localizedStatusKey, "start_status_scheduled")
        XCTAssertEqual(completed.localizedStatusKey, "start_status_completed")
    }

    func testRaceStartLegacyStatusesRemainCompatibleDuringTransition() {
        let planned = RaceStart(
            rawId: "start-1",
            name: nil,
            status: "planned",
            scheduledUTC: "2026-03-25T12:00:00Z",
            actualUTC: nil,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )
        let finished = RaceStart(
            rawId: "start-2",
            name: nil,
            status: "finished",
            scheduledUTC: "2026-03-25T12:00:00Z",
            actualUTC: nil,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )

        XCTAssertTrue(planned.isScheduledStatus)
        XCTAssertTrue(finished.isCompletedStatus)
    }

    func testRehearsalBroadcastSessionGetsAutoStopDeadline() {
        let startedAt = Date(timeIntervalSince1970: 1_743_190_000)
        let session = BroadcastSession(
            token: "token",
            boatToken: nil,
            startEntryId: "entry-1",
            startId: "start-1",
            boatId: nil,
            raceId: nil,
            seriesId: nil,
            startDisplayName: nil,
            summary: ParticipationSummary(name: nil, sailNumber: nil, rating: nil, club: nil, description: nil, colorHex: nil),
            mode: .rehearsal,
            startedAt: startedAt
        )

        XCTAssertTrue(session.isRehearsal)
        XCTAssertEqual(session.autoStopAt, startedAt.addingTimeInterval(BroadcastSession.rehearsalDuration))
    }

    func testLiveBroadcastSessionDoesNotGetAutoStopDeadline() {
        let session = BroadcastSession(
            token: "token",
            boatToken: nil,
            startEntryId: "entry-1",
            startId: "start-1",
            boatId: nil,
            raceId: nil,
            seriesId: nil,
            startDisplayName: nil,
            summary: ParticipationSummary(name: nil, sailNumber: nil, rating: nil, club: nil, description: nil, colorHex: nil),
            mode: .live,
            startedAt: Date(timeIntervalSince1970: 1_743_190_000)
        )

        XCTAssertFalse(session.isRehearsal)
        XCTAssertNil(session.autoStopAt)
    }

    func testBroadcastSessionMatchesOnlyItsOwnStart() {
        let session = BroadcastSession(
            token: "token",
            boatToken: nil,
            startEntryId: "entry-1",
            startId: "start-a",
            boatId: nil,
            raceId: "race-1",
            seriesId: nil,
            startDisplayName: nil,
            summary: ParticipationSummary(name: nil, sailNumber: nil, rating: nil, club: nil, description: nil, colorHex: nil),
            mode: .live,
            startedAt: Date(timeIntervalSince1970: 1_743_190_000)
        )

        XCTAssertTrue(session.matches(startId: "start-a"))
        XCTAssertFalse(session.matches(startId: "start-b"))
        XCTAssertFalse(session.matches(startId: nil))
        XCTAssertFalse(session.matches(startId: ""))
    }

    func testBroadcastSessionBlocksCTAForOtherStartsOnly() {
        let session = BroadcastSession(
            token: "token",
            boatToken: nil,
            startEntryId: "entry-1",
            startId: "start-a",
            boatId: nil,
            raceId: "race-1",
            seriesId: nil,
            startDisplayName: nil,
            summary: ParticipationSummary(name: nil, sailNumber: nil, rating: nil, club: nil, description: nil, colorHex: nil),
            mode: .live,
            startedAt: Date(timeIntervalSince1970: 1_743_190_000)
        )

        XCTAssertFalse(session.blocksStartBroadcastCTA(for: "start-a"))
        XCTAssertTrue(session.blocksStartBroadcastCTA(for: "start-b"))
        XCTAssertTrue(session.blocksStartBroadcastCTA(for: "cross-race-start"))
        XCTAssertFalse(session.blocksStartBroadcastCTA(for: nil))
        XCTAssertFalse(session.blocksStartBroadcastCTA(for: ""))
    }

    func testBroadcastSessionUsesSensibleDrawerFallbacks() {
        let session = BroadcastSession(
            token: "token",
            boatToken: nil,
            startEntryId: "entry-1",
            startId: "start-a",
            boatId: nil,
            raceId: "race-1",
            seriesId: nil,
            startDisplayName: "  ",
            summary: ParticipationSummary(name: nil, sailNumber: nil, rating: nil, club: nil, description: nil, colorHex: nil),
            mode: .live,
            startedAt: Date(timeIntervalSince1970: 1_743_190_000)
        )

        XCTAssertEqual(session.compactStartDisplayName, "Unknown start")
        XCTAssertEqual(session.summary.compactBoatName, "—")
        XCTAssertEqual(session.summary.compactRatingText(locale: Locale(identifier: "en_US_POSIX")), "—")
    }

    // MARK: - Helpers

    private func makeService() -> RaceService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return RaceService(baseURL: URL(string: "https://example.com")!, apiKey: "test-key", session: session)
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: -1))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
