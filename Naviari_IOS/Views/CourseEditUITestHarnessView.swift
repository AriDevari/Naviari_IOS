import SwiftUI

enum CourseEditUITestScenario {
    case markEdit(mode: String)
    case lineEdit(mode: String)
    case protectionHost

    static var current: CourseEditUITestScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        if let mode = value(for: "-UITestCourseMarkEdit", in: arguments) {
            return .markEdit(mode: mode)
        }
        if let mode = value(for: "-UITestCourseLineEdit", in: arguments) {
            return .lineEdit(mode: mode)
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
            case .protectionHost:
                CourseEditProtectionHarnessView()
            }
        }
        .task {
            configureInjectedLocationIfNeeded()
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
                    accessToken: "test-token"
                )
            }
        default:
            NavigationStack {
                CourseLineEditView(
                    mode: .editStartLine(testLine(name: launchValue("-UITestLineName") ?? NSLocalizedString("course_item_edit_start_line_title", comment: "")), courseId: "course-1"),
                    accessToken: "test-token"
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

private struct CourseEditProtectionHarnessView: View {
    @State private var showCodeModal = false

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
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("set_start_time_manage_code_message")
                        .font(AppFont.textStyle(.subheadline))
                        .foregroundStyle(.secondary)

                    TextField("participate_code_prefix", text: .constant(""))
                        .textFieldStyle(.roundedBorder)

                    Button("actions_cancel") {
                        showCodeModal = false
                    }
                    .font(AppUI.buttonFont)

                    Spacer()
                }
                .padding()
                .navigationTitle("set_start_time_manage_code_title")
                .navigationBarTitleDisplayMode(.inline)
            }
            .interactiveDismissDisabled(true)
        }
    }
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