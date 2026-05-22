//
//  ParticipateView.swift
//  Naviari_IOS
//
//  Collects basic entrant info and participation code for a race start.
//

import SwiftUI
import UIKit

/// Collects basic entrant info + participation code, then starts GPS broadcasting.
struct ParticipateView: View {
    let raceSummary: RaceSummary
    let start: RaceStart

    @State private var name = ""
    @State private var sailNumber = ""
    @State private var ratingValue = ""
    @State private var descriptionText = ""
    @State private var clubText = ""
    @State private var selectedColor = Theme.Colors.brandPrimary
    @State private var showParticipationInfo = false
    @State private var showCodeModal = false
    @State private var submissionError: String?
    @State private var isSubmitting = false
    @State private var storedToken: String?
    @State private var storedScope: ParticipationScope?
    @State private var storedScopeId: String?
    @State private var storedRecord: ParticipationRecord?
    @State private var hasPrefilledFields = false

    private let service = ParticipationService()
    private let storage = ParticipationStorage.shared
    @FocusState private var focusedField: ParticipationField?
    @EnvironmentObject private var metricsUploader: BoatMetricsUploader
    @EnvironmentObject private var userNotifications: UserNotifications
    @Environment(\.dismiss) private var dismiss
    private let inputContentFont = AppFont.fixed(21)

    private var isCompletedStart: Bool {
        start.isCompletedStatus
    }

    private var isRealBroadcastWindowOpen: Bool {
        start.isRealBroadcastWindowOpen()
    }

    private var isRehearsalMode: Bool {
        start.isRehearsalWindow()
    }

    private var isMissingEstimatedStart: Bool {
        !start.hasEstimatedStartDate
    }

    private var titleKey: LocalizedStringKey {
        isRehearsalMode ? "participate_rehearsal_title" : "participate_title"
    }

    private var primaryButtonKey: LocalizedStringKey {
        isRehearsalMode ? "participate_rehearsal_button" : "participate_button"
    }

    private var infoTitleKey: LocalizedStringKey {
        isRehearsalMode ? "participate_rehearsal_info_title" : "participate_info_title"
    }

    private var infoBodyKey: LocalizedStringKey {
        isRehearsalMode ? "participate_rehearsal_info_body" : "participate_info_body"
    }

    private var startDisplayName: String {
        if let trimmed = start.name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        return raceSummary.race.nameOrFallback
    }

