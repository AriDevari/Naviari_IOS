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
    @State private var storedToken: String?
    @State private var storedScope: ParticipationScope?
    @State private var storedScopeId: String?
    @State private var storedRecord: ParticipationRecord?
    @State private var hasPrefilledFields = false

    private let service = ParticipationService()
    private let storage = ParticipationStorage.shared
    @FocusState private var focusedField: ParticipationField?
    @EnvironmentObject private var metricsUploader: BoatMetricsUploader
    @Environment(\.dismiss) private var dismiss

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
        defer { isSubmitting = false }
        submissionError = nil
        do {
            let token: String
            if let storedToken, storedTokenIsValid {
                token = storedToken
            } else {
                guard let code = participationCode else {
                    submissionError = NSLocalizedString("participate_code_required", comment: "")
                    return
                }
                token = try await service.exchangeCodeForToken(code)
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
        let record = storage.loadRecord(for: startIdentifier, raceId: raceIdentifier, seriesId: seriesIdentifier)
        guard let record else { return }
        storedRecord = record
        storedToken = record.token
        storedScope = record.scope
        storedScopeId = record.scopeId
        prefillFieldsIfNeeded(from: record.summary)
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
            summary: summary
        )
        metricsUploader.startBroadcast(session: session)
        return true
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
