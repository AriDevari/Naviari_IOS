import Foundation
import SwiftUI

/// Deterministic, debug-only host for the S2 management-code continuation tests.
/// It is activated only by `-UITestManageAccessContinuation` and exercises the
/// production caller views with an in-process URLProtocol.
enum ManageAccessContinuationUITestScenario: String {
    case raceCourse = "race-course"
    case raceBuoy = "race-buoy"
    case startNoCourse = "start-no-course"
    case startExistingCourse = "start-existing-course"
    case setStartTime = "set-start-time"
    case setPosition = "set-position"
    case participate

    static var current: ManageAccessContinuationUITestScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-UITestManageAccessContinuation"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return ManageAccessContinuationUITestScenario(rawValue: arguments[index + 1])
    }

    static func value(for flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

struct ManageAccessContinuationUITestHarnessView: View {
    let scenario: ManageAccessContinuationUITestScenario

    @EnvironmentObject private var userNotifications: UserNotifications
    @StateObject private var browser = RaceBrowserViewModel()
    @State private var isPrepared = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if isPrepared {
                scenarioView
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            debugOverlay
        }
        .environmentObject(browser)
        .environmentObject(userNotifications)
        .task {
            guard !isPrepared else { return }
            if scenario == .raceCourse || scenario == .raceBuoy {
                await browser.selectRace(raceSummary)
            }
            isPrepared = true
        }
    }

    @ViewBuilder
    private var scenarioView: some View {
        switch scenario {
        case .raceCourse, .raceBuoy:
            NavigationStack {
                RaceDetailScreen(summary: raceSummary, onSelectStart: { _ in })
            }
        case .startNoCourse, .startExistingCourse:
            NavigationStack {
                StartDetailScreen(
                    raceSummary: raceSummary,
                    start: start,
                    onParticipate: {},
                    onSetStartTime: {},
                    onShowTimer: {},
                    onSetPositionTarget: { _ in }
                )
            }
        case .setStartTime:
            NavigationStack {
                SetStartTimeScreen(raceSummary: raceSummary, start: start)
            }
        case .setPosition:
            NavigationStack {
                SetPositionScreen(
                    raceSummary: raceSummary,
                    start: start,
                    target: .mark(
                        CourseMarkPositionTarget(
                            markId: "uitest-continuation-mark",
                            name: "UITest continuation mark",
                            description: nil,
                            roundingSide: "port",
                            type: "mark",
                            status: "preliminary"
                        )
                    )
                )
            }
        case .participate:
            NavigationStack {
                ParticipateView(raceSummary: raceSummary, start: start)
            }
        }
    }

    private var raceSummary: RaceSummary {
        RaceSummary(
            race: Race(
                rawId: Self.raceId,
                name: "UITest Management Race",
                description: nil,
                status: "scheduled",
                scheduledUTC: nil,
                actualUTC: nil,
                date: nil,
                slug: nil,
                parentSeriesId: Self.seriesId,
                starts: nil,
                imageId: nil
            ),
            seriesName: "UITest Management Series",
            seriesId: Self.seriesId,
            seriesImageId: nil,
            raceImageId: nil
        )
    }

    private var start: RaceStart {
        RaceStart(
            rawId: Self.startId,
            name: "UITest Management Start",
            status: "scheduled",
            scheduledUTC: "2030-01-01T10:00:00Z",
            actualUTC: nil,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )
    }

    @ViewBuilder
    private var debugOverlay: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(ManageAccessContinuationUITestURLProtocol.manageLoginRequestCount)")
                    .accessibilityIdentifier("race_detail_course_manage_login_count")
                Text("\(ManageAccessContinuationUITestURLProtocol.copyRequestCount)")
                    .accessibilityIdentifier("race_detail_course_copy_request_count")
                Text("\(ManageAccessContinuationUITestURLProtocol.manageLoginRequestCount)")
                    .accessibilityIdentifier("start_detail_manage_login_count")
                Text("\(ManageAccessContinuationUITestURLProtocol.startCopyRequestCount)")
                    .accessibilityIdentifier("start_detail_course_copy_request_count")
                Text("\(manageStorageCount)")
                    .accessibilityIdentifier("manage_access_storage_count")
                Text(manageContinuationState)
                    .accessibilityIdentifier("manage_access_continuation_state")
                Text(participationContinuationState)
                    .accessibilityIdentifier("participation_code_entry_result")
            }
            .font(AppFont.textStyle(.caption2, weight: .semibold))
            .padding(8)
            .background(Theme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.rowCard, style: .continuous))
            .padding(.leading, 12)
            .padding(.bottom, 12)
        }
    }

    private var manageStorageCount: Int {
        guard let data = UserDefaults.standard.data(forKey: "manage_access_tokens_v2"),
              let records = try? JSONDecoder().decode([String: ManageAccessTokenRecord].self, from: data) else {
            return 0
        }
        return records.count
    }

    private var manageContinuationState: String {
        let record = ManageAccessStorage.shared.loadToken(
            for: Self.startId,
            raceId: Self.raceId,
            seriesId: Self.seriesId
        )
        return record == nil ? "blocked" : "authorized"
    }

    private var participationContinuationState: String {
        let record = ParticipationStorage.shared.loadToken(
            for: Self.startId,
            raceId: Self.raceId,
            seriesId: Self.seriesId
        )
        return record?.token == ManageAccessContinuationUITestURLProtocol.participationToken
            ? "string-token-received"
            : "waiting"
    }

    static let startId = "uitest-start-detail-start"
    static let raceId = "uitest-race-detail"
    static let seriesId = "uitest-series-continuation"
}

