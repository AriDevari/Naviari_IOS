//
//  RaceDetailScreenUITestHarness.swift
//  Naviari_IOS
//
//  Debug-only host for `RaceDetailScreen` so XCUITest can launch the app
//  directly into a real `RaceDetailScreen` populated with deterministic
//  fixtures (S3 of the ios-race-level-course-selection feature).
//
//  Activated by passing `-UITestRaceDetailScreenState <letter>` at launch.
//  Letters map to: A | B | C (mirrors the race course state taxonomy used
//  throughout this feature).
//
//  This harness is never reachable in production — `ContentView` only routes
//  to it when `RaceDetailScreenUITestScenario.current` is non-nil, which
//  requires the launch argument above.
//
//  The harness installs a `URLProtocol` that intercepts the three endpoints
//  the race-detail flow depends on (`/api/starts`, `/api/starts/id/...`,
//  `/api/courses`) and returns scenario-specific fixtures, so the real
//  `RaceBrowserViewModel` and `RaceDetailViewModel` are exercised end-to-end
//  without a backend dependency.
//

import Foundation
import SwiftUI

/// Launch-argument-driven scenario selector for `RaceDetailScreen`.
///
/// XCUITest activates a scenario by adding two arguments to
/// `app.launchArguments`: `["-UITestRaceDetailScreenState", "<value>"]`.
/// Any other value is ignored.
enum RaceDetailScreenUITestScenario: Equatable {
    /// State A — both starts have `course == nil` so the section shows the
    /// template picker.
    case stateA
    /// State B — one start has a course, the other does not; section shows
    /// the mixed label.
    case stateB
    /// State C — both starts share the same course id; section shows the
    /// timeline and edit affordance.
    case stateC

    static var hasCachedRaceLevelToken: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return value(for: "-UITestRaceDetailHasRaceToken", in: arguments) == "1"
    }

    static var hasCachedStartLevelToken: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return value(for: "-UITestRaceDetailHasStartToken", in: arguments) == "1"
    }

    static var shouldReturnPartialCopyResult: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return value(for: "-UITestRaceDetailPartialCopy", in: arguments) == "1"
    }

    static var current: RaceDetailScreenUITestScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let raw = value(for: "-UITestRaceDetailScreenState", in: arguments) else {
            return nil
        }
        switch raw {
        case "A", "a", "stateA", "state_a":
            return .stateA
        case "B", "b", "stateB", "state_b":
            return .stateB
        case "C", "c", "stateC", "state_c":
            return .stateC
        default:
            return nil
        }
    }

    private static func value(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

/// SwiftUI host that drives a real `RaceDetailScreen` with deterministic
/// network responses via `RaceDetailScreenUITestURLProtocol`.
struct RaceDetailScreenUITestHarnessView: View {
    let scenario: RaceDetailScreenUITestScenario

    @EnvironmentObject private var userNotifications: UserNotifications
    @StateObject private var browser = RaceBrowserViewModel()
    @State private var isPrepared = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                if isPrepared {
                    RaceDetailScreen(
                        summary: harnessSummary,
                        onSelectStart: { _ in
                            // Tapping a start row is not exercised by these tests.
                        },
                        initialCourseTemplates: initialCourseTemplates
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                debugOverlay
            }
        }
        .environmentObject(browser)
        .environmentObject(userNotifications)
        .task {
            guard !isPrepared else { return }
            prepareHarness()
            await browser.selectRace(harnessSummary)
            isPrepared = true
        }
    }

    /// Fixture race summary used by every scenario. The `seriesId` is non-nil
    /// so template loading proceeds in State A.
    private var harnessSummary: RaceSummary {
        RaceSummary(
            race: Race(
                rawId: "uitest-race-detail",
                name: "UITest Race Detail",
                description: nil,
                status: "scheduled",
                scheduledUTC: nil,
                actualUTC: nil,
                date: nil,
                slug: nil,
                parentSeriesId: "uitest-series-detail",
                starts: nil,
                imageId: nil
            ),
            seriesName: "UITest Series",
            seriesId: "uitest-series-detail",
            seriesImageId: nil,
            raceImageId: nil
        )
    }

    @ViewBuilder
    private var debugOverlay: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(RaceDetailScreenUITestURLProtocol.copyRequestCount)")
                    .accessibilityIdentifier("race_detail_course_copy_request_count")
                Text("\(RaceDetailScreenUITestURLProtocol.manageLoginRequestCount)")
                    .accessibilityIdentifier("race_detail_course_manage_login_count")
            }
            .font(AppFont.textStyle(.caption2, weight: .semibold))
            .padding(8)
            .background(Theme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.rowCard, style: .continuous))
            .padding(.leading, 12)
            .padding(.bottom, 12)
        }
    }

    private func prepareHarness() {
        RaceDetailScreenUITestURLProtocol.reset(for: scenario)
        UserDefaults.standard.removeObject(forKey: "manage_access_tokens")
        UserDefaults.standard.removeObject(forKey: "participation_tokens")

        if RaceDetailScreenUITestScenario.hasCachedRaceLevelToken {
            ManageAccessStorage.shared.saveToken(
                token: RaceDetailScreenUITestURLProtocol.validManageToken,
                startId: nil,
                raceId: Self.raceId,
                seriesId: Self.seriesId
            )
        } else if RaceDetailScreenUITestScenario.hasCachedStartLevelToken {
            ManageAccessStorage.shared.saveToken(
                token: RaceDetailScreenUITestURLProtocol.validManageToken,
                startId: Self.startIdA,
                raceId: nil,
                seriesId: nil
            )
        }
    }

    static let raceId = "uitest-race-detail"
    static let seriesId = "uitest-series-detail"
    static let startIdA = RaceDetailScreenUITestURLProtocol.startIdA

    private var initialCourseTemplates: [RaceCourse] {
        switch scenario {
        case .stateC:
            return RaceDetailScreenUITestFixtures.templates
        case .stateA, .stateB:
            return []
        }
    }
}

