//
//  RaceDetailScreen.swift
//  Naviari_IOS
//
//  Shows metadata and start list for a single race selection, plus the
//  race-level course section (S3 of ios-race-level-course-selection).
//

import OSLog
import SwiftUI

private enum RaceCourseCopyAlert: Identifiable {
    case partial(successCount: Int, totalCount: Int)
    case requestFailed(detail: String?)

    var id: String {
        switch self {
        case let .partial(successCount, totalCount):
            return "partial-\(successCount)-\(totalCount)"
        case let .requestFailed(detail):
            return "request-failed-\(detail ?? "none")"
        }
    }
}

private enum RaceTemplateSelectionDispatch: String {
    case directCopy = "direct_copy"
    case confirmation = "confirmation"
}

/// Displays metadata for the selected race plus its list of starts and
/// the race-level course section.
struct RaceDetailScreen: View {
    let summary: RaceSummary
    var onSelectStart: (RaceStart) -> Void
    @EnvironmentObject private var viewModel: RaceBrowserViewModel
    @EnvironmentObject private var userNotifications: UserNotifications
    @StateObject private var courseViewModel: RaceDetailViewModel
    @StateObject private var buoyViewModel: BuoySectionViewModel

    @State private var showCodeModal = false
    @State private var pendingTemplate: RaceCourse?
    @State private var showCourseChangeConfirmation = false
    @State private var pendingCourseItemEditTarget: CourseItemEditTarget?
    @State private var pendingBuoyManageAction: PendingBuoyManageAction?
    @State private var courseItemEditTarget: CourseItemEditTarget?
    @State private var buoySetPositionTarget: BuoyRecord?
    @State private var copyAlert: RaceCourseCopyAlert?
    @State private var preferredActiveCourseItemId: String?

    private let accessService = ParticipationService()
    private let storage = ManageAccessStorage.shared
    private let logger = Logger(subsystem: "fi.mobiari.naviari-ios", category: "RaceDetailScreen")

    init(
        summary: RaceSummary,
        onSelectStart: @escaping (RaceStart) -> Void,
        initialCourseTemplates: [RaceCourse] = []
    ) {
        self.summary = summary
        self.onSelectStart = onSelectStart
        let raceId = summary.race.rawId ?? summary.race.slug ?? summary.id
        _courseViewModel = StateObject(
            wrappedValue: RaceDetailViewModel(
                raceId: raceId,
                seriesId: summary.seriesId,
                initialCourseTemplates: initialCourseTemplates
            )
        )
        _buoyViewModel = StateObject(
            wrappedValue: BuoySectionViewModel(raceId: raceId)
        )
    }

    private var raceIdentifier: String? {
        summary.race.rawId ?? summary.race.slug
    }

    private var seriesIdentifier: String? {
        summary.seriesId
    }

    /// Stable key for `.task(id:)` so we re-fetch the aggregated course state
    /// whenever the loaded starts list changes for the current race.
    private var courseStateTaskKey: String {
        let starts = viewModel.starts(for: summary)
        let ids = starts.compactMap { $0.rawId ?? $0.slug }.joined(separator: ",")
        return "\(summary.id)|\(ids.isEmpty ? "empty" : ids)"
    }

    /// Stable token derived from `courseViewModel.courseState` used as a
    /// `.task(id:)` key so we can react to state transitions without
    /// requiring `RaceCourseState` itself to conform to `Equatable`. The
    /// exact string content is not important — only its stability across
    /// repeated reads of the same case.
    private var courseStateTransitionKey: String {
        switch courseViewModel.courseState {
        case .loading:
            return "loading"
        case let .error(message):
            return "error:\(message)"
        case .noneSet:
            return "noneSet"
        case .mixedSet:
            return "mixedSet"
        case let .allSameId(course):
            return "allSameId:\(course.id)"
        case .noStarts:
            return "noStarts"
        }
    }

