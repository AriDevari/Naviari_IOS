import Foundation
import SwiftUI

enum CourseEditUITestScenario {
    case markEdit(mode: String)
    case lineEdit(mode: String)
    case codeEntry(screen: String)
    case protectionHost

    static var current: CourseEditUITestScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        if let mode = value(for: "-UITestCourseMarkEdit", in: arguments) {
            return .markEdit(mode: mode)
        }
        if let mode = value(for: "-UITestCourseLineEdit", in: arguments) {
            return .lineEdit(mode: mode)
        }
        if let screen = value(for: "-UITestCodeEntryScreen", in: arguments) {
            return .codeEntry(screen: screen)
        }
        if arguments.contains("-UITestCourseEditProtectionHost") {
            return .protectionHost
        }
        return nil
    }

    private static func value(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

enum StartDetailCourseReplacementUITestScenario: Equatable {
    case assignedCourse

    static var current: StartDetailCourseReplacementUITestScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard value(for: "-UITestStartDetailCourseReplacementScenario", in: arguments) != nil else {
            return nil
        }
        return .assignedCourse
    }

    static var hasCachedManageToken: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return value(for: "-UITestStartDetailCourseReplacementHasToken", in: arguments) == "1"
    }

    static var shouldFailCopyRequest: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return value(for: "-UITestStartDetailCourseReplacementCopyFails", in: arguments) == "1"
    }

    private static func value(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

struct CourseEditUITestHarnessView: View {
    let scenario: CourseEditUITestScenario

    @EnvironmentObject private var locationManager: LocationDataManager

    var body: some View {
        Group {
            switch scenario {
            case let .markEdit(mode):
                markEditView(mode: mode)
            case let .lineEdit(mode):
                lineEditView(mode: mode)
            case let .codeEntry(screen):
                CodeEntryUITestHarnessView(screen: screen)
            case .protectionHost:
                CourseEditProtectionHarnessView()
            }
        }
        .task {
            configureInjectedLocationIfNeeded()
            configureCodeEntryUITestIfNeeded()
        }
    }

    @ViewBuilder
    private func markEditView(mode: String) -> some View {
        switch mode.lowercased() {
        case "addmark":
            NavigationStack {
                CourseMarkEditView(
                    mode: .addMark(courseId: "course-1", afterSequence: 2),
                    accessToken: "test-token"
                )
            }
        default:
            NavigationStack {
                CourseMarkEditView(
                    mode: .editMark(testMarkItem(), courseId: "course-1"),
                    accessToken: "test-token"
                )
            }
        }
    }

    @ViewBuilder
    private func lineEditView(mode: String) -> some View {
        switch mode.lowercased() {
        case "finishline":
            NavigationStack {
                CourseLineEditView(
                    mode: .editFinishLine(testLine(name: launchValue("-UITestLineName") ?? NSLocalizedString("course_item_edit_finish_line_title", comment: "")), courseId: "course-1"),
                    accessToken: "test-token",
                    buoyOptions: []
                )
            }
        default:
            NavigationStack {
                CourseLineEditView(
                    mode: .editStartLine(testLine(name: launchValue("-UITestLineName") ?? NSLocalizedString("course_item_edit_start_line_title", comment: "")), courseId: "course-1"),
                    accessToken: "test-token",
                    buoyOptions: []
                )
            }
        }
    }

    private func configureInjectedLocationIfNeeded() {
        guard let latString = launchValue("-UITestLocationLat"),
              let lonString = launchValue("-UITestLocationLon"),
              let latitude = Double(latString),
              let longitude = Double(lonString) else {
            return
        }
        locationManager.injectTestLocation(latitude: latitude, longitude: longitude)
    }

    private func configureCodeEntryUITestIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-UITestCodeEntryScreen") else {
            CodeEntryUITestURLProtocol.isEnabled = false
            return
        }

        UserDefaults.standard.removeObject(forKey: "manage_access_tokens")
        UserDefaults.standard.removeObject(forKey: "participation_tokens")
        UserDefaults.standard.removeObject(forKey: "participation_records")

        CodeEntryUITestURLProtocol.isEnabled = arguments.contains("-UITestCodeEntryRejectInvalid")
        URLProtocol.registerClass(CodeEntryUITestURLProtocol.self)
    }

    private func launchValue(_ flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private func testMarkItem() -> CourseMarkItem {
        CourseMarkItem(
            id: "mark-1",
            sequence: 1,
            name: launchValue("-UITestMarkName") ?? NSLocalizedString("course_edit_name_placeholder", comment: ""),
            description: NSLocalizedString("course_edit_description_placeholder", comment: ""),
            rounding_side: launchValue("-UITestMarkRounding") ?? "port",
            type: "mark",
            status: launchValue("-UITestMarkStatus") ?? "preliminary",
            mark_lat: Double(launchValue("-UITestMarkLat") ?? "60.12"),
            mark_lon: Double(launchValue("-UITestMarkLon") ?? "24.95"),
            distance_to_next_m: nil,
            bearing_to_next_rad: nil,
            updated_at: nil
        )
    }

    private func testLine(name: String) -> CourseLine {
        CourseLine(
            id: "line-1",
            name: name,
            description: NSLocalizedString("course_edit_description_placeholder", comment: ""),
            status: launchValue("-UITestLineStatus") ?? "preliminary",
            mark_left_lat: Double(launchValue("-UITestLineLeftLat") ?? "60.12"),
            mark_left_lon: Double(launchValue("-UITestLineLeftLon") ?? "24.95"),
            mark_right_lat: Double(launchValue("-UITestLineRightLat") ?? "60.13"),
            mark_right_lon: Double(launchValue("-UITestLineRightLon") ?? "24.96"),
            midpoint_lat: nil,
            midpoint_lon: nil,
            length_m: nil,
            bearing_deg: nil,
            distance_to_first_mark_m: nil,
            bearing_to_first_mark_rad: nil,
            updated_at: nil
        )
    }
}

