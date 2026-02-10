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
            {"series":[{"id":"series-1","name":"Spring Series","races":[{"id":"race-1","name":"Opener","status":"planned"}]}]}
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
            {"starts":[{"id":"start-1","name":"Morning Fleet","status":"open"}]}
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
            starts: nil
        )
        let starts = try await service.fetchStarts(for: race)
        wait(for: [inspectedURL], timeout: 1.0)
        XCTAssertEqual(starts.first?.name, "Morning Fleet")
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
