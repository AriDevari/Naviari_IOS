import Foundation

private struct LatLonCoordinate: Decodable, Equatable {
    let lat: Double?
    let lon: Double?
}

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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case status
        case mark_left_lat
        case mark_left_lon
        case mark_right_lat
        case mark_right_lon
        case midpoint_lat
        case midpoint_lon
        case length_m
        case bearing_deg
        case distance_to_first_mark_m
        case bearing_to_first_mark_rad
        case updated_at

        // Newer backend shape: nested coordinate objects.
        case mark_left
        case mark_right
        case midpoint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decodeIfPresent(String.self, forKey: .status)

        let markLeft = try container.decodeIfPresent(LatLonCoordinate.self, forKey: .mark_left)
        let markRight = try container.decodeIfPresent(LatLonCoordinate.self, forKey: .mark_right)
        let midpoint = try container.decodeIfPresent(LatLonCoordinate.self, forKey: .midpoint)

        mark_left_lat = try container.decodeIfPresent(Double.self, forKey: .mark_left_lat) ?? markLeft?.lat
        mark_left_lon = try container.decodeIfPresent(Double.self, forKey: .mark_left_lon) ?? markLeft?.lon
        mark_right_lat = try container.decodeIfPresent(Double.self, forKey: .mark_right_lat) ?? markRight?.lat
        mark_right_lon = try container.decodeIfPresent(Double.self, forKey: .mark_right_lon) ?? markRight?.lon
        midpoint_lat = try container.decodeIfPresent(Double.self, forKey: .midpoint_lat) ?? midpoint?.lat
        midpoint_lon = try container.decodeIfPresent(Double.self, forKey: .midpoint_lon) ?? midpoint?.lon

        length_m = try container.decodeIfPresent(Double.self, forKey: .length_m)
        bearing_deg = try container.decodeIfPresent(Double.self, forKey: .bearing_deg)
        distance_to_first_mark_m = try container.decodeIfPresent(Double.self, forKey: .distance_to_first_mark_m)
        bearing_to_first_mark_rad = try container.decodeIfPresent(Double.self, forKey: .bearing_to_first_mark_rad)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
    }
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

    enum CodingKeys: String, CodingKey {
        case id
        case sequence
        case name
        case description
        case rounding_side
        case type
        case status
        case mark_lat
        case mark_lon
        case distance_to_next_m
        case bearing_to_next_rad
        case updated_at

        // Newer backend shape: nested mark coordinate object.
        case mark
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sequence = try container.decode(Int.self, forKey: .sequence)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        rounding_side = try container.decodeIfPresent(String.self, forKey: .rounding_side)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        status = try container.decodeIfPresent(String.self, forKey: .status)

        let mark = try container.decodeIfPresent(LatLonCoordinate.self, forKey: .mark)
        mark_lat = try container.decodeIfPresent(Double.self, forKey: .mark_lat) ?? mark?.lat
        mark_lon = try container.decodeIfPresent(Double.self, forKey: .mark_lon) ?? mark?.lon

        distance_to_next_m = try container.decodeIfPresent(Double.self, forKey: .distance_to_next_m)
        bearing_to_next_rad = try container.decodeIfPresent(Double.self, forKey: .bearing_to_next_rad)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
    }
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
        case "leftset", "rightset":
            self = .preliminary
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
    let rawStatus: String?
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

    init(
        id: String,
        name: String,
        description: String?,
        type: CourseMarkType,
        status: DefinitionStatus,
        rawStatus: String? = nil,
        markLat: Double?,
        markLon: Double?,
        roundingSide: RoundingSide?,
        bearingToNextRad: Double?,
        distanceToNextM: Double?,
        lineLengthM: Double?,
        lineBearingDeg: Double?,
        lineLeftLat: Double?,
        lineLeftLon: Double?,
        lineRightLat: Double?,
        lineRightLon: Double?,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.status = status
        self.rawStatus = rawStatus
        self.markLat = markLat
        self.markLon = markLon
        self.roundingSide = roundingSide
        self.bearingToNextRad = bearingToNextRad
        self.distanceToNextM = distanceToNextM
        self.lineLengthM = lineLengthM
        self.lineBearingDeg = lineBearingDeg
        self.lineLeftLat = lineLeftLat
        self.lineLeftLon = lineLeftLon
        self.lineRightLat = lineRightLat
        self.lineRightLon = lineRightLon
        self.updatedAt = updatedAt
    }

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

    private static let decimalOnePlaceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
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
                    rawStatus: startLine.status,
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
                    rawStatus: mark.status,
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
                    rawStatus: finishLine.status,
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
        let formatted = Self.decimalOnePlaceFormatter.string(from: NSNumber(value: nauticalMiles))
            ?? String(format: "%.1f", nauticalMiles)
        return "\(formatted) Nm"
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

enum CourseEndpointSide: String, Hashable {
    case left
    case right
}

enum CoursePositionSelection: Hashable {
    case mark(markId: String)
    case startLineEndpoint(lineId: String, side: CourseEndpointSide)
    case finishLineEndpoint(lineId: String, side: CourseEndpointSide)
}

struct CoordinatePoint: Hashable, Codable {
    let lat: Double
    let lon: Double
}

struct CourseMarkPositionTarget: Hashable {
    let markId: String
    let name: String
    let description: String?
    let roundingSide: String?
    let type: String?
    let status: String?
}

struct CourseLinePositionTarget: Hashable {
    let lineId: String
    let name: String
    let description: String?
    let status: String?
    let markLeft: CoordinatePoint?
    let markRight: CoordinatePoint?
}

enum SetPositionTarget: Hashable {
    case mark(CourseMarkPositionTarget)
    case startLine(CourseLinePositionTarget, side: CourseEndpointSide)
    case finishLine(CourseLinePositionTarget, side: CourseEndpointSide)

    var localizedTargetKey: String {
        switch self {
        case .mark:
            return "set_position_target_mark"
        case let .startLine(_, side):
            return side == .left ? "set_position_target_start_left" : "set_position_target_start_right"
        case let .finishLine(_, side):
            return side == .left ? "set_position_target_finish_left" : "set_position_target_finish_right"
        }
    }

    var guideImageAssetName: String {
        switch self {
        case .mark:
            return "SetPositionMarkGuide"
        case .startLine, .finishLine:
            return "SetPositionLineGuide"
        }
    }

    func nextLineStatus() -> String {
        let normalizedStatus: String
        let rawStatus: String
        let side: CourseEndpointSide

        switch self {
        case .mark:
            return "final"
        case let .startLine(target, selectedSide), let .finishLine(target, selectedSide):
            rawStatus = target.status?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "preliminary"
            normalizedStatus = rawStatus.lowercased()
            side = selectedSide
        }

        switch normalizedStatus {
        case "preliminary":
            return side == .left ? "leftSet" : "rightSet"
        case "leftset":
            return side == .right ? "final" : "leftSet"
        case "rightset":
            return side == .left ? "final" : "rightSet"
        case "final":
            return "final"
        default:
            return rawStatus
        }
    }
}
