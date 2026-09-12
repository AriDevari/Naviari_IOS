import XCTest
@testable import Naviari_IOS

// MARK: - DMSCoordinate conversion tests

final class CourseEditServiceTests: XCTestCase {

    // MARK: DMSCoordinate.toDecimal

    func testDMSCoordinateToDecimal_knownNorthernLatitude() {
        let dms = DMSCoordinate(degrees: 60, minutes: 10, seconds: 30.5, hemisphere: "N")
        let decimal = dms.toDecimal()
        // 60 + 10/60 + 30.5/3600 = 60 + 0.16667 + 0.008472 = 60.175139
        XCTAssertEqual(decimal, 60.175139, accuracy: 0.000001)
    }

    func testDMSCoordinateToDecimal_southHemisphereIsNegative() {
        let dms = DMSCoordinate(degrees: 33, minutes: 52, seconds: 0.0, hemisphere: "S")
        let decimal = dms.toDecimal()
        XCTAssertLessThan(decimal, 0, "Southern hemisphere should produce a negative decimal")
    }

    func testDMSCoordinateToDecimal_westHemisphereIsNegative() {
        let dms = DMSCoordinate(degrees: 118, minutes: 15, seconds: 0.0, hemisphere: "W")
        let decimal = dms.toDecimal()
        XCTAssertLessThan(decimal, 0, "Western hemisphere should produce a negative decimal")
    }

    func testDMSCoordinateRoundtrip_latitude() {
        let original = 60.123456
        let dms = DMSCoordinate(from: original, isLat: true)
        let restored = dms.toDecimal()
        XCTAssertEqual(restored, original, accuracy: 0.0001)
    }

    func testDMSCoordinateRoundtrip_longitude() {
        let original = 24.987654
        let dms = DMSCoordinate(from: original, isLat: false)
        let restored = dms.toDecimal()
        XCTAssertEqual(restored, original, accuracy: 0.0001)
    }

    func testDMSSecondsTextCodecDisplayString_usesLocaleDecimalSeparator() {
        let displayed = DMSSecondsTextCodec.displayString(for: 30.5, locale: Locale(identifier: "fi_FI"))
        XCTAssertEqual(displayed, "30,5")
    }

    func testDMSSecondsTextCodecDisplayString_keepsZeroAsAnExplicitValue() {
        XCTAssertEqual(DMSSecondsTextCodec.displayString(for: 0, locale: Locale(identifier: "en_US")), "0")
    }

    func testDMSSecondsTextCodecSanitize_usesLocaleDecimalSeparator() {
        let sanitized = DMSSecondsTextCodec.sanitize("30.5", maxLength: 6, locale: Locale(identifier: "fi_FI"))
        XCTAssertEqual(sanitized, "30,5")
    }

    func testDMSSecondsTextCodecParse_acceptsLocaleDecimalSeparator() {
        let parsed = DMSSecondsTextCodec.parse("30,5", locale: Locale(identifier: "fi_FI"))
        XCTAssertEqual(parsed, 30.5)
    }

    func testDecimalCoordinateTextCodecDisplayString_usesLocaleDecimalSeparator() {
        let displayed = DecimalCoordinateTextCodec.displayString(for: 60.123456, locale: Locale(identifier: "fi_FI"))
        XCTAssertEqual(displayed, "60,123456")
    }

    func testDecimalCoordinateTextCodecSanitize_usesLocaleDecimalSeparator() {
        let sanitized = DecimalCoordinateTextCodec.sanitize("60.123456", maxLength: 16, locale: Locale(identifier: "fi_FI"))
        XCTAssertEqual(sanitized, "60,123456")
    }

    func testDecimalCoordinateTextCodecParse_acceptsLocalizedNegativeValue() {
        let parsed = DecimalCoordinateTextCodec.parse("-24,987654", locale: Locale(identifier: "fi_FI"))
        XCTAssertEqual(parsed, -24.987654)
    }

