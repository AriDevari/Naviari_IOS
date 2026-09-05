import Foundation
import XCTest
@testable import Naviari_IOS

final class ParticipationServiceTests: XCTestCase {
    override func tearDown() {
        ParticipationServiceMockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testExchangeManageCodeForToken_decodesServerDeclaredScopeAndRole() async throws {
        let inspectedRequest = expectation(description: "manage login request")
        ParticipationServiceMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/access/login")
            inspectedRequest.fulfill()
            return Self.response(for: request, payload: """
            {"token":"manage-token","entity":{"type":"race","id":"race-1"},"role":"manage"}
            """)
        }

        let result = try await makeService().exchangeManageCodeForLoginResult("ABCD-1234")

        await fulfillment(of: [inspectedRequest], timeout: 1.0)
        XCTAssertEqual(result.token, "manage-token")
        XCTAssertEqual(result.scope, .race)
        XCTAssertEqual(result.scopeId, "race-1")
        XCTAssertEqual(result.role, "manage")
    }

    func testExchangeManageCodeForToken_rejectsUnsupportedEntityType() async {
        ParticipationServiceMockURLProtocol.requestHandler = { request in
            Self.response(for: request, payload: """
            {"token":"manage-token","entity":{"type":"boat","id":"boat-1"},"role":"manage"}
            """)
        }

        await assertManageLoginIsRejected()
    }

    func testExchangeManageCodeForToken_rejectsEmptyOrWhitespaceToken() async {
        let payloads = [
            #"{"token":"","entity":{"type":"race","id":"race-1"},"role":"manage"}"#,
            #"{"token":" \t\n ","entity":{"type":"race","id":"race-1"},"role":"manage"}"#,
        ]
        var payloadIndex = 0
        ParticipationServiceMockURLProtocol.requestHandler = { request in
            defer { payloadIndex += 1 }
            return Self.response(for: request, payload: payloads[payloadIndex])
        }

        await assertManageLoginIsRejected()
        await assertManageLoginIsRejected()
    }

    func testExchangeManageCodeForToken_rejectsMissingEntityId() async {
        let payloads = [
            #"{"token":"manage-token","entity":{"type":"race","id":""},"role":"manage"}"#,
            #"{"token":"manage-token","entity":{"type":"race"},"role":"manage"}"#,
        ]
        var payloadIndex = 0
        ParticipationServiceMockURLProtocol.requestHandler = { request in
            defer { payloadIndex += 1 }
            return Self.response(for: request, payload: payloads[payloadIndex])
        }

        await assertManageLoginIsRejected()
        await assertManageLoginIsRejected()
    }

    func testExchangeManageCodeForToken_rejectsParticipateOrViewRole() async {
        let payloads = [
            #"{"token":"manage-token","entity":{"type":"series","id":"series-1"},"role":"participate"}"#,
            #"{"token":"manage-token","entity":{"type":"series","id":"series-1"},"role":"view"}"#,
        ]
        var payloadIndex = 0
        ParticipationServiceMockURLProtocol.requestHandler = { request in
            defer { payloadIndex += 1 }
            return Self.response(for: request, payload: payloads[payloadIndex])
        }

        await assertManageLoginIsRejected()
        await assertManageLoginIsRejected()
    }

    private func makeService() -> ParticipationService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ParticipationServiceMockURLProtocol.self]
        return ParticipationService(
            session: URLSession(configuration: configuration),
            baseURL: URL(string: "https://example.com")!,
            apiKey: "test-key"
        )
    }

    private func assertManageLoginIsRejected() async {
        do {
            _ = try await makeService().exchangeManageCodeForLoginResult("ABCD-1234")
            XCTFail("Expected invalid manage login to be rejected")
        } catch {
            // Expected: invalid management results must never be returned.
        }
    }

    private static func response(for request: URLRequest, payload: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, Data(payload.utf8))
    }
}

private final class ParticipationServiceMockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
