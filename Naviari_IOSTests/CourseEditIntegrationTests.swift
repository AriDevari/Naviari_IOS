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
}
