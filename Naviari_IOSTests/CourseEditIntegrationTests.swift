import XCTest
@testable import Naviari_IOS

/// Unit tests for CourseItemEditTarget Identifiable conformance (S3).
final class CourseEditIntegrationTests: XCTestCase {

    // MARK: - Sample data helpers

    private func sampleMark(id: String = "mark-1") -> CourseMarkItem {
        // Decode from minimal JSON to satisfy Decodable init.
        let json = """
        { "id": "\(id)", "sequence": 1, "name": "Alpha" }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(CourseMarkItem.self, from: json)
    }

    private func sampleLine(id: String = "line-1") -> CourseLine {
        let json = """
        { "id": "\(id)", "name": "Start Line" }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(CourseLine.self, from: json)
    }

        private func sampleCourse() -> RaceCourse {
                let json = """
                {
                    "id": "course-1",
                    "name": "Course",
                    "description": null,
                    "series_id": "series-1",
                    "total_length_m": null,
                    "total_length_nm": null,
                    "is_template": false,
                    "template_source_id": null,
                    "start_line": {
                        "id": "start-line-1",
                        "name": "Start Line",
                        "description": null,
                        "status": "preliminary",
                        "mark_left_lat": null,
                        "mark_left_lon": null,
                        "mark_right_lat": null,
                        "mark_right_lon": null,
                        "midpoint_lat": null,
                        "midpoint_lon": null,
                        "length_m": null,
                        "bearing_deg": null,
                        "distance_to_first_mark_m": null,
                        "bearing_to_first_mark_rad": null,
                        "updated_at": null
                    },
                    "finish_line": {
                        "id": "finish-line-1",
                        "name": "Finish Line",
                        "description": null,
                        "status": "final",
                        "mark_left_lat": null,
                        "mark_left_lon": null,
                        "mark_right_lat": null,
                        "mark_right_lon": null,
                        "midpoint_lat": null,
                        "midpoint_lon": null,
                        "length_m": null,
                        "bearing_deg": null,
                        "distance_to_first_mark_m": null,
                        "bearing_to_first_mark_rad": null,
                        "updated_at": null
                    },
                    "course_marks": [
                        {
                            "id": "mark-1",
                            "sequence": 1,
                            "name": "Alpha",
                            "description": null,
                            "rounding_side": null,
                            "type": "mark",
                            "status": "preliminary",
                            "mark_lat": null,
                            "mark_lon": null,
                            "distance_to_next_m": null,
                            "bearing_to_next_rad": null,
                            "updated_at": null
                        }
                    ]
                }
                """.data(using: .utf8)!
                return try! JSONDecoder().decode(RaceCourse.self, from: json)
        }

    // MARK: - Tests

    func testCourseItemEditTarget_markHasStableId() {
        let mark = sampleMark(id: "mark-abc")
        let t1 = CourseItemEditTarget.mark(mark, courseId: "course-1")
        let t2 = CourseItemEditTarget.mark(mark, courseId: "course-1")
        XCTAssertEqual(t1.id, t2.id,
                       "Two .mark targets with the same mark ID and courseId must have identical .id strings")
    }

    func testCourseItemEditTarget_addMarkHasStableId() {
        let t1 = CourseItemEditTarget.addMark(courseId: "course-1", afterSequence: 3)
        let t2 = CourseItemEditTarget.addMark(courseId: "course-1", afterSequence: 3)
        XCTAssertEqual(t1.id, t2.id,
                       "Two .addMark targets with same courseId + afterSequence must have identical .id strings")
    }

    func testCourseItemEditTarget_distinctTargetsHaveDifferentIds() {
        let mark = sampleMark(id: "mark-abc")
        let line = sampleLine(id: "line-xyz")
        let markTarget = CourseItemEditTarget.mark(mark, courseId: "course-1")
        let lineTarget = CourseItemEditTarget.startLine(line, courseId: "course-1")
        XCTAssertNotEqual(markTarget.id, lineTarget.id,
                          ".mark and .startLine targets must have different .id values")
    }

    func testCourseAddMarkInsertionSequence_startLineReturnsFirstSequence() {
        let course = sampleCourse()

        XCTAssertEqual(courseAddMarkInsertionSequence(after: "start-line-1", in: course), 1)
    }

    func testCourseAddMarkInsertionSequence_markReturnsNextSequence() {
        let course = sampleCourse()

        XCTAssertEqual(courseAddMarkInsertionSequence(after: "mark-1", in: course), 2)
    }

    func testCourseAddMarkInsertionSequence_finishLineReturnsNil() {
        let course = sampleCourse()

        XCTAssertNil(courseAddMarkInsertionSequence(after: "finish-line-1", in: course))
    }
}
