//
//  RaceCourseSectionView.swift
//  Naviari_IOS
//
//  Reusable race-level course section. Renders the visual branch for each
//  `RaceCourseState` and fires callbacks; carries no ViewModel dependency.
//
//  Wiring into RaceDetailScreen is S3; this view is delivered standalone in
//  S2 so each state can be validated in isolation (XCUITest + Xcode Preview).
//

import SwiftUI

/// Race-level course section. Pure view: takes state and callbacks; owns no
/// network or storage logic.
///
/// State A (`.noneSet`): split-button template picker with loading/empty
/// variants. State B (`.mixedSet`): static informational label. State C
/// (`.allSameId(course)`): embedded `CourseTimelineView` with edit callback.
/// `.loading` shows a centered ProgressView and no section header. `.error`
/// shows `ErrorStateView` with a retry button. `.noStarts` renders nothing —
/// the host screen hides the section entirely in that case.
struct RaceCourseSectionView: View {
    let state: RaceCourseState
    let templates: [RaceCourse]
    let isTemplateLoading: Bool
    let isCopyLoading: Bool
    let preferredActiveItemId: String?
    let onTemplatePickerOpening: () -> Void
    let onTemplateSelected: (RaceCourse) -> Void
    let onEditCourse: (RaceCourse, String) -> Void
    let onAddAfter: (RaceCourse, String) -> Void
    let onRetry: () -> Void

    /// Local UI state for the embedded CourseTimelineView in State C.
    /// Held here so the parent screen does not need to own these bindings.
    @State private var activeCourseItemId: String?
    @State private var activeLineSubIndexByItemId: [String: Int] = [:]
    @State private var showTemplatePicker = false
    @State private var lastAppliedPreferredActiveItemId: String?

