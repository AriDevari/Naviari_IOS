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
            {"series":[{"id":"series-1","name":"Spring Series","races":[{"id":"race-1","name":"Opener","status":"scheduled","start_date":"2026-04-18","end_date":"2026-04-20"}]}]}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let service = makeService()
        let series = try await service.fetchRaceSeries()
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series.first?.races.first?.name, "Opener")
        XCTAssertEqual(series.first?.races.first?.startDate, "2026-04-18")
        XCTAssertEqual(series.first?.races.first?.endDate, "2026-04-20")
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

        func testFetchCourseTemplatesUsesTemplateScopeAndDecodesSummaryList() async throws {
                let inspectedRequest = expectation(description: "course templates request inspected")

                MockURLProtocol.requestHandler = { request in
                        XCTAssertEqual(request.httpMethod, "GET")
                        XCTAssertEqual(request.url?.path, "/api/courses")
                        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
                        let queryItems = components.queryItems ?? []
                        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "seriesId", value: "series-1")))
                        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "scope", value: "template")))
                        inspectedRequest.fulfill()

                        let payload = """
                        {
                            "courses": [
                                {
                                    "id": "template-1",
                                    "name": "Windward",
                                    "series_id": "series-1",
                                    "is_template": true,
                                    "total_length_nm": 12.4
                                }
                            ]
                        }
                        """.data(using: .utf8)!
                        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                        return (response, payload)
                }

                let service = makeService()
                let templates = try await service.fetchCourseTemplates(seriesId: "series-1")

                wait(for: [inspectedRequest], timeout: 1.0)
                XCTAssertEqual(templates.count, 1)
                XCTAssertEqual(templates.first?.id, "template-1")
                XCTAssertEqual(try XCTUnwrap(templates.first?.total_length_nm), 12.4, accuracy: 0.000_001)
        }

        func testCopyCourseTemplateToStartUsesStartCopyEndpointAndManageToken() async throws {
                let inspectedRequest = expectation(description: "course template copy request inspected")

                MockURLProtocol.requestHandler = { request in
                        XCTAssertEqual(request.httpMethod, "POST")
                        XCTAssertEqual(request.url?.path, "/api/starts/start-1/course-copy")
                        XCTAssertEqual(request.value(forHTTPHeaderField: "X-User-Key"), "manage-token-1")

                        let json = try XCTUnwrap(
                                try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
                        )
                        XCTAssertEqual(json["templateCourseId"] as? String, "template-1")
                        XCTAssertEqual(json["name"] as? String, "Windward")
                        XCTAssertEqual(json["updatedBy"] as? String, "ios-start-detail")
                        inspectedRequest.fulfill()

                        let payload = """
                        {
                            "ok": true,
                            "startId": "start-1",
                            "course": {
                                "id": "course-1",
                                "name": "Windward",
                                "course_marks": []
                            }
                        }
                        """.data(using: .utf8)!
                        let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
                        return (response, payload)
                }

                let service = makeService()
                let copiedCourse = try await service.copyCourseTemplateToStart(
                        startId: "start-1",
                        templateCourseId: "template-1",
                        accessToken: "manage-token-1",
                        name: "Windward"
                )

                wait(for: [inspectedRequest], timeout: 1.0)
                XCTAssertEqual(copiedCourse.id, "course-1")
                XCTAssertEqual(copiedCourse.name, "Windward")
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

    func testValidateParticipationFormRejectsMissingName() {
        let result = validateParticipationForm(name: "  ", sailNumber: "FIN-123", ratingValue: "1.123")

        XCTAssertEqual(result, .failure(.missingName))
    }

    func testValidateParticipationFormRejectsMissingSailNumber() {
        let result = validateParticipationForm(name: "Boat", sailNumber: " ", ratingValue: "1.123")

        XCTAssertEqual(result, .failure(.missingSailNumber))
    }

    func testValidateParticipationFormRejectsNonPositiveOrInvalidRating() {
        XCTAssertEqual(
            validateParticipationForm(name: "Boat", sailNumber: "FIN-123", ratingValue: "0"),
            .failure(.invalidRating)
        )
        XCTAssertEqual(
            validateParticipationForm(name: "Boat", sailNumber: "FIN-123", ratingValue: "-1"),
            .failure(.invalidRating)
        )
        XCTAssertEqual(
            validateParticipationForm(name: "Boat", sailNumber: "FIN-123", ratingValue: "abc"),
            .failure(.invalidRating)
        )
    }

    func testValidateParticipationFormTrimsAndAcceptsLocalizedRating() {
        let result = validateParticipationForm(
            name: "  Boat  ",
            sailNumber: "  FIN-123  ",
            ratingValue: "1,234",
            locale: Locale(identifier: "fi_FI")
        )

        XCTAssertEqual(
            result,
            .success(
                ValidatedParticipationFormValues(
                    name: "Boat",
                    sailNumber: "FIN-123",
                    rating: 1.234
                )
            )
        )
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

    func testBroadcastSessionRequiresBoatTokenForUploadCredentials() {
        let session = BroadcastSession(
            token: "token",
            boatToken: nil,
            startEntryId: "entry-1",
            startId: "start-a",
            boatId: nil,
            raceId: nil,
            seriesId: nil,
            startDisplayName: nil,
            summary: ParticipationSummary(name: nil, sailNumber: nil, rating: nil, club: nil, description: nil, colorHex: nil),
            mode: .live,
            startedAt: Date(timeIntervalSince1970: 1_743_190_000)
        )

        XCTAssertFalse(session.hasUploadCredentials)
    }

    func testBroadcastSessionCanReuseOnlyMatchingModeAndCredentials() {
        let baseSummary = ParticipationSummary(name: nil, sailNumber: nil, rating: nil, club: nil, description: nil, colorHex: nil)
        let active = BroadcastSession(
            token: "token-a",
            boatToken: "boat-token-a",
            startEntryId: "entry-1",
            startId: "start-a",
            boatId: "boat-a",
            raceId: nil,
            seriesId: nil,
            startDisplayName: nil,
            summary: baseSummary,
            mode: .rehearsal,
            startedAt: Date(timeIntervalSince1970: 1_743_190_000)
        )

        let matching = BroadcastSession(
            token: "token-a",
            boatToken: "boat-token-a",
            startEntryId: "entry-1",
            startId: "start-a",
            boatId: "boat-a",
            raceId: nil,
            seriesId: nil,
            startDisplayName: nil,
            summary: baseSummary,
            mode: .rehearsal,
            startedAt: Date(timeIntervalSince1970: 1_743_190_100)
        )

        let liveMode = BroadcastSession(
            token: "token-a",
            boatToken: "boat-token-a",
            startEntryId: "entry-1",
            startId: "start-a",
            boatId: "boat-a",
            raceId: nil,
            seriesId: nil,
            startDisplayName: nil,
            summary: baseSummary,
            mode: .live,
            startedAt: Date(timeIntervalSince1970: 1_743_190_100)
        )

        let rotatedBoatToken = BroadcastSession(
            token: "token-a",
            boatToken: "boat-token-b",
            startEntryId: "entry-1",
            startId: "start-a",
            boatId: "boat-a",
            raceId: nil,
            seriesId: nil,
            startDisplayName: nil,
            summary: baseSummary,
            mode: .rehearsal,
            startedAt: Date(timeIntervalSince1970: 1_743_190_100)
        )

        XCTAssertTrue(active.canReuse(for: matching))
        XCTAssertFalse(active.canReuse(for: liveMode))
        XCTAssertFalse(active.canReuse(for: rotatedBoatToken))
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

    func testDefinitionStatusMapsLinePartialStatesToPreliminary() {
        XCTAssertEqual(DefinitionStatus(from: "leftSet"), .preliminary)
        XCTAssertEqual(DefinitionStatus(from: "rightSet"), .preliminary)
        XCTAssertEqual(DefinitionStatus(from: " RIGHTSET "), .preliminary)
    }

    func testDefinitionStatusKeepsUnknownValuesAsNone() {
        XCTAssertEqual(DefinitionStatus(from: "unexpected"), .none)
    }

    func testRaceCourseDecoderSupportsNestedCoordinateShape() throws {
        let payload = """
        {
          "id": "course-1",
          "name": "Sample Course",
          "start_line": {
            "id": "start-line-1",
            "status": "leftSet",
            "mark_left": { "lat": 60.111, "lon": 24.111 },
            "mark_right": { "lat": 60.222, "lon": 24.222 }
          },
          "finish_line": {
            "id": "finish-line-1",
            "status": "rightSet",
            "mark_left": { "lat": 60.333, "lon": 24.333 },
            "mark_right": { "lat": 60.444, "lon": 24.444 }
          },
          "course_marks": [
            {
              "id": "mark-1",
              "sequence": 1,
              "status": "preliminary",
              "mark": { "lat": 60.555, "lon": 24.555 }
            }
          ]
        }
        """.data(using: .utf8)!

        let course = try JSONDecoder().decode(RaceCourse.self, from: payload)
        let startLine = try XCTUnwrap(course.start_line)
        let finishLine = try XCTUnwrap(course.finish_line)
        let firstMark = try XCTUnwrap(course.course_marks.first)
        XCTAssertEqual(try XCTUnwrap(startLine.mark_left_lat), 60.111, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(startLine.mark_right_lon), 24.222, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(finishLine.mark_left_lon), 24.333, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(firstMark.mark_lat), 60.555, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(firstMark.mark_lon), 24.555, accuracy: 0.000_001)

        let timeline = CourseTimelineItem.buildTimeline(from: course)
        XCTAssertEqual(timeline.first(where: { $0.type == .start })?.status, .preliminary)
        XCTAssertEqual(timeline.first(where: { $0.type == .finish })?.status, .preliminary)
    }

    func testRaceCourseDecoderSupportsLegacyFlatCoordinateShape() throws {
        let payload = """
        {
          "id": "course-legacy",
          "start_line": {
            "id": "start-line-legacy",
            "status": "preliminary",
            "mark_left_lat": 61.001,
            "mark_left_lon": 25.001,
            "mark_right_lat": 61.002,
            "mark_right_lon": 25.002
          },
          "course_marks": [
            {
              "id": "mark-legacy-1",
              "sequence": 1,
              "status": "final",
              "mark_lat": 61.101,
              "mark_lon": 25.101
            }
          ]
        }
        """.data(using: .utf8)!

        let course = try JSONDecoder().decode(RaceCourse.self, from: payload)
        let startLine = try XCTUnwrap(course.start_line)
        let firstMark = try XCTUnwrap(course.course_marks.first)
        XCTAssertEqual(try XCTUnwrap(startLine.mark_left_lat), 61.001, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(startLine.mark_right_lon), 25.002, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(firstMark.mark_lat), 61.101, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(firstMark.mark_lon), 25.101, accuracy: 0.000_001)
    }

    func testRaceCourseDecoderDefaultsMissingCourseItemsForTemplateSummary() throws {
        let payload = """
        {
          "id": "template-1",
          "name": "Windward",
          "series_id": "series-1",
          "is_template": true,
          "total_length_nm": 12.4
        }
        """.data(using: .utf8)!

        let course = try JSONDecoder().decode(RaceCourse.self, from: payload)
        XCTAssertEqual(course.id, "template-1")
        XCTAssertEqual(course.name, "Windward")
        XCTAssertEqual(course.series_id, "series-1")
        XCTAssertEqual(course.is_template, true)
        XCTAssertEqual(try XCTUnwrap(course.total_length_nm), 12.4, accuracy: 0.000_001)
        XCTAssertEqual(course.course_marks, [])
        XCTAssertNil(course.start_line)
        XCTAssertNil(course.finish_line)
    }

    func testSetPositionTargetLineStatusTransitions() {
        let lineTarget = CourseLinePositionTarget(
            lineId: "line-1",
            name: "Start line",
            description: nil,
            status: "preliminary",
            markLeft: CoordinatePoint(lat: 60.1, lon: 24.1),
            markRight: CoordinatePoint(lat: 60.2, lon: 24.2)
        )

        XCTAssertEqual(
            SetPositionTarget.startLine(lineTarget, side: .left).nextLineStatus(),
            "leftSet"
        )
        XCTAssertEqual(
            SetPositionTarget.startLine(lineTarget, side: .right).nextLineStatus(),
            "rightSet"
        )
    }

    func testSetPositionTargetLineStatusTransitionsReachFinalFromPartialStates() {
        let leftSet = CourseLinePositionTarget(
            lineId: "line-1",
            name: "Start line",
            description: nil,
            status: "leftSet",
            markLeft: CoordinatePoint(lat: 60.1, lon: 24.1),
            markRight: CoordinatePoint(lat: 60.2, lon: 24.2)
        )
        let rightSet = CourseLinePositionTarget(
            lineId: "line-1",
            name: "Start line",
            description: nil,
            status: "rightSet",
            markLeft: CoordinatePoint(lat: 60.1, lon: 24.1),
            markRight: CoordinatePoint(lat: 60.2, lon: 24.2)
        )

        XCTAssertEqual(
            SetPositionTarget.startLine(leftSet, side: .right).nextLineStatus(),
            "final"
        )
        XCTAssertEqual(
            SetPositionTarget.finishLine(rightSet, side: .left).nextLineStatus(),
            "final"
        )
    }

    func testSetPositionTargetLineStatusKeepsCurrentStateWhenReSettingSameSide() {
        let leftSet = CourseLinePositionTarget(
            lineId: "line-1",
            name: "Finish line",
            description: nil,
            status: "leftSet",
            markLeft: CoordinatePoint(lat: 60.1, lon: 24.1),
            markRight: CoordinatePoint(lat: 60.2, lon: 24.2)
        )
        let finalStatus = CourseLinePositionTarget(
            lineId: "line-2",
            name: "Finish line",
            description: nil,
            status: "final",
            markLeft: CoordinatePoint(lat: 60.1, lon: 24.1),
            markRight: CoordinatePoint(lat: 60.2, lon: 24.2)
        )
        let testData = CourseLinePositionTarget(
            lineId: "line-3",
            name: "Finish line",
            description: nil,
            status: "testData",
            markLeft: CoordinatePoint(lat: 60.1, lon: 24.1),
            markRight: CoordinatePoint(lat: 60.2, lon: 24.2)
        )

        XCTAssertEqual(
            SetPositionTarget.finishLine(leftSet, side: .left).nextLineStatus(),
            "leftSet"
        )
        XCTAssertEqual(
            SetPositionTarget.finishLine(finalStatus, side: .left).nextLineStatus(),
            "final"
        )
        XCTAssertEqual(
            SetPositionTarget.finishLine(testData, side: .left).nextLineStatus(),
            "testData"
        )
    }

    func testSetCoursePositionForMarkUsesCourseMarksEndpointAndFinalStatus() async throws {
        let inspectedRequest = expectation(description: "course mark upsert request inspected")

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.url?.path, "/api/course-marks")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-User-Key"), "manage-token-1")

            let json = try XCTUnwrap(
                try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
            )
            XCTAssertEqual(json["id"] as? String, "mark-1")
            XCTAssertEqual(json["name"] as? String, "M1")
            XCTAssertEqual(json["status"] as? String, "final")
            let mark = try XCTUnwrap(json["mark"] as? [String: Any])
            XCTAssertEqual(mark["lat"] as? Double, 60.123)
            XCTAssertEqual(mark["lon"] as? Double, 24.456)
            inspectedRequest.fulfill()

            let payload = """
            {"ok":true,"mark":{"id":"mark-1"}}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let service = makeService()
        let target = SetPositionTarget.mark(
            CourseMarkPositionTarget(
                markId: "mark-1",
                name: "M1",
                description: "Mark 1",
                roundingSide: "port",
                type: "race_point",
                status: "preliminary"
            )
        )

        try await service.setCoursePosition(
            target: target,
            coordinate: CoordinatePoint(lat: 60.123, lon: 24.456),
            accessToken: "manage-token-1"
        )

        wait(for: [inspectedRequest], timeout: 1.0)
    }

    func testSetCoursePositionForStartLinePreservesUntouchedEndpoint() async throws {
        let inspectedRequest = expectation(description: "start line upsert request inspected")

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.url?.path, "/api/start-lines")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-User-Key"), "manage-token-1")

            let json = try XCTUnwrap(
                try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
            )
            XCTAssertEqual(json["id"] as? String, "line-1")
            XCTAssertEqual(json["status"] as? String, "leftSet")

            let markLeft = try XCTUnwrap(json["markLeft"] as? [String: Any])
            XCTAssertEqual(markLeft["lat"] as? Double, 60.5)
            XCTAssertEqual(markLeft["lon"] as? Double, 24.5)

            let markRight = try XCTUnwrap(json["markRight"] as? [String: Any])
            XCTAssertEqual(markRight["lat"] as? Double, 60.2)
            XCTAssertEqual(markRight["lon"] as? Double, 24.2)
            inspectedRequest.fulfill()

            let payload = """
            {"ok":true,"startLine":{"id":"line-1"}}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let service = makeService()
        let target = SetPositionTarget.startLine(
            CourseLinePositionTarget(
                lineId: "line-1",
                name: "Start line",
                description: "desc",
                status: "preliminary",
                markLeft: CoordinatePoint(lat: 60.1, lon: 24.1),
                markRight: CoordinatePoint(lat: 60.2, lon: 24.2)
            ),
            side: .left
        )

        try await service.setCoursePosition(
            target: target,
            coordinate: CoordinatePoint(lat: 60.5, lon: 24.5),
            accessToken: "manage-token-1"
        )

        wait(for: [inspectedRequest], timeout: 1.0)
    }

    func testSetCoursePositionForStartLineUsesFreshCourseEndpointInsteadOfStaleScreenValue() async throws {
        let fetchedCurrentLine = expectation(description: "current start course requested")
        let inspectedWrite = expectation(description: "start line write inspected")

        MockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/api/starts/id/start-1":
                XCTAssertEqual(request.httpMethod, "GET")
                fetchedCurrentLine.fulfill()
                let payload = """
                {
                  "ok": true,
                  "start": { "id": "start-1", "name": "Start 1", "status": "scheduled" },
                  "course": {
                    "id": "course-1",
                    "course_marks": [],
                    "start_line": {
                      "id": "line-1",
                      "name": "Start line",
                      "status": "leftSet",
                      "mark_left_lat": 60.5,
                      "mark_left_lon": 24.5,
                      "mark_right_lat": 60.2,
                      "mark_right_lon": 24.2
                    }
                  }
                }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, payload)

            case "/api/start-lines":
                XCTAssertEqual(request.httpMethod, "PUT")
                let json = try XCTUnwrap(
                    try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
                )
                XCTAssertEqual(json["status"] as? String, "final")

                let markLeft = try XCTUnwrap(json["markLeft"] as? [String: Any])
                XCTAssertEqual(markLeft["lat"] as? Double, 60.5)
                XCTAssertEqual(markLeft["lon"] as? Double, 24.5)

                let markRight = try XCTUnwrap(json["markRight"] as? [String: Any])
                XCTAssertEqual(markRight["lat"] as? Double, 60.8)
                XCTAssertEqual(markRight["lon"] as? Double, 24.8)
                inspectedWrite.fulfill()

                let payload = """
                { "ok": true, "startLine": { "id": "line-1" } }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, payload)

            default:
                throw RaceServiceError.invalidURL
            }
        }

        let target = SetPositionTarget.startLine(
            CourseLinePositionTarget(
                lineId: "line-1",
                name: "Start line",
                description: "stale screen snapshot",
                status: "preliminary",
                markLeft: CoordinatePoint(lat: 60.1, lon: 24.1),
                markRight: CoordinatePoint(lat: 60.2, lon: 24.2)
            ),
            side: .right
        )

        try await makeService().setCoursePosition(
            target: target,
            coordinate: CoordinatePoint(lat: 60.8, lon: 24.8),
            accessToken: "manage-token-1",
            startId: "start-1"
        )

        wait(for: [fetchedCurrentLine, inspectedWrite], timeout: 1.0)
    }

    func testSetCoursePositionThrowsWhenUntouchedLineEndpointIsMissing() async throws {
        let service = makeService()
        let target = SetPositionTarget.finishLine(
            CourseLinePositionTarget(
                lineId: "line-1",
                name: "Finish line",
                description: nil,
                status: "preliminary",
                markLeft: nil,
                markRight: nil
            ),
            side: .left
        )

        do {
            try await service.setCoursePosition(
                target: target,
                coordinate: CoordinatePoint(lat: 60.1, lon: 24.1),
                accessToken: "manage-token-1"
            )
            XCTFail("Expected invalid request error")
        } catch let error as RaceServiceError {
            switch error {
            case .invalidRequest:
                break
            default:
                XCTFail("Unexpected RaceServiceError: \(error)")
            }
        }
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