enum RaceDetailScreenUITestFixtures {
    static let templates: [RaceCourse] = [
        decodeTemplate(id: "uitest-detail-tpl-1", name: "UITest Windward"),
        decodeTemplate(id: "uitest-detail-tpl-2", name: "UITest Triangle")
    ]

    private static func decodeTemplate(id: String, name: String) -> RaceCourse {
        let json = """
        {
          "id": "\(id)",
          "name": "\(name)",
          "description": null,
          "series_id": "uitest-series-detail",
          "total_length_m": 1852,
          "total_length_nm": 1.0,
          "is_template": true,
          "template_source_id": null,
          "start_line": null,
          "finish_line": null,
          "course_marks": []
        }
        """
        return try! JSONDecoder().decode(RaceCourse.self, from: Data(json.utf8))
    }
}

/// URLProtocol that returns deterministic JSON for the endpoints
/// `RaceDetailScreen` depends on. Installed only when the harness boots and
/// removed implicitly when the app terminates.
final class RaceDetailScreenUITestURLProtocol: URLProtocol {
    static let validManageToken = "uitest-race-detail-manage-token"

    private static let lock = NSLock()
    /// Scenario the harness is rendering; controls the JSON returned for
    /// `/api/starts/id/<id>` so the aggregated course state matches the
    /// requested visual branch.
    static var activeScenario: RaceDetailScreenUITestScenario = .stateA

    private static var copyRequestCountStorage = 0
    private static var manageLoginRequestCountStorage = 0
    private static var courseJSONByStartIdStorage: [String: String?] = [:]

    // Two stable fixture start ids — kept short so XCUITest output is readable.
    static let startIdA = "uitest-detail-start-a"
    static let startIdB = "uitest-detail-start-b"

