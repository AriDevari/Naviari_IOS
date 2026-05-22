import SwiftUI

/// Set-start-time flow with manage-code gate and manual time submission.
struct SetStartTimeScreen: View {
    private static let utcFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    enum Tab: CaseIterable, Identifiable {
        case setTime
        case timer

        var id: Self { self }

        var titleKey: LocalizedStringKey {
            switch self {
            case .setTime:
                return "set_start_time_tab_manual"
            case .timer:
                return "set_start_time_tab_timer"
            }
        }
    }

    let raceSummary: RaceSummary
    let start: RaceStart

    @State private var selectedTab: Tab = .setTime

    // Manage-code gate state
    @State private var showCodeModal = false
    @State private var storedToken: String?
    @State private var storedScope: ManageAccessScope?
    @State private var storedScopeId: String?

    // Manual tab state
    @State private var selectedHour = 0
    @State private var selectedMinute = 0
    @State private var selectedDateBase = Date()
    @State private var manualStateInitialized = false
    @State private var manualSubmitError: String?

    // Timer tab state
    @State private var timerDurationMinutes = 5
    @State private var timerSubmitError: String?

    // Reset state
    @State private var showResetConfirmation = false
    @State private var resetError: String?

    // Info help state
    @State private var showInfo = false

    private let accessService = ParticipationService()
    private let storage = ManageAccessStorage.shared

    // Oversized fonts/targets for harsh-condition usability
    private let largeMetricFont = AppFont.fixed(96, weight: .semibold)
    private let largeButtonTouchSize: CGFloat = 88
    private let largeButtonVisualHeight: CGFloat = 66

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userNotifications: UserNotifications
    @EnvironmentObject private var viewModel: RaceBrowserViewModel

