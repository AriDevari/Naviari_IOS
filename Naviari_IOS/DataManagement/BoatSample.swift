import CoreLocation

struct BoatSample: Hashable {
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let speed: CLLocationSpeed
    let course: CLLocationDirection
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
