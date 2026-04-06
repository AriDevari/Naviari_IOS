import CoreLocation
import SwiftUI

/// Captures current GPS location and writes it to the selected course target.
struct SetPositionScreen: View {
    let raceSummary: RaceSummary
    let start: RaceStart
    let target: SetPositionTarget

    @State private var codePrefix = ""
    @State private var codeSuffix = ""
    @State private var showCodeModal = false
    @State private var isValidatingCode = false
    @State private var codeValidationError: String?
    @State private var codeValidationAttempts = 0
    @State private var storedToken: String?
    @State private var storedScope: ManageAccessScope?
    @State private var storedScopeId: String?
    @State private var submissionError: String?
    @State private var isSubmitting = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationDataManager
    @EnvironmentObject private var viewModel: RaceBrowserViewModel

    private let accessService = ParticipationService()
    private let storage = ManageAccessStorage.shared
    private let maxCodeValidationAttempts = 5
    private let inputContentFont = AppFont.fixed(21)
    private let raceService = RaceService()

    var body: some View {
        ScreenContainer(showBack: true, title: Text("set_position_title")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(start.name ?? raceSummary.race.nameOrFallback)
                        .font(AppFont.textStyle(.headline))

                    Text(LocalizedStringKey(target.localizedTargetKey))
                        .font(AppFont.textStyle(.title3, weight: .semibold))

                    Text("set_position_guide_text")
                        .font(AppFont.textStyle(.subheadline))
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Image(target.guideImageAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.materialCard, style: .continuous))

                    readinessHintSection

                    if let submissionError {
                        Text(submissionError)
                            .foregroundStyle(Theme.Colors.error)
                            .font(AppFont.textStyle(.footnote))
                    }

                    Button {
                        Task { await submitPosition() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight)
                        } else {
                            RaceManagerButtonLabel("set_position_button")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.RaceManager.primaryColor)
                    .disabled(isSubmitDisabled)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showCodeModal) {
            codeValidationSheet
        }
        .task(id: storageScopeKey) {
            await loadStoredManageAccess()
            showCodeModal = !hasReusableToken
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

    private var locationAuthorizationIsValid: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    private var latestCoordinate: CoordinatePoint? {
        guard let coordinate = locationManager.latestLocation?.coordinate else {
            return nil
        }
        return CoordinatePoint(lat: coordinate.latitude, lon: coordinate.longitude)
    }

    private var isSubmitDisabled: Bool {
        isSubmitting || !hasReusableToken || !locationAuthorizationIsValid || latestCoordinate == nil
    }

    @ViewBuilder
    private var readinessHintSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !hasReusableToken {
                Text("set_position_error_manage_token_required")
                    .font(AppFont.textStyle(.footnote))
                    .foregroundStyle(Theme.Colors.error)
            }

            if !locationAuthorizationIsValid {
                Text("set_position_error_location_permission_required")
                    .font(AppFont.textStyle(.footnote))
                    .foregroundStyle(Theme.Colors.error)
            } else if latestCoordinate == nil {
                Text("set_position_error_location_unavailable")
                    .font(AppFont.textStyle(.footnote))
                    .foregroundStyle(Theme.Colors.error)
            }
        }
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
            codeValidationError = NSLocalizedString("set_position_error_manage_token_required", comment: "")
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
            submissionError = nil
        } catch {
            codeValidationAttempts += 1
            codeValidationError = error.localizedDescription
        }
    }

    private func submitPosition() async {
        guard !isSubmitting else { return }

        guard let token = storedToken, storedTokenIsValid else {
            submissionError = NSLocalizedString("set_position_error_manage_token_required", comment: "")
            showCodeModal = true
            return
        }

        guard locationAuthorizationIsValid else {
            submissionError = NSLocalizedString("set_position_error_location_permission_required", comment: "")
            return
        }

        guard let coordinate = latestCoordinate else {
            submissionError = NSLocalizedString("set_position_error_location_unavailable", comment: "")
            return
        }

        isSubmitting = true
        submissionError = nil
        defer { isSubmitting = false }

        do {
            try await raceService.setCoursePosition(
                target: target,
                coordinate: coordinate,
                accessToken: token
            )

            if let startId = startIdentifier {
                viewModel.requestCourseRefresh(for: startId)
            }

            dismiss()
        } catch {
            submissionError = error.localizedDescription.isEmpty
                ? NSLocalizedString("set_position_error_save_failed", comment: "")
                : error.localizedDescription
        }
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

