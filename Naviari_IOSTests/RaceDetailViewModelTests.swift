import XCTest
@testable import Naviari_IOS

/// Tests for `RaceDetailViewModel` covering aggregated course-state derivation,
/// shared race-level template copy, and the race-level token-scope predicate.
///
/// Network calls are stubbed with `MockURLProtocol`. The view model is built
/// with a `RaceService` whose URLSession is configured to route every request
/// through the mock so we can both stub responses and count call invocations
/// per endpoint.
@MainActor
final class RaceDetailViewModelTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
    }

    // MARK: - State derivation tests

    func testCourseState_allNil_isNoneSet() async {
        let starts = [makeStart(id: "start-1"), makeStart(id: "start-2")]
        configureStartDetailHandler(perStartCourses: [
            "start-1": nil,
            "start-2": nil,
        ])
        let viewModel = makeViewModel()

        await viewModel.loadCourseState(starts: starts)

        switch viewModel.courseState {
        case .noneSet:
            break
        default:
            XCTFail("Expected .noneSet, got \(viewModel.courseState)")
        }
    }

    func testCourseState_allSameId_isAllSameId() async {
        let starts = [makeStart(id: "start-1"), makeStart(id: "start-2"), makeStart(id: "start-3")]
        configureStartDetailHandler(perStartCourses: [
            "start-1": "course-shared",
            "start-2": "course-shared",
            "start-3": "course-shared",
        ])
        let viewModel = makeViewModel()

        await viewModel.loadCourseState(starts: starts)

        switch viewModel.courseState {
        case let .allSameId(course):
            XCTAssertEqual(course.id, "course-shared")
        default:
            XCTFail("Expected .allSameId, got \(viewModel.courseState)")
        }
    }

    func testCourseState_mixedNilAndSet_isMixedSet() async {
        let starts = [makeStart(id: "start-1"), makeStart(id: "start-2"), makeStart(id: "start-3")]
        configureStartDetailHandler(perStartCourses: [
            "start-1": "course-a",
            "start-2": nil,
            "start-3": "course-a",
        ])
        let viewModel = makeViewModel()

        await viewModel.loadCourseState(starts: starts)

        switch viewModel.courseState {
        case .mixedSet:
            break
        default:
            XCTFail("Expected .mixedSet, got \(viewModel.courseState)")
        }
    }

    func testCourseState_emptyStarts_isNoStarts() async {
        let viewModel = makeViewModel()

        await viewModel.loadCourseState(starts: [])

        switch viewModel.courseState {
        case .noStarts:
            break
        default:
            XCTFail("Expected .noStarts, got \(viewModel.courseState)")
        }
    }

    // MARK: - Shared race copy tests

    func testCopyTemplateToRace_callsRaceServiceOnce() async {
        let starts = [
            makeStart(id: "start-1"),
            makeStart(id: "start-2"),
            makeStart(id: "start-3"),
        ]
        let counter = CallCounter()

        configureCopyAndReloadHandler(
            copyCounter: counter,
            perStartCoursesAfter: ["start-1": "course-new", "start-2": "course-new", "start-3": "course-new"],
            raceCopyResult: .success(linkedStartCount: 3, totalStartCount: 3)
        )

        let viewModel = makeViewModel()

        await viewModel.copyTemplateToRace(
            templateId: "template-1",
            starts: starts,
            accessToken: "manage-token"
        )

        XCTAssertEqual(counter.copyCallCount, 1)
        XCTAssertEqual(viewModel.copySuccessCount, 3)
        XCTAssertEqual(viewModel.copyFailureCount, 0)
    }

    func testCopyTemplateToRace_onSuccess_reloadsCourseState() async {
        let starts = [makeStart(id: "start-1"), makeStart(id: "start-2")]
        let counter = CallCounter()

        configureCopyAndReloadHandler(
            copyCounter: counter,
            perStartCoursesAfter: ["start-1": "course-new", "start-2": "course-new"],
            raceCopyResult: .success(linkedStartCount: 2, totalStartCount: 2)
        )

        let viewModel = makeViewModel()

        await viewModel.copyTemplateToRace(
            templateId: "template-1",
            starts: starts,
            accessToken: "manage-token"
        )

        // State should transition to .allSameId after refresh.
        switch viewModel.courseState {
        case let .allSameId(course):
            XCTAssertEqual(course.id, "course-new")
        default:
            XCTFail("Expected .allSameId after reload, got \(viewModel.courseState)")
        }
        XCTAssertEqual(counter.startDetailCallCount, starts.count)
    }

    func testCopyTemplateToRace_usesReturnedCountsAndReloadsMixedState() async {
        let starts = [
            makeStart(id: "start-1"),
            makeStart(id: "start-2"),
            makeStart(id: "start-3"),
        ]
        let counter = CallCounter()

        configureCopyAndReloadHandler(
            copyCounter: counter,
            perStartCoursesAfter: ["start-1": "course-new", "start-2": nil, "start-3": "course-new"],
            raceCopyResult: .success(linkedStartCount: 2, totalStartCount: 3)
        )

        let viewModel = makeViewModel()

        await viewModel.copyTemplateToRace(
            templateId: "template-1",
            starts: starts,
            accessToken: "manage-token"
        )

        XCTAssertEqual(counter.copyCallCount, 1)
        XCTAssertEqual(viewModel.copySuccessCount, 2)
        XCTAssertEqual(viewModel.copyFailureCount, 1)
        switch viewModel.courseState {
        case .mixedSet:
            break
        default:
            XCTFail("Expected .mixedSet after partial failure, got \(viewModel.courseState)")
        }
    }

    func testCopyTemplateToRace_onRequestFailure_reportsAllFailures() async {
        let starts = [
            makeStart(id: "start-1"),
            makeStart(id: "start-2"),
            makeStart(id: "start-3"),
        ]
        let counter = CallCounter()

        configureCopyAndReloadHandler(
            copyCounter: counter,
            perStartCoursesAfter: ["start-1": nil, "start-2": nil, "start-3": nil],
            raceCopyResult: .failure
        )

        let viewModel = makeViewModel()

        await viewModel.copyTemplateToRace(
            templateId: "template-1",
            starts: starts,
            accessToken: "manage-token"
        )

        XCTAssertEqual(counter.copyCallCount, 1)
        XCTAssertEqual(viewModel.copySuccessCount, 0)
        XCTAssertEqual(viewModel.copyFailureCount, 3)
        switch viewModel.courseState {
        case .noneSet:
            break
        default:
            XCTFail("Expected .noneSet after failed copy reload, got \(viewModel.courseState)")
        }
    }

    // MARK: - Token-scope predicate tests

    func testStoredTokenIsValidAtRaceLevel_startScopeToken_returnsFalse() {
        let viewModel = makeViewModel(raceId: "race-1", seriesId: "series-1")
        // Force the predicate to see a .start scope record. Even though the
        // production `reloadToken()` path will not actually load one (because
        // it passes startId: nil), we test the predicate rejection branch
        // explicitly to defend against future refactors that might widen the
        // loadToken lookup.
        viewModel._seedStoredTokenForTesting(scope: .start, scopeId: "start-1", token: "start-tok")

        XCTAssertFalse(viewModel.storedTokenIsValidAtRaceLevel)
        XCTAssertFalse(viewModel.hasValidRaceLevelToken)
    }

    func testStoredTokenIsValidAtRaceLevel_raceScopeToken_returnsTrue() {
        let viewModel = makeViewModel(raceId: "race-1", seriesId: "series-1")
        viewModel._seedStoredTokenForTesting(scope: .race, scopeId: "race-1", token: "race-tok")

        XCTAssertTrue(viewModel.storedTokenIsValidAtRaceLevel)
        XCTAssertTrue(viewModel.hasValidRaceLevelToken)
    }

    func testStoredTokenIsValidAtRaceLevel_seriesScopeToken_returnsTrue() {
        let viewModel = makeViewModel(raceId: "race-1", seriesId: "series-1")
        viewModel._seedStoredTokenForTesting(scope: .series, scopeId: "series-1", token: "series-tok")

        XCTAssertTrue(viewModel.storedTokenIsValidAtRaceLevel)
        XCTAssertTrue(viewModel.hasValidRaceLevelToken)
    }

    // MARK: - Helpers

    /// Thread-safe counter used to observe per-endpoint call counts from
    /// inside the `MockURLProtocol.requestHandler` closure. URLSession may
    /// dispatch concurrent requests, so all access is locked.
    final class CallCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var _copyCallCount: Int = 0
        private var _startDetailCallCount: Int = 0

        var copyCallCount: Int {
            lock.lock(); defer { lock.unlock() }
            return _copyCallCount
        }

        var startDetailCallCount: Int {
            lock.lock(); defer { lock.unlock() }
            return _startDetailCallCount
        }

        func incrementCopy() {
            lock.lock(); defer { lock.unlock() }
            _copyCallCount += 1
        }

        func incrementStartDetail() {
            lock.lock(); defer { lock.unlock() }
            _startDetailCallCount += 1
        }
    }

    private func makeViewModel(raceId: String = "race-1", seriesId: String? = "series-1") -> RaceDetailViewModel {
        let service = makeService()
        // Isolate storage so test pollution between cases is impossible.
        let suiteName = "RaceDetailViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let storage = ManageAccessStorage(userDefaults: defaults)
        return RaceDetailViewModel(
            raceId: raceId,
            seriesId: seriesId,
            raceService: service,
            manageAccessStorage: storage
        )
    }

    private func makeService() -> RaceService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return RaceService(baseURL: URL(string: "https://example.com")!, apiKey: "test-key", session: session)
    }

    private func makeStart(id: String) -> RaceStart {
        let json = """
        {"id":"\(id)","name":"\(id) name","status":"scheduled"}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(RaceStart.self, from: json)
    }

    /// Stubs `GET /api/starts/id/{startId}` for each entry in `perStartCourses`.
    /// A nil course id results in `course: null` in the response payload.
    private func configureStartDetailHandler(perStartCourses: [String: String?]) {
        MockURLProtocol.requestHandler = { request in
            guard let path = request.url?.path else {
                throw NSError(domain: "RaceDetailViewModelTests", code: 1)
            }
            if let startId = Self.extractStartIdFromDetailPath(path) {
                let courseId = perStartCourses[startId] ?? nil
                let data = Self.startDetailPayload(startId: startId, courseId: courseId)
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, data)
            }
            throw NSError(domain: "RaceDetailViewModelTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected path: \(path)"])
        }
    }

    private enum RaceCopyResult {
        case success(linkedStartCount: Int, totalStartCount: Int)
        case failure
    }

    /// Stubs `POST /api/races/{id}/course-copy` and the follow-up
    /// `GET /api/starts/id/{id}` calls so a full shared-copy + reload cycle can
    /// be observed in one handler. Call counts per endpoint go to `copyCounter`.
    private func configureCopyAndReloadHandler(
        copyCounter: CallCounter,
        perStartCoursesAfter: [String: String?],
        raceCopyResult: RaceCopyResult
    ) {
        MockURLProtocol.requestHandler = { request in
            guard let path = request.url?.path else {
                throw NSError(domain: "RaceDetailViewModelTests", code: 1)
            }

            if path.hasSuffix("/course-copy"), request.httpMethod == "POST" {
                copyCounter.incrementCopy()
                if Self.extractRaceIdFromCopyPath(path) != "race-1" {
                    throw NSError(domain: "RaceDetailViewModelTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unexpected race copy path: \(path)"])
                }
                switch raceCopyResult {
                case let .success(linkedStartCount, totalStartCount):
                    let payload = """
                    {"ok":true,"raceId":"race-1","course":{"id":"course-new","name":"Windward","course_marks":[]},"linkedStartCount":\(linkedStartCount),"totalStartCount":\(totalStartCount)}
                    """.data(using: .utf8)!
                    let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
                    return (response, payload)
                case .failure:
                    let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                    return (response, Data(#"{"error":"forced failure"}"#.utf8))
                }
            }

            if let startId = Self.extractStartIdFromDetailPath(path) {
                copyCounter.incrementStartDetail()
                let courseId = perStartCoursesAfter[startId] ?? nil
                let data = Self.startDetailPayload(startId: startId, courseId: courseId)
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, data)
            }

            throw NSError(domain: "RaceDetailViewModelTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unexpected path: \(path)"])
        }
    }

    // MARK: - Payload builders

    private static func startDetailPayload(startId: String, courseId: String?) -> Data {
        let coursePart: String
        if let courseId {
            coursePart = "\"course\":{\"id\":\"\(courseId)\",\"name\":\"Course \(courseId)\",\"course_marks\":[]}"
        } else {
            coursePart = "\"course\":null"
        }
        let json = """
        {"ok":true,"start":{"id":"\(startId)","name":"\(startId) name","status":"scheduled"},\(coursePart)}
        """
        return json.data(using: .utf8)!
    }

    /// Returns the start id from `/api/starts/id/{startId}`.
    private static func extractStartIdFromDetailPath(_ path: String) -> String? {
        let prefix = "/api/starts/id/"
        guard path.hasPrefix(prefix) else { return nil }
        return String(path.dropFirst(prefix.count))
    }

    /// Returns the race id from `/api/races/{raceId}/course-copy`.
    private static func extractRaceIdFromCopyPath(_ path: String) -> String? {
        let prefix = "/api/races/"
        let suffix = "/course-copy"
        guard path.hasPrefix(prefix), path.hasSuffix(suffix) else { return nil }
        let startIndex = path.index(path.startIndex, offsetBy: prefix.count)
        let endIndex = path.index(path.endIndex, offsetBy: -suffix.count)
        return String(path[startIndex..<endIndex])
    }
}
