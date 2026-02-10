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
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .padding(18)
                .background(statusColor)
                .clipShape(Circle())
                .shadow(color: statusColor.opacity(0.5), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel(Text(statusDescription))
        .sheet(isPresented: $showDetail) {
            GPSStatusDetailView(locationManager: locationManager)
        }
    }

    private var statusColor: Color {
        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            return .red
        }
        if let error = locationManager.lastErrorMessage, !error.isEmpty {
            return .red
        }
        guard let accuracy = locationManager.lastAccuracy else {
            return Color.orange
        }
        if accuracy > 20 {
            return Color.orange
        }
        let normalized = max(0, min(1, accuracy / 20))
        let minHue: Double = 0.33 // green
        let maxHue: Double = 0.14 // yellow
        let hue = minHue - (minHue - maxHue) * normalized
        return Color(hue: hue, saturation: 0.9, brightness: 0.9)
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
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
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
                        .foregroundStyle(.red)
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