    func testDecimalCoordinateTextCodecPlaceholder_supportsCustomPrecision() {
        let placeholder = DecimalCoordinateTextCodec.placeholder(
            for: 90,
            locale: Locale(identifier: "fi_FI"),
            maximumFractionDigits: 1
        )
        XCTAssertEqual(placeholder, "90")
    }

    func testBearingDistanceProjection_roundTripsBearingAndDistance() {
        let origin = CoordinatePoint(lat: 60.1699, lon: 24.9384)
        let destination = BearingDistanceProjection.destination(
            from: origin,
            bearingDegrees: 72.5,
            distanceMeters: 850
        )

        let projection = BearingDistanceProjection.bearingAndDistance(from: origin, to: destination)

        XCTAssertEqual(projection.bearingDegrees, 72.5, accuracy: 0.1)
        XCTAssertEqual(projection.distanceMeters, 850, accuracy: 0.5)
    }

    @MainActor
    func testCopyFromBuoyRequiresSelectionBeforeResolvingCoordinate() {
        let locationManager = LocationDataManager()
        let controller = CourseCoordinateEditorController()
        controller.prefill(coordinate: CoordinatePoint(lat: 60.1, lon: 24.1))
        controller.handleCopyFromBuoyAction()

        switch controller.resolvedCoordinate(locationManager: locationManager) {
        case .success:
            XCTFail("Copy-from-buoy mode must not resolve the old coordinate before a buoy is selected.")
        case let .failure(error):
            XCTAssertEqual(
                error,
                NSLocalizedString("course_edit_buoy_selection_required_error", comment: "")
            )
        }
    }

    @MainActor
    func testCoursePositionLocationReadinessRejectsStaleAndInaccurateLocations() {
        let locationManager = LocationDataManager()
        let now = Date()

        locationManager.injectTestLocation(
            latitude: 60.1,
            longitude: 24.1,
            accuracy: 5,
            timestamp: now.addingTimeInterval(-16)
        )
        if case .stale = locationManager.coursePositionLocationReadiness(now: now) {
            // Expected.
        } else {
            XCTFail("A 16-second-old location must not be used for setting a course position.")
        }

        locationManager.injectTestLocation(
            latitude: 60.1,
            longitude: 24.1,
            accuracy: 101,
            timestamp: now
        )
        if case .inaccurate = locationManager.coursePositionLocationReadiness(now: now) {
            // Expected.
        } else {
            XCTFail("A location with over 100 m horizontal accuracy must not be used for setting a course position.")
        }
    }

    // MARK: - DDMCoordinate conversion tests

    func testDDMCoordinateToDecimal_northernLatitude() {
        // 60° 07.407' N = 60 + 7.407/60 = 60.12345
        let ddm = DDMCoordinate(degrees: 60, decimalMinutes: 7.407, hemisphere: "N")
        XCTAssertEqual(ddm.toDecimal(), 60.12345, accuracy: 0.000001)
    }

    func testDDMCoordinateToDecimal_easternLongitudeIsPositive() {
        let ddm = DDMCoordinate(degrees: 24, decimalMinutes: 55.402, hemisphere: "E")
        XCTAssertGreaterThan(ddm.toDecimal(), 0, "Eastern hemisphere should produce a positive decimal")
    }

    func testDDMCoordinateToDecimal_southHemisphereIsNegative() {
        let ddm = DDMCoordinate(degrees: 33, decimalMinutes: 52.0, hemisphere: "S")
        XCTAssertLessThan(ddm.toDecimal(), 0, "Southern hemisphere should produce a negative decimal")
    }

    func testDDMCoordinateToDecimal_westHemisphereIsNegative() {
        let ddm = DDMCoordinate(degrees: 118, decimalMinutes: 15.0, hemisphere: "W")
        XCTAssertLessThan(ddm.toDecimal(), 0, "Western hemisphere should produce a negative decimal")
    }

