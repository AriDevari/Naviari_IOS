import Foundation

struct RaceCourse: Decodable, Equatable {
    let id: String
    let name: String?
    let description: String?
    let start_line: CourseLine?
    let finish_line: CourseLine?
    let course_marks: [CourseMarkItem]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case start_line
        case finish_line
        case course_marks
    }
}

struct CourseLine: Decodable, Equatable {
    let id: String
    let name: String?
    let description: String?
    let status: String?
    let mark_left_lat: Double?
    let mark_left_lon: Double?
    let mark_right_lat: Double?
    let mark_right_lon: Double?
    let midpoint_lat: Double?
    let midpoint_lon: Double?
    let length_m: Double?
    let bearing_deg: Double?
    let distance_to_first_mark_m: Double?
    let bearing_to_first_mark_rad: Double?
    let updated_at: String?
}

struct CourseMarkItem: Decodable, Equatable {
    let id: String
    let sequence: Int
    let name: String?
    let description: String?
    let rounding_side: String?
    let type: String?
    let status: String?
    let mark_lat: Double?
    let mark_lon: Double?
    let distance_to_next_m: Double?
    let bearing_to_next_rad: Double?
    let updated_at: String?
}

enum CourseMarkType: String, Decodable, Equatable {
    case start
    case mark
    case finish
}

enum RoundingSide: String, Decodable, Equatable {
    case port
    case starboard
    case gate
}

enum DefinitionStatus: Equatable {
    case final_
    case preliminary
    case none

    init(from rawStatus: String?) {
        switch rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "final":
            self = .final_
        case "preliminary":
            self = .preliminary
        default:
            self = .none
        }
    }
}

struct CourseTimelineItem: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String?
    let type: CourseMarkType
    let status: DefinitionStatus
    let markLat: Double?
    let markLon: Double?
    let roundingSide: RoundingSide?
    let bearingToNextRad: Double?
    let distanceToNextM: Double?
    let lineLengthM: Double?
    let lineBearingDeg: Double?
    let lineLeftLat: Double?
    let lineLeftLon: Double?
    let lineRightLat: Double?
    let lineRightLon: Double?
    let updatedAt: Date?

    private static let iso8601Parsers: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        return [withFractional, withoutFractional]
    }()

    private static let updatedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func buildTimeline(from course: RaceCourse) -> [CourseTimelineItem] {
        var items: [CourseTimelineItem] = []

        if let startLine = course.start_line {
            items.append(
                CourseTimelineItem(
                    id: startLine.id,
                    name: startLine.name ?? "",
                    description: startLine.description,
                    type: .start,
                    status: DefinitionStatus(from: startLine.status),
                    markLat: nil,
                    markLon: nil,
                    roundingSide: nil,
                    bearingToNextRad: nil,
                    distanceToNextM: nil,
                    lineLengthM: startLine.length_m,
                    lineBearingDeg: startLine.bearing_deg,
                    lineLeftLat: startLine.mark_left_lat,
                    lineLeftLon: startLine.mark_left_lon,
                    lineRightLat: startLine.mark_right_lat,
                    lineRightLon: startLine.mark_right_lon,
                    updatedAt: parseUpdatedAt(startLine.updated_at)
                )
            )
        }

        let sortedMarks = course.course_marks.sorted { $0.sequence < $1.sequence }
        for mark in sortedMarks {
            items.append(
                CourseTimelineItem(
                    id: mark.id,
                    name: mark.name ?? "",
                    description: mark.description,
                    type: .mark,
                    status: DefinitionStatus(from: mark.status),
                    markLat: mark.mark_lat,
                    markLon: mark.mark_lon,
                    roundingSide: mark.rounding_side.flatMap { RoundingSide(rawValue: $0.lowercased()) },
                    bearingToNextRad: mark.bearing_to_next_rad,
                    distanceToNextM: mark.distance_to_next_m,
                    lineLengthM: nil,
                    lineBearingDeg: nil,
                    lineLeftLat: nil,
                    lineLeftLon: nil,
                    lineRightLat: nil,
                    lineRightLon: nil,
                    updatedAt: parseUpdatedAt(mark.updated_at)
                )
            )
        }

        if let finishLine = course.finish_line {
            items.append(
                CourseTimelineItem(
                    id: finishLine.id,
                    name: finishLine.name ?? "",
                    description: finishLine.description,
                    type: .finish,
                    status: DefinitionStatus(from: finishLine.status),
                    markLat: nil,
                    markLon: nil,
                    roundingSide: nil,
                    bearingToNextRad: nil,
                    distanceToNextM: nil,
                    lineLengthM: finishLine.length_m,
                    lineBearingDeg: finishLine.bearing_deg,
                    lineLeftLat: finishLine.mark_left_lat,
                    lineLeftLon: finishLine.mark_left_lon,
                    lineRightLat: finishLine.mark_right_lat,
                    lineRightLon: finishLine.mark_right_lon,
                    updatedAt: parseUpdatedAt(finishLine.updated_at)
                )
            )
        }

        return items
    }

    var bearingToNextDeg: String? {
        guard let bearingToNextRad else { return nil }
        let degrees = bearingToNextRad * 180.0 / .pi
        return String(format: "%03.0f°", degrees)
    }

    var distanceToNextNm: String? {
        guard let distanceToNextM else { return nil }
        let nauticalMiles = distanceToNextM / 1852.0
        return String(format: "%.2f nm", nauticalMiles)
    }

    var lineBearingLabel: String? {
        guard let lineBearingDeg else { return nil }
        return String(format: "%03.0f°", lineBearingDeg)
    }

    var lineLengthLabel: String? {
        guard let lineLengthM else { return nil }
        return String(format: "%.0f m", lineLengthM)
    }

    var coordinateLabel: String? {
        guard let markLat, let markLon else { return nil }
        return Self.formatDMS(lat: markLat, lon: markLon)
    }

    var lineLeftCoordinateLabel: String? {
        guard let lineLeftLat, let lineLeftLon else { return nil }
        return Self.formatDMS(lat: lineLeftLat, lon: lineLeftLon)
    }

    var lineRightCoordinateLabel: String? {
        guard let lineRightLat, let lineRightLon else { return nil }
        return Self.formatDMS(lat: lineRightLat, lon: lineRightLon)
    }

    var updatedAtLabel: String? {
        guard let updatedAt else { return nil }
        return Self.updatedAtFormatter.string(from: updatedAt)
    }

    private static func parseUpdatedAt(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        for parser in iso8601Parsers {
            if let date = parser.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static func formatDMS(lat: Double, lon: Double) -> String {
        let latHemisphere = lat >= 0 ? "N" : "S"
        let lonHemisphere = lon >= 0 ? "E" : "W"

        let latDMS = toDMS(abs(lat))
        let lonDMS = toDMS(abs(lon))

        return String(
            format: "%d° %02d' %04.1f\" %@ / %d° %02d' %04.1f\" %@",
            latDMS.degrees,
            latDMS.minutes,
            latDMS.seconds,
            latHemisphere,
            lonDMS.degrees,
            lonDMS.minutes,
            lonDMS.seconds,
            lonHemisphere
        )
    }

    private static func toDMS(_ value: Double) -> (degrees: Int, minutes: Int, seconds: Double) {
        let degrees = Int(value)
        let minutesTotal = (value - Double(degrees)) * 60.0
        let minutes = Int(minutesTotal)
        let seconds = (minutesTotal - Double(minutes)) * 60.0
        return (degrees, minutes, seconds)
    }
}