    var body: some View {
        ScreenContainer(showBack: true, title: Text("race_title")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(summary.race.nameOrFallback)
                        .font(AppFont.textStyle(.title2, weight: .semibold))

                    if let dateText = viewModel.formattedDate(for: summary.race) {
                        LabeledContent {
                            Text(dateText)
                        } label: {
                            Text("race_date_label")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent {
                        Text(summary.race.status ?? NSLocalizedString("start_status_unknown", comment: ""))
                    } label: {
                        Text("race_status_label")
                            .foregroundStyle(.secondary)
                    }

                    if let description = summary.race.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("race_description_label")
                                .foregroundStyle(.secondary)
                            Text(description)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Divider().padding(.vertical, 8)

                    Text("race_starts_title")
                        .font(AppFont.textStyle(.headline))

                    if viewModel.isLoadingStarts(for: summary) && viewModel.starts(for: summary).isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 16)
                    } else if let errorMessage = viewModel.startError(for: summary) {
                        ErrorStateView(
                            message: errorMessage,
                            buttonTitleKey: "races_retry_button",
                            action: {
                                Task {
                                    await viewModel.retryStarts()
                                }
                            }
                        )
                    } else {
                        let starts = viewModel.starts(for: summary)
                        if starts.isEmpty {
                            Text("starts_empty")
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(starts) { start in
                                    Button {
                                        onSelectStart(start)
                                    } label: {
                                        RaceStartRowView(
                                            start: start,
                                            timeText: viewModel.formattedStartTime(for: start)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Race-level course section — only injected when at least
                    // one start exists. Separator mirrors the divider style
                    // already used above.
                    if !viewModel.starts(for: summary).isEmpty {
                        Divider().padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            RaceCourseSectionView(
                                state: courseViewModel.courseState,
                                templates: courseViewModel.courseTemplates,
                                isTemplateLoading: courseViewModel.isLoadingTemplates,
                                isCopyLoading: courseViewModel.isCopying,
                                preferredActiveItemId: preferredActiveCourseItemId,
                                onTemplatePickerOpening: handleTemplatePickerOpening,
                                onTemplateSelected: handleTemplateSelected,
                                onEditCourse: handleEditCourse,
                                onAddAfter: handleAddAfter,
                                onRetry: handleRetry
                            )
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("race_course_section")
                    }

                    Divider().padding(.vertical, 8)

                    BuoySectionView(
                        titleKey: "buoy_section_title",
                        buoys: buoyViewModel.buoys,
                        activeBuoyId: Binding(
                            get: { buoyViewModel.activeBuoyId },
                            set: { buoyViewModel.activeBuoyId = $0 }
                        ),
                        sectionAccessibilityIdentifier: "race_buoy_section",
                        addButtonAccessibilityIdentifier: "race_buoy_add_button",
                        onAddTapped: handleAddBuoy,
                        onEditBuoy: handleEditBuoy,
                        onSetCoordinates: handleSetBuoyCoordinates
                    )
                }
                .padding()
            }
        }
        .task {
            await viewModel.ensureRaceData(for: summary)
        }
        .task(id: raceIdentifier ?? summary.id) {
            buoyViewModel.reload()
        }
        .task(id: courseStateTaskKey) {
            await refreshCourseStateIfStartsAvailable()
        }
        .task(id: courseStateTransitionKey) {
            handleCourseStateChange(courseViewModel.courseState)
        }
        .alert(item: $copyAlert) { alert in
            switch alert {
            case let .partial(successCount, totalCount):
                return Alert(
                    title: Text("race_course_copy_error_title"),
                    message: Text(
                        String(
                            format: NSLocalizedString("race_course_copy_partial_message", comment: ""),
                            successCount,
                            totalCount
                        )
                    ),
                    dismissButton: .cancel(Text("actions_ok"))
                )
            case let .requestFailed(detail):
                return Alert(
                    title: Text("race_course_copy_request_failed_title"),
                    message: Text(copyRequestFailureMessage(detail: detail)),
                    dismissButton: .cancel(Text("actions_ok"))
                )
            }
        }
        .alert(
            Text("race_course_change_all_confirm_title"),
            isPresented: $showCourseChangeConfirmation
        ) {
            Button("actions_cancel", role: .cancel) {
                pendingTemplate = nil
            }
            Button("race_course_change_all_confirm_action", role: .destructive) {
                confirmPendingTemplateCopy()
            }
        } message: {
            Text("race_course_change_all_confirm_message")
        }
        .sheet(isPresented: $showCodeModal) {
            CodeEntryView<ManageAccessLoginResult>(
                titleKey: "set_start_time_manage_code_title",
                messageKey: "race_course_manage_code_hint",
                verifyButtonKey: "set_start_time_manage_code_verify_button",
                cancelButtonKey: "actions_cancel",
                accentColor: Theme.RaceManager.primaryColor,
                onVerify: { code in
                    try await accessService.exchangeManageCodeForLoginResult(code)
                },
                onSuccess: { loginResult in
                    guard loginResult.role == "manage" else {
                        return "manage_code_role_invalid"
                    }
                    guard managesRaceHierarchy(loginResult) else {
                        return pendingBuoyManageAction == nil
                            ? "manage_code_scope_invalid_race_course"
                            : "manage_code_scope_invalid_race_buoy"
                    }

                    storage.save(loginResult: loginResult)
                    showCodeModal = false

                    let pendingTemplateLocal = pendingTemplate
                    let pendingEditLocal = pendingCourseItemEditTarget
                    let pendingBuoyActionLocal = pendingBuoyManageAction

                    Task { @MainActor in
                        courseViewModel.reloadToken()

                        if let pendingTemplateLocal {
                            pendingTemplate = pendingTemplateLocal
                            guard courseViewModel.hasValidRaceLevelToken else {
                                return
                            }
                            continuePendingTemplateSelectionIfAuthorized()
                        } else if let pendingEditLocal {
                            pendingCourseItemEditTarget = nil
                            courseItemEditTarget = pendingEditLocal
                        } else if let pendingBuoyActionLocal {
                            pendingBuoyManageAction = nil
                            performAuthorizedBuoyManageAction(pendingBuoyActionLocal)
                        }
                    }
                    return nil
                },
                onCancel: {
                    pendingTemplate = nil
                    pendingCourseItemEditTarget = nil
                    pendingBuoyManageAction = nil
                    showCodeModal = false
                }
            )
        }
        .sheet(item: $courseItemEditTarget) { target in
            courseItemEditSheet(for: target)
        }
        .fullScreenCover(item: $buoySetPositionTarget) { buoy in
            NavigationStack {
                BuoySetPositionScreen(
                    contextTitle: summary.race.nameOrFallback,
                    buoy: buoy
                ) { savedBuoy in
                    buoySetPositionTarget = nil
                    handleBuoyPositionSaved(savedBuoy)
                }
            }
        }
        .sheet(
            item: Binding(
                get: { buoyViewModel.editorMode },
                set: { buoyViewModel.editorMode = $0 }
            )
        ) { mode in
            NavigationStack {
                BuoyEditorView(mode: mode, storage: .shared) { outcome in
                    buoyViewModel.editorMode = nil
                    handleBuoyEditorOutcome(outcome)
                }
            }
        }
    }

    // MARK: - Course state coordination

    private func refreshCourseStateIfStartsAvailable() async {
        let starts = viewModel.starts(for: summary)
        guard !starts.isEmpty else { return }
        courseViewModel.reloadToken()
        await courseViewModel.loadCourseState(starts: starts)
    }

    private func handleCourseStateChange(_ state: RaceCourseState) {
        switch state {
        case .noneSet:
            guard let seriesIdentifier else { return }
            // Avoid re-fetching if templates already present or a load is
            // already in flight.
            if !courseViewModel.isLoadingTemplates && courseViewModel.courseTemplates.isEmpty {
                Task {
                    await courseViewModel.loadTemplates(seriesId: seriesIdentifier)
                }
            }
        default:
            break
        }
    }

    private func handleTemplatePickerOpening() {
        switch courseViewModel.courseState {
        case .mixedSet, .allSameId:
            break
        default:
            return
        }
        guard let seriesIdentifier else { return }
        guard !courseViewModel.isLoadingTemplates else { return }
        guard courseViewModel.courseTemplates.isEmpty else { return }

        Task {
            await courseViewModel.loadTemplates(seriesId: seriesIdentifier)
        }
    }

    private func managesRaceHierarchy(_ loginResult: ManageAccessLoginResult) -> Bool {
        switch loginResult.scope {
        case .race:
            return loginResult.scopeId == raceIdentifier
        case .series:
            return loginResult.scopeId == seriesIdentifier
        case .start:
            return false
        }
    }

    private func templateSelectionDispatch(for state: RaceCourseState) -> RaceTemplateSelectionDispatch? {
        switch state {
        case .noneSet:
            return .directCopy
        case .mixedSet, .allSameId:
            return .confirmation
        case .loading, .error, .noStarts:
            return nil
        }
    }

    private func continuePendingTemplateSelectionIfAuthorized() {
        guard let dispatch = templateSelectionDispatch(for: courseViewModel.courseState),
              let template = pendingTemplate else {
            pendingTemplate = nil
            return
        }

        courseViewModel.reloadToken()
        guard courseViewModel.hasValidRaceLevelToken,
              let accessToken = courseViewModel.storedToken else {
            pendingCourseItemEditTarget = nil
            pendingBuoyManageAction = nil
            showCourseChangeConfirmation = false
            showCodeModal = true
            return
        }

        logger.info("raceCourseDispatch action=\(dispatch.rawValue, privacy: .public)")

        switch dispatch {
        case .directCopy:
            pendingTemplate = nil
            showCourseChangeConfirmation = false
            Task {
                await performTemplateCopy(template: template, accessToken: accessToken)
            }
        case .confirmation:
            showCourseChangeConfirmation = true
        }
    }

    // MARK: - Section callbacks

    private func handleTemplateSelected(_ template: RaceCourse) {
        courseViewModel.reloadToken()
        pendingTemplate = template
        showCourseChangeConfirmation = false

        if courseViewModel.hasValidRaceLevelToken, courseViewModel.storedToken != nil {
            continuePendingTemplateSelectionIfAuthorized()
            return
        }

        pendingCourseItemEditTarget = nil
        pendingBuoyManageAction = nil
        showCodeModal = true
    }

    private func confirmPendingTemplateCopy() {
        guard let pendingTemplate else { return }

        courseViewModel.reloadToken()
        guard courseViewModel.hasValidRaceLevelToken,
              let accessToken = courseViewModel.storedToken else {
            showCourseChangeConfirmation = false
            showCodeModal = true
            return
        }

        Task {
            await MainActor.run {
                self.pendingTemplate = nil
                self.showCourseChangeConfirmation = false
            }
            await performTemplateCopy(template: pendingTemplate, accessToken: accessToken)
        }
    }

    private func handleEditCourse(_ course: RaceCourse, itemId: String) {
        let courseId = course.id
        let target = editableTarget(in: course, courseId: courseId, itemId: itemId)
        guard let target else { return }
        presentCourseItemEditor(target)
    }

    private func handleAddAfter(_ course: RaceCourse, itemId: String) {
        let courseId = course.id
        guard let afterSequence = courseAddMarkInsertionSequence(after: itemId, in: course) else {
            return
        }
        presentCourseItemEditor(.addMark(courseId: courseId, afterSequence: afterSequence))
    }

    private func handleRetry() {
        Task {
            await refreshCourseStateIfStartsAvailable()
        }
    }

    private func handleAddBuoy() {
        requestBuoyManageAction(.present(.add(raceId: buoyViewModel.raceId)))
    }

    private func handleEditBuoy(_ buoy: BuoyRecord) {
        requestBuoyManageAction(.present(.edit(buoy)))
    }

    private func handleSetBuoyCoordinates(_ buoy: BuoyRecord) {
        requestBuoyManageAction(.setPosition(buoy))
    }

    private func requestBuoyManageAction(_ action: PendingBuoyManageAction) {
        courseViewModel.reloadToken()
        guard courseViewModel.hasValidRaceLevelToken,
              courseViewModel.storedToken != nil else {
            pendingTemplate = nil
            pendingCourseItemEditTarget = nil
            pendingBuoyManageAction = action
            showCodeModal = true
            return
        }

        pendingBuoyManageAction = nil
        performAuthorizedBuoyManageAction(action)
    }

    private func performAuthorizedBuoyManageAction(_ action: PendingBuoyManageAction) {
        switch action {
        case let .present(mode):
            buoyViewModel.editorMode = mode
        case let .setPosition(buoy):
            buoySetPositionTarget = buoy
        }
    }

    private func handleBuoyEditorOutcome(_ outcome: BuoyEditorOutcome) {
        buoyViewModel.handleEditorOutcome(outcome)
        let messageKey: String
        switch outcome {
        case .saved:
            messageKey = "buoy_save_success"
        case .removed:
            messageKey = "buoy_delete_success"
        }
        userNotifications.show(
            message: NSLocalizedString(messageKey, comment: ""),
            severity: .success
        )
    }

    private func handleBuoyPositionSaved(_ buoy: BuoyRecord) {
        buoyViewModel.activeBuoyId = buoy.id
        buoyViewModel.reload()
        userNotifications.show(
            message: NSLocalizedString("buoy_save_success", comment: ""),
            severity: .success
        )
    }

    // MARK: - Shared race copy

    private func performTemplateCopy(template: RaceCourse, accessToken: String) async {
        let starts = viewModel.starts(for: summary)
        guard !starts.isEmpty else { return }
        let outcome = await courseViewModel.copyTemplateToRace(
            templateId: template.id,
            starts: starts,
            accessToken: accessToken
        )

        switch outcome {
        case let .partial(linkedStartCount, totalStartCount):
            copyAlert = .partial(successCount: linkedStartCount, totalCount: totalStartCount)
        case let .requestFailed(detail):
            copyAlert = .requestFailed(detail: detail)
        case .noResult, .complete:
            break
        }
    }

    private func copyRequestFailureMessage(detail: String?) -> String {
        guard let detail = normalizedAlertDetail(detail) else {
            return NSLocalizedString("race_course_copy_request_failed_message", comment: "")
        }

        return String(
            format: NSLocalizedString("race_course_copy_request_failed_message_with_detail", comment: ""),
            detail
        )
    }

    private func normalizedAlertDetail(_ detail: String?) -> String? {
        guard let detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty else {
            return nil
        }
        return detail
    }

    // MARK: - Edit navigation

    private func editableTarget(in course: RaceCourse, courseId: String, itemId: String) -> CourseItemEditTarget? {
        if let mark = course.course_marks.first(where: { $0.id == itemId }) {
            return .mark(mark, courseId: courseId)
        }
        if let startLine = course.start_line, startLine.id == itemId {
            return .startLine(startLine, courseId: courseId)
        }
        if let finishLine = course.finish_line, finishLine.id == itemId {
            return .finishLine(finishLine, courseId: courseId)
        }
        return nil
    }

    private func presentCourseItemEditor(_ target: CourseItemEditTarget) {
        courseViewModel.reloadToken()
        guard courseViewModel.hasValidRaceLevelToken,
              courseViewModel.storedToken != nil else {
            pendingTemplate = nil
            pendingCourseItemEditTarget = target
            showCodeModal = true
            return
        }
        pendingCourseItemEditTarget = nil
        courseItemEditTarget = target
    }

    @ViewBuilder
    private func courseItemEditSheet(for target: CourseItemEditTarget) -> some View {
        let token = courseViewModel.storedToken ?? ""
        switch target {
        case let .mark(item, courseId):
            NavigationStack {
                CourseMarkEditView(
                    mode: .editMark(item, courseId: courseId),
                    accessToken: token,
                    buoyOptions: buoyViewModel.buoys
                ) { outcome in
                    let successMessageKey = courseItemSaveSuccessMessageKey(for: target, outcome: outcome)
                    courseItemEditTarget = nil
                    Task { await handleCourseItemSave(outcome, successMessageKey: successMessageKey) }
                }
            }
        case let .addMark(courseId, afterSequence):
            NavigationStack {
                CourseMarkEditView(
                    mode: .addMark(courseId: courseId, afterSequence: afterSequence),
                    accessToken: token,
                    buoyOptions: buoyViewModel.buoys
                ) { outcome in
                    let successMessageKey = courseItemSaveSuccessMessageKey(for: target, outcome: outcome)
                    courseItemEditTarget = nil
                    Task { await handleCourseItemSave(outcome, successMessageKey: successMessageKey) }
                }
            }
        case let .startLine(line, courseId):
            NavigationStack {
                CourseLineEditView(
                    mode: .editStartLine(line, courseId: courseId),
                    accessToken: token,
                    buoyOptions: buoyViewModel.buoys
                ) { outcome in
                    let successMessageKey = courseItemSaveSuccessMessageKey(for: target, outcome: outcome)
                    courseItemEditTarget = nil
                    Task { await handleCourseItemSave(outcome, successMessageKey: successMessageKey) }
                }
            }
        case let .finishLine(line, courseId):
            NavigationStack {
                CourseLineEditView(
                    mode: .editFinishLine(line, courseId: courseId),
                    accessToken: token,
                    buoyOptions: buoyViewModel.buoys
                ) { outcome in
                    let successMessageKey = courseItemSaveSuccessMessageKey(for: target, outcome: outcome)
                    courseItemEditTarget = nil
                    Task { await handleCourseItemSave(outcome, successMessageKey: successMessageKey) }
                }
            }
        }
    }

    private func handleCourseItemSave(_ outcome: CourseItemSaveOutcome, successMessageKey: String?) async {
        switch outcome {
        case let .saved(activeItemId):
            preferredActiveCourseItemId = nil
            preferredActiveCourseItemId = activeItemId
        case .removed:
            preferredActiveCourseItemId = nil
        }

        await refreshCourseStateIfStartsAvailable()
        if let successMessageKey {
            userNotifications.show(
                message: NSLocalizedString(successMessageKey, comment: ""),
                severity: .success
            )
        }
    }

    private func courseItemSaveSuccessMessageKey(for target: CourseItemEditTarget, outcome: CourseItemSaveOutcome) -> String? {
        guard case .saved = outcome else { return nil }

        switch target {
        case .mark, .addMark:
            return "course_edit_mark_save_success"
        case .startLine:
            return "course_edit_start_line_save_success"
        case .finishLine:
            return "course_edit_finish_line_save_success"
        }
    }
}
