import CoreLocation

/// Lightweight wrapper for a `CLLocation` that normalizes the fields the uploader needs.
/// Keeping this struct `Hashable` lets buffers deduplicate samples if necessary.
struct BoatSample: Hashable {
    /// Timestamp when Core Location produced the sample.
    let timestamp: Date
    /// Raw WGS84 coordinate.
    let coordinate: CLLocationCoordinate2D
    /// Speed over ground in meters per second (guaranteed non-negative).
    let speed: CLLocationSpeed
    /// Course over ground in degrees (clamped to [0, 360)).
    let course: CLLocationDirection
    /// Horizontal accuracy reported by the device.
    let accuracy: CLLocationAccuracy

    static func == (lhs: BoatSample, rhs: BoatSample) -> Bool {
        lhs.timestamp == rhs.timestamp &&
            lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.speed == rhs.speed &&
            lhs.course == rhs.course &&
            lhs.accuracy == rhs.accuracy
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(speed)
        hasher.combine(course)
        hasher.combine(accuracy)
    }
}