    var body: some View {
        switch state {
        case .loading:
            loadingBranch
        case let .error(message):
            errorBranch(message: message)
        case .noneSet:
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader
                stateAContent
            }
        case .mixedSet:
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader
                stateBContent
            }
        case let .allSameId(course):
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader
                stateCContent(for: course)
            }
        case .noStarts:
            EmptyView()
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        Text("race_course_section_title")
            .font(AppFont.textStyle(.headline))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("race_course_section_header")
    }

    // MARK: - State A

    @ViewBuilder
    private var stateAContent: some View {
        // Sub-label is always present in State A.
        Text("race_course_none_set_hint")
            .font(AppFont.textStyle(.body))
            .foregroundStyle(Theme.Colors.textSecondary)
            .accessibilityIdentifier("race_course_none_set_hint")

        if isTemplateLoading {
            HStack {
                Spacer()
                ProgressView()
                    .accessibilityIdentifier("race_course_loading")
                Spacer()
            }
            .padding(.vertical, 12)
        } else if templates.isEmpty {
            Text("race_course_no_templates")
                .font(AppFont.textStyle(.body))
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityIdentifier("race_course_no_templates_label")
        } else {
            templatePicker(
                titleKey: "start_detail_course_template_button",
                accessibilityIdentifier: "race_course_template_picker_button",
                loadsTemplatesOnExpand: false
            )
        }
    }

    private func templatePicker(
        titleKey: LocalizedStringKey,
        accessibilityIdentifier: String,
        loadsTemplatesOnExpand: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CourseTemplatePickerButton(
                isEnabled: !isCopyLoading,
                isExpanded: showTemplatePicker,
                isCopying: isCopyLoading,
                titleKey: titleKey,
                accessibilityIdentifier: accessibilityIdentifier,
                onTap: {
                    toggleTemplatePicker(loadsTemplatesOnExpand: loadsTemplatesOnExpand)
                }
            )

            if showTemplatePicker, !templates.isEmpty {
                CourseTemplatePickerDropdown(
                    templates: templates,
                    optionIdentifierPrefix: "race_course_template_button_",
                    onTemplateSelected: handleTemplateSelection
                )
            }
        }
    }

    private func toggleTemplatePicker(loadsTemplatesOnExpand: Bool) {
        guard !isCopyLoading else { return }

        let isOpening = !showTemplatePicker
        withAnimation(.easeInOut(duration: 0.18)) {
            showTemplatePicker.toggle()
        }

        if isOpening, loadsTemplatesOnExpand, templates.isEmpty, !isTemplateLoading {
            onTemplatePickerOpening()
        }
    }

    private func handleTemplateSelection(_ template: RaceCourse) {
        withAnimation(.easeInOut(duration: 0.18)) {
            showTemplatePicker = false
        }
        onTemplateSelected(template)
    }

    // MARK: - State B

    private var stateBContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("race_course_mixed_hint")
                .font(AppFont.textStyle(.body))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("race_course_mixed_label")

            CourseTemplatePickerButton(
                isEnabled: !isTemplateLoading && !isCopyLoading,
                isExpanded: showTemplatePicker,
                isCopying: isTemplateLoading || isCopyLoading,
                titleKey: "race_course_change_all_button",
                accessibilityIdentifier: "race_course_change_all_button",
                onTap: {
                    toggleTemplatePicker(loadsTemplatesOnExpand: true)
                }
            )
            .accessibilityHint(Text("race_course_change_all_confirm_message"))

            if showTemplatePicker, !templates.isEmpty {
                CourseTemplatePickerDropdown(
                    templates: templates,
                    optionIdentifierPrefix: "race_course_template_button_",
                    onTemplateSelected: handleTemplateSelection
                )
            } else if showTemplatePicker, !isTemplateLoading, templates.isEmpty {
                Text("race_course_no_templates")
                    .font(AppFont.textStyle(.body))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityIdentifier("race_course_no_templates_label")
            }
        }
    }

    // MARK: - State C

    @ViewBuilder
    private func stateCContent(for course: RaceCourse) -> some View {
        let items = CourseTimelineItem.buildTimeline(from: course)
        VStack(alignment: .leading, spacing: 12) {
            CourseTimelineView(
                items: items,
                activeItemId: $activeCourseItemId,
                activeSubIndexByItemId: $activeLineSubIndexByItemId,
                horizontalPadding: 0,
                onPositionSelected: { _ in
                    // Position selection is not exposed at race level. Course-mark
                    // GPS capture remains a start-detail / mark-edit responsibility.
                },
                onEditSelected: { itemId in
                    onEditCourse(course, itemId)
                },
                onAddAfter: { itemId in
                    onAddAfter(course, itemId)
                }
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("race_course_timeline")
            .onAppear {
                applyPreferredActiveItemIdIfNeeded(from: items)
            }
            .onChange(of: preferredActiveItemId) { _, _ in
                applyPreferredActiveItemIdIfNeeded(from: items)
            }
            .onChange(of: items.map(\.id)) { _, _ in
                applyPreferredActiveItemIdIfNeeded(from: items)
            }

            CourseTemplatePickerButton(
                isEnabled: !isTemplateLoading && !isCopyLoading,
                isExpanded: showTemplatePicker,
                isCopying: isTemplateLoading || isCopyLoading,
                titleKey: "race_course_change_all_button",
                accessibilityIdentifier: "race_course_change_all_button",
                onTap: {
                    toggleTemplatePicker(loadsTemplatesOnExpand: true)
                }
            )
            .accessibilityHint(Text("race_course_change_all_confirm_message"))

            if showTemplatePicker, !templates.isEmpty {
                CourseTemplatePickerDropdown(
                    templates: templates,
                    optionIdentifierPrefix: "race_course_template_button_",
                    onTemplateSelected: handleTemplateSelection
                )
            } else if showTemplatePicker, !isTemplateLoading, templates.isEmpty {
                Text("race_course_no_templates")
                    .font(AppFont.textStyle(.body))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityIdentifier("race_course_no_templates_label")
            }
        }
    }

    private func applyPreferredActiveItemIdIfNeeded(from items: [CourseTimelineItem]) {
        guard let preferredActiveItemId,
              preferredActiveItemId != lastAppliedPreferredActiveItemId,
              items.contains(where: { $0.id == preferredActiveItemId }) else {
            return
        }

        activeCourseItemId = preferredActiveItemId
        lastAppliedPreferredActiveItemId = preferredActiveItemId
    }

    // MARK: - Loading branch

    private var loadingBranch: some View {
        HStack {
            Spacer()
            ProgressView()
                .accessibilityIdentifier("race_course_loading")
            Spacer()
        }
        .padding(.vertical, 24)
    }

    // MARK: - Error branch

    private func errorBranch(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            ErrorStateView(
                message: message,
                buttonTitleKey: "races_retry_button",
                action: onRetry,
                buttonAccessibilityIdentifier: "race_course_retry_button"
            )
        }
    }
}

// MARK: - Previews

/// Decoded fixtures for previews. Production builds never load these — they
/// exist only so SwiftUI Previews can render a representative `RaceCourse`
/// without depending on the network.
private enum RaceCourseSectionPreviewFixtures {
    static let templates: [RaceCourse] = [
        decodeTemplate(id: "tpl-1", name: "Windward / Leeward"),
        decodeTemplate(id: "tpl-2", name: "Triangle"),
        decodeTemplate(id: "tpl-3", name: "Coastal")
    ]

