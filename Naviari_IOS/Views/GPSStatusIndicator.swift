//
//  GPSStatusIndicator.swift
//  Naviari_IOS
//
//  Floating button + sheet for live GPS accuracy diagnostics.
//

import SwiftUI
import CoreLocation

/// Floating circular button that reflects live GPS accuracy and opens a diagnostic sheet.
struct GPSStatusButton: View {
    @ObservedObject var locationManager: LocationDataManager
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            Image(systemName: "location.fill")
                .font(Theme.Typography.iconMedium)
                .foregroundStyle(.white)
                .padding(18)
                .background(statusColor)
                .clipShape(Circle())
                .shadow(color: statusColor.opacity(Theme.Effects.floatingStatusShadowOpacity), radius: Theme.Effects.floatingStatusShadowRadius, x: 0, y: Theme.Effects.floatingStatusShadowYOffset)
        }
        .accessibilityLabel(Text(statusDescription))
        .sheet(isPresented: $showDetail) {
            GPSStatusDetailView(locationManager: locationManager)
        }
    }

    private var statusColor: Color {
        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            return Theme.Colors.statusRed
        }
        if let error = locationManager.lastErrorMessage, !error.isEmpty {
            return Theme.Colors.statusRed
        }
        guard let accuracy = locationManager.lastAccuracy else {
            return Theme.Colors.statusYellow
        }
        if accuracy > 20 {
            return Theme.Colors.statusYellow
        }
        let normalized = max(0, min(1, accuracy / 20))
        return Theme.Colors.statusBlend(normalized: normalized)
    }

    private var statusDescription: String {
        if let accuracy = locationManager.lastAccuracy {
            return String(format: NSLocalizedString("gps_status_accessibility", comment: "Accuracy in meters"), accuracy)
        }
        return NSLocalizedString("gps_status_waiting", comment: "Waiting for GPS")
    }
}

/// Modal sheet that surfaces detailed GPS telemetry (accuracy, lat/lon, speed, course).
private struct GPSStatusDetailView: View {
    @ObservedObject var locationManager: LocationDataManager
    @Environment(\.dismiss) private var dismiss

    private var location: CLLocation? {
        locationManager.latestLocation
    }

    private var accuracyText: String {
        if let accuracy = locationManager.lastAccuracy {
            return String(format: "%.1f m", accuracy)
        }
        return NSLocalizedString("gps_status_unavailable", comment: "Unavailable")
    }

    private var latitudeText: String {
        guard let latitude = location?.coordinate.latitude else {
            return "—"
        }
        return String(format: "%.5f°", latitude)
    }

    private var longitudeText: String {
        guard let longitude = location?.coordinate.longitude else {
            return "—"
        }
        return String(format: "%.5f°", longitude)
    }

    private var speedText: String {
        guard let speed = location?.speed, speed >= 0 else {
            return "—"
        }
        let knots = speed * 1.943844 // m/s to knots
        return String(format: "%.1f kn", knots)
    }

    private var courseText: String {
        guard let course = location?.course, course >= 0 else {
            return "—"
        }
        return String(format: "%.0f°", course)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("gps_status_accuracy")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(accuracyText)
                        .font(Theme.Typography.metricValue)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.trailing)
                }

                VStack(alignment: .leading, spacing: 12) {
                    infoRow(label: "gps_status_latitude", value: latitudeText)
                    infoRow(label: "gps_status_longitude", value: longitudeText)
                    infoRow(label: "gps_status_speed", value: speedText)
                    infoRow(label: "gps_status_course", value: courseText)
                }

                if let error = locationManager.lastErrorMessage {
                    Text(error)
                        .foregroundStyle(Theme.Colors.error)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("gps_status_title")
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

    private func infoRow(label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
