//
//  StartDetailScreen.swift
//  Naviari_IOS
//
//  Displays the selected race start metadata and placeholder content.
//

import SwiftUI

/// Shows start-specific metadata and the entry point into the participation flow.
struct StartDetailScreen: View {
    private enum ManageProtectedNavigationTarget {
        case setStartTime
        case setPosition(SetPositionTarget)
    }

    private static let templatePickerCoordinateSpace = "start-detail-template-picker-space"
    private static let rehearsalVisibilityDelay: TimeInterval = 30
    private static let rehearsalUploadCadence: TimeInterval = 10
    private static let uploadBoundaryTolerance: TimeInterval = 0.001
    private static let rehearsalVerificationBaseURL = URL(string: "https://naviari.org")!
    private static let rehearsalVerificationMarkdownTargets = [
        "https://naviari.org/",
        "https://naviari.org"
    ]

    let raceSummary: RaceSummary
    let start: RaceStart
    var onParticipate: () -> Void
    var onSetStartTime: () -> Void
    var onSetPositionTarget: (SetPositionTarget) -> Void
    @EnvironmentObject private var viewModel: RaceBrowserViewModel
    @EnvironmentObject private var metricsUploader: BoatMetricsUploader
    @State private var showStopConfirmation = false
    @State private var courseItems: [CourseTimelineItem] = []
    @State private var activeCourseItemId: String?
    @State private var activeLineSubIndexByItemId: [String: Int] = [:]
    @State private var loadedCourse: RaceCourse?
    @State private var isCourseLoaded = false
    @State private var isCourseLoading = false
    @State private var courseTemplates: [RaceCourse] = []
    @State private var isTemplateLoading = false
    @State private var templateLoadError: String?
    @State private var templateCopyError: String?
    @State private var isTemplateCopying = false
    @State private var showTemplatePicker = false
    @State private var templateButtonFrame: CGRect = .zero
    @State private var showCodeModal = false
    @State private var showParticipationCodeModal = false
    @State private var storedToken: String?
    @State private var storedScope: ManageAccessScope?
    @State private var storedScopeId: String?
    @State private var storedParticipationToken: String?
    @State private var storedParticipationScope: ParticipationScope?
    @State private var storedParticipationScopeId: String?
    @State private var pendingTemplateSelection: RaceCourse?
    @State private var pendingCourseItemEditTarget: CourseItemEditTarget?
    @State private var pendingManageNavigationTarget: ManageProtectedNavigationTarget?
    @State private var rehearsalNotificationId: UUID?
    @State private var courseItemEditTarget: CourseItemEditTarget?

    @EnvironmentObject private var userNotifications: UserNotifications

    private let accessService = ParticipationService()
    private let storage = ManageAccessStorage.shared
    private let participationStorage = ParticipationStorage.shared
    private let raceService = RaceService()

    private var resolvedStart: RaceStart {
        guard let startId = start.rawId ?? start.slug else {
            return start
        }
        if let updated = viewModel.selectedRaceStarts.first(where: { ($0.rawId ?? $0.slug) == startId }) {
            return updated
        }
        return start
    }

    private var currentStartIdentifier: String? {
        resolvedStart.rawId ?? resolvedStart.slug
    }

    private var raceIdentifier: String? {
        raceSummary.race.rawId ?? raceSummary.race.slug
    }

    private var seriesIdentifier: String? {
        raceSummary.seriesId
    }

    private var storageScopeKey: String {
        [currentStartIdentifier ?? "", raceIdentifier ?? "", seriesIdentifier ?? ""].joined(separator: "|")
    }

    private var storedTokenIsValid: Bool {
        guard let scope = storedScope, let scopeId = storedScopeId else { return false }
        switch scope {
        case .start:
            return scopeId == currentStartIdentifier
        case .race:
            return scopeId == raceIdentifier
        case .series:
            return scopeId == seriesIdentifier
        }
    }

    private var hasReusableToken: Bool {
        storedToken != nil && storedTokenIsValid
    }

    private var hasReusableParticipationToken: Bool {
        storedParticipationToken != nil && storedParticipationTokenIsValid
    }

    private var storedParticipationTokenIsValid: Bool {
        guard let scope = storedParticipationScope, let scopeId = storedParticipationScopeId else { return false }
        switch scope {
        case .start:
            return scopeId == currentStartIdentifier
        case .race:
            return scopeId == raceIdentifier
        case .series:
            return scopeId == seriesIdentifier
        }
    }