struct StartDetailCourseReplacementUITestHarnessView: View {
    let scenario: StartDetailCourseReplacementUITestScenario

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
                name: "UITest Start Detail Race",
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
            seriesName: "UITest Start Detail Series",
            seriesId: Self.seriesId,
            seriesImageId: nil,
            raceImageId: nil
        )
    }

    private var harnessStart: RaceStart {
        RaceStart(
            rawId: Self.startId,
            name: "UITest Start Detail Start",
            status: "scheduled",
            scheduledUTC: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
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
                Text("\(StartDetailCourseReplacementUITestURLProtocol.copyRequestCount)")
                    .accessibilityIdentifier("start_detail_course_copy_request_count")
                Text("\(StartDetailCourseReplacementUITestURLProtocol.manageLoginRequestCount)")
                    .accessibilityIdentifier("start_detail_course_manage_login_count")
                Text("\(browser.courseRefreshToken(for: Self.startId))")
                    .accessibilityIdentifier("start_detail_course_refresh_request_count")
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
        UserDefaults.standard.removeObject(forKey: "manage_access_tokens")
        UserDefaults.standard.removeObject(forKey: "participation_tokens")
        UserDefaults.standard.removeObject(forKey: "participation_records")

        if StartDetailCourseReplacementUITestScenario.hasCachedManageToken {
            ManageAccessStorage.shared.saveToken(
                token: StartDetailCourseReplacementUITestURLProtocol.validManageToken,
                startId: Self.startId,
                raceId: Self.raceId,
                seriesId: Self.seriesId
            )
        }
    }

    static let startId = "uitest-start-detail-start"
    static let raceId = "uitest-start-detail-race"
    static let seriesId = "uitest-start-detail-series"
}

private enum CodeEntryUITestScreen: String {
    case startDetail
    case startDetailSetStartTime
    case startDetailParticipate
    case setPosition
    case setStartTime
    case participate
}

private enum CodeEntryUITestRoute: Hashable {
    case setPosition
    case setStartTime
    case participate
}

private struct CodeEntryUITestHarnessView: View {
    let screen: String

    var body: some View {
        switch CodeEntryUITestScreen(rawValue: screen) {
        case .startDetail:
            CourseEditProtectionHarnessView()
        case .startDetailSetStartTime:
            StartDetailCodeEntryHarnessView()
        case .startDetailParticipate:
            StartDetailCodeEntryHarnessView()
        case .setPosition:
            CodeEntryNavigationHarnessView(route: .setPosition)
        case .setStartTime:
            CodeEntryNavigationHarnessView(route: .setStartTime)
        case .participate:
            CodeEntryNavigationHarnessView(route: .participate)
        case .none:
            EmptyView()
        }
    }
}

