import CoreLocation
import SwiftUI

/// Captures current GPS location and writes it to the selected course target.
struct SetPositionScreen: View {
    let raceSummary: RaceSummary
    let start: RaceStart
    let target: SetPositionTarget

    @State private var showCodeModal = false
    @State private var storedToken: String?
    @State private var storedScope: ManageAccessScope?
    @State private var storedScopeId: String?
    @State private var submissionError: String?
    @State private var isSubmitting = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationDataManager
    @EnvironmentObject private var userNotifications: UserNotifications
    @EnvironmentObject private var viewModel: RaceBrowserViewModel

    private let accessService = ParticipationService()
    private let storage = ManageAccessStorage.shared
    private let raceService = RaceService()

    var body: some View {
        ScreenContainer(showBack: true, title: Text("set_position_title")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(start.name ?? raceSummary.race.nameOrFallback)
                        .font(AppFont.textStyle(.headline))

                    Text(LocalizedStringKey(target.localizedTargetKey))
                        .font(AppFont.textStyle(.title3, weight: .semibold))

                    Text(LocalizedStringKey(target.guideTextKey))
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
                            SetPositionPrimaryButtonLabel()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.RaceManager.primaryColor)
                    .disabled(isSubmitDisabled)
                }
                .padding()
            }
            .accessibilityIdentifier("set_position_screen")
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
                    submissionError = nil
                    Task { await loadStoredManageAccess() }
                },
                onCancel: {
                    showCodeModal = false
                }
            )
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

            userNotifications.show(
                message: NSLocalizedString(successMessageKey, comment: ""),
                severity: .success
            )
            dismiss()
        } catch {
            submissionError = error.localizedDescription.isEmpty
                ? NSLocalizedString("set_position_error_save_failed", comment: "")
                : error.localizedDescription
        }
    }

    private var successMessageKey: String {
        switch target {
        case .mark:
            return "set_position_success_mark"
        case let .startLine(_, side):
            return side == .left ? "set_position_success_start_left" : "set_position_success_start_right"
        case let .finishLine(_, side):
            return side == .left ? "set_position_success_finish_left" : "set_position_success_finish_right"
        }
    }

}

private struct SetPositionPrimaryButtonLabel: View {
    var body: some View {
        ZStack {
            Text("set_position_button")
                .font(Theme.Typography.button)
            HStack {
                Spacer()
                Image(systemName: "mappin.and.ellipse")
                    .font(Theme.Typography.iconMedium)
                    .padding(.trailing, Theme.Sizing.primaryButtonHeight / 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Theme.Sizing.primaryButtonHeight)
    }
}