    func testDDMCoordinateFromDecimal_roundTripLatitude() {
        let original = 60.123456
        let ddm = DDMCoordinate(from: original, isLat: true)
        XCTAssertEqual(ddm.hemisphere, "N")
        XCTAssertEqual(ddm.toDecimal(), original, accuracy: 0.0000001)
    }

    func testDDMCoordinateFromDecimal_roundTripNegativeLongitude() {
        let original = -24.987654
        let ddm = DDMCoordinate(from: original, isLat: false)
        XCTAssertEqual(ddm.hemisphere, "W")
        XCTAssertEqual(ddm.toDecimal(), original, accuracy: 0.0000001)
    }

    func testDDMCoordinate_bridgesDMSLosslessly() {
        // Converting DMS -> DDM must preserve the decimal value (decimalMinutes = min + sec/60).
        let dms = DMSCoordinate(degrees: 60, minutes: 7, seconds: 24.42, hemisphere: "N")
        let ddm = DDMCoordinate(dms: dms)
        XCTAssertEqual(ddm.toDecimal(), dms.toDecimal(), accuracy: 0.0000001)
    }

    func testDDMCoordinate_toDMSRoundTrip() {
        let ddm = DDMCoordinate(degrees: 24, decimalMinutes: 55.402, hemisphere: "E")
        let restored = DDMCoordinate(dms: ddm.toDMS())
        XCTAssertEqual(restored.toDecimal(), ddm.toDecimal(), accuracy: 0.0000001)
    }

    // MARK: DDMCoordinate boundary / validity

    func testDDMCoordinateValidity_minutesJustBelow60AreValid() {
        XCTAssertTrue(DDMCoordinate(degrees: 59, decimalMinutes: 59.99, hemisphere: "N").isValid(isLatitude: true))
    }

    func testDDMCoordinateValidity_minutesAt60AreInvalid() {
        XCTAssertFalse(DDMCoordinate(degrees: 59, decimalMinutes: 60.0, hemisphere: "N").isValid(isLatitude: true))
    }

    func testDDMCoordinateValidity_zeroMinutesAreValid() {
        XCTAssertTrue(DDMCoordinate(degrees: 12, decimalMinutes: 0.0, hemisphere: "E").isValid(isLatitude: false))
    }

    func testDDMCoordinateValidity_maxLatitudeRequiresZeroMinutes() {
        XCTAssertTrue(DDMCoordinate(degrees: 90, decimalMinutes: 0.0, hemisphere: "N").isValid(isLatitude: true))
        XCTAssertFalse(DDMCoordinate(degrees: 90, decimalMinutes: 0.5, hemisphere: "N").isValid(isLatitude: true))
    }

    func testDDMCoordinateValidity_maxLongitudeRequiresZeroMinutes() {
        XCTAssertTrue(DDMCoordinate(degrees: 180, decimalMinutes: 0.0, hemisphere: "E").isValid(isLatitude: false))
        XCTAssertFalse(DDMCoordinate(degrees: 180, decimalMinutes: 0.001, hemisphere: "E").isValid(isLatitude: false))
    }

    // MARK: DDMMinutesTextCodec

    func testDDMMinutesTextCodecDisplayString_usesThreeDecimalsWithLeadingZero() {
        // Marine-chartplotter style: whole-minute part padded to 2 digits.
        XCTAssertEqual(DDMMinutesTextCodec.displayString(for: 7.407, locale: Locale(identifier: "en_US")), "07.407")
    }

    func testDDMMinutesTextCodecDisplayString_padsWholeMinutesAndKeepsFraction() {
        XCTAssertEqual(DDMMinutesTextCodec.displayString(for: 5.4, locale: Locale(identifier: "en_US")), "05.4")
    }

    func testDDMMinutesTextCodecDisplayString_doesNotPadTwoDigitMinutes() {
        XCTAssertEqual(DDMMinutesTextCodec.displayString(for: 55.402, locale: Locale(identifier: "fi_FI")), "55,402")
    }