private struct StartDetailCodeEntryHarnessView: View {
    @State private var navigationResult: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                StartDetailScreen(
                    raceSummary: raceSummary,
                    start: start,
                    onParticipate: {
                        navigationResult = "participate"
                    },
                    onSetStartTime: {
                        navigationResult = "set-start-time"
                    },
                    onShowTimer: {
                        navigationResult = "show-timer"
                    },
                    onSetPositionTarget: { _ in
                        navigationResult = "set-position"
                    }
                )

                if let navigationResult {
                    Text(navigationResult)
                        .accessibilityIdentifier("start_detail_navigation_result")
                }
            }
        }
    }

    private var raceSummary: RaceSummary {
        RaceSummary(
            race: Race(
                rawId: "uitest-race-start-detail",
                name: "UITest Race Start Detail",
                description: nil,
                status: "scheduled",
                scheduledUTC: nil,
                actualUTC: nil,
                date: nil,
                slug: nil,
                parentSeriesId: "uitest-series-start-detail",
                starts: nil,
                imageId: nil
            ),
            seriesName: "UITest Series",
            seriesId: "uitest-series-start-detail",
            seriesImageId: nil,
            raceImageId: nil
        )
    }

    private var start: RaceStart {
        RaceStart(
            rawId: "uitest-start-start-detail",
            name: "UITest Start Detail",
            status: "scheduled",
            scheduledUTC: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            actualUTC: nil,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )
    }
}

final class StartDetailCourseReplacementUITestURLProtocol: URLProtocol {
    static let validManageToken = "uitest-manage-token"

