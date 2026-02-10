//
//  LocationDataManager.swift
//  Naviari_IOS
//
//  Handles GPS authorization, accuracy configuration, and buffering of raw samples.
//

import CoreLocation
import Foundation

/// Centralizes Core Location configuration and exposes both raw locations and 1 Hz “accepted” samples for telemetry components.
@MainActor
final class LocationDataManager: NSObject, ObservableObject {
    /// Sliding window of raw `CLLocation` updates (used for debugging overlays).
    @Published private(set) var recentSamples: [CLLocation] = []
    /// Most recent `CLLocation` value.
    @Published private(set) var latestLocation: CLLocation?
    /// Accuracy (meters) for the latest reading.
    @Published private(set) var lastAccuracy: CLLocationAccuracy?
    /// Error message surfaced when Core Location reports a failure.
    @Published private(set) var lastErrorMessage: String?
    /// Authorization state mirrored into SwiftUI.
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Flag that mirrors whether the manager is actively receiving updates.
    @Published private(set) var isUpdating = false
    /// Debounced ≥1 Hz samples converted into `BoatSample` structs for broadcast services.
    @Published private(set) var acceptedSamples: [BoatSample] = []

    private let manager = CLLocationManager()
    private let bufferSize = 256
    private let acceptedBufferSize = 600
    private var lastAcceptedTimestamp: TimeInterval = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        let supportsBackground = LocationDataManager.supportsBackgroundLocation
        manager.allowsBackgroundLocationUpdates = supportsBackground
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = supportsBackground
    }

    /// Requests permission (if needed) and starts listening for GPS updates.
    func start() {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            isUpdating = true
        case .restricted, .denied:
            isUpdating = false
        @unknown default:
            isUpdating = false
        }
    }

    /// Stops GPS updates entirely (used when the user opts out).
    func stop() {
        manager.stopUpdatingLocation()
        isUpdating = false
    }

    /// Returns true when Info.plist enables background `location` mode.
    private static var supportsBackgroundLocation: Bool {
        if let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] {
            return modes.contains("location")
        }
        return false
    }
}

extension LocationDataManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
                isUpdating = true
            default:
                manager.stopUpdatingLocation()
                isUpdating = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let latest = locations.last else { return }
            recentSamples.append(contentsOf: locations)
            if recentSamples.count > bufferSize {
                recentSamples.removeFirst(recentSamples.count - bufferSize)
            }
            latestLocation = latest
            lastAccuracy = latest.horizontalAccuracy
            lastErrorMessage = nil
            isUpdating = true
            locations.forEach { processAcceptedSample(from: $0) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Converts a raw `CLLocation` into a `BoatSample` when ≥1 s has elapsed and appends it to the shared buffer.
    private func processAcceptedSample(from location: CLLocation) {
        let timestamp = location.timestamp.timeIntervalSince1970
        if timestamp - lastAcceptedTimestamp < 1 {
            return
        }
        lastAcceptedTimestamp = timestamp
        let sample = BoatSample(
            timestamp: location.timestamp,
            coordinate: location.coordinate,
            speed: max(location.speed, 0),
            course: location.course >= 0 ? location.course : 0,
            accuracy: location.horizontalAccuracy
        )
        acceptedSamples.append(sample)
        if acceptedSamples.count > acceptedBufferSize {
            acceptedSamples.removeFirst(acceptedSamples.count - acceptedBufferSize)
        }
    }
}