    func testDDMMinutesTextCodecPlaceholder_usesLeadingZeroForm() {
        XCTAssertEqual(DDMMinutesTextCodec.placeholder(locale: Locale(identifier: "en_US")), "00.000")
    }

    func testDDMMinutesTextCodecDisplayString_guardsRoundingBoundary() {
        // 59.9996 must NOT round up to 60.000 on display, and must parse back below 60.
        let displayed = DDMMinutesTextCodec.displayString(for: 59.9996, locale: Locale(identifier: "en_US"))
        XCTAssertNotEqual(displayed, "60")
        let parsedBack = DDMMinutesTextCodec.parse(displayed, locale: Locale(identifier: "en_US"))
        XCTAssertNotNil(parsedBack)
        XCTAssertLessThan(parsedBack ?? 60, 60)
    }

    func testDDMMinutesTextCodecSanitize_usesLocaleDecimalSeparator() {
        XCTAssertEqual(DDMMinutesTextCodec.sanitize("7.407", maxLength: 6, locale: Locale(identifier: "fi_FI")), "7,407")
    }

    func testDDMMinutesTextCodecParse_acceptsLocaleDecimalSeparator() {
        XCTAssertEqual(DDMMinutesTextCodec.parse("7,407", locale: Locale(identifier: "fi_FI")), 7.407)
    }

    func testDDMMinutesTextCodecParse_leadingZeroParsesIdentically() {
        XCTAssertEqual(
            DDMMinutesTextCodec.parse("07.407", locale: Locale(identifier: "en_US")),
            DDMMinutesTextCodec.parse("7.407", locale: Locale(identifier: "en_US"))
        )
    }

    // MARK: resolvedCoordinate(.ddm)

    @MainActor
    func testResolvedCoordinateDDM_acceptsCompleteEntryWithoutSeconds() {
        let locationManager = LocationDataManager()
        let controller = CourseCoordinateEditorController()
        controller.coordinateEntryMode = .ddm
        // 60° 07.407' N, 24° 55.402' E as the shared DMS state.
        controller.lat = DMSCoordinate(degrees: 60, minutes: 7, seconds: 24.42, hemisphere: "N")
        controller.lon = DMSCoordinate(degrees: 24, minutes: 55, seconds: 24.12, hemisphere: "E")
        controller.latDDMEntryState = DDMFieldEntryState(degreesText: "60", minutesText: "7.407")
        controller.lonDDMEntryState = DDMFieldEntryState(degreesText: "24", minutesText: "55.402")

        // The DMS entry states carry no seconds; a seconds-based gate WOULD reject this.
        XCTAssertFalse(controller.latEntryState.isComplete,
                       "Precondition: DMS completeness gate would block because seconds are empty.")

        switch controller.resolvedCoordinate(locationManager: locationManager, persistChanges: false) {
        case let .success(coordinate):
            XCTAssertEqual(coordinate.lat, 60.12345, accuracy: 0.001)
            XCTAssertEqual(coordinate.lon, 24.92337, accuracy: 0.001)
        case let .failure(error):
            XCTFail("DDM must accept a complete entry that has no seconds field: \(error)")
        }
    }

    @MainActor
    func testResolvedCoordinateDDM_rejectsIncompleteEntry() {
        let locationManager = LocationDataManager()
        let controller = CourseCoordinateEditorController()
        controller.coordinateEntryMode = .ddm
        controller.lat = DMSCoordinate(degrees: 60, minutes: 7, seconds: 24.42, hemisphere: "N")
        controller.lon = DMSCoordinate(degrees: 24, minutes: 55, seconds: 24.12, hemisphere: "E")
        // Latitude decimal-minutes missing -> incomplete.
        controller.latDDMEntryState = DDMFieldEntryState(degreesText: "60", minutesText: "")
        controller.lonDDMEntryState = DDMFieldEntryState(degreesText: "24", minutesText: "55.402")

        switch controller.resolvedCoordinate(locationManager: locationManager, persistChanges: false) {
        case .success:
            XCTFail("DDM must reject an incomplete entry (missing decimal minutes).")
        case let .failure(error):
            XCTAssertEqual(error, NSLocalizedString("course_edit_coordinate_incomplete_error", comment: ""))
        }
    }