    static var copyRequestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return copyRequestCountStorage
    }

    static var manageLoginRequestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return manageLoginRequestCountStorage
    }

    static func reset(for scenario: RaceDetailScreenUITestScenario = .stateA) {
        lock.lock()
        defer { lock.unlock() }

        activeScenario = scenario
        copyRequestCountStorage = 0
        manageLoginRequestCountStorage = 0
        courseJSONByStartIdStorage = initialCourseMap(for: scenario)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return false }
        if path == "/api/starts" { return true }
        if path == "/api/courses" { return true }
        if path == "/api/access/login" { return true }
        if path.hasPrefix("/api/starts/id/") { return true }
        if path == "/api/races/\(RaceDetailScreenUITestHarnessView.raceId)/course-copy" { return true }
        return false
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
        let responseBody: Data
        let statusCode: Int

        if path == "/api/starts" {
            responseBody = Self.startsListJSON()
            statusCode = 200
        } else if path == "/api/courses" {
            responseBody = Self.coursesJSON()
            statusCode = 200
        } else if path == "/api/access/login" {
            responseBody = Self.manageLoginJSON()
            statusCode = 200
        } else if path.hasPrefix("/api/starts/id/") {
            let id = String(path.dropFirst("/api/starts/id/".count))
            responseBody = Self.startDetailJSON(for: id)
            statusCode = 200
        } else if path == "/api/races/\(RaceDetailScreenUITestHarnessView.raceId)/course-copy" {
            responseBody = Self.copyCourseJSON()
            statusCode = 201
        } else {
            responseBody = Data("{}".utf8)
            statusCode = 200
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    // MARK: - Fixture builders

    private static func startsListJSON() -> Data {
        let json = """
        {
          "starts": [
            {
              "id": "\(startIdA)",
              "name": "Start A",
              "status": "scheduled",
              "scheduled_utc": "2030-01-01T10:00:00Z",
              "actual_utc": null,
              "description": null,
              "class_name": null,
              "slug": null,
              "image_id": null,
              "icon_key": null,
              "icon_color": null
            },
            {
              "id": "\(startIdB)",
              "name": "Start B",
              "status": "scheduled",
              "scheduled_utc": "2030-01-01T10:15:00Z",
              "actual_utc": null,
              "description": null,
              "class_name": null,
              "slug": null,
              "image_id": null,
              "icon_key": null,
              "icon_color": null
            }
          ]
        }
        """
        return Data(json.utf8)
    }

    private static func manageLoginJSON() -> Data {
        lock.lock()
        manageLoginRequestCountStorage += 1
        lock.unlock()
        return Data("{\"token\":\"\(validManageToken)\"}".utf8)
    }

    private static func coursesJSON() -> Data {
        let json = """
        {
          "courses": [
            \(courseJSON(id: "uitest-detail-tpl-1", name: "UITest Windward")),
            \(courseJSON(id: "uitest-detail-tpl-2", name: "UITest Triangle"))
          ]
        }
        """
        return Data(json.utf8)
    }

    private static func startDetailJSON(for startId: String) -> Data {
        lock.lock()
        let course = courseJSONByStartIdStorage[startId] ?? nil
        lock.unlock()
        return startEnvelope(startId: startId, course: course)
    }

    private static func copyCourseJSON() -> Data {
        lock.lock()
        copyRequestCountStorage += 1
        if RaceDetailScreenUITestScenario.shouldReturnPartialCopyResult {
            courseJSONByStartIdStorage[startIdA] = replacementSharedCourseJSON()
            courseJSONByStartIdStorage[startIdB] = nil
        } else {
            courseJSONByStartIdStorage[startIdA] = replacementSharedCourseJSON()
            courseJSONByStartIdStorage[startIdB] = replacementSharedCourseJSON()
        }
        lock.unlock()

        let linkedStartCount = RaceDetailScreenUITestScenario.shouldReturnPartialCopyResult ? 1 : 2
        let json = """
        {
          "ok": true,
          "raceId": "\(RaceDetailScreenUITestHarnessView.raceId)",
          "course": \(replacementSharedCourseJSON()),
          "linkedStartCount": \(linkedStartCount),
          "totalStartCount": 2
        }
        """
        return Data(json.utf8)
    }

    private static func initialCourseMap(for scenario: RaceDetailScreenUITestScenario) -> [String: String?] {
        switch scenario {
        case .stateA:
            return [
                startIdA: nil,
                startIdB: nil,
            ]
        case .stateB:
            return [
                startIdA: mixedCourseJSON(),
                startIdB: nil,
            ]
        case .stateC:
            return [
                startIdA: sharedCourseJSON(),
                startIdB: sharedCourseJSON(),
            ]
        }
    }

    private static func mixedCourseJSON() -> String {
        courseJSON(id: "uitest-detail-course-mixed-a", name: "UITest Mixed A")
    }

    private static func sharedCourseJSON() -> String {
        compactSharedCourseJSON(id: "uitest-detail-shared-course", name: "UITest Shared Course")
    }

    private static func replacementSharedCourseJSON() -> String {
        compactSharedCourseJSON(
            id: "uitest-detail-shared-course-replacement",
            name: "UITest Shared Replacement",
            markName: "Replacement Mark 1",
            markDescription: "Replacement Windward"
        )
    }

    private static func startEnvelope(startId: String, course: String?) -> Data {
        let courseField = course ?? "null"
        let json = """
        {
          "ok": true,
          "start": {
            "id": "\(startId)",
            "name": "Start \(startId)",
            "status": "scheduled",
            "scheduled_utc": "2030-01-01T10:00:00Z",
            "actual_utc": null,
            "description": null,
            "class_name": null,
            "slug": null,
            "image_id": null,
            "icon_key": null,
            "icon_color": null
          },
          "course": \(courseField)
        }
        """
        return Data(json.utf8)
    }

    private static func courseJSON(
        id: String,
        name: String,
        startLineName: String = "Start Line",
        finishLineName: String = "Finish Line",
        markName: String = "Mark 1",
        markDescription: String = "Windward"
    ) -> String {
                """
                {
                    "id": "\(id)",
                    "name": "\(name)",
                    "description": null,
                    "series_id": "uitest-series-detail",
                    "total_length_m": 1852,
                    "total_length_nm": 1.0,
                    "is_template": false,
                    "template_source_id": null,
                    "start_line": {
                        "id": "\(id)-line-start",
                        "name": "\(startLineName)",
                        "description": null,
                        "status": "preliminary",
                        "mark_left_lat": 60.17,
                        "mark_left_lon": 24.94,
                        "mark_right_lat": 60.16,
                        "mark_right_lon": 24.95,
                        "midpoint_lat": null,
                        "midpoint_lon": null,
                        "length_m": 120,
                        "bearing_deg": 270,
                        "distance_to_first_mark_m": null,
                        "bearing_to_first_mark_rad": null,
                        "updated_at": null
                    },
                    "finish_line": {
                        "id": "\(id)-line-finish",
                        "name": "\(finishLineName)",
                        "description": null,
                        "status": "final",
                        "mark_left_lat": 60.18,
                        "mark_left_lon": 24.98,
                        "mark_right_lat": 60.19,
                        "mark_right_lon": 24.99,
                        "midpoint_lat": null,
                        "midpoint_lon": null,
                        "length_m": 100,
                        "bearing_deg": 90,
                        "distance_to_first_mark_m": null,
                        "bearing_to_first_mark_rad": null,
                        "updated_at": null
                    },
                    "course_marks": [
                        {
                            "id": "\(id)-mark-1",
                            "sequence": 1,
                            "name": "\(markName)",
                            "description": "\(markDescription)",
                            "rounding_side": "port",
                            "type": "mark",
                            "status": "preliminary",
                            "mark_lat": 60.175,
                            "mark_lon": 24.97,
                            "distance_to_next_m": 1852,
                            "bearing_to_next_rad": 1.2,
                            "updated_at": null
                        }
                    ]
                }
                """
        }

        private static func compactSharedCourseJSON(
                id: String,
                name: String,
                markName: String = "Mark 1",
                markDescription: String = "Windward"
        ) -> String {
                """
                {
                    "id": "\(id)",
                    "name": "\(name)",
                    "description": null,
                    "series_id": "uitest-series-detail",
                    "total_length_m": 1852,
                    "total_length_nm": 1.0,
                    "is_template": false,
                    "template_source_id": null,
                    "start_line": {
                        "id": "\(id)-line-start",
                        "name": "Start Line",
                        "description": null,
                        "status": "preliminary",
                        "mark_left_lat": 60.17,
                        "mark_left_lon": 24.94,
                        "mark_right_lat": 60.16,
                        "mark_right_lon": 24.95,
                        "midpoint_lat": null,
                        "midpoint_lon": null,
                        "length_m": 120,
                        "bearing_deg": 270,
                        "distance_to_first_mark_m": null,
                        "bearing_to_first_mark_rad": null,
                        "updated_at": null
                    },
                    "finish_line": null,
                    "course_marks": [
                        {
                            "id": "\(id)-mark-1",
                            "sequence": 1,
                            "name": "\(markName)",
                            "description": "\(markDescription)",
                            "rounding_side": "port",
                            "type": "mark",
                            "status": "preliminary",
                            "mark_lat": 60.175,
                            "mark_lon": 24.97,
                            "distance_to_next_m": null,
                            "bearing_to_next_rad": null,
                            "updated_at": null
                        }
                    ]
                }
                """
    }
}
