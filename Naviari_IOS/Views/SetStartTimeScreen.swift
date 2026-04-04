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
    @State private var codePrefix = ""
    @State private var codeSuffix = ""
    @State private var showCodeModal = false
    @State private var isValidatingCode = false
    @State private var codeValidationError: String?
    @State private var codeValidationAttempts = 0
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
    private let maxCodeValidationAttempts = 5
    private let inputContentFont = AppFont.fixed(21)

    // Oversized fonts/targets for harsh-condition usability
    private let largeMetricFont = AppFont.fixed(96, weight: .semibold)
    private let largeButtonTouchSize: CGFloat = 88
    private let largeButtonVisualHeight: CGFloat = 66

    @Environment(\.dismiss) private var dismiss
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
            codeValidationSheet
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

    private var manageCode: String? {
        let trimmedPrefix = codePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSuffix = codeSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrefix.isEmpty, !trimmedSuffix.isEmpty else {
            return nil
        }
        return "\(trimmedPrefix)-\(trimmedSuffix)"
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

    private var codeAttemptsRemaining: Int {
        max(0, maxCodeValidationAttempts - codeValidationAttempts)
    }

    private var hasCodeAttemptsRemaining: Bool {
        codeAttemptsRemaining > 0
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

    private func verifyManageCode() async {
        guard hasCodeAttemptsRemaining else { return }
        guard !isValidatingCode else { return }
        guard let code = manageCode else {
            codeValidationError = NSLocalizedString("participate_code_required", comment: "")
            return
        }

        isValidatingCode = true
        codeValidationError = nil
        defer { isValidatingCode = false }

        do {
            let token = try await accessService.exchangeManageCodeForToken(code)
            storage.saveToken(
                token: token,
                startId: startIdentifier,
                raceId: raceIdentifier,
                seriesId: seriesIdentifier
            )
            await loadStoredManageAccess()
            codePrefix = ""
            codeSuffix = ""
            showCodeModal = false
            manualSubmitError = nil
            timerSubmitError = nil
        } catch {
            codeValidationAttempts += 1
            codeValidationError = error.localizedDescription
        }
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
            dismiss()
            return
        }

        resetError = viewModel.actualStartSubmitError
            ?? NSLocalizedString("set_start_time_error_reset_failed", comment: "")
    }

    @ViewBuilder
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
                    Text("-")
                        .font(AppFont.textStyle(.title2))
                        .foregroundStyle(.secondary)
                    TextField("participate_code_suffix", text: $codeSuffix)
                        .font(inputContentFont)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let codeValidationError {
                    Text(codeValidationError)
                        .foregroundStyle(Theme.Colors.error)
                        .font(AppFont.textStyle(.footnote))
                }

                if hasCodeAttemptsRemaining {
                    Text(
                        String(
                            format: NSLocalizedString("participate_code_attempts_remaining", comment: ""),
                            codeAttemptsRemaining
                        )
                    )
                    .font(AppFont.textStyle(.footnote))
                    .foregroundStyle(.secondary)
                } else {
                    Text("participate_code_attempts_exhausted")
                        .font(AppFont.textStyle(.footnote))
                        .foregroundStyle(Theme.Colors.error)
                }

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
                .tint(AppUI.brandPrimary)
                .disabled(isValidatingCode || !hasCodeAttemptsRemaining || manageCode == nil)

                Button("back_button") {
                    dismiss()
                }
                .font(AppUI.buttonFont)
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding()
            .navigationTitle("set_start_time_manage_code_title")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
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