    private var canShowTemplateSelection: Bool {
        currentStartIdentifier != nil && seriesIdentifier != nil
    }

    private var courseReloadTaskKey: String {
        guard let startId = resolvedStart.rawId else {
            return resolvedStart.id
        }
        return "\(startId)|\(viewModel.courseRefreshToken(for: startId))"
    }

    private var rehearsalVerificationURL: URL {
        guard let rawStartId = currentStartIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawStartId.isEmpty else {
            return Self.rehearsalVerificationBaseURL
        }

        var components = URLComponents(
            url: Self.rehearsalVerificationBaseURL,
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "start_id", value: rawStartId)]
        return components?.url ?? Self.rehearsalVerificationBaseURL
    }

    private var activeSessionMatchesCurrentStart: Bool {
        metricsUploader.activeSession?.matches(startId: currentStartIdentifier) == true
    }

    private var shouldShowActiveBroadcastSection: Bool {
        metricsUploader.isBroadcasting && activeSessionMatchesCurrentStart
    }

    private var activeRehearsalSession: BroadcastSession? {
        guard activeSessionMatchesCurrentStart,
              let session = metricsUploader.activeSession,
              session.isRehearsal else {
            return nil
        }
        return session
    }

    private var shouldHideParticipateCTAForOtherActiveBroadcast: Bool {
        metricsUploader.isBroadcasting
            && metricsUploader.activeSession?.blocksStartBroadcastCTA(for: currentStartIdentifier) == true
    }

    private var isRehearsalWindow: Bool {
        resolvedStart.isRehearsalWindow()
    }

    private var isMissingEstimatedStart: Bool {
        !resolvedStart.hasEstimatedStartDate
    }

    private var primaryActionKey: LocalizedStringKey {
        isRehearsalWindow ? "participate_rehearsal_button" : "participate_button"
    }

    private var shouldShowParticipateCTA: Bool {
        !shouldShowActiveBroadcastSection
            && !resolvedStart.isCompletedStatus
            && !isMissingEstimatedStart
            && !shouldHideParticipateCTAForOtherActiveBroadcast
    }

    private var shouldShowRehearsalAutoStopMessage: Bool {
        metricsUploader.lastStopReason == .rehearsalTimeLimitReached
            && metricsUploader.lastStoppedSession?.startId == currentStartIdentifier
    }

    private var shouldShowSetStartTimeCTA: Bool {
        !resolvedStart.isCompletedStatus
    }

    private var activeRehearsalNotificationKey: String {
        guard let session = activeRehearsalSession else {
            return "inactive"
        }
        return [
            session.startEntryId,
            session.startId ?? "",
            String(session.startedAt.timeIntervalSince1970)
        ].joined(separator: "|")
    }

    var body: some View {
        ScreenContainer(showBack: true, title: Text("start_title")) {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        Text(resolvedStart.name ?? raceSummary.race.nameOrFallback)
                            .font(AppFont.textStyle(.title2, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()

                        ScrollView {
                            VStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 16) {
                                    startTimingMetadataRow

                                    LabeledContent {
                                        Text(LocalizedStringKey(resolvedStart.localizedStatusKey))
                                    } label: {
                                        Text("race_status_label")
                                            .foregroundStyle(.secondary)
                                    }

                                    if let description = resolvedStart.description, !description.isEmpty {
                                        Text(description)
                                            .padding(.top, 8)
                                    }
                                }
                                .padding(.horizontal)

                                if shouldShowActiveBroadcastSection {
                                    activeBroadcastSection
                                } else if resolvedStart.isCompletedStatus {
                                    unavailableState(messageKey: "start_detail_completed_message")
                                } else if isMissingEstimatedStart {
                                    unavailableState(messageKey: "participate_estimated_start_required_hint")
                                } else if shouldHideParticipateCTAForOtherActiveBroadcast {
                                    EmptyView()
                                } else {
                                    Button(action: handleParticipateTap) {
                                        Text(primaryActionKey)
                                            .font(AppUI.buttonFont)
                                            .frame(maxWidth: .infinity)
                                            .frame(minHeight: AppUI.primaryButtonHeight)
                                    }
                                    .accessibilityIdentifier("start_detail_participate_button")
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppUI.brandPrimary)
                                    .padding(.horizontal)

                                    if shouldShowRehearsalAutoStopMessage {
                                        unavailableState(messageKey: "start_detail_rehearsal_autostop_message")
                                    }
                                }

                                if shouldShowSetStartTimeCTA {
                                    Button(action: handleSetStartTimeTap) {
                                        RaceManagerButtonLabel("set_start_time_title")
                                    }
                                    .accessibilityIdentifier("start_detail_set_start_time_button")
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Theme.RaceManager.primaryColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Sizing.primaryButtonHeight / 2, style: .continuous)
                                            .stroke(Theme.RaceManager.primaryColor, lineWidth: 1.5)
                                    )
                                    .padding(.horizontal)
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("race_course_header")
                                        .font(AppFont.textStyle(.headline))
                                        .padding(.horizontal)

                                    if !courseItems.isEmpty {
                                        CourseTimelineView(
                                            items: courseItems,
                                            activeItemId: $activeCourseItemId,
                                            activeSubIndexByItemId: $activeLineSubIndexByItemId,
                                            onPositionSelected: { selection in
                                                handleCoursePositionSelection(selection)
                                            },
                                            onEditSelected: { itemId in
                                                handleEditSelected(itemId: itemId)
                                            },
                                            onAddAfter: { itemId in
                                                handleAddAfter(itemId: itemId)
                                            }
                                        )
                                    } else if isCourseLoading {
                                        ProgressView()
                                            .padding()
                                    } else if isCourseLoaded {
                                        emptyCourseState
                                    }
                                }
                                .padding(.top, 16)
                            }
                            .padding(.bottom, 24)
                        }
                        .accessibilityIdentifier("start_detail_screen")
                    }

                    if showTemplatePicker {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture { dismissTemplatePicker() }

                        templatePickerOverlay(in: geometry)
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                            .zIndex(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .coordinateSpace(name: Self.templatePickerCoordinateSpace)
                .onPreferenceChange(TemplatePickerButtonFramePreferenceKey.self) { frame in
                    templateButtonFrame = frame
                }
            }
        }
        .alert(
            Text("broadcast_stop_confirm_title"),
            isPresented: $showStopConfirmation
        ) {
            Button("broadcast_stop_confirm_yes", role: .destructive) {
                metricsUploader.stopBroadcast()
            }
            Button("broadcast_stop_confirm_no", role: .cancel) {}
        } message: {
            Text("broadcast_stop_confirm_message")
        }
        .task(id: resolvedStart.id + (resolvedStart.status ?? "")) {
            stopBroadcastIfCompletedForCurrentStart()
        }
        .task(id: storageScopeKey) {
            await loadStoredManageAccess()
            await loadStoredParticipationAccess()
        }
        .task(id: courseReloadTaskKey) {
            await loadCourse()
        }
        .task(id: activeRehearsalNotificationKey) {
            syncRehearsalNotification()
        }
        .sheet(isPresented: $showParticipationCodeModal) {
            CodeEntryView(
                titleKey: "participate_code_modal_title",
                messageKey: "participate_code_modal_message",
                verifyButtonKey: "participate_code_verify_button",
                cancelButtonKey: "actions_cancel",
                accentColor: AppUI.brandPrimary,
                onVerify: { code in
                    try await accessService.exchangeCodeForToken(code)
                },
                onSuccess: { token in
                    participationStorage.saveToken(
                        token: token,
                        startId: currentStartIdentifier,
                        raceId: raceIdentifier,
                        seriesId: seriesIdentifier
                    )
                    showParticipationCodeModal = false

                    Task {
                        await loadStoredParticipationAccess()
                        await MainActor.run {
                            onParticipate()
                        }
                    }
                },
                onCancel: {
                    showParticipationCodeModal = false
                }
            )
        }
        .sheet(isPresented: $showCodeModal) {
            CodeEntryView(
                titleKey: "set_start_time_manage_code_title",
                messageKey: "set_start_time_manage_code_message",
                verifyButtonKey: "set_start_time_manage_code_verify_button",
                cancelButtonKey: "actions_cancel",
                accentColor: Theme.RaceManager.primaryColor,
                onVerify: { code in
                    try await accessService.exchangeManageCodeForToken(code)
                },
                onSuccess: { token in
                    storage.saveToken(
                        token: token,
                        startId: currentStartIdentifier,
                        raceId: raceIdentifier,
                        seriesId: seriesIdentifier
                    )
                    showCodeModal = false

                    let pendingTemplate = pendingTemplateSelection
                    let pendingEditTarget = pendingCourseItemEditTarget
                    let pendingManageNavigation = pendingManageNavigationTarget

                    Task {
                        await loadStoredManageAccess()

                        if let pendingTemplate {
                            await MainActor.run {
                                pendingTemplateSelection = nil
                            }
                            await copyTemplateToStart(pendingTemplate)
                        } else if let pendingEditTarget {
                            await MainActor.run {
                                pendingCourseItemEditTarget = nil
                                courseItemEditTarget = pendingEditTarget
                            }
                        } else if let pendingManageNavigation {
                            await MainActor.run {
                                pendingManageNavigationTarget = nil
                                performManageProtectedNavigation(pendingManageNavigation)
                            }
                        }
                    }
                },
                onCancel: {
                    pendingCourseItemEditTarget = nil
                    pendingManageNavigationTarget = nil
                    showCodeModal = false
                }
            )
        }
        .sheet(item: $courseItemEditTarget) { target in
            courseItemEditSheet(for: target)
        }
        .onDisappear {
            dismissRehearsalNotificationIfNeeded()
        }
    }

    @ViewBuilder
    private func templatePickerOverlay(in geometry: GeometryProxy) -> some View {
        let layout = templatePickerLayout(in: geometry)

        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(courseTemplates.enumerated()), id: \.element.id) { index, template in
                        Button {
                            dismissTemplatePicker()
                            Task { await copyTemplateToStart(template) }
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                Text(templateSelectionTitle(for: template))
                                    .font(AppFont.textStyle(.body))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight, alignment: .leading)
                            .background(Theme.Colors.surfacePrimary)
                        }
                        .buttonStyle(.plain)

                        if index < courseTemplates.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .frame(height: layout.height)
        }
        .frame(width: layout.width, alignment: .leading)
        .background(Theme.Colors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.materialCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.materialCard, style: .continuous)
                .stroke(Theme.RaceManager.primaryColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(Theme.Effects.floatingStatusShadowOpacity * 0.35),
            radius: Theme.Effects.floatingStatusShadowRadius,
            x: 0,
            y: Theme.Effects.floatingStatusShadowYOffset
        )
        .offset(x: layout.origin.x, y: layout.origin.y)
    }

    @ViewBuilder
    private var activeBroadcastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                showStopConfirmation = true
            } label: {
                Text("broadcast_stop_button")
                    .font(AppUI.buttonFont)
                    .frame(maxWidth: .infinity, minHeight: AppUI.primaryButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.destructive)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var emptyCourseState: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isTemplateLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("start_detail_course_template_loading")
                        .font(AppFont.textStyle(.footnote))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            if let templateLoadError, !templateLoadError.isEmpty {
                Text(templateLoadError)
                    .font(AppFont.textStyle(.footnote))
                    .foregroundStyle(Theme.Colors.error)
            }

            if let templateCopyError, !templateCopyError.isEmpty {
                Text(templateCopyError)
                    .font(AppFont.textStyle(.footnote))
                    .foregroundStyle(Theme.Colors.error)
            }

            if !isTemplateLoading && courseTemplates.isEmpty {
                Text("start_detail_course_template_empty")
                    .font(AppFont.textStyle(.footnote))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if canShowTemplateSelection && !courseTemplates.isEmpty {
                SplitActionButton(
                    variant: .outlined(accentColor: Theme.RaceManager.primaryColor),
                    isEnabled: !isTemplateCopying,
                    isExpanded: showTemplatePicker,
                    onPrimaryTap: {
                        toggleTemplatePicker()
                    },
                    onSecondaryTap: {
                        toggleTemplatePicker()
                    }
                ) {
                    HStack {
                        Spacer()
                        if isTemplateCopying {
                            ProgressView()
                                .tint(Theme.RaceManager.primaryColor)
                        } else {
                            Text("start_detail_course_template_button")
                                .font(Theme.Typography.button)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: TemplatePickerButtonFramePreferenceKey.self,
                            value: geometry.frame(in: .named(Self.templatePickerCoordinateSpace))
                        )
                    }
                )
            }
        }
        .padding(.horizontal)
    }

    private func rehearsalActiveMessage(at referenceDate: Date) -> String {
        let baseText = rehearsalDeepLinkedMarkdown(
            NSLocalizedString("start_detail_rehearsal_active_message", comment: "")
        )
        let delayReminder = NSLocalizedString("participate_rehearsal_delay_reminder", comment: "")
        let autoStopReminder = NSLocalizedString("participate_rehearsal_autostop", comment: "")
        guard let secondsRemaining = rehearsalDelaySecondsRemaining(at: referenceDate) else {
            return [baseText, delayReminder, autoStopReminder].joined(separator: "\n\n")
        }

        let countdownFormat = rehearsalDeepLinkedMarkdown(
            NSLocalizedString("start_detail_rehearsal_active_message_countdown", comment: "")
        )
        let countdownMessage = String.localizedStringWithFormat(countdownFormat, secondsRemaining)
        return [countdownMessage, delayReminder, autoStopReminder].joined(separator: "\n\n")
    }

    private func syncRehearsalNotification() {
        guard activeRehearsalSession != nil else {
            dismissRehearsalNotificationIfNeeded()
            return
        }

        rehearsalNotificationId = userNotifications.showLiveMarkdown(
            severity: .info,
            autoHideDuration: 35,
            messageBuilder: { referenceDate in
                rehearsalActiveMessage(at: referenceDate)
            }
        )
    }

    private func dismissRehearsalNotificationIfNeeded() {
        guard let rehearsalNotificationId else { return }
        userNotifications.dismiss(id: rehearsalNotificationId)
        self.rehearsalNotificationId = nil
    }

    private func loadCourse() async {
        guard let startId = resolvedStart.rawId else { return }
        isCourseLoading = true
        isCourseLoaded = false
        templateCopyError = nil
        do {
            let response = try await raceService.fetchStartDetail(startId: startId)
            if let course = response.course {
                loadedCourse = course
                courseItems = CourseTimelineItem.buildTimeline(from: course)
                courseTemplates = []
                templateLoadError = nil
                pruneCourseTimelineUIState()
            } else {
                loadedCourse = nil
                courseItems = []
                activeCourseItemId = nil
                activeLineSubIndexByItemId = [:]
                await loadCourseTemplatesIfNeeded(force: true)
            }
        } catch {
            loadedCourse = nil
            courseItems = []
            activeCourseItemId = nil
            activeLineSubIndexByItemId = [:]
            courseTemplates = []
            templateLoadError = nil
        }
        isCourseLoading = false
        isCourseLoaded = true
    }

    private func loadCourseTemplatesIfNeeded(force: Bool) async {
        guard let seriesIdentifier, !seriesIdentifier.isEmpty else {
            courseTemplates = []
            templateLoadError = NSLocalizedString("start_detail_course_template_empty", comment: "")
            return
        }
        if isTemplateLoading {
            return
        }
        if !force && !courseTemplates.isEmpty {
            return
        }

        isTemplateLoading = true
        templateLoadError = nil
        defer { isTemplateLoading = false }

        do {
            let templates = try await raceService.fetchCourseTemplates(seriesId: seriesIdentifier)
            courseTemplates = templates.sorted { lhs, rhs in
                courseTemplateDisplayName(lhs).localizedCaseInsensitiveCompare(courseTemplateDisplayName(rhs)) == .orderedAscending
            }
        } catch {
            courseTemplates = []
            templateLoadError = error.localizedDescription.isEmpty
                ? NSLocalizedString("start_detail_course_template_error", comment: "")
                : error.localizedDescription
        }
    }

    private func loadStoredManageAccess() async {
        guard let tokenRecord = storage.loadToken(for: currentStartIdentifier, raceId: raceIdentifier, seriesId: seriesIdentifier) else {
            storedToken = nil
            storedScope = nil
            storedScopeId = nil
            return
        }

        storedToken = tokenRecord.token
        storedScope = tokenRecord.scope
        storedScopeId = tokenRecord.scopeId
    }

    private func loadStoredParticipationAccess() async {
        if let tokenRecord = participationStorage.loadToken(for: currentStartIdentifier, raceId: raceIdentifier, seriesId: seriesIdentifier) {
            storedParticipationToken = tokenRecord.token
            storedParticipationScope = tokenRecord.scope
            storedParticipationScopeId = tokenRecord.scopeId
            return
        }

        storedParticipationToken = nil
        storedParticipationScope = nil
        storedParticipationScopeId = nil
    }

    private func copyTemplateToStart(_ template: RaceCourse) async {
        guard let startId = resolvedStart.rawId else {
            templateCopyError = NSLocalizedString("start_detail_course_template_copy_error", comment: "")
            return
        }
        guard hasReusableToken, let storedToken else {
            pendingTemplateSelection = template
            showCodeModal = true
            return
        }

        isTemplateCopying = true
        templateCopyError = nil
        defer { isTemplateCopying = false }

        do {
            let copiedCourse = try await raceService.copyCourseTemplateToStart(
                startId: startId,
                templateCourseId: template.id,
                accessToken: storedToken,
                name: normalizedOptionalText(template.name),
                description: normalizedOptionalText(template.description)
            )
            loadedCourse = copiedCourse
            courseItems = CourseTimelineItem.buildTimeline(from: copiedCourse)
            isCourseLoaded = true
            dismissTemplatePicker()
            activeCourseItemId = nil
            activeLineSubIndexByItemId = [:]
            courseTemplates = []
            templateLoadError = nil
            viewModel.requestCourseRefresh(for: startId)
            userNotifications.show(
                message: NSLocalizedString("start_detail_course_template_copy_success", comment: ""),
                severity: .success
            )
        } catch {
            templateCopyError = error.localizedDescription.isEmpty
                ? NSLocalizedString("start_detail_course_template_copy_error", comment: "")
                : error.localizedDescription
        }
    }

    private func handleParticipateTap() {
        guard hasReusableParticipationToken else {
            showParticipationCodeModal = true
            return
        }

        onParticipate()
    }

    private func handleSetStartTimeTap() {
        requestManageProtectedNavigation(.setStartTime)
    }

    private func requestManageProtectedNavigation(_ target: ManageProtectedNavigationTarget) {
        guard hasReusableToken else {
            pendingManageNavigationTarget = target
            showCodeModal = true
            return
        }

        performManageProtectedNavigation(target)
    }

    private func performManageProtectedNavigation(_ target: ManageProtectedNavigationTarget) {
        switch target {
        case .setStartTime:
            onSetStartTime()
        case let .setPosition(positionTarget):
            onSetPositionTarget(positionTarget)
        }
    }

    private func handleCoursePositionSelection(_ selection: CoursePositionSelection) {
        guard let course = loadedCourse else { return }
        guard let target = setPositionTarget(from: selection, in: course) else { return }
        requestManageProtectedNavigation(.setPosition(target))
    }

    private func setPositionTarget(from selection: CoursePositionSelection, in course: RaceCourse) -> SetPositionTarget? {
        switch selection {
        case let .mark(markId):
            guard let mark = course.course_marks.first(where: { $0.id == markId }) else {
                return nil
            }
            return .mark(
                CourseMarkPositionTarget(
                    markId: mark.id,
                    name: mark.name ?? "",
                    description: mark.description,
                    roundingSide: mark.rounding_side,
                    type: mark.type,
                    status: mark.status
                )
            )

        case let .startLineEndpoint(lineId, side):
            guard let line = course.start_line, line.id == lineId else {
                return nil
            }
            return .startLine(lineTarget(from: line), side: side)

        case let .finishLineEndpoint(lineId, side):
            guard let line = course.finish_line, line.id == lineId else {
                return nil
            }
            return .finishLine(lineTarget(from: line), side: side)
        }
    }

    private func lineTarget(from line: CourseLine) -> CourseLinePositionTarget {
        CourseLinePositionTarget(
            lineId: line.id,
            name: line.name ?? "",
            description: line.description,
            status: line.status,
            markLeft: coordinatePoint(lat: line.mark_left_lat, lon: line.mark_left_lon),
            markRight: coordinatePoint(lat: line.mark_right_lat, lon: line.mark_right_lon)
        )
    }

    private func coordinatePoint(lat: Double?, lon: Double?) -> CoordinatePoint? {
        guard let lat, let lon else { return nil }
        return CoordinatePoint(lat: lat, lon: lon)
    }

    private func courseTemplateDisplayName(_ template: RaceCourse) -> String {
        let trimmed = template.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty
            ? NSLocalizedString("start_detail_course_template_unnamed", comment: "")
            : trimmed
    }

    private func templateSelectionTitle(for template: RaceCourse) -> String {
        let name = courseTemplateDisplayName(template)
        guard let lengthLabel = templateLengthLabel(for: template) else {
            return name
        }
        return "\(name) · \(lengthLabel)"
    }

    private func templateLengthLabel(for template: RaceCourse) -> String? {
        if let nauticalMiles = template.total_length_nm, nauticalMiles.isFinite {
            return String(
                format: NSLocalizedString("start_detail_course_template_length_nm_format", comment: ""),
                nauticalMiles
            )
        }
        if let meters = template.total_length_m, meters.isFinite {
            if meters >= 1000 {
                return String(
                    format: NSLocalizedString("start_detail_course_template_length_km_format", comment: ""),
                    meters / 1000
                )
            }
            return String(
                format: NSLocalizedString("start_detail_course_template_length_m_format", comment: ""),
                meters
            )
        }
        return nil
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func toggleTemplatePicker() {
        guard !courseTemplates.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            showTemplatePicker.toggle()
        }
    }

    private func dismissTemplatePicker() {
        guard showTemplatePicker else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            showTemplatePicker = false
        }
    }

    private func templatePickerLayout(in geometry: GeometryProxy) -> TemplatePickerLayout {
        let horizontalInset: CGFloat = 16
        let topInset: CGFloat = 8
        let bottomInset = max(12, geometry.safeAreaInsets.bottom + 8)
        let preferredSpacing: CGFloat = 8
        let rowHeight = Theme.Sizing.primaryButtonHeight
        let contentHeight = CGFloat(courseTemplates.count) * rowHeight
        let maxHeight = max(120, geometry.size.height - topInset - bottomInset)
        let height = min(contentHeight, maxHeight)
        let width = max(220, templateButtonFrame.width > 0 ? templateButtonFrame.width : geometry.size.width - (horizontalInset * 2))
        let maxOriginX = max(horizontalInset, geometry.size.width - horizontalInset - width)
        let originX = min(max(horizontalInset, templateButtonFrame.minX), maxOriginX)
        let preferredOriginY = templateButtonFrame.maxY + preferredSpacing
        let maximumOriginY = geometry.size.height - bottomInset - height
        let originY = max(topInset, min(preferredOriginY, maximumOriginY))
        return TemplatePickerLayout(origin: CGPoint(x: originX, y: originY), width: width, height: height)
    }

    private func pruneCourseTimelineUIState() {
        let validIds = Set(courseItems.map(\.id))
        if let activeCourseItemId, !validIds.contains(activeCourseItemId) {
            self.activeCourseItemId = nil
        }
        activeLineSubIndexByItemId = activeLineSubIndexByItemId.filter { validIds.contains($0.key) }
    }

    private func rehearsalDeepLinkedMarkdown(_ localizedMarkdown: String) -> String {
        let deepLink = rehearsalVerificationURL.absoluteString
        return Self.rehearsalVerificationMarkdownTargets.reduce(localizedMarkdown) { partial, target in
            partial.replacingOccurrences(of: target, with: deepLink)
        }
    }

    private func rehearsalDelaySecondsRemaining(at referenceDate: Date) -> Int? {
        guard let startedAt = activeRehearsalSession?.startedAt else {
            return nil
        }

        let uploadBoundaryDelay = uploadBoundaryDelaySeconds(from: startedAt)
        let visibleAt = startedAt.addingTimeInterval(Self.rehearsalVisibilityDelay + uploadBoundaryDelay)
        let remaining = Int(ceil(visibleAt.timeIntervalSince(referenceDate)))
        return remaining > 0 ? remaining : nil
    }

    private func uploadBoundaryDelaySeconds(from startedAt: Date) -> TimeInterval {
        let cadence = Self.rehearsalUploadCadence
        let remainder = startedAt.timeIntervalSince1970.truncatingRemainder(dividingBy: cadence)
        let normalizedRemainder = remainder >= 0 ? remainder : remainder + cadence
        let delay = cadence - normalizedRemainder
        return delay >= cadence - Self.uploadBoundaryTolerance ? 0 : delay
    }

    // MARK: - Course item edit (S3)

    private func handleEditSelected(itemId: String) {
        guard let course = loadedCourse else { return }
        let courseId = course.id

        // Check if it's a mark.
        if let mark = course.course_marks.first(where: { $0.id == itemId }) {
            presentCourseItemEditor(.mark(mark, courseId: courseId))
            return
        }
        // Check start line.
        if let startLine = course.start_line, startLine.id == itemId {
            presentCourseItemEditor(.startLine(startLine, courseId: courseId))
            return
        }
        // Check finish line.
        if let finishLine = course.finish_line, finishLine.id == itemId {
            presentCourseItemEditor(.finishLine(finishLine, courseId: courseId))
            return
        }
    }

    private func handleAddAfter(itemId: String) {
        guard let course = loadedCourse else { return }
        let courseId = course.id
        // Find the tapped mark's sequence; insert after it.
        if let mark = course.course_marks.first(where: { $0.id == itemId }) {
            presentCourseItemEditor(.addMark(courseId: courseId, afterSequence: mark.sequence + 1))
        }
    }

    private func presentCourseItemEditor(_ target: CourseItemEditTarget) {
        guard hasReusableToken else {
            pendingCourseItemEditTarget = target
            showCodeModal = true
            return
        }

        pendingCourseItemEditTarget = nil
        courseItemEditTarget = target
    }

    @ViewBuilder
    private func courseItemEditSheet(for target: CourseItemEditTarget) -> some View {
        let token = storedToken ?? ""
        switch target {
        case let .mark(item, courseId):
            NavigationStack {
                CourseMarkEditView(
                    mode: .editMark(item, courseId: courseId),
                    accessToken: token
                ) { _ in
                    courseItemEditTarget = nil
                    Task { await reloadCourseAfterEdit() }
                }
            }
        case let .addMark(courseId, afterSequence):
            NavigationStack {
                CourseMarkEditView(
                    mode: .addMark(courseId: courseId, afterSequence: afterSequence),
                    accessToken: token
                ) { _ in
                    courseItemEditTarget = nil
                    Task { await reloadCourseAfterEdit() }
                }
            }
        case let .startLine(line, courseId):
            NavigationStack {
                CourseLineEditView(
                    mode: .editStartLine(line, courseId: courseId),
                    accessToken: token
                ) { _ in
                    courseItemEditTarget = nil
                    Task { await reloadCourseAfterEdit() }
                }
            }
        case let .finishLine(line, courseId):
            NavigationStack {
                CourseLineEditView(
                    mode: .editFinishLine(line, courseId: courseId),
                    accessToken: token
                ) { _ in
                    courseItemEditTarget = nil
                    Task { await reloadCourseAfterEdit() }
                }
            }
        }
    }

    private func reloadCourseAfterEdit() async {
        isCourseLoaded = false
        isCourseLoading = true
        loadedCourse = nil
        courseItems = []
        activeCourseItemId = nil
        activeLineSubIndexByItemId = [:]
        await loadCourse()
        if let startId = resolvedStart.rawId {
            viewModel.requestCourseRefresh(for: startId)
        }
    }

    private func unavailableState(messageKey: LocalizedStringKey) -> some View {
        Text(messageKey)
            .font(AppFont.textStyle(.subheadline))
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
    }

    @ViewBuilder
    private var startTimingMetadataRow: some View {
        if resolvedStart.actualStartDate != nil {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                actualStartMetadataRow(for: viewModel.actualStartHeaderState(for: resolvedStart, now: context.date))
            }
        } else {
            LabeledContent {
                Text(viewModel.formattedStartTime(for: resolvedStart) ?? "—")
            } label: {
                Text("race_date_label")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func actualStartMetadataRow(for state: ActualStartHeaderState) -> some View {
        switch state {
        case let .scheduled(timeText):
            LabeledContent {
                Text(timeText ?? "—")
            } label: {
                Text("race_date_label")
                    .foregroundStyle(.secondary)
            }
        case let .countdown(timeToStartText):
            LabeledContent {
                Text(timeToStartText)
                    .monospacedDigit()
            } label: {
                Text("start_detail_time_to_start_label")
                    .foregroundStyle(.secondary)
            }
        case let .started(actualLocalTimeText):
            LabeledContent {
                Text(actualLocalTimeText)
            } label: {
                Text("start_detail_started_label")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stopBroadcastIfCompletedForCurrentStart() {
        guard resolvedStart.isCompletedStatus, activeSessionMatchesCurrentStart, metricsUploader.isBroadcasting else {
            return
        }
        metricsUploader.stopBroadcast(reason: .completedStart)
    }

}

// MARK: - CourseItemEditTarget

/// Identifies which course item (and which edit mode) the sheet should open.
enum CourseItemEditTarget: Identifiable {
    case mark(CourseMarkItem, courseId: String)
    case addMark(courseId: String, afterSequence: Int)
    case startLine(CourseLine, courseId: String)
    case finishLine(CourseLine, courseId: String)

    var id: String {
        switch self {
        case let .mark(item, courseId):
            return "mark|\(courseId)|\(item.id)"
        case let .addMark(courseId, afterSequence):
            return "addMark|\(courseId)|\(afterSequence)"
        case let .startLine(line, courseId):
            return "startLine|\(courseId)|\(line.id)"
        case let .finishLine(line, courseId):
            return "finishLine|\(courseId)|\(line.id)"
        }
    }
}

private struct TemplatePickerLayout {
    let origin: CGPoint
    let width: CGFloat
    let height: CGFloat
}

private struct TemplatePickerButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}
