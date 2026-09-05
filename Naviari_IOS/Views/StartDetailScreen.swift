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
    var onShowTimer: () -> Void
    var onSetPositionTarget: (SetPositionTarget) -> Void
    @StateObject private var buoyViewModel: BuoySectionViewModel
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
    @State private var showCourseChangeConfirmation = false
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
    @State private var pendingBuoyManageAction: PendingBuoyManageAction?
    @State private var pendingManageNavigationTarget: ManageProtectedNavigationTarget?
    @State private var rehearsalNotificationId: UUID?
    @State private var courseItemEditTarget: CourseItemEditTarget?
    @State private var buoySetPositionTarget: BuoyRecord?
    @State private var preferredActiveCourseItemIdAfterEdit: String?

    @EnvironmentObject private var userNotifications: UserNotifications

    private let accessService = ParticipationService()
    private let storage = ManageAccessStorage.shared
    private let participationStorage = ParticipationStorage.shared
    private let raceService = RaceService()

    init(
        raceSummary: RaceSummary,
        start: RaceStart,
        onParticipate: @escaping () -> Void,
        onSetStartTime: @escaping () -> Void,
        onShowTimer: @escaping () -> Void,
        onSetPositionTarget: @escaping (SetPositionTarget) -> Void
    ) {
        self.raceSummary = raceSummary
        self.start = start
        self.onParticipate = onParticipate
        self.onSetStartTime = onSetStartTime
        self.onShowTimer = onShowTimer
        self.onSetPositionTarget = onSetPositionTarget
        let buoyRaceId = raceSummary.race.rawId ?? raceSummary.race.slug ?? raceSummary.id
        _buoyViewModel = StateObject(wrappedValue: BuoySectionViewModel(raceId: buoyRaceId))
    }

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
                                    if resolvedStart.actualStartDate != nil {
                                        SplitActionButton(
                                            variant: .dualOutlined(
                                                primaryColor: Theme.Colors.brandPrimary,
                                                secondaryColor: Theme.RaceManager.primaryColor
                                            ),
                                            secondaryIconName: Theme.RaceManager.iconName,
                                            primaryAccessibilityIdentifier: "start_detail_show_timer_button",
                                            secondaryAccessibilityIdentifier: "start_detail_set_start_time_button",
                                            onPrimaryTap: { onShowTimer() },
                                            onSecondaryTap: handleSetStartTimeTap
                                        ) {
                                            Text("start_detail_show_timer_button")
                                                .font(Theme.Typography.button)
                                        }
                                        .padding(.horizontal)
                                    } else {
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

                                        courseChangeActionSection
                                    } else if isCourseLoading {
                                        ProgressView()
                                            .padding()
                                    } else if isCourseLoaded {
                                        emptyCourseState
                                    }
                                }
                                .padding(.top, 16)

                                VStack(alignment: .leading, spacing: 12) {
                                    BuoySectionView(
                                        titleKey: "buoy_section_title",
                                        buoys: buoyViewModel.buoys,
                                        activeBuoyId: Binding(
                                            get: { buoyViewModel.activeBuoyId },
                                            set: { buoyViewModel.activeBuoyId = $0 }
                                        ),
                                        sectionAccessibilityIdentifier: "start_buoy_section",
                                        addButtonAccessibilityIdentifier: "start_buoy_add_button",
                                        onAddTapped: handleAddBuoy,
                                        onEditBuoy: handleEditBuoy,
                                        onSetCoordinates: handleSetBuoyCoordinates
                                    )
                                    .padding(.horizontal)
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
        .task(id: raceIdentifier ?? raceSummary.id) {
            buoyViewModel.reload()
        }
        .task(id: courseReloadTaskKey) {
            await loadCourse()
        }
        .task(id: activeRehearsalNotificationKey) {
            syncRehearsalNotification()
        }
        .sheet(isPresented: $showParticipationCodeModal) {
            CodeEntryView<String>(
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
                    return nil
                },
                onCancel: {
                    showParticipationCodeModal = false
                }
            )
        }
        .sheet(isPresented: $showCodeModal) {
            manageCodeEntrySheet
        }
        .sheet(item: $courseItemEditTarget) { target in
            courseItemEditSheet(for: target)
        }
        .fullScreenCover(item: $buoySetPositionTarget) { buoy in
            NavigationStack {
                BuoySetPositionScreen(
                    contextTitle: resolvedStart.name ?? raceSummary.race.nameOrFallback,
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
        .onDisappear {
            dismissRehearsalNotificationIfNeeded()
        }
    }

    private var manageCodeEntrySheet: some View {
        CodeEntryView<ManageAccessLoginResult>(
            titleKey: "set_start_time_manage_code_title",
            messageKey: "set_start_time_manage_code_message",
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
                guard managesStartHierarchy(loginResult) else {
                    return pendingTemplateSelection == nil
                        ? "manage_code_scope_invalid_generic"
                        : "manage_code_scope_invalid_start_course"
                }

                storage.save(loginResult: loginResult)
                showCodeModal = false

                let pendingTemplate = pendingTemplateSelection
                let pendingEditTarget = pendingCourseItemEditTarget
                let pendingManageNavigation = pendingManageNavigationTarget
                let pendingBuoyAction = pendingBuoyManageAction

                Task {
                    await loadStoredManageAccess()

                    if let pendingTemplate {
                        if loadedCourse != nil {
                            await MainActor.run {
                                showCourseChangeConfirmation = true
                            }
                        } else {
                            await MainActor.run {
                                pendingTemplateSelection = nil
                            }
                            await copyTemplateToStart(pendingTemplate)
                        }
                    } else if let pendingEditTarget {
                        await MainActor.run {
                            pendingCourseItemEditTarget = nil
                            courseItemEditTarget = pendingEditTarget
                        }
                    } else if let pendingBuoyAction {
                        await MainActor.run {
                            pendingBuoyManageAction = nil
                            performAuthorizedBuoyManageAction(pendingBuoyAction)
                        }
                    } else if let pendingManageNavigation {
                        await MainActor.run {
                            pendingManageNavigationTarget = nil
                            performManageProtectedNavigation(pendingManageNavigation)
                        }
                    }
                }
                return nil
            },
            onCancel: {
                pendingTemplateSelection = nil
                pendingCourseItemEditTarget = nil
                pendingBuoyManageAction = nil
                pendingManageNavigationTarget = nil
                showCodeModal = false
            }
        )
    }

    @ViewBuilder
    private func templatePickerOverlay(in geometry: GeometryProxy) -> some View {
        let layout = templatePickerLayout(in: geometry)

        VStack(spacing: 0) {
            ScrollView {
                CourseTemplatePickerDropdown(
                    templates: courseTemplates,
                    optionIdentifierPrefix: "start_detail_course_template_option_",
                    onTemplateSelected: { template in
                        handleTemplateSelection(template)
                    }
                )
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
                CourseTemplatePickerButton(
                    isEnabled: !isTemplateCopying,
                    isExpanded: showTemplatePicker,
                    isCopying: isTemplateCopying,
                    titleKey: "start_detail_course_template_button",
                    accessibilityIdentifier: "start_detail_course_template_picker_button",
                    onTap: toggleTemplatePicker
                )
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

    @ViewBuilder
    private var courseChangeActionSection: some View {
        if loadedCourse != nil && canShowTemplateSelection {
            VStack(alignment: .leading, spacing: 12) {
                CourseTemplatePickerButton(
                    isEnabled: !isTemplateLoading && !isTemplateCopying && !courseTemplates.isEmpty,
                    isExpanded: showTemplatePicker,
                    isCopying: isTemplateLoading || isTemplateCopying,
                    titleKey: "start_detail_course_change_button",
                    accessibilityIdentifier: "start_detail_course_change_button",
                    onTap: toggleTemplatePicker
                )
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: TemplatePickerButtonFramePreferenceKey.self,
                            value: geometry.frame(in: .named(Self.templatePickerCoordinateSpace))
                        )
                    }
                )
                .accessibilityHint(Text("start_detail_course_change_confirm_message"))

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
            }
            .padding(.horizontal)
            .alert(
                Text("start_detail_course_change_confirm_title"),
                isPresented: $showCourseChangeConfirmation
            ) {
                Button("actions_cancel", role: .cancel) {
                    pendingTemplateSelection = nil
                }
                Button("start_detail_course_change_confirm_action", role: .destructive) {
                    confirmPendingTemplateChange()
                }
            } message: {
                Text("start_detail_course_change_confirm_message")
            }
        }
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
                templateLoadError = nil
                pruneCourseTimelineUIState()
                await loadCourseTemplatesIfNeeded(force: false)
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

    private func managesStartHierarchy(_ loginResult: ManageAccessLoginResult) -> Bool {
        switch loginResult.scope {
        case .start:
            return loginResult.scopeId == currentStartIdentifier
        case .race:
            return loginResult.scopeId == raceIdentifier
        case .series:
            return loginResult.scopeId == seriesIdentifier
        }
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
        showCourseChangeConfirmation = false
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
            templateLoadError = nil
            pendingTemplateSelection = nil
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

    private func handleTemplateSelection(_ template: RaceCourse) {
        dismissTemplatePicker()

        guard loadedCourse != nil else {
            Task { await copyTemplateToStart(template) }
            return
        }

        pendingTemplateSelection = template

        guard hasReusableToken else {
            showCodeModal = true
            return
        }

        showCourseChangeConfirmation = true
    }

    private func confirmPendingTemplateChange() {
        guard let pendingTemplateSelection else { return }
        Task {
            await MainActor.run {
                self.pendingTemplateSelection = nil
            }
            await copyTemplateToStart(pendingTemplateSelection)
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
        guard hasReusableToken else {
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
        if let afterSequence = courseAddMarkInsertionSequence(after: itemId, in: course) {
            presentCourseItemEditor(.addMark(courseId: courseId, afterSequence: afterSequence))
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
                    accessToken: token,
                    buoyOptions: buoyViewModel.buoys
                ) { outcome in
                    let successMessageKey = courseItemSaveSuccessMessageKey(for: target, outcome: outcome)
                    courseItemEditTarget = nil
                    Task { await reloadCourseAfterEdit(outcome: outcome, successMessageKey: successMessageKey) }
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
                    Task { await reloadCourseAfterEdit(outcome: outcome, successMessageKey: successMessageKey) }
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
                    Task { await reloadCourseAfterEdit(outcome: outcome, successMessageKey: successMessageKey) }
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
                    Task { await reloadCourseAfterEdit(outcome: outcome, successMessageKey: successMessageKey) }
                }
            }
        }
    }

    private func reloadCourseAfterEdit(outcome: CourseItemSaveOutcome, successMessageKey: String?) async {
        switch outcome {
        case let .saved(activeItemId):
            preferredActiveCourseItemIdAfterEdit = activeItemId
        case .removed:
            preferredActiveCourseItemIdAfterEdit = nil
        }

        isCourseLoaded = false
        isCourseLoading = true
        loadedCourse = nil
        courseItems = []
        activeCourseItemId = nil
        activeLineSubIndexByItemId = [:]
        await loadCourse()
        if let preferredActiveCourseItemIdAfterEdit,
           courseItems.contains(where: { $0.id == preferredActiveCourseItemIdAfterEdit }) {
            activeCourseItemId = preferredActiveCourseItemIdAfterEdit
        }
        preferredActiveCourseItemIdAfterEdit = nil
        if let startId = resolvedStart.rawId {
            viewModel.requestCourseRefresh(for: startId)
        }
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