    @MainActor
    func testCoordinateModeRoundTrip_dmsToDdmToDecimalPreservesCoordinate() {
        let locationManager = LocationDataManager()
        let controller = CourseCoordinateEditorController()
        let original = CoordinatePoint(lat: 60.123456, lon: 24.923370)
        controller.prefill(coordinate: original)

        // Switch DMS -> DDM -> decimal on the same value.
        controller.handleDMSAction()
        controller.handleDDMAction()
        controller.handleDecimalNumbersAction()

        switch controller.resolvedCoordinate(locationManager: locationManager, persistChanges: false) {
        case let .success(coordinate):
            XCTAssertEqual(coordinate.lat, original.lat, accuracy: 0.000001)
            XCTAssertEqual(coordinate.lon, original.lon, accuracy: 0.000001)
        case let .failure(error):
            XCTFail("Round-trip DMS->DDM->decimal must preserve the coordinate: \(error)")
        }
    }

    // MARK: - RaceService mock tests

    /// Returns a RaceService wired to the mock session and records the last request.
    private func makeService(responseData: Data, statusCode: Int = 200) -> (RaceService, MockURLSession) {
        let mock = MockURLSession(responseData: responseData, statusCode: statusCode)
        let service = RaceService(
            baseURL: URL(string: "https://test.naviari.test")!,
            apiKey: "test-key",
            session: mock.urlSession
        )
        return (service, mock)
    }

    private func sampleMarkJSON(id: String = "mark-abc") -> Data {
        """
        {
          "id": "\(id)",
          "sequence": 1,
          "name": "Test Mark",
          "status": "final"
        }
        """.data(using: .utf8)!
    }

    // MARK: updateCourseMark

    func testUpdateCourseMarkRequest_httpMethod() async throws {
        let (service, mock) = makeService(responseData: sampleMarkJSON())
        let payload = CourseMarkWritePayload(
            id: "mark-1",
            name: "Alpha",
            description: nil,
            roundingSide: "port",
            type: "mark",
            status: "final",
            mark: CoordinatePoint(lat: 60.1, lon: 24.9),
            updatedBy: "test"
        )
        _ = try await service.updateCourseMark(payload, accessToken: "tok")
        XCTAssertEqual(mock.capturedRequest?.httpMethod, "PUT")
    }

    func testUpdateCourseMarkRequest_path() async throws {
        let (service, mock) = makeService(responseData: sampleMarkJSON())
        let payload = CourseMarkWritePayload(
            id: "mark-1",
            name: "Alpha",
            description: nil,
            roundingSide: "port",
            type: "mark",
            status: "final",
            mark: CoordinatePoint(lat: 60.1, lon: 24.9),
            updatedBy: "test"
        )
        _ = try await service.updateCourseMark(payload, accessToken: "tok")
        let path = mock.capturedRequest?.url?.path ?? ""
        XCTAssertTrue(path.contains("/api/course-marks"), "Path should contain /api/course-marks, got: \(path)")
    }

    func testUpdateCourseMarkRequest_includesMarkId() async throws {
        let (service, mock) = makeService(responseData: sampleMarkJSON(id: "mark-xyz"))
        let markId = "mark-xyz"
        let payload = CourseMarkWritePayload(
            id: markId,
            name: "Beta",
            description: nil,
            roundingSide: "starboard",
            type: "mark",
            status: "preliminary",
            mark: CoordinatePoint(lat: 60.2, lon: 24.8),
            updatedBy: "test"
        )
        _ = try await service.updateCourseMark(payload, accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            XCTFail("No body data or JSON decoding failed")
            return
        }
        XCTAssertEqual(json["id"] as? String, markId)
    }

