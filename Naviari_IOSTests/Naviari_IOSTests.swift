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

    func testUpdateStartActualTimeUsesPatchTimingContract() async throws {
        let inspectedRequest = expectation(description: "patch request inspected")

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/api/starts/start-1/timing")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "test-key")

            let json = try XCTUnwrap(
                try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
            )
            XCTAssertEqual(json["actualUtc"] as? String, "2025-05-01T10:05:00Z")
            XCTAssertEqual(json["updatedBy"] as? String, "ios-tests")
            inspectedRequest.fulfill()

            let payload = """
            {"start":{"id":"start-1","name":"Morning Fleet","status":"scheduled","scheduled_utc":"2025-05-01T10:00:00Z","actual_utc":"2025-05-01T10:05:00Z"}}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let service = makeService()
        let start = try await service.updateStartActualTime(
            startId: "start-1",
            actualUtc: "2025-05-01T10:05:00Z",
            updatedBy: "ios-tests"
        )

        wait(for: [inspectedRequest], timeout: 1.0)
        XCTAssertEqual(start.rawId, "start-1")
        XCTAssertEqual(start.actualUTC, "2025-05-01T10:05:00Z")
    }

    func testUpdateStartActualTimeSurfacesServerError() async throws {
        MockURLProtocol.requestHandler = { request in
            let payload = """
            {"ok":false,"error":"Manage access is required to update start timing."}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let service = makeService()

        do {
            _ = try await service.updateStartActualTime(
                startId: "start-1",
                actualUtc: "2025-05-01T10:05:00Z"
            )
            XCTFail("Expected server error")
        } catch let error as RaceServiceError {
            switch error {
            case let .serverError(statusCode, message):
                XCTAssertEqual(statusCode, 403)
                XCTAssertEqual(message, "Manage access is required to update start timing.")
            default:
                XCTFail("Unexpected RaceServiceError: \(error)")
            }
        }
    }

    func testUpdateStartActualTimeIncludesManageTokenHeaderWhenProvided() async throws {
        let inspectedRequest = expectation(description: "manage header included")

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-User-Key"), "manage-token-1")
            inspectedRequest.fulfill()

            let payload = """
            {"start":{"id":"start-1","name":"Morning Fleet","status":"scheduled","scheduled_utc":"2025-05-01T10:00:00Z","actual_utc":"2025-05-01T10:05:00Z"}}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let service = makeService()
        _ = try await service.updateStartActualTime(
            startId: "start-1",
            actualUtc: "2025-05-01T10:05:00Z",
            accessToken: "manage-token-1"
        )

        wait(for: [inspectedRequest], timeout: 1.0)
    }

    func testExchangeManageCodeForTokenUsesAccessLoginContract() async throws {
        let inspectedRequest = expectation(description: "manage login request inspected")

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/access/login")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "test-key")

            let json = try XCTUnwrap(
                try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
            )
            XCTAssertEqual(json["code"] as? String, "ABCD-1234")
            inspectedRequest.fulfill()

            let payload = """
            {"ok":true,"token":"manage-token-1"}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let service = makeParticipationService()
        let token = try await service.exchangeManageCodeForToken("ABCD-1234")

        wait(for: [inspectedRequest], timeout: 1.0)
        XCTAssertEqual(token, "manage-token-1")
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

    func testLocalizedHourMinuteFormatsTwentyFourHourClock() {
        let date = Date(timeIntervalSince1970: 1_775_138_700)

        let formatted = DateFormattingHelper.localizedHourMinute(
            from: date,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(formatted, "14:05")
    }

    func testActualStartCountdownUsesDayTextWhenMoreThanTwoDaysRemain() {
        let now = Date(timeIntervalSince1970: 1_775_088_000)
        let target = now.addingTimeInterval((4 * 86_400) + 3_600)

        let formatted = DateFormattingHelper.actualStartCountdownString(
            to: target,
            now: now,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(formatted, "in 4 days")
    }

    func testActualStartCountdownUsesClockFormatWhenTwoDaysOrLessRemain() {
        let now = Date(timeIntervalSince1970: 1_775_088_000)
        let target = now.addingTimeInterval((18 * 3_600) + (42 * 60) + 9)

        let formatted = DateFormattingHelper.actualStartCountdownString(
            to: target,
            now: now,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(formatted, "18:42:09")
    }

    func testActualStartCountdownClampsPastValuesToZero() {
        let now = Date(timeIntervalSince1970: 1_775_088_000)
        let target = now.addingTimeInterval(-30)

        let formatted = DateFormattingHelper.actualStartCountdownString(
            to: target,
            now: now,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(formatted, "00:00:00")
    }

    func testActualStartEditorInitialDatePrefersActualUtc() {
        let referenceDate = Date(timeIntervalSince1970: 1_775_088_000)
        let start = RaceStart(
            rawId: "start-1",
            name: "Morning Fleet",
            status: "scheduled",
            scheduledUTC: "2026-03-25T12:00:00Z",
            actualUTC: "2026-03-25T12:05:00Z",
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )

        XCTAssertEqual(
            start.actualStartEditorInitialDate(referenceDate: referenceDate).timeIntervalSince1970,
            Date(timeIntervalSince1970: 1_743_005_100).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testActualStartEditorInitialDateFallsBackToScheduledUtc() {
        let referenceDate = Date(timeIntervalSince1970: 1_775_088_000)
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

        XCTAssertEqual(
            start.actualStartEditorInitialDate(referenceDate: referenceDate).timeIntervalSince1970,
            Date(timeIntervalSince1970: 1_743_004_800).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testActualStartEditorInitialDateFallsBackToRoundedCurrentMinute() {
        let referenceDate = Date(timeIntervalSince1970: 1_775_138_759)
        let start = RaceStart(
            rawId: "start-1",
            name: "Morning Fleet",
            status: "scheduled",
            scheduledUTC: nil,
            actualUTC: nil,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )

        XCTAssertEqual(
            start.actualStartEditorInitialDate(referenceDate: referenceDate).timeIntervalSince1970,
            Date(timeIntervalSince1970: 1_775_138_740).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testActualStartDateFromTimerUsesDefaultFiveMinuteConcept() {
        let referenceDate = Date(timeIntervalSince1970: 1_775_138_759)

        XCTAssertEqual(
            RaceStart.actualStartDateFromTimer(minutes: 5, referenceDate: referenceDate).timeIntervalSince1970,
            Date(timeIntervalSince1970: 1_775_139_040).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testActualStartDateFromTimerUsesChangedMinuteValue() {
        let referenceDate = Date(timeIntervalSince1970: 1_775_138_759)

        XCTAssertEqual(
            RaceStart.actualStartDateFromTimer(minutes: 12, referenceDate: referenceDate).timeIntervalSince1970,
            Date(timeIntervalSince1970: 1_775_139_460).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    @MainActor
    func testActualStartHeaderStateUsesScheduledWhenActualMissing() {
        let viewModel = RaceBrowserViewModel()
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

        let state = viewModel.actualStartHeaderState(for: start)
        guard case let .scheduled(timeText) = state else {
            return XCTFail("Expected scheduled state")
        }

        XCTAssertEqual(timeText, viewModel.formattedStartTime(for: start))
    }

    @MainActor
    func testActualStartHeaderStateUsesCountdownWhenActualInFuture() {
        let viewModel = RaceBrowserViewModel()
        let now = Date(timeIntervalSince1970: 1_775_088_000)
        let target = now.addingTimeInterval((2 * 3_600) + (15 * 60) + 10)
        let actualUtc = ISO8601DateFormatter().string(from: target)
        let start = RaceStart(
            rawId: "start-1",
            name: "Morning Fleet",
            status: "scheduled",
            scheduledUTC: "2026-03-25T12:00:00Z",
            actualUTC: actualUtc,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )

        let expected = DateFormattingHelper.actualStartCountdownString(to: target, now: now)
        let state = viewModel.actualStartHeaderState(for: start, now: now)
        guard case let .countdown(timeToStartText) = state else {
            return XCTFail("Expected countdown state")
        }

        XCTAssertEqual(timeToStartText, expected)
    }

    @MainActor
    func testActualStartHeaderStateUsesStartedWhenActualReached() {
        let viewModel = RaceBrowserViewModel()
        let now = Date(timeIntervalSince1970: 1_775_088_000)
        let actualDate = now.addingTimeInterval(-30)
        let actualUtc = ISO8601DateFormatter().string(from: actualDate)
        let start = RaceStart(
            rawId: "start-1",
            name: "Morning Fleet",
            status: "scheduled",
            scheduledUTC: "2026-03-25T12:00:00Z",
            actualUTC: actualUtc,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )

        let expected = DateFormattingHelper.localizedHourMinute(from: actualDate)
        let state = viewModel.actualStartHeaderState(for: start, now: now)
        guard case let .started(actualLocalTimeText) = state else {
            return XCTFail("Expected started state")
        }

        XCTAssertEqual(actualLocalTimeText, expected)
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

    func testManageAccessStoragePrefersStartThenRaceThenSeries() {
        let suiteName = "ManageAccessStorageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storage = ManageAccessStorage(userDefaults: defaults)
        storage.saveToken(token: "series-token", startId: nil, raceId: nil, seriesId: "series-1")
        storage.saveToken(token: "race-token", startId: nil, raceId: "race-1", seriesId: nil)
        storage.saveToken(token: "start-token", startId: "start-1", raceId: nil, seriesId: nil)

        let record = storage.loadToken(for: "start-1", raceId: "race-1", seriesId: "series-1")
        XCTAssertEqual(record?.scope, .start)
        XCTAssertEqual(record?.scopeId, "start-1")
        XCTAssertEqual(record?.token, "start-token")
    }

    func testManageAccessStorageFallsBackToRaceThenSeries() {
        let suiteName = "ManageAccessStorageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storage = ManageAccessStorage(userDefaults: defaults)
        storage.saveToken(token: "series-token", startId: nil, raceId: nil, seriesId: "series-1")
        storage.saveToken(token: "race-token", startId: nil, raceId: "race-1", seriesId: nil)

        let raceFallback = storage.loadToken(for: "missing-start", raceId: "race-1", seriesId: "series-1")
        XCTAssertEqual(raceFallback?.scope, .race)
        XCTAssertEqual(raceFallback?.scopeId, "race-1")
        XCTAssertEqual(raceFallback?.token, "race-token")

        let seriesFallback = storage.loadToken(for: "missing-start", raceId: "missing-race", seriesId: "series-1")
        XCTAssertEqual(seriesFallback?.scope, .series)
        XCTAssertEqual(seriesFallback?.scopeId, "series-1")
        XCTAssertEqual(seriesFallback?.token, "series-token")
    }

    func testManageAccessStorageReturnsNilWhenNoMatchingScopeExists() {
        let suiteName = "ManageAccessStorageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storage = ManageAccessStorage(userDefaults: defaults)
        storage.saveToken(token: "series-token", startId: nil, raceId: nil, seriesId: "series-1")

        let record = storage.loadToken(for: "start-1", raceId: "race-1", seriesId: "series-2")
        XCTAssertNil(record)
    }

    // MARK: - Helpers

    private func makeService() -> RaceService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return RaceService(baseURL: URL(string: "https://example.com")!, apiKey: "test-key", session: session)
    }

    private func makeParticipationService() -> ParticipationService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return ParticipationService(session: session, baseURL: URL(string: "https://example.com")!, apiKey: "test-key")
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