    private static let lock = NSLock()
    private static var copyRequestCountStorage = 0
    private static var manageLoginRequestCountStorage = 0
    private static var currentCourseJSONStorage = initialCourseJSON()

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

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        copyRequestCountStorage = 0
        manageLoginRequestCountStorage = 0
        currentCourseJSONStorage = initialCourseJSON()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return false }
        if path == "/api/courses" { return true }
        if path == "/api/access/login" { return true }
        if path == "/api/starts/id/\(StartDetailCourseReplacementUITestHarnessView.startId)" { return true }
        if path == "/api/starts/\(StartDetailCourseReplacementUITestHarnessView.startId)/course-copy" { return true }
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
        let statusCode: Int
        let body: Data

        switch path {
        case "/api/courses":
            statusCode = 200
            body = Self.templatesJSON()
        case "/api/access/login":
            statusCode = 200
            body = Self.manageLoginJSON()
        case "/api/starts/id/\(StartDetailCourseReplacementUITestHarnessView.startId)":
            statusCode = 200
            body = Self.startDetailJSON()
        case "/api/starts/\(StartDetailCourseReplacementUITestHarnessView.startId)/course-copy":
            if StartDetailCourseReplacementUITestScenario.shouldFailCopyRequest {
                Self.recordCopyAttempt()
                statusCode = 500
                body = Data("{\"error\":\"UITest synthetic copy failure\"}".utf8)
            } else {
                statusCode = 201
                body = Self.copyCourseJSON()
            }
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
        let currentCourseJSON = currentCourseJSONStorage
        lock.unlock()

        let json = """
        {
          "ok": true,
          "start": {
            "id": "\(StartDetailCourseReplacementUITestHarnessView.startId)",
            "name": "UITest Start Detail Start",
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
            \(templateJSON(id: "uitest-start-detail-template-a", name: "Replacement Alpha")),
            \(templateJSON(id: "uitest-start-detail-template-replacement", name: "Replacement Bravo"))
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

    private static func copyCourseJSON() -> Data {
        recordCopyAttempt()
        lock.lock()
        currentCourseJSONStorage = replacementCourseJSON()
        let currentCourseJSON = currentCourseJSONStorage
        lock.unlock()

        let json = """
        {
          "ok": true,
          "startId": "\(StartDetailCourseReplacementUITestHarnessView.startId)",
          "course": \(currentCourseJSON)
        }
        """
        return Data(json.utf8)
    }

    private static func recordCopyAttempt() {
        lock.lock()
        copyRequestCountStorage += 1
        lock.unlock()
    }

    private static func templateJSON(id: String, name: String) -> String {
        """
        {
          "id": "\(id)",
          "name": "\(name)",
          "description": null,
          "series_id": "\(StartDetailCourseReplacementUITestHarnessView.seriesId)",
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

    private static func initialCourseJSON() -> String {
        fullCourseJSON(
            id: "uitest-start-detail-course-assigned",
            name: "Assigned Course",
            startLineName: "Assigned Start Line",
            markName: "Assigned Mark 1",
            finishLineName: "Assigned Finish Line"
        )
    }

    private static func replacementCourseJSON() -> String {
        fullCourseJSON(
            id: "uitest-start-detail-course-replacement",
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
          "series_id": "\(StartDetailCourseReplacementUITestHarnessView.seriesId)",
          "total_length_m": 3704,
          "total_length_nm": 2.0,
          "is_template": false,
          "template_source_id": "uitest-start-detail-template-replacement",
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

private struct CodeEntryNavigationHarnessView: View {
    let route: CodeEntryUITestRoute
    @State private var path: [CodeEntryUITestRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationDestination(for: CodeEntryUITestRoute.self) { destination in
                    switch destination {
                    case .setPosition:
                        SetPositionScreen(
                            raceSummary: codeEntryRaceSummary(screen: "set-position"),
                            start: codeEntryStart(screen: "set-position"),
                            target: .mark(
                                CourseMarkPositionTarget(
                                    markId: "test-mark-1",
                                    name: "Test Mark",
                                    description: nil,
                                    roundingSide: "port",
                                    type: "mark",
                                    status: "preliminary"
                                )
                            )
                        )
                    case .setStartTime:
                        SetStartTimeScreen(
                            raceSummary: codeEntryRaceSummary(screen: "set-start-time"),
                            start: codeEntryStart(screen: "set-start-time")
                        )
                    case .participate:
                        ParticipateView(
                            raceSummary: codeEntryRaceSummary(screen: "participate"),
                            start: codeEntryStart(screen: "participate")
                        )
                    }
                }
                .task {
                    guard path.isEmpty else { return }
                    path.append(route)
                }
        }
    }

    private func codeEntryRaceSummary(screen: String) -> RaceSummary {
        RaceSummary(
            race: Race(
                rawId: "uitest-race-\(screen)",
                name: "UITest Race \(screen)",
                description: nil,
                status: "scheduled",
                scheduledUTC: nil,
                actualUTC: nil,
                date: nil,
                slug: nil,
                parentSeriesId: "uitest-series-\(screen)",
                starts: nil,
                imageId: nil
            ),
            seriesName: "UITest Series",
            seriesId: "uitest-series-\(screen)",
            seriesImageId: nil,
            raceImageId: nil
        )
    }

    private func codeEntryStart(screen: String) -> RaceStart {
        RaceStart(
            rawId: "uitest-start-\(screen)",
            name: "UITest Start \(screen)",
            status: "scheduled",
            scheduledUTC: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            actualUTC: nil,
            description: nil,
            className: nil,
            slug: nil,
            imageId: nil,
            iconKey: nil,
            iconColor: nil
        )
    }
}

private struct CourseEditProtectionHarnessView: View {
    @State private var showCodeModal = false
    @State private var codePrefix = ""
    @State private var codeSuffix = ""
    @State private var isValidatingCode = false
    @State private var codeValidationError: String?
    @State private var codeValidationAttempts = 0

    private let maxCodeValidationAttempts = 5
    private let inputContentFont = AppFont.fixed(21)
    private let accessService = ParticipationService()

    var body: some View {
        ScreenContainer(showBack: false, title: Text("course_item_edit_mark_title")) {
            VStack(alignment: .leading, spacing: 16) {
                Button("course_test_open_edit_button") {
                    showCodeModal = true
                }
                .accessibilityIdentifier("course_test_open_edit_button")
                .font(AppUI.buttonFont)

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showCodeModal) {
            codeValidationSheet
            .interactiveDismissDisabled(true)
        }
    }

    private var manageCode: String? {
        let trimmedPrefix = codePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSuffix = codeSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrefix.isEmpty, !trimmedSuffix.isEmpty else {
            return nil
        }
        return "\(trimmedPrefix)-\(trimmedSuffix)"
    }

    private var codeAttemptsRemaining: Int {
        max(0, maxCodeValidationAttempts - codeValidationAttempts)
    }

    private var hasCodeAttemptsRemaining: Bool {
        codeAttemptsRemaining > 0
    }

    private var codeValidationSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("set_start_time_manage_code_message")
                    .font(AppFont.textStyle(.subheadline))
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("participate_code_prefix", text: $codePrefix)
                        .font(inputContentFont)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("code_entry_prefix_field")
                    Text("-")
                        .font(AppFont.textStyle(.title2))
                        .foregroundStyle(.secondary)
                    TextField("participate_code_suffix", text: $codeSuffix)
                        .font(inputContentFont)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("code_entry_suffix_field")
                }

                Text(codeValidationError ?? " ")
                    .foregroundStyle(Theme.Colors.error)
                    .font(AppFont.textStyle(.footnote))
                    .opacity(codeValidationError == nil ? 0 : 1)
                    .accessibilityIdentifier("code_entry_error_label")

                Text(
                    hasCodeAttemptsRemaining
                        ? String(
                            format: NSLocalizedString("participate_code_attempts_remaining", comment: ""),
                            codeAttemptsRemaining
                        )
                        : NSLocalizedString("participate_code_attempts_exhausted", comment: "")
                )
                .font(AppFont.textStyle(.footnote))
                .foregroundStyle(hasCodeAttemptsRemaining ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.Colors.error))
                .accessibilityIdentifier("code_entry_attempts_label")

                Button {
                    Task { await verifyManageCode() }
                } label: {
                    if isValidatingCode {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("set_start_time_manage_code_verify_button")
                            .font(AppUI.buttonFont)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.RaceManager.primaryColor)
                .disabled(isValidatingCode || !hasCodeAttemptsRemaining || manageCode == nil)
                .accessibilityIdentifier("code_entry_verify_button")

                Button("actions_cancel") {
                    showCodeModal = false
                }
                .font(AppUI.buttonFont)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("code_entry_cancel_button")

                Spacer()
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("code_entry_modal")
            .navigationTitle("set_start_time_manage_code_title")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func verifyManageCode() async {
        guard hasCodeAttemptsRemaining else { return }
        guard !isValidatingCode else { return }
        guard let code = manageCode else { return }

        isValidatingCode = true
        codeValidationError = nil
        defer { isValidatingCode = false }

        do {
            _ = try await accessService.exchangeManageCodeForToken(code)
            codePrefix = ""
            codeSuffix = ""
            showCodeModal = false
        } catch {
            codeValidationAttempts += 1
            codeValidationError = error.localizedDescription
        }
    }
}

private final class CodeEntryUITestURLProtocol: URLProtocol {
    static var isEnabled = false

    override class func canInit(with request: URLRequest) -> Bool {
        guard isEnabled, let path = request.url?.path else {
            return false
        }
        return path == "/api/access/login"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com/api/access/login")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let body = Data("{\"error\":\"Invalid UITest code\"}".utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension CourseMarkItem {
    init(
        id: String,
        sequence: Int,
        name: String?,
        description: String?,
        rounding_side: String?,
        type: String?,
        status: String?,
        mark_lat: Double?,
        mark_lon: Double?,
        distance_to_next_m: Double?,
        bearing_to_next_rad: Double?,
        updated_at: String?
    ) {
        self.id = id
        self.sequence = sequence
        self.name = name
        self.description = description
        self.rounding_side = rounding_side
        self.type = type
        self.status = status
        self.mark_lat = mark_lat
        self.mark_lon = mark_lon
        self.distance_to_next_m = distance_to_next_m
        self.bearing_to_next_rad = bearing_to_next_rad
        self.updated_at = updated_at
    }
}

private extension CourseLine {
    init(
        id: String,
        name: String?,
        description: String?,
        status: String?,
        mark_left_lat: Double?,
        mark_left_lon: Double?,
        mark_right_lat: Double?,
        mark_right_lon: Double?,
        midpoint_lat: Double?,
        midpoint_lon: Double?,
        length_m: Double?,
        bearing_deg: Double?,
        distance_to_first_mark_m: Double?,
        bearing_to_first_mark_rad: Double?,
        updated_at: String?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.status = status
        self.mark_left_lat = mark_left_lat
        self.mark_left_lon = mark_left_lon
        self.mark_right_lat = mark_right_lat
        self.mark_right_lon = mark_right_lon
        self.midpoint_lat = midpoint_lat
        self.midpoint_lon = midpoint_lon
        self.length_m = length_m
        self.bearing_deg = bearing_deg
        self.distance_to_first_mark_m = distance_to_first_mark_m
        self.bearing_to_first_mark_rad = bearing_to_first_mark_rad
        self.updated_at = updated_at
    }
}