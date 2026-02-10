//
//  LocationDataManager.swift
//  Naviari_IOS
//
//  Handles GPS authorization, accuracy configuration, and buffering of raw samples.
//

import CoreLocation
import Foundation

@MainActor
final class LocationDataManager: NSObject, ObservableObject {
    @Published private(set) var recentSamples: [CLLocation] = []
    @Published private(set) var latestLocation: CLLocation?
    @Published private(set) var lastAccuracy: CLLocationAccuracy?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isUpdating = false
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

    func stop() {
        manager.stopUpdatingLocation()
        isUpdating = false
    }

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