    var body: some View {
        ScreenContainer(
            showBack: true,
            title: Text(titleKey),
            trailing: AnyView(
                Button(action: { showParticipationInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(Theme.Typography.iconLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(showCodeModal)
            )
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(start.name ?? raceSummary.race.nameOrFallback)
                        .font(AppFont.textStyle(.headline))

                    if isRehearsalMode {
                        rehearsalGuidanceCard
                    }

                    formFields

                    if let submissionError {
                        Text(submissionError)
                            .foregroundStyle(Theme.Colors.error)
                    }

                    Button(action: { Task { await submitBroadcastRequest() } }) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: AppUI.primaryButtonHeight)
                        } else {
                            Text(primaryButtonKey)
                                .font(AppUI.buttonFont)
                                .frame(maxWidth: .infinity, minHeight: AppUI.primaryButtonHeight)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppUI.brandPrimary)
                    .padding(.top, 16)
                    .disabled(isBroadcastActionDisabled)

                    if !isRehearsalMode {
                        Text(ctaHintKey)
                            .font(AppFont.textStyle(.footnote))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
            }
            .accessibilityIdentifier("participate_screen")
        }
        .sheet(isPresented: $showParticipationInfo) {
            InfoHelpView(titleKey: infoTitleKey, bodyKey: infoBodyKey)
        }
        .sheet(isPresented: $showCodeModal) {
            CodeEntryView(
                titleKey: "participate_code_modal_title",
                messageKey: "participate_code_modal_message",
                verifyButtonKey: "participate_code_verify_button",
                cancelButtonKey: "back_button",
                accentColor: AppUI.brandPrimary,
                onVerify: { code in
                    try await service.exchangeCodeForToken(code)
                },
                onSuccess: { token in
                    storage.saveToken(
                        token: token,
                        startId: startIdentifier,
                        raceId: raceIdentifier,
                        seriesId: seriesIdentifier
                    )
                    showCodeModal = false
                    Task { await loadStoredParticipation() }
                },
                onCancel: {
                    showCodeModal = false
                }
            )
        }
        .task(id: startIdentifier) {
            resetFormForNewStart()
            await loadStoredParticipation()
            stopBroadcastIfCompletedForCurrentStart()
            showCodeModal = !hasReusableToken
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("done_button") {
                    focusedField = nil
                }
                .font(AppUI.buttonFont)
            }
        }
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            inputField(titleKey: "participate_name_label", text: $name, placeholder: "participate_name_placeholder")
                .focused($focusedField, equals: .name)

            HStack(alignment: .top, spacing: 16) {
                inputField(titleKey: "participate_sail_label", text: $sailNumber, placeholder: "participate_sail_placeholder")
                    .focused($focusedField, equals: .sailNumber)
                decimalInputField(titleKey: "participate_rating_label", text: $ratingValue, placeholder: "participate_rating_placeholder")
                    .focused($focusedField, equals: .rating)
            }

            HStack(alignment: .top, spacing: 16) {
                inputField(titleKey: "participate_club_label", text: $clubText, placeholder: "participate_club_placeholder")
                    .focused($focusedField, equals: .club)

                VStack(alignment: .leading, spacing: 8) {
                    Text("participate_color_label")
                        .font(AppFont.textStyle(.subheadline))
                        .foregroundStyle(.secondary)
                    ColorPicker("participate_color_label", selection: $selectedColor)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            inputField(titleKey: "participate_description_label", text: $descriptionText, placeholder: "participate_description_placeholder")
                .focused($focusedField, equals: .description)
        }
    }

    private func inputField(titleKey: LocalizedStringKey, text: Binding<String>, placeholder: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(titleKey)
                    .font(AppFont.textStyle(.subheadline))
                    .foregroundStyle(.secondary)
            }
            TextField(placeholder, text: text)
                .font(inputContentFont)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func decimalInputField(titleKey: LocalizedStringKey, text: Binding<String>, placeholder: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey)
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .font(inputContentFont)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.none)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasReusableToken: Bool {
        storedToken != nil && storedTokenIsValid
    }

    private var isBroadcastActionDisabled: Bool {
        isSubmitting || !hasReusableToken || isCompletedStart || isMissingEstimatedStart
    }

    private var ctaHintKey: LocalizedStringKey {
        if isCompletedStart {
            return "participate_completed_hint"
        }
        if isMissingEstimatedStart {
            return "participate_estimated_start_required_hint"
        }
        if isRehearsalMode {
            return "participate_rehearsal_hint"
        }
        return "participate_cta_hint"
    }

    private var rehearsalGuidanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("participate_rehearsal_guidance_title")
                .font(AppFont.textStyle(.headline))

