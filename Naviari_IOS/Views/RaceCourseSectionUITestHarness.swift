//
//  RaceCourseSectionUITestHarness.swift
//  Naviari_IOS
//
//  Debug-only host for `RaceCourseSectionView` so XCUITest can launch the app
//  directly into one of the section's visual states (S2 of the
//  ios-race-level-course-selection feature).
//
//  Activated by passing `-UITestRaceCourseSectionState <letter>` at launch.
//  Letters map to: A | A_loading | A_copy | A_empty | B | C | loading | error.
//
//  This harness is never reachable in production — `ContentView` only routes
//  to it when `RaceCourseSectionUITestScenario.current` is non-nil, which
//  requires the launch argument above.
//

import Foundation
import SwiftUI

/// Launch-argument-driven scenario selector for `RaceCourseSectionView`.
///
/// XCUITest activates a scenario by adding two arguments to `app.launchArguments`:
/// `["-UITestRaceCourseSectionState", "<value>"]`. Any other value is ignored.
enum RaceCourseSectionUITestScenario: Equatable {
    /// State A with three template buttons available; no loading, no copy in flight.
    case stateATemplates
    /// State A while templates are being fetched — shows a centered ProgressView.
    case stateALoading
    /// State A while a shared-course copy is in flight — picker disabled
    /// and a `ProgressView` overlays the list.
    case stateACopyLoading
    /// State A with zero templates returned — shows the no-templates label.
    case stateAEmpty
    /// State B — mixed courses across starts.
    case stateBMixed
    /// State C — all starts share the same course (uses a deterministic fixture).
    case stateCAllSame
    /// Top-level `.loading` (no header).
    case loading
    /// Top-level `.error(...)` with a retry button.
    case error

    /// Reads the current launch arguments and returns the matching scenario,
    /// or `nil` if no race-course-section flag was supplied.
    static var current: RaceCourseSectionUITestScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let raw = value(for: "-UITestRaceCourseSectionState", in: arguments) else {
            return nil
        }
        switch raw {
        case "A", "a", "stateA", "state_a":
            return .stateATemplates
        case "A_loading", "a_loading":
            return .stateALoading
        case "A_copy", "a_copy":
            return .stateACopyLoading
        case "A_empty", "a_empty":
            return .stateAEmpty
        case "B", "b", "stateB", "state_b":
            return .stateBMixed
        case "C", "c", "stateC", "state_c":
            return .stateCAllSame
        case "loading":
            return .loading
        case "error":
            return .error
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

/// SwiftUI host that hands one of the eight scenarios to `RaceCourseSectionView`.
///
/// Renders `RaceCourseSectionView` inside a scroll view so the timeline branch
/// (State C) does not get clipped on smaller devices. No environment objects
/// are required.
struct RaceCourseSectionUITestHarnessView: View {
    let scenario: RaceCourseSectionUITestScenario

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RaceCourseSectionView(
                    state: state,
                    templates: templates,
                    isTemplateLoading: isTemplateLoading,
                    isCopyLoading: isCopyLoading,
                    preferredActiveItemId: nil,
                    onTemplatePickerOpening: {},
                    onTemplateSelected: { _ in },
                    onEditCourse: { _, _ in },
                    onAddAfter: { _, _ in },
                    onRetry: {}
                )
            }
            .padding(.vertical, 24)
        }
        .accessibilityIdentifier("race_course_section_uitest_host")
    }

    // MARK: - Scenario → view parameters

    private var state: RaceCourseState {
        switch scenario {
        case .stateATemplates, .stateALoading, .stateACopyLoading, .stateAEmpty:
            return .noneSet
        case .stateBMixed:
            return .mixedSet
        case .stateCAllSame:
            return .allSameId(RaceCourseSectionUITestFixtures.sharedCourse)
        case .loading:
            return .loading
        case .error:
            return .error("UITest synthetic error")
        }
    }

    private var templates: [RaceCourse] {
        switch scenario {
        case .stateATemplates, .stateACopyLoading, .stateCAllSame:
            return RaceCourseSectionUITestFixtures.templates
        case .stateAEmpty, .stateALoading, .stateBMixed, .loading, .error:
            return []
        }
    }

    private var isTemplateLoading: Bool {
        scenario == .stateALoading
    }

    private var isCopyLoading: Bool {
        scenario == .stateACopyLoading
    }
}

/// Decoded fixtures used by the UITest harness. Kept fileprivate-equivalent
/// (internal-but-prefixed) so production code paths never reference them.
enum RaceCourseSectionUITestFixtures {
    static let templates: [RaceCourse] = [
        decodeTemplate(id: "uitest-tpl-1", name: "UITest Windward"),
        decodeTemplate(id: "uitest-tpl-2", name: "UITest Triangle"),
        decodeTemplate(id: "uitest-tpl-3", name: "UITest Coastal")
    ]

    static let sharedCourse: RaceCourse = decodeSharedCourse()

    private static func decodeTemplate(id: String, name: String) -> RaceCourse {
        let json = """
        {
          "id": "\(id)",
          "name": "\(name)",
          "description": null,
          "series_id": "uitest-series",
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

    private static func decodeSharedCourse() -> RaceCourse {
        let json = """
        {
          "id": "uitest-course-shared",
          "name": "UITest Race Day Course",
          "description": null,
          "series_id": "uitest-series",
          "total_length_m": 3704,
          "total_length_nm": 2.0,
          "is_template": false,
          "template_source_id": "uitest-tpl-1",
          "start_line": {
            "id": "uitest-line-start",
            "name": "UITest Start Line",
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
            "id": "uitest-line-finish",
            "name": "UITest Finish Line",
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
              "id": "uitest-mark-1",
              "sequence": 1,
              "name": "UITest Mark 1",
              "description": "Windward",
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
        return try! JSONDecoder().decode(RaceCourse.self, from: Data(json.utf8))
    }
}
