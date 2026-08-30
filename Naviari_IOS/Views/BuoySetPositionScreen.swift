import SwiftUI

struct BuoySetPositionScreen: View {
    let contextTitle: String
    let buoy: BuoyRecord
    let storage: BuoyStorage
    var onSaved: (BuoyRecord) -> Void = { _ in }

    @State private var submissionError: String?
    @State private var isSubmitting = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationDataManager

    init(
        contextTitle: String,
        buoy: BuoyRecord,
        storage: BuoyStorage = .shared,
        onSaved: @escaping (BuoyRecord) -> Void = { _ in }
    ) {
        self.contextTitle = contextTitle
        self.buoy = buoy
        self.storage = storage
        self.onSaved = onSaved
    }

    var body: some View {
        ScreenContainer(showBack: true, title: Text("set_position_title")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(contextTitle)
                        .font(AppFont.textStyle(.headline))

                    Text("set_position_target_buoy")
                        .font(AppFont.textStyle(.title3, weight: .semibold))

                    Text("set_position_guide_text_buoy")
                        .font(AppFont.textStyle(.subheadline))
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Image("SetPositionBuoyGuide")
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
                        submitPosition()
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
            .accessibilityIdentifier("buoy_set_position_screen")
        }
    }

    private var locationReadiness: CoursePositionLocationReadiness {
        locationManager.coursePositionLocationReadiness()
    }

    private var latestCoordinate: CoordinatePoint? {
        guard case let .ready(coordinate) = locationReadiness else { return nil }
        return coordinate
    }

    private var locationAuthorizationIsValid: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    private var isSubmitDisabled: Bool {
        isSubmitting || !locationAuthorizationIsValid || latestCoordinate == nil
    }

    @ViewBuilder
    private var readinessHintSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !locationAuthorizationIsValid {
                Text("set_position_error_location_permission_required")
                    .font(AppFont.textStyle(.footnote))
                    .foregroundStyle(Theme.Colors.error)
            } else if let errorMessage = locationReadiness.errorMessage {
                Text(errorMessage)
                    .font(AppFont.textStyle(.footnote))
                    .foregroundStyle(Theme.Colors.error)
            }
        }
    }

    private func submitPosition() {
        guard !isSubmitting else { return }
        guard locationAuthorizationIsValid else {
            submissionError = NSLocalizedString("set_position_error_location_permission_required", comment: "")
            return
        }
        let coordinate: CoordinatePoint
        switch locationReadiness {
        case let .ready(value):
            coordinate = value
        case .unavailable, .stale, .inaccurate:
            submissionError = locationReadiness.errorMessage
            return
        }

        isSubmitting = true
        submissionError = nil

        let savedBuoy = storage.updateBuoy(
            id: buoy.id,
            raceId: buoy.raceId,
            name: buoy.name,
            description: buoy.description,
            coordinate: coordinate
        )

        isSubmitting = false

        guard let savedBuoy else {
            submissionError = NSLocalizedString("buoy_edit_save_error", comment: "")
            return
        }

        onSaved(savedBuoy)
        dismiss()
    }
}