    var body: some View {
        ScreenContainer(
            showBack: true,
            title: Text("set_start_time_title"),
            trailing: AnyView(
                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(Theme.Typography.iconLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            )
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(start.name ?? raceSummary.race.nameOrFallback)
                        .font(AppFont.textStyle(.headline))

                    Picker("set_start_time_mode_label", selection: $selectedTab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.titleKey).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedTab == .setTime {
                        manualTabContent
                    } else {
                        timerTabContent
                    }
                }
                .padding()
            }
            .accessibilityIdentifier("set_start_time_screen")
        }
        .sheet(isPresented: $showInfo) {
            SetStartTimeInfoView(
                titleKey: "set_start_time_info_title",
                bodyKey: selectedTab == .setTime
                    ? "set_start_time_info_body_manual"
                    : "set_start_time_info_body_timer"
            )
        }
        .sheet(isPresented: $showCodeModal) {
            CodeEntryView(
                titleKey: "set_start_time_manage_code_title",
                messageKey: "set_start_time_manage_code_message",
                verifyButtonKey: "set_start_time_manage_code_verify_button",
                cancelButtonKey: "back_button",
                accentColor: AppUI.brandPrimary,
                onVerify: { code in
                    try await accessService.exchangeManageCodeForToken(code)
                },
                onSuccess: { token in
                    storage.saveToken(
                        token: token,
                        startId: startIdentifier,
                        raceId: raceIdentifier,
                        seriesId: seriesIdentifier
                    )
                    showCodeModal = false
                    manualSubmitError = nil
                    timerSubmitError = nil
                    Task { await loadStoredManageAccess() }
                },
                onCancel: {
                    showCodeModal = false
                }
            )
        }
        .alert(
            Text("set_start_time_reset_confirm_title"),
            isPresented: $showResetConfirmation
        ) {
            Button(role: .destructive) {
                Task { await performReset() }
            } label: {
                Text("set_start_time_reset_confirm_action")
            }
            Button(role: .cancel) {} label: {
                Text("actions_cancel")
            }
        } message: {
            Text("set_start_time_reset_confirm_message")
        }
        .task(id: storageScopeKey) {
            await loadStoredManageAccess()
            showCodeModal = !hasReusableToken
            initializeManualStateIfNeeded()
        }
    }

    private var startIdentifier: String? {
        start.rawId ?? start.slug
    }

    private var raceIdentifier: String? {
        raceSummary.race.rawId ?? raceSummary.race.slug
    }

    private var seriesIdentifier: String? {
        raceSummary.seriesId
    }

    private var storageScopeKey: String {
        [startIdentifier ?? "", raceIdentifier ?? "", seriesIdentifier ?? ""].joined(separator: "|")
    }

    private var hasReusableToken: Bool {
        storedToken != nil && storedTokenIsValid
    }

    private var storedTokenIsValid: Bool {
        guard let scope = storedScope, let scopeId = storedScopeId else { return false }
        switch scope {
        case .start:
            return scopeId == startIdentifier
        case .race:
            return scopeId == raceIdentifier
        case .series:
            return scopeId == seriesIdentifier
        }
    }

    private var hasExistingActualTime: Bool {
        start.actualStartDate != nil
    }

    private var isSubmittingManualTime: Bool {
        viewModel.isSubmittingActualStart
    }

    private var isSubmittingTimerTime: Bool {
        viewModel.isSubmittingActualStart
    }

    private var timerPreviewDate: Date {
        RaceStart.actualStartDateFromTimer(minutes: timerDurationMinutes, referenceDate: Date())
    }

    private var timerPreviewTimeText: String {
        DateFormattingHelper.localizedHourMinute(from: timerPreviewDate)
    }



    @ViewBuilder
    private var manualTabContent: some View {
        VStack(spacing: 24) {
            // Date context label
            Text(DateFormattingHelper.localizedTodayDate(from: selectedDateBase))
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Two-column stepper layout: Hours : Minutes
            HStack(alignment: .center, spacing: 4) {
                // Hours column
                VStack(spacing: 6) {
                    Button(action: { adjustHour(by: 1) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(Theme.Typography.iconLarge)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: largeButtonTouchSize, minHeight: largeButtonVisualHeight)
                    .contentShape(Rectangle().size(width: largeButtonTouchSize, height: largeButtonTouchSize))
                    .accessibilityLabel(NSLocalizedString("set_start_time_increase_hours", comment: "Increase hours"))

                    Text(String(format: "%02d", selectedHour))
                        .font(largeMetricFont)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Button(action: { adjustHour(by: -1) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(Theme.Typography.iconLarge)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: largeButtonTouchSize, minHeight: largeButtonVisualHeight)
                    .contentShape(Rectangle().size(width: largeButtonTouchSize, height: largeButtonTouchSize))
                    .accessibilityLabel(NSLocalizedString("set_start_time_decrease_hours", comment: "Decrease hours"))
                }

                // Colon
                Text(":")
                    .font(largeMetricFont)
                    .foregroundStyle(Theme.Colors.textPrimary)

                // Minutes column
                VStack(spacing: 6) {
                    Button(action: { adjustMinute(by: 1) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(Theme.Typography.iconLarge)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: largeButtonTouchSize, minHeight: largeButtonVisualHeight)
                    .contentShape(Rectangle().size(width: largeButtonTouchSize, height: largeButtonTouchSize))
                    .accessibilityLabel(NSLocalizedString("set_start_time_increase_minutes", comment: "Increase minutes"))

                    Text(String(format: "%02d", selectedMinute))
                        .font(largeMetricFont)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Button(action: { adjustMinute(by: -1) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(Theme.Typography.iconLarge)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: largeButtonTouchSize, minHeight: largeButtonVisualHeight)
                    .contentShape(Rectangle().size(width: largeButtonTouchSize, height: largeButtonTouchSize))
                    .accessibilityLabel(NSLocalizedString("set_start_time_decrease_minutes", comment: "Decrease minutes"))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: NSLocalizedString("set_start_time_time_accessibility", comment: ""), selectedHour, selectedMinute))

            if let manualSubmitError {
                Text(manualSubmitError)
                    .foregroundStyle(Theme.Colors.error)
                    .font(AppFont.textStyle(.footnote))
            }

            Button {
                Task { await submitManualTime() }
            } label: {
                if isSubmittingManualTime {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight)
                } else {
                    RaceManagerButtonLabel("set_start_time_set_button")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.RaceManager.primaryColor)
            .disabled(isSubmittingManualTime)

            if hasExistingActualTime {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Text("set_start_time_reset_button")
                        .font(Theme.Typography.button)
                }
                .disabled(viewModel.isSubmittingActualStart)
            }

            if let resetError {
                Text(resetError)
                    .foregroundStyle(Theme.Colors.error)
                    .font(AppFont.textStyle(.footnote))
            }
        }
        .padding()
    }



    @ViewBuilder
    private var timerTabContent: some View {
        VStack(spacing: 24) {
            // Date context label
            Text(DateFormattingHelper.localizedTodayDate(from: Date()))
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Single centered duration column – matches manual tab layout
            HStack(alignment: .center, spacing: 4) {
                VStack(spacing: 6) {
                    Button(action: { adjustTimerDuration(by: 1) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(Theme.Typography.iconLarge)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: largeButtonTouchSize, minHeight: largeButtonVisualHeight)
                    .contentShape(Rectangle().size(width: largeButtonTouchSize, height: largeButtonTouchSize))
                    .accessibilityLabel(NSLocalizedString("set_start_time_increase_duration", comment: "Increase duration"))

                    Text(String(format: "%d:00", timerDurationMinutes))
                        .font(largeMetricFont)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .accessibilityLabel(String(format: NSLocalizedString("set_start_time_timer_duration_accessibility", comment: ""), timerDurationMinutes))

                    Button(action: { adjustTimerDuration(by: -1) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(Theme.Typography.iconLarge)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: largeButtonTouchSize, minHeight: largeButtonVisualHeight)
                    .contentShape(Rectangle().size(width: largeButtonTouchSize, height: largeButtonTouchSize))
                    .disabled(timerDurationMinutes <= 1)
                    .accessibilityLabel(NSLocalizedString("set_start_time_decrease_duration", comment: "Decrease duration"))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity)

            if let timerSubmitError {
                Text(timerSubmitError)
                    .foregroundStyle(Theme.Colors.error)
                    .font(AppFont.textStyle(.footnote))
            }

            Button {
                Task { await submitTimerTime() }
            } label: {
                if isSubmittingTimerTime {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight)
                } else {
                    RaceManagerButtonLabel("set_start_time_start_button")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.RaceManager.primaryColor)
            .disabled(isSubmittingTimerTime)

            if hasExistingActualTime {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Text("set_start_time_reset_button")
                        .font(Theme.Typography.button)
                }
                .disabled(viewModel.isSubmittingActualStart)
            }

            if let resetError {
                Text(resetError)
                    .foregroundStyle(Theme.Colors.error)
                    .font(AppFont.textStyle(.footnote))
            }
        }
        .padding()
    }

    private func initializeManualStateIfNeeded() {
        guard !manualStateInitialized else { return }
        let initialDate = start.actualStartEditorInitialDate()
        let calendar = Calendar.current
        selectedDateBase = initialDate
        selectedHour = calendar.component(.hour, from: initialDate)
        selectedMinute = calendar.component(.minute, from: initialDate)
        manualStateInitialized = true
    }

    private func adjustHour(by delta: Int) {
        selectedHour = wrap(value: selectedHour + delta, modulo: 24)
        manualSubmitError = nil
    }

    private func adjustMinute(by delta: Int) {
        selectedMinute = wrap(value: selectedMinute + delta, modulo: 60)
        manualSubmitError = nil
    }

    private func adjustTimerDuration(by delta: Int) {
        timerDurationMinutes = max(1, timerDurationMinutes + delta)
        timerSubmitError = nil
    }

    private func wrap(value: Int, modulo: Int) -> Int {
        ((value % modulo) + modulo) % modulo
    }

    private func loadStoredManageAccess() async {
        guard let tokenRecord = storage.loadToken(for: startIdentifier, raceId: raceIdentifier, seriesId: seriesIdentifier) else {
            storedToken = nil
            storedScope = nil
            storedScopeId = nil
            return
        }

        storedToken = tokenRecord.token
        storedScope = tokenRecord.scope
        storedScopeId = tokenRecord.scopeId
    }

    private func submitManualTime() async {
        guard hasReusableToken else {
            manualSubmitError = NSLocalizedString("set_start_time_error_management_code_required", comment: "")
            showCodeModal = true
            return
        }

        var calendar = Calendar.current
        calendar.timeZone = .current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: selectedDateBase)
        var components = DateComponents()
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = selectedHour
        components.minute = selectedMinute
        components.second = 0
        components.timeZone = .current

        guard let localDate = calendar.date(from: components) else {
            manualSubmitError = NSLocalizedString("set_start_time_error_invalid_selection", comment: "")
            return
        }

        viewModel.clearActualStartSubmitError()
        manualSubmitError = nil

        let actualUtc = Self.utcFormatter.string(from: localDate)
        let updated = await viewModel.submitActualStartTime(
            for: start,
            actualUtc: actualUtc,
            manageAccessToken: storedToken
        )

        if updated != nil {
            userNotifications.show(
                message: NSLocalizedString("set_start_time_success_manual", comment: ""),
                severity: .success
            )
            dismiss()
            return
        }

        manualSubmitError = viewModel.actualStartSubmitError
            ?? NSLocalizedString("set_start_time_error_set_failed", comment: "")
    }

    private func submitTimerTime() async {
        guard hasReusableToken else {
            timerSubmitError = NSLocalizedString("set_start_time_error_management_code_required", comment: "")
            showCodeModal = true
            return
        }

        viewModel.clearActualStartSubmitError()
        timerSubmitError = nil

        let computedDate = RaceStart.actualStartDateFromTimer(minutes: timerDurationMinutes, referenceDate: Date())
        let actualUtc = Self.utcFormatter.string(from: computedDate)

        let updated = await viewModel.submitActualStartTime(
            for: start,
            actualUtc: actualUtc,
            manageAccessToken: storedToken
        )

        if updated != nil {
            userNotifications.show(
                message: NSLocalizedString("set_start_time_success_timer", comment: ""),
                severity: .success
            )
            dismiss()
            return
        }

        timerSubmitError = viewModel.actualStartSubmitError
            ?? NSLocalizedString("set_start_time_error_timer_failed", comment: "")
    }

    private func performReset() async {
        guard hasReusableToken else {
            resetError = NSLocalizedString("set_start_time_error_management_code_required", comment: "")
            showCodeModal = true
            return
        }

        viewModel.clearActualStartSubmitError()
        resetError = nil

        let updated = await viewModel.resetActualStartTime(
            for: start,
            manageAccessToken: storedToken
        )

        if updated != nil {
            userNotifications.show(
                message: NSLocalizedString("set_start_time_success_reset", comment: ""),
                severity: .success
            )
            dismiss()
            return
        }

        resetError = viewModel.actualStartSubmitError
            ?? NSLocalizedString("set_start_time_error_reset_failed", comment: "")
    }

}

private struct SetStartTimeInfoView: View {
    let titleKey: LocalizedStringKey
    let bodyKey: LocalizedStringKey
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(bodyKey)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(titleKey)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("close_button") {
                        dismiss()
                    }
                    .font(AppUI.buttonFont)
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
    }
}
