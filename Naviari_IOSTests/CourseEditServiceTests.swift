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
            courseId: "course-1",
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