    static let sharedCourse: RaceCourse = decodeSharedCourse()

    static func decodeTemplate(id: String, name: String) -> RaceCourse {
        let json = """
        {
          "id": "\(id)",
          "name": "\(name)",
          "description": null,
          "series_id": "series-preview",
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

    static func decodeSharedCourse() -> RaceCourse {
        let json = """
        {
          "id": "course-shared",
          "name": "Race Day Course",
          "description": null,
          "series_id": "series-preview",
          "total_length_m": 3704,
          "total_length_nm": 2.0,
          "is_template": false,
          "template_source_id": "tpl-1",
          "start_line": {
            "id": "line-start",
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
          "finish_line": {
            "id": "line-finish",
            "name": "Finish Line",
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
              "id": "mark-1",
              "sequence": 1,
              "name": "Mark 1",
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

#Preview("State A — Templates", traits: .sizeThatFitsLayout) {
    RaceCourseSectionView(
        state: .noneSet,
        templates: RaceCourseSectionPreviewFixtures.templates,
        isTemplateLoading: false,
        isCopyLoading: false,
        preferredActiveItemId: nil,
        onTemplatePickerOpening: {},
        onTemplateSelected: { _ in },
        onEditCourse: { _, _ in },
        onAddAfter: { _, _ in },
        onRetry: {}
    )
    .padding(.vertical)
}

#Preview("State A — Loading", traits: .sizeThatFitsLayout) {
    RaceCourseSectionView(
        state: .noneSet,
        templates: [],
        isTemplateLoading: true,
        isCopyLoading: false,
        preferredActiveItemId: nil,
        onTemplatePickerOpening: {},
        onTemplateSelected: { _ in },
        onEditCourse: { _, _ in },
        onAddAfter: { _, _ in },
        onRetry: {}
    )
    .padding(.vertical)
}

#Preview("State A — Copy In Flight", traits: .sizeThatFitsLayout) {
    RaceCourseSectionView(
        state: .noneSet,
        templates: RaceCourseSectionPreviewFixtures.templates,
        isTemplateLoading: false,
        isCopyLoading: true,
        preferredActiveItemId: nil,
        onTemplatePickerOpening: {},
        onTemplateSelected: { _ in },
        onEditCourse: { _, _ in },
        onAddAfter: { _, _ in },
        onRetry: {}
    )
    .padding(.vertical)
}

#Preview("State B — Mixed", traits: .sizeThatFitsLayout) {
    RaceCourseSectionView(
        state: .mixedSet,
        templates: [],
        isTemplateLoading: false,
        isCopyLoading: false,
        preferredActiveItemId: nil,
        onTemplatePickerOpening: {},
        onTemplateSelected: { _ in },
        onEditCourse: { _, _ in },
        onAddAfter: { _, _ in },
        onRetry: {}
    )
    .padding(.vertical)
}

#Preview("State C — Shared Course", traits: .sizeThatFitsLayout) {
    RaceCourseSectionView(
        state: .allSameId(RaceCourseSectionPreviewFixtures.sharedCourse),
        templates: [],
        isTemplateLoading: false,
        isCopyLoading: false,
        preferredActiveItemId: nil,
        onTemplatePickerOpening: {},
        onTemplateSelected: { _ in },
        onEditCourse: { _, _ in },
        onAddAfter: { _, _ in },
        onRetry: {}
    )
    .padding(.vertical)
}

#Preview("Loading", traits: .sizeThatFitsLayout) {
    RaceCourseSectionView(
        state: .loading,
        templates: [],
        isTemplateLoading: false,
        isCopyLoading: false,
        preferredActiveItemId: nil,
        onTemplatePickerOpening: {},
        onTemplateSelected: { _ in },
        onEditCourse: { _, _ in },
        onAddAfter: { _, _ in },
        onRetry: {}
    )
    .padding(.vertical)
}

#Preview("Error", traits: .sizeThatFitsLayout) {
    RaceCourseSectionView(
        state: .error("Couldn't load course state."),
        templates: [],
        isTemplateLoading: false,
        isCopyLoading: false,
        preferredActiveItemId: nil,
        onTemplatePickerOpening: {},
        onTemplateSelected: { _ in },
        onEditCourse: { _, _ in },
        onAddAfter: { _, _ in },
        onRetry: {}
    )
    .padding(.vertical)
}