final class ManageAccessContinuationUITestURLProtocol: URLProtocol {
    static let manageToken = "uitest-manage-token"
    static let participationToken = "uitest-participation-token"

    private static let lock = NSLock()
    private static var manageLoginRequestCountStorage = 0
    private static var copyRequestCountStorage = 0
    private static var startCopyRequestCountStorage = 0

    static var manageLoginRequestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return manageLoginRequestCountStorage
    }

    static var copyRequestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return copyRequestCountStorage
    }

    static var startCopyRequestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return startCopyRequestCountStorage
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        manageLoginRequestCountStorage = 0
        copyRequestCountStorage = 0
        startCopyRequestCountStorage = 0
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return false }
        return path == "/api/starts"
            || path == "/api/courses"
            || path == "/api/access/login"
            || path.hasPrefix("/api/starts/id/")
            || path == "/api/races/\(ManageAccessContinuationUITestHarnessView.raceId)/course-copy"
            || path == "/api/starts/\(ManageAccessContinuationUITestHarnessView.startId)/course-copy"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let path = url.path
        let body: Data
        let statusCode: Int
        switch path {
        case "/api/starts":
            body = startsJSON()
            statusCode = 200
        case "/api/courses":
            body = templatesJSON()
            statusCode = 200
        case "/api/access/login":
            body = loginJSON()
            statusCode = 200
        case "/api/races/\(ManageAccessContinuationUITestHarnessView.raceId)/course-copy":
            Self.incrementCopyRequest()
            body = raceCopyJSON()
            statusCode = 201
        case "/api/starts/\(ManageAccessContinuationUITestHarnessView.startId)/course-copy":
            Self.incrementStartCopyRequest()
            body = startCopyJSON()
            statusCode = 201
        default:
            if path.hasPrefix("/api/starts/id/") {
                body = startDetailJSON(for: String(path.dropFirst("/api/starts/id/".count)))
                statusCode = 200
            } else {
                body = Data("{}".utf8)
                statusCode = 404
            }
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func startsJSON() -> Data {
        Data("""
        {"starts":[
          {"id":"uitest-start-detail-start","name":"UITest Management Start","status":"scheduled","scheduled_utc":"2030-01-01T10:00:00Z","actual_utc":null,"description":null,"class_name":null,"slug":null,"image_id":null,"icon_key":null,"icon_color":null},
          {"id":"uitest-detail-start-a","name":"UITest Race Start A","status":"scheduled","scheduled_utc":"2030-01-01T10:15:00Z","actual_utc":null,"description":null,"class_name":null,"slug":null,"image_id":null,"icon_key":null,"icon_color":null}
        ]}
        """.utf8)
    }

    private func templatesJSON() -> Data {
        Data("""
        {"courses":[
          {"id":"uitest-start-detail-template-a","name":"UITest Template","description":null,"series_id":"uitest-series-continuation","total_length_m":1000,"total_length_nm":0.5,"is_template":true,"template_source_id":null,"start_line":null,"finish_line":null,"course_marks":[]},
          {"id":"uitest-detail-tpl-1","name":"UITest Race Template","description":null,"series_id":"uitest-series-continuation","total_length_m":1000,"total_length_nm":0.5,"is_template":true,"template_source_id":null,"start_line":null,"finish_line":null,"course_marks":[]}
        ]}
        """.utf8)
    }

    private func loginJSON() -> Data {
        let scenario = ManageAccessContinuationUITestScenario.current
        if scenario == .participate {
            return Data("{\"token\":\"\(Self.participationToken)\"}".utf8)
        }

        Self.lock.lock()
        Self.manageLoginRequestCountStorage += 1
        Self.lock.unlock()

        let scope = ManageAccessContinuationUITestScenario.value(for: "-UITestManageLoginScope") ?? "start"
        let defaultScopeId: String
        switch scope {
        case "race":
            defaultScopeId = ManageAccessContinuationUITestHarnessView.raceId
        case "series":
            defaultScopeId = ManageAccessContinuationUITestHarnessView.seriesId
        default:
            defaultScopeId = ManageAccessContinuationUITestHarnessView.startId
        }
        let scopeId = ManageAccessContinuationUITestScenario.value(for: "-UITestManageLoginScopeId") ?? defaultScopeId
        let role = ManageAccessContinuationUITestScenario.value(for: "-UITestManageLoginRole") ?? "manage"
        return Data("{\"token\":\"\(Self.manageToken)\",\"entity\":{\"type\":\"\(scope)\",\"id\":\"\(scopeId)\"},\"role\":\"\(role)\"}".utf8)
    }

    private func startDetailJSON(for startId: String) -> Data {
        let scenario = ManageAccessContinuationUITestScenario.current
        let course = scenario == .startExistingCourse ? existingCourseJSON() : "null"
        return Data("""
        {"ok":true,"start":{"id":"\(startId)","name":"UITest Management Start","status":"scheduled","scheduled_utc":"2030-01-01T10:00:00Z","actual_utc":null,"description":null,"class_name":null,"slug":null,"image_id":null,"icon_key":null,"icon_color":null},"course":\(course)}
        """.utf8)
    }

    private func raceCopyJSON() -> Data {
        Data("""
        {"ok":true,"raceId":"uitest-race-detail","course":\(existingCourseJSON()),"linkedStartCount":2,"totalStartCount":2}
        """.utf8)
    }

    private func startCopyJSON() -> Data {
        Data("""
        {"ok":true,"startId":"uitest-start-detail-start","course":\(existingCourseJSON())}
        """.utf8)
    }

    private func existingCourseJSON() -> String {
        """
        {"id":"uitest-existing-course","name":"UITest Existing Course","description":null,"series_id":"uitest-series-continuation","total_length_m":1000,"total_length_nm":0.5,"is_template":false,"template_source_id":null,"start_line":null,"finish_line":null,"course_marks":[{"id":"uitest-existing-mark","sequence":1,"name":"UITest Existing Mark","description":null,"rounding_side":"port","type":"mark","status":"preliminary","mark_lat":60.17,"mark_lon":24.94,"distance_to_next_m":null,"bearing_to_next_rad":null,"updated_at":null}]}
        """
    }

    private static func incrementCopyRequest() {
        lock.lock()
        defer { lock.unlock() }
        copyRequestCountStorage += 1
    }

    private static func incrementStartCopyRequest() {
        lock.lock()
        defer { lock.unlock() }
        startCopyRequestCountStorage += 1
    }
}