            Text("participate_rehearsal_guidance_body")
                .font(AppFont.textStyle(.subheadline))
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.materialCard, style: .continuous))
    }

    /// Validates code/token, submits the start entry, persists it, and starts broadcasting.
    private func submitBroadcastRequest() async {
        guard !isSubmitting else { return }
        guard let startId = startIdentifier else {
            submissionError = NSLocalizedString("participate_start_missing", comment: "")
            return
        }
        guard !isCompletedStart else {
            submissionError = NSLocalizedString("participate_completed_hint", comment: "")
            stopBroadcastIfCompletedForCurrentStart()
            return
        }
        guard !isMissingEstimatedStart else {
            submissionError = NSLocalizedString("participate_estimated_start_required_hint", comment: "")
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        submissionError = nil
        do {
            guard let token = storedToken, storedTokenIsValid else {
                submissionError = NSLocalizedString("participate_code_required", comment: "")
                showCodeModal = true
                return
            }
            let storedRecordForStart = storedRecordForCurrentStart
            let existingBoatId = storedRecordForStart?.boatId
            let colorHex = hexString(from: selectedColor)
            let submission = ParticipationSubmission(
                startId: startId,
                boatId: existingBoatId,
                name: trimmedOrNil(name),
                sailNumber: trimmedOrNil(sailNumber),
                club: trimmedOrNil(clubText),
                rating: parsedRatingValue(),
                description: trimmedOrNil(descriptionText),
                displayColor: colorHex,
                issueNewBoatSecret: existingBoatId == nil
            )
            let result = try await service.submitStartEntry(token: token, submission: submission)
            let mergedResult = ParticipationResult(
                startEntryId: result.startEntryId ?? storedRecordForStart?.startEntryId,
                boatId: result.boatId ?? storedRecordForStart?.boatId,
                boatToken: result.boatToken ?? storedRecordForStart?.boatToken,
                boatCode: result.boatCode ?? storedRecordForStart?.boatCode
            )
            let summary = ParticipationSummary(
                name: submission.name,
                sailNumber: submission.sailNumber,
                rating: submission.rating,
                club: submission.club,
                description: submission.description,
                colorHex: colorHex
            )
            if let startRecord = persistRecords(token: token, result: mergedResult, summary: summary) {
                storedRecord = startRecord
                let started = startBroadcastIfReady(record: startRecord, summaryOverride: summary)
                if started {
                    await MainActor.run { dismiss() }
                    return
                }
            }
        } catch {
            submissionError = error.localizedDescription
        }
    }

    /// Converts the localized rating text field into a decimal value (fallback to en_US when needed).
    private func parsedRatingValue() -> Double? {
        let trimmed = ratingValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        if let number = formatter.number(from: trimmed) {
            return number.doubleValue
        }
        let dotFormatter = NumberFormatter()
        dotFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dotFormatter.number(from: trimmed)?.doubleValue
    }

    private func hexString(from color: Color) -> String? {
#if canImport(UIKit)
        let uiColor = UIColor(color)
        guard let components = uiColor.cgColor.components else { return nil }
        let compCount = components.count
        let r = compCount >= 1 ? components[0] : 0
        let g = compCount >= 2 ? components[1] : 0
        let b = compCount >= 3 ? components[2] : r
        return String(
            format: "#%02lX%02lX%02lX",
            lroundf(Float(r * 255)),
            lroundf(Float(g * 255)),
            lroundf(Float(b * 255))
        )
#else
        return nil
#endif
    }

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

    /// Restores any saved participation token/summary for the current start/race/series.
    private func loadStoredParticipation() async {
        if let record = storage.loadRecord(for: startIdentifier, raceId: raceIdentifier, seriesId: seriesIdentifier) {
            storedRecord = record
            storedToken = record.token
            storedScope = record.scope
            storedScopeId = record.scopeId
            prefillFieldsIfNeeded(from: record.summary)
            return
        }

        if let tokenRecord = storage.loadToken(for: startIdentifier, raceId: raceIdentifier, seriesId: seriesIdentifier) {
            storedToken = tokenRecord.token
            storedScope = tokenRecord.scope
            storedScopeId = tokenRecord.scopeId
        }
    }

    /// Populates editable fields using a saved summary only once per start to avoid overwriting user edits.
    private func prefillFieldsIfNeeded(from summary: ParticipationSummary) {
        guard !hasPrefilledFields else { return }
        hasPrefilledFields = true
        if let value = summary.name { name = value }
        if let value = summary.sailNumber { sailNumber = value }
        if let value = summary.rating {
            let formatter = NumberFormatter()
            formatter.locale = Locale.current
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 3
            ratingValue = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
        if let value = summary.club { clubText = value }
        if let value = summary.description { descriptionText = value }
        if let hex = summary.colorHex, let color = Color(hex: hex) {
            selectedColor = color
        }
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

    /// Persists participation records for start/race/series scopes and returns the start-level record for broadcasting.
    @discardableResult
    private func persistRecords(token: String, result: ParticipationResult, summary: ParticipationSummary) -> ParticipationRecord? {
        var records: [ParticipationRecord] = []
        let now = Date()
        var startRecord: ParticipationRecord?
        if let startId = startIdentifier {
            let record = ParticipationRecord(
                scope: .start,
                scopeId: startId,
                token: token,
                startEntryId: result.startEntryId,
                boatId: result.boatId,
                boatToken: result.boatToken,
                boatCode: result.boatCode,
                summary: summary,
                savedAt: now
            )
            records.append(record)
            startRecord = record
        }
        if let raceId = raceIdentifier {
            records.append(
                ParticipationRecord(
                    scope: .race,
                    scopeId: raceId,
                    token: token,
                    startEntryId: result.startEntryId,
                    boatId: result.boatId,
                    boatToken: result.boatToken,
                    boatCode: result.boatCode,
                    summary: summary,
                    savedAt: now
                )
            )
        }
        if let seriesId = seriesIdentifier {
            records.append(
                ParticipationRecord(
                    scope: .series,
                    scopeId: seriesId,
                    token: token,
                    startEntryId: result.startEntryId,
                    boatId: result.boatId,
                    boatToken: result.boatToken,
                    boatCode: result.boatCode,
                    summary: summary,
                    savedAt: now
                )
            )
        }
        storage.saveRecords(records)
        storedToken = token
        storedScope = .start
        storedScopeId = startIdentifier
        return startRecord
    }

    /// Clears state when the user navigates to a different start.
    private func resetFormForNewStart() {
        name = ""
        sailNumber = ""
        ratingValue = ""
        descriptionText = ""
        clubText = ""
        selectedColor = Theme.Colors.brandPrimary
        submissionError = nil
        showCodeModal = false
        storedRecord = nil
        storedToken = nil
        storedScope = nil
        storedScopeId = nil
        hasPrefilledFields = false
    }

    private var storedRecordForCurrentStart: ParticipationRecord? {
        guard let startIdentifier else { return nil }
        guard let storedRecord else { return nil }
        guard storedRecord.scope == .start, storedRecord.scopeId == startIdentifier else { return nil }
        return storedRecord
    }

    /// Boots the uploader once we have a valid start-level token/scope.
    private func startBroadcastIfReady(record: ParticipationRecord, summaryOverride: ParticipationSummary? = nil) -> Bool {
        guard !isCompletedStart, !isMissingEstimatedStart else {
            return false
        }
        guard
            record.scope == .start,
            record.scopeId == startIdentifier,
            let startEntryId = record.startEntryId,
            let startId = startIdentifier
        else {
            return false
        }

        if
            let activeSession = metricsUploader.activeSession,
            metricsUploader.isBroadcasting,
            activeSession.startId == startId,
            activeSession.startEntryId == startEntryId
        {
            return true
        }
        let summary = summaryOverride ?? record.summary
        let session = BroadcastSession(
            token: record.token,
            boatToken: record.boatToken,
            startEntryId: startEntryId,
            startId: startId,
            boatId: record.boatId,
            raceId: raceIdentifier,
            seriesId: seriesIdentifier,
            startDisplayName: startDisplayName,
            summary: summary,
            mode: isRehearsalMode ? .rehearsal : .live,
            startedAt: Date()
        )
        metricsUploader.startBroadcast(session: session)
        if !isRehearsalMode {
            userNotifications.show(
                markdownMessage: NSLocalizedString("participate_live_started_notification", comment: ""),
                severity: .info
            )
        }
        return true
    }

    private func stopBroadcastIfCompletedForCurrentStart() {
        guard isCompletedStart, metricsUploader.activeSession?.startId == startIdentifier, metricsUploader.isBroadcasting else {
            return
        }
        metricsUploader.stopBroadcast(reason: .completedStart)
    }
}

private struct InfoHelpView: View {
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

struct ParticipationSummaryView: View {
    let summary: ParticipationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeled("participate_name_label") {
                Text(summary.name ?? "—")
            }
            labeled("participate_sail_label") {
                Text(summary.sailNumber ?? "—")
            }
            labeled("participate_rating_label") {
                Text(formattedRating(summary.rating))
            }
            labeled("participate_club_label") {
                Text(summary.club ?? "—")
            }
            labeled("participate_description_label") {
                Text(summary.description ?? "—")
            }
            if let colorHex = summary.colorHex {
                HStack {
                    Text(LocalizedStringKey("participate_color_label"))
                    Spacer()
                    Circle()
                        .fill(Color(hex: colorHex) ?? .gray)
                        .frame(width: 20, height: 20)
                    Text(colorHex)
                        .font(AppFont.textStyle(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedRating(_ value: Double?) -> String {
        guard let value else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func labeled(_ key: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        LabeledContent {
            content()
        } label: {
            Text(key)
        }
    }
}

private extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard let int = Int(hexSanitized, radix: 16) else { return nil }
        let red = Double((int >> 16) & 0xFF) / 255.0
        let green = Double((int >> 8) & 0xFF) / 255.0
        let blue = Double(int & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

private enum ParticipationField: Hashable {
    case name
    case sailNumber
    case rating
    case club
    case description
}
