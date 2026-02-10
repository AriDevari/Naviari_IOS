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
    @State private var selectedColor = Color.blue
    @State private var codePrefix = ""
    @State private var codeSuffix = ""
    @State private var showParticipationInfo = false
    @State private var submissionError: String?
    @State private var isSubmitting = false
    @State private var submittedSummary: ParticipationSummary?
    @State private var storedToken: String?
    @State private var storedScope: ParticipationScope?
    @State private var storedScopeId: String?
    @State private var hasPrefilledFields = false

    private let service = ParticipationService()
    private let storage = ParticipationStorage.shared
    @FocusState private var focusedField: ParticipationField?
    @EnvironmentObject private var metricsUploader: BoatMetricsUploader

    var body: some View {
        ScreenContainer(
            showBack: true,
            title: Text("participate_title"),
            trailing: AnyView(
                Button(action: { showParticipationInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            )
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(start.name ?? raceSummary.race.nameOrFallback)
                        .font(.headline)

                    if let summary = submittedSummary {
                        ParticipationSummaryView(summary: summary)
                        broadcastStatusSection
                    } else {
                        formFields

                        if let submissionError {
                            Text(submissionError)
                                .foregroundStyle(.red)
                        }

                        Button(action: { Task { await submitBroadcastRequest() } }) {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                VStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 140, height: 140)
                                        .overlay(
                                            Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                                                .font(.system(size:120))
                                                .foregroundStyle(.white)
                                                .backgroundStyle(.yellow)
                                        )

                                    Text("participate_cta_hint")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 16)
                        .disabled(isBroadcastActionDisabled)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showParticipationInfo) {
            InfoHelpView(titleKey: "participate_info_title", bodyKey: "participate_info_body")
        }
        .task(id: startIdentifier) {
            resetFormForNewStart()
            await loadStoredParticipation()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("done_button") {
                    focusedField = nil
                }
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
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ColorPicker("participate_color_label", selection: $selectedColor)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            inputField(titleKey: "participate_description_label", text: $descriptionText, placeholder: "participate_description_placeholder")
                .focused($focusedField, equals: .description)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("participate_code_label")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("participate_code_prefix", text: $codePrefix)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .codePrefix)
                    Text("-")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    TextField("participate_code_suffix", text: $codeSuffix)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .codeSuffix)
                }
                if hasReusableToken {
                    Text("participate_code_reuse_notice")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func inputField(titleKey: LocalizedStringKey, text: Binding<String>, placeholder: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(titleKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func decimalInputField(titleKey: LocalizedStringKey, text: Binding<String>, placeholder: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.none)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var participationCode: String? {
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

    private var isBroadcastActionDisabled: Bool {
        if hasReusableToken {
            return isSubmitting
        }
        return isSubmitting || participationCode == nil
    }

    /// Validates code/token, submits the start entry, persists it, and starts broadcasting.
    private func submitBroadcastRequest() async {
        guard !isSubmitting else { return }
        guard let startId = startIdentifier else {
            submissionError = NSLocalizedString("participate_start_missing", comment: "")
            return
        }
        isSubmitting = true
        submissionError = nil
        do {
            let token: String
            if let storedToken, storedTokenIsValid {
                token = storedToken
            } else {
                guard let code = participationCode else {
                    submissionError = NSLocalizedString("participate_code_required", comment: "")
                    isSubmitting = false
                    return
                }
                token = try await service.exchangeCodeForToken(code)
            }
            let colorHex = hexString(from: selectedColor)
            let submission = ParticipationSubmission(
                startId: startId,
                name: trimmedOrNil(name),
                sailNumber: trimmedOrNil(sailNumber),
                club: trimmedOrNil(clubText),
                rating: parsedRatingValue(),
                description: trimmedOrNil(descriptionText),
                displayColor: colorHex
            )
            let result = try await service.submitStartEntry(token: token, submission: submission)
            let summary = ParticipationSummary(
                name: submission.name,
                sailNumber: submission.sailNumber,
                rating: submission.rating,
                club: submission.club,
                description: submission.description,
                colorHex: colorHex
            )
            submittedSummary = summary
            if let startRecord = persistRecords(token: token, result: result, summary: summary) {
                startBroadcastIfReady(record: startRecord, summaryOverride: summary)
            }
        } catch {
            submissionError = error.localizedDescription
        }
        isSubmitting = false
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
        let record = storage.loadRecord(for: startIdentifier, raceId: raceIdentifier, seriesId: seriesIdentifier)
        guard let record else { return }
        storedToken = record.token
        storedScope = record.scope
        storedScopeId = record.scopeId
        if record.scope == .start, record.scopeId == startIdentifier {
            submittedSummary = record.summary
            startBroadcastIfReady(record: record)
        } else {
            prefillFieldsIfNeeded(from: record.summary)
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
        selectedColor = .blue
        codePrefix = ""
        codeSuffix = ""
        submissionError = nil
        submittedSummary = nil
        storedToken = nil
        storedScope = nil
        storedScopeId = nil
        hasPrefilledFields = false
    }

    /// Boots the uploader once we have a valid start-level token/scope.
    private func startBroadcastIfReady(record: ParticipationRecord, summaryOverride: ParticipationSummary? = nil) {
        guard
            record.scope == .start,
            record.scopeId == startIdentifier,
            let startEntryId = record.startEntryId,
            let startId = startIdentifier
        else {
            return
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
            summary: summary
        )
        metricsUploader.startBroadcast(session: session)
    }

    private var isBroadcastingForCurrentStart: Bool {
        guard let currentStartId = startIdentifier else { return false }
        guard
            metricsUploader.isBroadcasting,
            let session = metricsUploader.activeSession,
            let sessionStartId = session.startId
        else {
            return false
        }
        return sessionStartId == currentStartId
    }

    @ViewBuilder
    private var broadcastStatusSection: some View {
        if isBroadcastingForCurrentStart {
            BroadcastStatusCard(
                lastSample: metricsUploader.lastAcceptedSample,
                lastSendAt: metricsUploader.lastSendAt,
                backlogSeconds: metricsUploader.backlogSeconds,
                retryCount: metricsUploader.retryCount,
                lastErrorAt: metricsUploader.lastErrorAt,
                errorMessage: metricsUploader.lastErrorMessage
            )
            .transition(.opacity)
        } else if submittedSummary != nil {
            BroadcastStatusPlaceholder()
                .transition(.opacity)
        }
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
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
    }
}

private struct ParticipationSummaryView: View {
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
                        .font(.caption)
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

/// Informational card shown when no broadcast session is active for the selected start.
private struct BroadcastStatusPlaceholder: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("broadcast_status_inactive")
                    .font(.headline)
                Text("broadcast_status_placeholder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.secondary.opacity(0.2))
        )
    }
}

/// Displays live telemetry/broadcast diagnostics (last sample, backlog, retries, errors).
private struct BroadcastStatusCard: View {
    let lastSample: BoatSample?
    let lastSendAt: Date?
    let backlogSeconds: Int
    let retryCount: Int
    let lastErrorAt: Date?
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("broadcast_status_active")
                        .font(.headline)
                    Text(statusSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                BroadcastStatusRow(
                    titleKey: "broadcast_status_last_sample",
                    value: sampleDescription
                )
                if let accuracyDescription {
                    BroadcastStatusRow(
                        titleKey: "gps_status_accuracy",
                        value: accuracyDescription
                    )
                }
                BroadcastStatusRow(
                    titleKey: "broadcast_status_last_upload",
                    value: uploadDescription
                )
                BroadcastStatusRow(
                    titleKey: "broadcast_status_backlog_label",
                    value: backlogDescription
                )
                if retryCount > 0 {
                    BroadcastStatusRow(
                        titleKey: "broadcast_status_retry_label",
                        value: retryDescription
                    )
                }
            }

            if let errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("broadcast_status_error_prefix")
                            .font(.subheadline)
                            .bold()
                        Text(errorMessage)
                            .font(.footnote)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.05))
        )
    }

    private var statusSubtitle: String {
        NSLocalizedString("broadcast_status_active_subtitle", comment: "")
    }

    private var sampleDescription: String {
        guard let lastSample else {
            return NSLocalizedString("broadcast_status_waiting_sample", comment: "")
        }
        return Self.composeTimeDescription(from: lastSample.timestamp)
    }

    private var uploadDescription: String {
        guard let lastSendAt else {
            return NSLocalizedString("broadcast_status_waiting_upload", comment: "")
        }
        return Self.composeTimeDescription(from: lastSendAt)
    }

    private var accuracyDescription: String? {
        guard let accuracy = lastSample?.accuracy, accuracy >= 0 else { return nil }
        let measurement = Measurement(value: accuracy, unit: UnitLength.meters)
        BroadcastStatusCard.measurementFormatter.locale = Locale.current
        return BroadcastStatusCard.measurementFormatter.string(from: measurement)
    }

    private var backlogDescription: String {
        if backlogSeconds <= 0 {
            return NSLocalizedString("broadcast_status_backlog_clear", comment: "")
        }
        let duration = TimeInterval(backlogSeconds)
        let formatted = BroadcastStatusCard.durationFormatter.string(from: duration) ?? "\(backlogSeconds)s"
        return String(
            format: NSLocalizedString("broadcast_status_backlog_value", comment: ""),
            formatted
        )
    }

    private var retryDescription: String {
        let countString = String(
            format: NSLocalizedString("broadcast_status_retry_count_value", comment: ""),
            retryCount
        )
        if let lastErrorAt {
            let relative = DateFormattingHelper.relativeTimeString(from: lastErrorAt)
            return "\(countString) • \(relative)"
        }
        return countString
    }

    private static func composeTimeDescription(from date: Date) -> String {
        let relative = DateFormattingHelper.relativeTimeString(from: date)
        let absolute = DateFormattingHelper.localizedShortDateTime(from: date)
        return "\(relative) • \(absolute)"
    }

    private static let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter.roundingMode = .halfUp
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .short
        formatter.collapsesLargestUnit = false
        return formatter
    }()
}

/// Reusable row layout inside the broadcast status card.
private struct BroadcastStatusRow: View {
    let titleKey: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    case codePrefix
    case codeSuffix
}