    func testUpdateCourseMarkRequest_encodesLatLon() async throws {
        let (service, mock) = makeService(responseData: sampleMarkJSON())
        let payload = CourseMarkWritePayload(
            id: "mark-1",
            name: "Alpha",
            description: nil,
            roundingSide: "port",
            type: "mark",
            status: "final",
            mark: CoordinatePoint(lat: 60.175139, lon: 24.945),
            updatedBy: "test"
        )
        _ = try await service.updateCourseMark(payload, accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let mark = json["mark"] as? [String: Any] else {
            XCTFail("Could not decode mark from body")
            return
        }
        XCTAssertEqual(mark["lat"] as? Double ?? 0, 60.175139, accuracy: 0.000001)
        XCTAssertEqual(mark["lon"] as? Double ?? 0, 24.945, accuracy: 0.000001)
    }

    func testUpdateCourseMarkRequest_omitsCourseId() async throws {
        let (service, mock) = makeService(responseData: sampleMarkJSON())
        let payload = CourseMarkWritePayload(
            id: "mark-1",
            name: "Alpha",
            description: nil,
            roundingSide: "port",
            type: "mark",
            status: "final",
            mark: CoordinatePoint(lat: 60.1, lon: 24.9),
            updatedBy: "test"
        )
        _ = try await service.updateCourseMark(payload, accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            XCTFail("No body data or JSON decoding failed")
            return
        }
        XCTAssertNil(json["courseId"], "Existing mark updates must not send courseId")
    }

    // MARK: insertCourseMark

    func testInsertCourseMarkRequest_httpMethod() async throws {
        let (service, mock) = makeService(responseData: sampleMarkJSON())
        let payload = CourseMarkInsertPayload(
            sequence: 2,
            name: "New Mark",
            description: nil,
            roundingSide: "port",
            type: "mark",
            status: "preliminary",
            mark: CoordinatePoint(lat: 60.1, lon: 24.9)
        )
        _ = try await service.insertCourseMark(courseId: "course-1", payload: payload, accessToken: "tok")
        XCTAssertEqual(mock.capturedRequest?.httpMethod, "POST")
    }

    func testInsertCourseMarkRequest_path() async throws {
        let courseId = "course-abc-123"
        let (service, mock) = makeService(responseData: sampleMarkJSON())
        let payload = CourseMarkInsertPayload(
            sequence: 3,
            name: "New Mark",
            description: nil,
            roundingSide: "port",
            type: "mark",
            status: "preliminary",
            mark: CoordinatePoint(lat: 60.1, lon: 24.9)
        )
        _ = try await service.insertCourseMark(courseId: courseId, payload: payload, accessToken: "tok")
        let path = mock.capturedRequest?.url?.path ?? ""
        XCTAssertTrue(path.contains("/api/courses/\(courseId)/course-marks"),
                      "Path should contain /api/courses/\(courseId)/course-marks, got: \(path)")
    }

    func testInsertCourseMarkRequest_encodesSequence() async throws {
        let (service, mock) = makeService(responseData: sampleMarkJSON())
        let expectedSequence = 5
        let payload = CourseMarkInsertPayload(
            sequence: expectedSequence,
            name: "New Mark",
            description: nil,
            roundingSide: "starboard",
            type: "mark",
            status: "preliminary",
            mark: CoordinatePoint(lat: 60.3, lon: 24.7)
        )
        _ = try await service.insertCourseMark(courseId: "course-1", payload: payload, accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            XCTFail("No body data")
            return
        }
        XCTAssertEqual(json["sequence"] as? Int, expectedSequence)
    }

    func testInsertCourseMarkRequest_encodesRacePointType() async throws {
        let (service, mock) = makeService(responseData: sampleMarkJSON())
        let payload = CourseMarkInsertPayload(
            sequence: 2,
            name: "New Mark",
            description: nil,
            roundingSide: "starboard",
            type: "race_point",
            status: "preliminary",
            mark: CoordinatePoint(lat: 60.3, lon: 24.7)
        )
        _ = try await service.insertCourseMark(courseId: "course-1", payload: payload, accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            XCTFail("No body data")
            return
        }
        XCTAssertEqual(json["type"] as? String, "race_point")
    }

    // MARK: deleteCourseMark

    func testDeleteCourseMarkRequest_httpMethod() async throws {
        let (service, mock) = makeService(responseData: Data(), statusCode: 204)
        try await service.deleteCourseMark(id: "mark-del", accessToken: "tok")
        XCTAssertEqual(mock.capturedRequest?.httpMethod, "DELETE")
    }

    func testDeleteCourseMarkRequest_path() async throws {
        let markId = "mark-del-456"
        let (service, mock) = makeService(responseData: Data(), statusCode: 204)
        try await service.deleteCourseMark(id: markId, accessToken: "tok")
        let path = mock.capturedRequest?.url?.path ?? ""
        XCTAssertTrue(path.hasSuffix("/api/course-marks/\(markId)"),
                      "Path should end with /api/course-marks/\(markId), got: \(path)")
    }

    // MARK: - S2: updateStartLine / updateFinishLine

    private func sampleLineJSON() -> Data {
        """
        { "ok": true }
        """.data(using: .utf8)!
    }

    private func sampleLinePayload(
        id: String = "line-1",
        leftLat: Double = 60.1,
        leftLon: Double = 24.9,
        rightLat: Double = 60.2,
        rightLon: Double = 24.8
    ) -> CourseLineWritePayload {
        CourseLineWritePayload(
            id: id,
            name: "Start Line",
            description: nil,
            status: "final",
            markLeft: CoordinatePoint(lat: leftLat, lon: leftLon),
            markRight: CoordinatePoint(lat: rightLat, lon: rightLon),
            updatedBy: "test"
        )
    }

    func testUpdateStartLineRequest_httpMethod() async throws {
        let (service, mock) = makeService(responseData: sampleLineJSON())
        try await service.updateStartLine(sampleLinePayload(), accessToken: "tok")
        XCTAssertEqual(mock.capturedRequest?.httpMethod, "PUT")
    }

    func testUpdateStartLineRequest_path() async throws {
        let (service, mock) = makeService(responseData: sampleLineJSON())
        try await service.updateStartLine(sampleLinePayload(), accessToken: "tok")
        let path = mock.capturedRequest?.url?.path ?? ""
        XCTAssertTrue(path.contains("/api/start-lines"), "Path should contain /api/start-lines, got: \(path)")
    }

    func testUpdateStartLineRequest_encodesLeftEndLatLon() async throws {
        let (service, mock) = makeService(responseData: sampleLineJSON())
        let payload = sampleLinePayload(leftLat: 60.123, leftLon: 24.567)
        try await service.updateStartLine(payload, accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let markLeft = json["markLeft"] as? [String: Any] else {
            XCTFail("Could not decode markLeft from body")
            return
        }
        XCTAssertEqual(markLeft["lat"] as? Double ?? 0, 60.123, accuracy: 0.0001)
        XCTAssertEqual(markLeft["lon"] as? Double ?? 0, 24.567, accuracy: 0.0001)
    }

    func testUpdateStartLineRequest_encodesRightEndLatLon() async throws {
        let (service, mock) = makeService(responseData: sampleLineJSON())
        let payload = sampleLinePayload(rightLat: 60.321, rightLon: 24.765)
        try await service.updateStartLine(payload, accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let markRight = json["markRight"] as? [String: Any] else {
            XCTFail("Could not decode markRight from body")
            return
        }
        XCTAssertEqual(markRight["lat"] as? Double ?? 0, 60.321, accuracy: 0.0001)
        XCTAssertEqual(markRight["lon"] as? Double ?? 0, 24.765, accuracy: 0.0001)
    }

    func testUpdateStartLineRequest_encodesId() async throws {
        let lineId = "start-line-uuid"
        let (service, mock) = makeService(responseData: sampleLineJSON())
        try await service.updateStartLine(sampleLinePayload(id: lineId), accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            XCTFail("No body data")
            return
        }
        XCTAssertEqual(json["id"] as? String, lineId)
    }

    func testUpdateStartLineRequest_omitsCourseId() async throws {
        let (service, mock) = makeService(responseData: sampleLineJSON())
        try await service.updateStartLine(sampleLinePayload(), accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            XCTFail("No body data")
            return
        }
        XCTAssertNil(json["courseId"], "Existing line updates must not send courseId")
    }

    func testUpdateFinishLineRequest_httpMethod() async throws {
        let (service, mock) = makeService(responseData: sampleLineJSON())
        try await service.updateFinishLine(sampleLinePayload(), accessToken: "tok")
        XCTAssertEqual(mock.capturedRequest?.httpMethod, "PUT")
    }

    func testUpdateFinishLineRequest_path() async throws {
        let (service, mock) = makeService(responseData: sampleLineJSON())
        try await service.updateFinishLine(sampleLinePayload(), accessToken: "tok")
        let path = mock.capturedRequest?.url?.path ?? ""
        XCTAssertTrue(path.contains("/api/finish-lines"), "Path should contain /api/finish-lines, got: \(path)")
    }

    func testUpdateFinishLineRequest_encodesLeftAndRightEnds() async throws {
        let (service, mock) = makeService(responseData: sampleLineJSON())
        let payload = sampleLinePayload(leftLat: 61.1, leftLon: 25.1, rightLat: 61.2, rightLon: 25.2)
        try await service.updateFinishLine(payload, accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let markLeft = json["markLeft"] as? [String: Any],
              let markRight = json["markRight"] as? [String: Any] else {
            XCTFail("Could not decode markLeft/markRight from body")
            return
        }
        XCTAssertEqual(markLeft["lat"] as? Double ?? 0, 61.1, accuracy: 0.0001)
        XCTAssertEqual(markRight["lat"] as? Double ?? 0, 61.2, accuracy: 0.0001)
    }

    func testUpdateFinishLineRequest_omitsCourseId() async throws {
        let (service, mock) = makeService(responseData: sampleLineJSON())
        try await service.updateFinishLine(sampleLinePayload(), accessToken: "tok")
        guard let bodyData = mock.capturedRequest?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            XCTFail("No body data")
            return
        }
        XCTAssertNil(json["courseId"], "Existing line updates must not send courseId")
    }
}

// MARK: - MockURLSession helper

/// Thread-safe mock URLSession that captures the last request.
final class MockURLSession {
    private(set) var capturedRequest: URLRequest?
    private let responseData: Data
    private let statusCode: Int

    init(responseData: Data, statusCode: Int = 200) {
        self.responseData = responseData
        self.statusCode = statusCode
    }

    var urlSession: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CourseEditMockURLProtocol.self]
        CourseEditMockURLProtocol.handler = { [weak self] request in
            self?.capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: self?.statusCode ?? 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (self?.responseData ?? Data(), response)
        }
        return URLSession(configuration: config)
    }
}

final class CourseEditMockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = CourseEditMockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        // Collect body stream into httpBody if needed.
        var req = request
        if req.httpBody == nil, let stream = request.httpBodyStream {
            var data = Data()
            stream.open()
            let bufferSize = 4096
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: bufferSize)
                if read > 0 { data.append(buffer, count: read) }
            }
            stream.close()
            req.httpBody = data
        }
        let (data, response) = handler(req)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
