import Foundation
import SwiftUI

enum StartDetailCourseManagementUITestScenario: String {
    case noCourseCachedStartToken
    case noCourseRaceTokenAfterCodeEntry
    case existingCourseCachedRaceToken
    case invalidScopeRaceToken

    static var current: StartDetailCourseManagementUITestScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-UITestStartDetailCourseManagementScenario"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return StartDetailCourseManagementUITestScenario(rawValue: arguments[index + 1])
    }
}

struct StartDetailCourseManagementUITestHarnessView: View {
    let scenario: StartDetailCourseManagementUITestScenario

    @EnvironmentObject private var userNotifications: UserNotifications
    @StateObject private var browser = RaceBrowserViewModel()
    @State private var isPrepared = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                if isPrepared {
                    StartDetailScreen(
                        raceSummary: harnessSummary,
                        start: harnessStart,
                        onParticipate: {},
                        onSetStartTime: {},
                        onShowTimer: {},
                        onSetPositionTarget: { _ in }
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
            isPrepared = true
        }
    }

    private var harnessSummary: RaceSummary {
        RaceSummary(
            race: Race(
                rawId: Self.raceId,
                name: "UITest Start Management Race",
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
            seriesName: "UITest Start Management Series",
            seriesId: Self.seriesId,
            seriesImageId: nil,
            raceImageId: nil
        )
    }

    private var harnessStart: RaceStart {
        RaceStart(
            rawId: Self.startId,
            name: "UITest Start Management Start",
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
                Text("\(StartDetailCourseManagementUITestURLProtocol.copyRequestCount)")
                    .accessibilityIdentifier("start_detail_course_copy_request_count")
                Text("\(StartDetailCourseManagementUITestURLProtocol.manageLoginRequestCount)")
                    .accessibilityIdentifier("start_detail_manage_login_count")
                Text("\(StartDetailCourseManagementUITestURLProtocol.refreshRequestCount)")
                    .accessibilityIdentifier("start_detail_course_refresh_request_count")
                Text("\(manageStorageCount)")
                    .accessibilityIdentifier("manage_access_storage_count")
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

    private func prepareHarness() {
        StartDetailCourseManagementUITestURLProtocol.reset(for: scenario)
        UserDefaults.standard.removeObject(forKey: "manage_access_tokens")
        UserDefaults.standard.removeObject(forKey: "manage_access_tokens_v2")
        UserDefaults.standard.removeObject(forKey: "manage_access_tokens_schema_version")
        UserDefaults.standard.removeObject(forKey: "participation_tokens")
        UserDefaults.standard.removeObject(forKey: "participation_records")

        switch scenario {
        case .noCourseCachedStartToken:
            ManageAccessStorage.shared.save(
                loginResult: ManageAccessLoginResult(
                    token: StartDetailCourseManagementUITestURLProtocol.validManageToken,
                    scope: .start,
                    scopeId: Self.startId,
                    role: "manage"
                )
            )
        case .existingCourseCachedRaceToken:
            ManageAccessStorage.shared.save(
                loginResult: ManageAccessLoginResult(
                    token: StartDetailCourseManagementUITestURLProtocol.validManageToken,
                    scope: .race,
                    scopeId: Self.raceId,
                    role: "manage"
                )
            )
        case .noCourseRaceTokenAfterCodeEntry, .invalidScopeRaceToken:
            break
        }
    }

    static let startId = "uitest-start-management-start"
    static let raceId = "uitest-start-management-race"
    static let seriesId = "uitest-start-management-series"
    static let invalidRaceId = "uitest-start-management-other-race"
}

final class StartDetailCourseManagementUITestURLProtocol: URLProtocol {
    static let validManageToken = "uitest-start-management-token"

    private static let lock = NSLock()
    private static var copyRequestCountStorage = 0
    private static var manageLoginRequestCountStorage = 0
    private static var startDetailRequestCountStorage = 0
    private static var currentCourseJSONStorage = "null"

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

    static var refreshRequestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return max(0, startDetailRequestCountStorage - 1)
    }

    static func reset(for scenario: StartDetailCourseManagementUITestScenario) {
        lock.lock()
        defer { lock.unlock() }
        copyRequestCountStorage = 0
        manageLoginRequestCountStorage = 0
        startDetailRequestCountStorage = 0
        switch scenario {
        case .existingCourseCachedRaceToken:
            currentCourseJSONStorage = assignedCourseJSON()
        case .noCourseCachedStartToken, .noCourseRaceTokenAfterCodeEntry, .invalidScopeRaceToken:
            currentCourseJSONStorage = "null"
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return false }
        return path == "/api/courses"
            || path == "/api/access/login"
            || path == "/api/starts/id/\(StartDetailCourseManagementUITestHarnessView.startId)"
            || path == "/api/starts/\(StartDetailCourseManagementUITestHarnessView.startId)/course-copy"
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
        let statusCode: Int
        let body: Data

        switch path {
        case "/api/courses":
            statusCode = 200
            body = Self.templatesJSON()
        case "/api/access/login":
            statusCode = 200
            body = Self.manageLoginJSON()
        case "/api/starts/id/\(StartDetailCourseManagementUITestHarnessView.startId)":
            statusCode = 200
            body = Self.startDetailJSON()
        case "/api/starts/\(StartDetailCourseManagementUITestHarnessView.startId)/course-copy":
            statusCode = 201
            body = Self.copyCourseJSON()
        default:
            statusCode = 404
            body = Data("{}".utf8)
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

    private static func startDetailJSON() -> Data {
        lock.lock()
        startDetailRequestCountStorage += 1
        let currentCourseJSON = currentCourseJSONStorage
        lock.unlock()

        let json = """
        {
          "ok": true,
          "start": {
            "id": "\(StartDetailCourseManagementUITestHarnessView.startId)",
            "name": "UITest Start Management Start",
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
          "course": \(currentCourseJSON)
        }
        """
        return Data(json.utf8)
    }

    private static func templatesJSON() -> Data {
        let json = """
        {
          "courses": [
            \(templateJSON(id: "uitest-start-management-template-alpha", name: "Template Alpha")),
            \(templateJSON(id: "uitest-start-management-template-replacement", name: "Template Replacement"))
          ]
        }
        """
        return Data(json.utf8)
    }

    private static func manageLoginJSON() -> Data {
        lock.lock()
        manageLoginRequestCountStorage += 1
        lock.unlock()

        let scopeId: String
        switch StartDetailCourseManagementUITestScenario.current {
        case .invalidScopeRaceToken:
            scopeId = StartDetailCourseManagementUITestHarnessView.invalidRaceId
        case .some(.noCourseRaceTokenAfterCodeEntry):
            scopeId = StartDetailCourseManagementUITestHarnessView.raceId
        default:
            scopeId = StartDetailCourseManagementUITestHarnessView.startId
        }

        return Data(
            "{\"token\":\"\(validManageToken)\",\"entity\":{\"type\":\"race\",\"id\":\"\(scopeId)\"},\"role\":\"manage\"}".utf8
        )
    }

    private static func copyCourseJSON() -> Data {
        lock.lock()
        copyRequestCountStorage += 1
        currentCourseJSONStorage = refreshedCourseJSON()
        lock.unlock()

        let json = """
        {
          "ok": true,
          "startId": "\(StartDetailCourseManagementUITestHarnessView.startId)",
          "course": \(copiedCourseJSON())
        }
        """
        return Data(json.utf8)
    }

    private static func templateJSON(id: String, name: String) -> String {
        """
        {
          "id": "\(id)",
          "name": "\(name)",
          "description": null,
          "series_id": "\(StartDetailCourseManagementUITestHarnessView.seriesId)",
          "total_length_m": 1852,
          "total_length_nm": 1.0,
          "is_template": true,
          "template_source_id": null,
          "start_line": null,
          "finish_line": null,
          "course_marks": []
        }
        """
    }

    private static func assignedCourseJSON() -> String {
        fullCourseJSON(
            id: "uitest-start-management-course-assigned",
            name: "Assigned Course",
            startLineName: "Assigned Start Line",
            markName: "Assigned Mark 1",
            finishLineName: "Assigned Finish Line"
        )
    }

    private static func copiedCourseJSON() -> String {
        fullCourseJSON(
            id: "uitest-start-management-course-copied",
            name: "Copied Course Pending Refresh",
            startLineName: "Copied Start Line",
            markName: "Copied Mark 1",
            finishLineName: "Copied Finish Line"
        )
    }

    private static func refreshedCourseJSON() -> String {
        fullCourseJSON(
            id: "uitest-start-management-course-replacement",
            name: "Replacement Course",
            startLineName: "Replacement Start Line",
            markName: "Replacement Mark 1",
            finishLineName: "Replacement Finish Line"
        )
    }

    private static func fullCourseJSON(
        id: String,
        name: String,
        startLineName: String,
        markName: String,
        finishLineName: String
    ) -> String {
        """
        {
          "id": "\(id)",
          "name": "\(name)",
          "description": null,
          "series_id": "\(StartDetailCourseManagementUITestHarnessView.seriesId)",
          "total_length_m": 3704,
          "total_length_nm": 2.0,
          "is_template": false,
          "template_source_id": "uitest-start-management-template-replacement",
          "start_line": {
            "id": "\(id)-start-line",
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
            "distance_to_first_mark_m": 300,
            "bearing_to_first_mark_rad": 1.57,
            "updated_at": null
          },
          "finish_line": {
            "id": "\(id)-finish-line",
            "name": "\(finishLineName)",
            "description": null,
            "status": "preliminary",
            "mark_left_lat": 60.20,
            "mark_left_lon": 24.98,
            "mark_right_lat": 60.19,
            "mark_right_lon": 24.99,
            "midpoint_lat": null,
            "midpoint_lon": null,
            "length_m": 110,
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
              "description": null,
              "rounding_side": "port",
              "type": "mark",
              "status": "preliminary",
              "mark_lat": 60.18,
              "mark_lon": 24.96,
              "distance_to_next_m": 850,
              "bearing_to_next_rad": 0.78,
              "updated_at": null
            }
          ]
        }
        """
    }
}